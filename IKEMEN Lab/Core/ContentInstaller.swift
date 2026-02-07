import Foundation
import AppKit
import os.log

// MARK: - Content Installer

/// Handles installation of characters, stages, and screenpacks from archives or folders.
/// Manages archive extraction, content type detection, screenpack redirection, and portrait validation.
public final class ContentInstaller {
    
    // MARK: - Singleton
    
    public static let shared = ContentInstaller()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ikemenlab", category: "ContentInstaller")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Content Installation
    
    /// Detect archive format by file content (magic bytes)
    private func detectArchiveFormat(from fileURL: URL) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? fileHandle.close() }
        
        guard let headerData = try? fileHandle.read(upToCount: 8) else { return nil }
        let bytes = [UInt8](headerData)
        
        // ZIP: PK (0x50 0x4B)
        if bytes.count >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B {
            return "zip"
        }
        
        // RAR: Rar! (0x52 0x61 0x72 0x21)
        if bytes.count >= 4 && bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 && bytes[3] == 0x21 {
            return "rar"
        }
        
        // 7z: 7z (0x37 0x7A 0xBC 0xAF 0x27 0x1C)
        if bytes.count >= 6 && bytes[0] == 0x37 && bytes[1] == 0x7A && bytes[2] == 0xBC && bytes[3] == 0xAF {
            return "7z"
        }
        
        // ACE: **ACE** at offset 7 (0x2A 0x2A 0x41 0x43 0x45 0x2A 0x2A)
        if bytes.count >= 14, bytes[7] == 0x2A, bytes[8] == 0x2A, bytes[9] == 0x41, bytes[10] == 0x43, bytes[11] == 0x45, bytes[12] == 0x2A, bytes[13] == 0x2A {
            return "ace"
        }
        
        return nil
    }
    
    /// Install content from an archive file (zip, rar, 7z - auto-detects character or stage)
    public func installContent(from archiveURL: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Create temp directory
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Detect format by magic bytes first, fall back to extension
        let ext = detectArchiveFormat(from: archiveURL) ?? archiveURL.pathExtension.lowercased()
        
        // Extract based on file type
        try extractArchive(from: archiveURL, to: tempDir, format: ext)
        
        // Find the extracted content
        let extractedItems = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.isDirectoryKey])
        
        // Skip __MACOSX folder if present
        let contentItems = extractedItems.filter { !$0.lastPathComponent.hasPrefix("__MACOSX") && !$0.lastPathComponent.hasPrefix(".") }
        
        guard let firstItem = contentItems.first else {
            throw IkemenError.installFailed("Archive appears to be empty")
        }
        
        // Determine if it's a directory or files
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: firstItem.path, isDirectory: &isDirectory)
        
        let contentFolder: URL
        if isDirectory.boolValue {
            contentFolder = firstItem
        } else {
            // Files are at root level, use temp dir as content folder
            contentFolder = tempDir
        }
        
        return try installContentFolder(from: contentFolder, to: workingDir, overwrite: overwrite)
    }
    
    /// Extract archive to destination
    private func extractArchive(from archiveURL: URL, to destDir: URL, format: String) throws {
        let process = Process()
        
        switch format {
        case "zip":
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", archiveURL.path, destDir.path]
            
        case "rar":
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/unrar")
            process.arguments = ["x", "-y", archiveURL.path, destDir.path + "/"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
        case "7z":
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
            process.arguments = ["x", "-o\(destDir.path)", "-y", archiveURL.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
        case "ace":
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/unace")
            process.arguments = ["x", "-y", archiveURL.path, destDir.path + "/"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
        default:
            throw IkemenError.installFailed("Unsupported archive format: \(format). Supported: zip, rar, 7z, ace")
        }
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            switch format {
            case "rar":
                throw IkemenError.installFailed("Failed to extract RAR file. Make sure unrar is installed (brew install rar)")
            case "7z":
                throw IkemenError.installFailed("Failed to extract 7z file. Make sure p7zip is installed (brew install p7zip)")
            case "ace":
                throw IkemenError.installFailed("Failed to extract ACE file. Make sure unace is installed (brew install unace)")
            default:
                throw IkemenError.installFailed("Failed to extract \(format) file")
            }
        }
    }
    
    /// Install content from a folder (auto-detects character, stage, or screenpack)
    public func installContentFolder(from folderURL: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        // Scan the folder to determine content type
        let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // First check for screenpack (system.def with fight/select sections)
        let systemDefFile = contents.first { $0.lastPathComponent.lowercased() == "system.def" }
        if let systemDef = systemDefFile,
           let defContent = try? String(contentsOf: systemDef, encoding: .utf8).lowercased() {
            // Screenpack system.def has [Files] section referencing select, fight, etc.
            let hasScreenpackFiles = defContent.contains("[files]") &&
                                    (defContent.contains("select") || defContent.contains("fight") || defContent.contains("title"))
            // Also check for [Title Info] or [Select Info] sections which are screenpack-specific
            let hasScreenpackSections = defContent.contains("[title info]") || 
                                       defContent.contains("[select info]") ||
                                       defContent.contains("[vs screen]") ||
                                       defContent.contains("[option info]")
            
            if hasScreenpackFiles || hasScreenpackSections {
                return try installScreenpack(from: folderURL, to: workingDir, overwrite: overwrite)
            }
        }
        
        // Read DEF file to determine content type
        // Filter out storyboard .def files (intros/endings with [SceneDef])
        var characterDefFile: URL? = nil
        var stageDefFile: URL? = nil
        
        for defFile in defFiles {
            if let defContent = try? String(contentsOf: defFile, encoding: .utf8).lowercased() {
                // Skip storyboards (intros/endings) - they have [SceneDef] section
                if defContent.contains("[scenedef]") {
                    continue
                }
                
                // Character DEF files have [Files] section with cmd, cns, air, etc.
                let isCharacterFile = defContent.contains("[files]") && 
                                     (defContent.contains(".cmd") || defContent.contains(".cns") || defContent.contains(".air"))
                
                if isCharacterFile {
                    characterDefFile = defFile
                    break  // Found a character, use it
                }
                
                // Stage DEF files have [StageInfo] or [BGdef] section
                let isStageFile = defContent.contains("[stageinfo]") || 
                                  defContent.contains("[bgdef]") ||
                                  defContent.contains("[bg ")
                
                if isStageFile {
                    stageDefFile = defFile
                    // Don't break - keep looking for characters (they take priority)
                }
            }
        }
        
        // Install based on what we found (character takes priority over stage)
        if characterDefFile != nil {
            return try installCharacter(from: folderURL, to: workingDir, overwrite: overwrite)
        }
        
        if stageDefFile != nil {
            return try installStage(from: folderURL, to: workingDir, overwrite: overwrite)
        }
        
        // Fallback: check for character-specific files
        let fileNames = contents.map { $0.lastPathComponent.lowercased() }
        let hasCharacterFiles = fileNames.contains { name in
            name.hasSuffix(".air") || name.hasSuffix(".cmd") || name.hasSuffix(".cns")
        }
        
        if hasCharacterFiles {
            return try installCharacter(from: folderURL, to: workingDir, overwrite: overwrite)
        } else if !defFiles.isEmpty {
            // Default to stage if only has .def and .sff
            return try installStage(from: folderURL, to: workingDir, overwrite: overwrite)
        }
        
        throw IkemenError.invalidContent("Could not determine content type. Ensure the folder contains character files (.def, .sff, .air, .cmd, .cns) or stage files (.def, .sff).")
    }
    
    // MARK: - Screenpack Installation
    
    /// Install a screenpack from a folder (copy to data/ directory)
    public func installScreenpack(from source: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        let dataDir = workingDir.appendingPathComponent("data")
        let screenpackName = source.lastPathComponent
        let destPath = dataDir.appendingPathComponent(screenpackName)
        
        // Try to get the display name from system.def
        var displayName = screenpackName
        let systemDefPath = source.appendingPathComponent("system.def")
        if let parsed = DEFParser.parse(url: systemDefPath) {
            displayName = parsed.name ?? parsed.value(for: "name", inSection: "info") ?? screenpackName
        }
        
        // Check if screenpack already exists
        let isUpdate = fileManager.fileExists(atPath: destPath.path)
        if isUpdate {
            if !overwrite {
                throw IkemenError.duplicateContent(displayName)
            }
            // Remove old version
            try fileManager.removeItem(at: destPath)
        }
        
        // Copy to data directory
        try fileManager.copyItem(at: source, to: destPath)
        
        // Redirect screenpack to use the global select.def instead of its own
        redirectScreenpackToGlobalSelectDef(screenpackPath: destPath)
        
        let action = isUpdate ? "Updated" : "Installed"
        return "\(action) screenpack: \(displayName)"
    }
    
    /// Modify a screenpack's system.def to use the global select.def
    /// This ensures all screenpacks share the same character roster
    public func redirectScreenpackToGlobalSelectDef(screenpackPath: URL) {
        let systemDefPath = screenpackPath.appendingPathComponent("system.def")
        
        guard fileManager.fileExists(atPath: systemDefPath.path),
              var content = try? String(contentsOf: systemDefPath, encoding: .utf8) else {
            return
        }
        
        // Find and replace select.def references to point to the global one
        // Common patterns: "select = select.def" or "select=select.def"
        // Replace with path relative from data/screenpack/ back to data/select.def
        let patterns = [
            (try? NSRegularExpression(pattern: #"^(\s*select\s*=\s*)select\.def"#, options: [.anchorsMatchLines, .caseInsensitive])),
            (try? NSRegularExpression(pattern: #"^(\s*select\s*=\s*)["\']?select\.def["\']?"#, options: [.anchorsMatchLines, .caseInsensitive]))
        ]
        
        var modified = false
        for pattern in patterns.compactMap({ $0 }) {
            let range = NSRange(content.startIndex..., in: content)
            if pattern.firstMatch(in: content, range: range) != nil {
                content = pattern.stringByReplacingMatches(in: content, range: range, withTemplate: "$1../select.def")
                modified = true
            }
        }
        
        if modified {
            do {
                try content.write(to: systemDefPath, atomically: true, encoding: .utf8)
                Self.logger.info("Redirected screenpack to global select.def: \(screenpackPath.lastPathComponent)")
            } catch {
                Self.logger.error("Failed to write screenpack redirect: \(error.localizedDescription)")
            }
        }
    }
    
    /// Redirect all installed screenpacks to use the global select.def
    /// Call this to fix existing screenpacks that have their own select.def
    public func redirectAllScreenpacksToGlobalSelectDef(in workingDir: URL) -> Int {
        let dataDir = workingDir.appendingPathComponent("data")
        var fixedCount = 0
        
        guard let contents = try? fileManager.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return 0
        }
        
        for item in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let systemDefPath = item.appendingPathComponent("system.def")
                if fileManager.fileExists(atPath: systemDefPath.path) {
                    // Check if this screenpack has its own select.def that might be in use
                    let screenpackSelectDef = item.appendingPathComponent("select.def")
                    if fileManager.fileExists(atPath: screenpackSelectDef.path) {
                        redirectScreenpackToGlobalSelectDef(screenpackPath: item)
                        fixedCount += 1
                    }
                }
            }
        }
        
        return fixedCount
    }
    
    /// Sync characters from the chars/ folder to a screenpack's select.def
    @available(*, deprecated, message: "Use redirectScreenpackToGlobalSelectDef instead")
    public func syncCharactersToScreenpack(selectDefPath: URL, workingDir: URL) {
        let charsDir = workingDir.appendingPathComponent("chars")
        
        guard let charFolders = try? fileManager.contentsOfDirectory(at: charsDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for charFolder in charFolders {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: charFolder.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            
            let charName = charFolder.lastPathComponent
            
            // Skip hidden folders
            if charName.hasPrefix(".") { continue }
            
            // Find the def entry for this character
            let defEntry = findCharacterDefEntry(charName: charName, in: charFolder)
            do {
                try SelectDefManager.shared.addCharacterToSelectDefFile(defEntry, selectDefPath: selectDefPath)
            } catch {
                Self.logger.warning("Failed to sync character \(charName) to screenpack select.def: \(error.localizedDescription)")
            }
        }
    }
    
    /// Sync all characters to all screenpack select.def files
    @available(*, deprecated, message: "Use redirectAllScreenpacksToGlobalSelectDef instead")
    public func syncAllScreenpacks(in workingDir: URL) -> Int {
        let dataDir = workingDir.appendingPathComponent("data")
        var syncedCount = 0
        
        guard let contents = try? fileManager.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return 0
        }
        
        for item in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let screenpackDir = item
                let systemDef = screenpackDir.appendingPathComponent("system.def")
                if fileManager.fileExists(atPath: systemDef.path) {
                    redirectScreenpackToGlobalSelectDef(screenpackPath: screenpackDir)
                    syncedCount += 1
                }
            }
        }
        
        Self.logger.info("Redirected \(syncedCount) screenpack(s) to global select.def")
        return syncedCount
    }
    
    // MARK: - Character Installation
    
    /// Install a character from a folder
    public func installCharacter(from source: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        let charsDir = workingDir.appendingPathComponent("chars")
        
        // Find the .def file to get the proper character name
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // Determine character name from DEF file or folder
        var charName = source.lastPathComponent
        var displayName = charName
        
        if let defFile = defFiles.first {
            // Use DEF filename as the folder name (standard convention)
            charName = defFile.deletingPathExtension().lastPathComponent
            
            // Try to read the "name" field from DEF file for display
            if let parsed = DEFParser.parse(url: defFile) {
                displayName = parsed.name ?? displayName
            }
        }
        
        // Sanitize the folder name for consistency
        var sanitizedName = FolderSanitizer.shared.sanitizeFolderName(charName)
        var destPath = charsDir.appendingPathComponent(sanitizedName)
        
        // Check if destination exists - distinguish between update vs collision
        var isUpdate = false
        if fileManager.fileExists(atPath: destPath.path) {
            // Check if this is the same character (same display name) or a different one
            let existingDefPath = destPath.appendingPathComponent("\(sanitizedName).def")
            var isSameCharacter = false
            
            if fileManager.fileExists(atPath: existingDefPath.path),
               let existingParsed = DEFParser.parse(url: existingDefPath) {
                let existingName = existingParsed.name ?? sanitizedName
                isSameCharacter = (existingName.lowercased() == displayName.lowercased())
            }
            
            if isSameCharacter {
                // Duplicate detected!
                if !overwrite {
                    throw IkemenError.duplicateContent(displayName)
                }
                
                // True update - replace existing
                isUpdate = true
                try fileManager.removeItem(at: destPath)
                ImageCache.shared.clearCharacter(sanitizedName)
            } else {
                // Collision - different character with same sanitized name
                // Append number to make unique
                var counter = 2
                var uniqueName = "\(sanitizedName)_\(counter)"
                var uniquePath = charsDir.appendingPathComponent(uniqueName)
                while fileManager.fileExists(atPath: uniquePath.path) {
                    counter += 1
                    uniqueName = "\(sanitizedName)_\(counter)"
                    uniquePath = charsDir.appendingPathComponent(uniqueName)
                }
                sanitizedName = uniqueName
                destPath = uniquePath
            }
        }
        
        // Copy to chars directory
        try fileManager.copyItem(at: source, to: destPath)
        
        // Find the .def file to determine the correct select.def entry
        let defEntry = findCharacterDefEntry(charName: sanitizedName, in: destPath)
        
        // Add to select.def if not already present
        if !isUpdate {
            try SelectDefManager.shared.addCharacterToSelectDef(defEntry, in: workingDir)
        }
        
        // Index in metadata database
        if let contents = try? fileManager.contentsOfDirectory(at: destPath, includingPropertiesForKeys: nil),
           let defFile = contents.first(where: { $0.pathExtension.lowercased() == "def" }) {
            let info = CharacterInfo(directory: destPath, defFile: defFile)
            do {
                try MetadataStore.shared.indexCharacter(info)
            } catch {
                Self.logger.warning("Failed to index character metadata: \(error.localizedDescription)")
            }
        }
        
        // Notify that content has changed
        NotificationCenter.default.post(name: .contentChanged, object: nil)
        
        // Check for portrait issues and generate warning
        var warnings = validateCharacterPortrait(in: destPath)
        
        // Note if folder was renamed
        if sanitizedName != charName {
            warnings.append("Renamed from '\(charName)'")
        }
        
        if !warnings.isEmpty {
            return "Installed character: \(displayName) ⚠️ \(warnings.joined(separator: ", "))"
        }
        return "Installed character: \(displayName)"
    }
    
    /// Find the correct select.def entry for a character
    /// IKEMEN GO expects either:
    /// - Just folder name (e.g., "kfm") if folder/folder.def exists with exact case match
    /// - Explicit path (e.g., "Bbhood/BBHood.def") if the def filename differs from folder name
    /// NOTE: Skips storyboard .def files (intros/endings with [SceneDef])
    public func findCharacterDefEntry(charName: String, in charPath: URL) -> String {
        guard let contents = try? fileManager.contentsOfDirectory(at: charPath, includingPropertiesForKeys: nil) else {
            return charName
        }
        
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // Filter out storyboard .def files (they have [SceneDef] section)
        let characterDefFiles = defFiles.filter { defFile in
            guard let content = try? String(contentsOf: defFile, encoding: .utf8).lowercased() else {
                return false
            }
            // Must have [Files] section and NOT have [SceneDef]
            return content.contains("[files]") && !content.contains("[scenedef]")
        }
        
        // If no character defs found, fall back to all defs (for safety)
        let candidateDefs = characterDefFiles.isEmpty ? defFiles : characterDefFiles
        
        // Look for a .def file with EXACT case match to folder name
        // e.g., folder "kfm" needs "kfm.def" (not "KFM.def" or "Kfm.def")
        let exactMatchDef = candidateDefs.first { 
            $0.deletingPathExtension().lastPathComponent == charName 
        }
        
        if exactMatchDef != nil {
            // Exact match - can use just the folder name
            return charName
        }
        
        // No exact match - need explicit path
        // Prefer a def file that matches case-insensitively, otherwise use first def
        let caseInsensitiveMatch = candidateDefs.first { 
            $0.deletingPathExtension().lastPathComponent.lowercased() == charName.lowercased() 
        }
        
        if let defFile = caseInsensitiveMatch ?? candidateDefs.first {
            return "\(charName)/\(defFile.lastPathComponent)"
        }
        
        return charName
    }
    
    // MARK: - Stage Installation
    
    /// Install a stage from a folder
    public func installStage(from source: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        let stagesDir = workingDir.appendingPathComponent("stages")
        
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        var installedStages: [String] = []
        
        // Filter relevant files
        let relevantFiles = contents.filter { 
            let ext = $0.pathExtension.lowercased()
            return ["def", "sff", "mp3", "ogg", "wav"].contains(ext)
        }
        
        // Check for duplicates before installing
        if !overwrite {
            for file in relevantFiles {
                let destPath = stagesDir.appendingPathComponent(file.lastPathComponent)
                if fileManager.fileExists(atPath: destPath.path) {
                    throw IkemenError.duplicateContent(file.lastPathComponent)
                }
            }
        }
        
        for file in contents {
            let ext = file.pathExtension.lowercased()
            
            // IMPORTANT: Do NOT sanitize stage filenames!
            // Stage .def files contain internal references to .sff files by exact name.
            // Renaming breaks these references and causes IKEMEN GO to crash.
            // Example: Green_Might_Hulk.def references "stages/Green_Might_(Hulk).sff"
            // If we rename the .sff, the .def can't find it.
            var destFileName = file.lastPathComponent
            
            // Sanitize DEF files to avoid select.def parsing issues (commas are separators)
            // We only sanitize the .def file itself, not resources (sff/snd) which are referenced by exact name
            if ext == "def" {
                destFileName = destFileName.replacingOccurrences(of: ",", with: "_")
            }
            
            let destPath = stagesDir.appendingPathComponent(destFileName)
            
            // Check for collision with existing file - if exists, replace it (update)
            if fileManager.fileExists(atPath: destPath.path) {
                try fileManager.removeItem(at: destPath)
            }
            
            try fileManager.copyItem(at: file, to: destPath)
            
            if ext == "def" {
                let stageName = (destFileName as NSString).deletingPathExtension
                installedStages.append(stageName)
                // Clear cached images
                ImageCache.shared.clearStage(stageName)
                
                // Index in metadata database
                let info = StageInfo(defFile: destPath)
                do {
                    try MetadataStore.shared.indexStage(info)
                } catch {
                    Self.logger.warning("Failed to index stage metadata: \(error.localizedDescription)")
                }
            }
        }
        
        // Add stages to select.def
        for stageName in installedStages {
            try SelectDefManager.shared.addStageToSelectDef(stageName, in: workingDir)
        }
        
        // Notify that content has changed
        NotificationCenter.default.post(name: .contentChanged, object: nil)
        
        var result: String
        if installedStages.count == 1 {
            result = "Installed stage: \(installedStages[0])"
        } else if installedStages.count > 1 {
            result = "Installed \(installedStages.count) stages: \(installedStages.joined(separator: ", "))"
        } else {
            result = "No stages found to install"
        }
        
        return result
    }
    
    // MARK: - Validation
    
    /// Validate character portrait and return any warnings
    public func validateCharacterPortrait(in charPath: URL) -> [String] {
        var warnings: [String] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: charPath, includingPropertiesForKeys: nil) else {
            return warnings
        }
        
        let sffFiles = contents.filter { $0.pathExtension.lowercased() == "sff" }
        
        guard let sffFile = sffFiles.first else {
            warnings.append("No sprite file found")
            return warnings
        }
        
        if let portraitInfo = checkSFFPortraitDimensions(sffFile) {
            if portraitInfo.width > 200 || portraitInfo.height > 200 {
                warnings.append("Large portrait (\(portraitInfo.width)x\(portraitInfo.height))")
            } else if portraitInfo.width == 0 || portraitInfo.height == 0 {
                warnings.append("Missing portrait sprite")
            }
        }
        
        return warnings
    }
    
    /// Check SFF file for portrait sprite dimensions
    private func checkSFFPortraitDimensions(_ sffURL: URL) -> (width: Int, height: Int)? {
        guard let data = try? Data(contentsOf: sffURL) else { return nil }
        guard data.count > 32 else { return nil }
        
        let signature = String(data: data[0..<12], encoding: .ascii) ?? ""
        
        if signature.hasPrefix("ElecbyteSpr") {
            return parseSFFv1PortraitDimensions(data)
        }
        
        return nil
    }
    
    /// Parse SFF v1 to find portrait sprite dimensions
    private func parseSFFv1PortraitDimensions(_ data: Data) -> (width: Int, height: Int)? {
        guard data.count > 32 else { return nil }
        
        func readUInt16(at offset: Int) -> UInt16 {
            guard offset + 1 < data.count else { return 0 }
            return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        }
        
        func readUInt32(at offset: Int) -> UInt32 {
            guard offset + 3 < data.count else { return 0 }
            return UInt32(data[offset]) |
                   (UInt32(data[offset + 1]) << 8) |
                   (UInt32(data[offset + 2]) << 16) |
                   (UInt32(data[offset + 3]) << 24)
        }
        
        let numImages = readUInt32(at: 20)
        let firstSubfileOffset = readUInt32(at: 24)
        
        guard numImages > 0, firstSubfileOffset < data.count else { return nil }
        
        var offset = Int(firstSubfileOffset)
        
        for _ in 0..<min(Int(numImages), 1000) {
            guard offset + 20 <= data.count else { break }
            
            let nextOffset = readUInt32(at: offset)
            let groupNum = readUInt16(at: offset + 12)
            let imageNum = readUInt16(at: offset + 14)
            
            if groupNum == 9000 && imageNum == 0 {
                let pcxOffset = offset + 32
                if pcxOffset + 12 <= data.count {
                    let xmin = readUInt16(at: pcxOffset + 4)
                    let ymin = readUInt16(at: pcxOffset + 6)
                    let xmax = readUInt16(at: pcxOffset + 8)
                    let ymax = readUInt16(at: pcxOffset + 10)
                    
                    let width = Int(xmax) - Int(xmin) + 1
                    let height = Int(ymax) - Int(ymin) + 1
                    
                    if width > 0 && height > 0 && width < 2000 && height < 2000 {
                        return (width, height)
                    }
                }
            }
            
            if nextOffset == 0 || nextOffset <= offset { break }
            offset = Int(nextOffset)
        }
        
        return nil
    }
}
