import Foundation
import AppKit

// MARK: - Content Manager

/// Manages installation, validation, and organization of MUGEN/Ikemen content
/// Handles characters, stages, and select.def editing
public final class ContentManager {
    
    // MARK: - Singleton
    
    public static let shared = ContentManager()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Content Installation
    
    /// Install content from an archive file (zip, rar, 7z - auto-detects character or stage)
    public func installContent(from archiveURL: URL, to workingDir: URL) throws -> String {
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Create temp directory
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let ext = archiveURL.pathExtension.lowercased()
        
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
        
        return try installContentFolder(from: contentFolder, to: workingDir)
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
            
        default:
            throw IkemenError.installFailed("Unsupported archive format: \(format). Supported: zip, rar, 7z")
        }
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            switch format {
            case "rar":
                throw IkemenError.installFailed("Failed to extract RAR file. Make sure unrar is installed (brew install rar)")
            case "7z":
                throw IkemenError.installFailed("Failed to extract 7z file. Make sure p7zip is installed (brew install p7zip)")
            default:
                throw IkemenError.installFailed("Failed to extract \(format) file")
            }
        }
    }
    
    /// Install content from a folder (auto-detects character, stage, or screenpack)
    public func installContentFolder(from folderURL: URL, to workingDir: URL) throws -> String {
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
                return try installScreenpack(from: folderURL, to: workingDir)
            }
        }
        
        // Read DEF file to determine content type
        for defFile in defFiles {
            if let defContent = try? String(contentsOf: defFile, encoding: .utf8).lowercased() {
                // Stage DEF files have [StageInfo] section or bgdef/spr entries
                let isStageFile = defContent.contains("[stageinfo]") || 
                                  defContent.contains("[bg ") ||
                                  defContent.contains("bgdef") ||
                                  (defContent.contains("spr") && !defContent.contains("[files]"))
                
                // Character DEF files have [Files] section with cmd, cns, air, etc.
                let isCharacterFile = defContent.contains("[files]") && 
                                     (defContent.contains(".cmd") || defContent.contains(".cns") || defContent.contains(".air"))
                
                if isStageFile && !isCharacterFile {
                    return try installStage(from: folderURL, to: workingDir)
                } else if isCharacterFile {
                    return try installCharacter(from: folderURL, to: workingDir)
                }
            }
        }
        
        // Fallback: check for character-specific files
        let fileNames = contents.map { $0.lastPathComponent.lowercased() }
        let hasCharacterFiles = fileNames.contains { name in
            name.hasSuffix(".air") || name.hasSuffix(".cmd") || name.hasSuffix(".cns")
        }
        
        if hasCharacterFiles {
            return try installCharacter(from: folderURL, to: workingDir)
        } else if !defFiles.isEmpty {
            // Default to stage if only has .def and .sff
            return try installStage(from: folderURL, to: workingDir)
        }
        
        throw IkemenError.invalidContent("Could not determine content type. Ensure the folder contains character files (.def, .sff, .air, .cmd, .cns) or stage files (.def, .sff).")
    }
    
    // MARK: - Screenpack Installation
    
    /// Install a screenpack from a folder (copy to data/ directory)
    public func installScreenpack(from source: URL, to workingDir: URL) throws -> String {
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
            // Remove old version
            try fileManager.removeItem(at: destPath)
        }
        
        // Copy to data directory
        try fileManager.copyItem(at: source, to: destPath)
        
        // If the screenpack has a select.def, sync existing characters to it
        let screenpackSelectDef = destPath.appendingPathComponent("select.def")
        if fileManager.fileExists(atPath: screenpackSelectDef.path) {
            syncCharactersToScreenpack(selectDefPath: screenpackSelectDef, workingDir: workingDir)
        }
        
        let action = isUpdate ? "Updated" : "Installed"
        return "\(action) screenpack: \(displayName)"
    }
    
    /// Sync characters from the chars/ folder to a screenpack's select.def
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
            if let defEntry = findCharacterDefEntry(in: charFolder) {
                try? addCharacterToSelectDefFile(defEntry, selectDefPath: selectDefPath)
            }
        }
    }
    
    /// Sync all characters to all screenpack select.def files
    public func syncAllScreenpacks(in workingDir: URL) -> Int {
        let dataDir = workingDir.appendingPathComponent("data")
        var syncedCount = 0
        
        guard let contents = try? fileManager.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return 0
        }
        
        for item in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                let screenpackSelectDef = item.appendingPathComponent("select.def")
                if fileManager.fileExists(atPath: screenpackSelectDef.path) {
                    syncCharactersToScreenpack(selectDefPath: screenpackSelectDef, workingDir: workingDir)
                    syncedCount += 1
                }
            }
        }
        
        print("Synced characters to \(syncedCount) screenpack(s)")
        return syncedCount
    }
    
    // MARK: - Character Installation
    
    /// Install a character from a folder
    public func installCharacter(from source: URL, to workingDir: URL) throws -> String {
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
        
        let destPath = charsDir.appendingPathComponent(charName)
        
        // Check if character already exists
        let isUpdate = fileManager.fileExists(atPath: destPath.path)
        if isUpdate {
            // Remove old version
            try fileManager.removeItem(at: destPath)
            // Clear cached images
            ImageCache.shared.clearCharacter(charName)
        }
        
        // Copy to chars directory
        try fileManager.copyItem(at: source, to: destPath)
        
        // Find the .def file to determine the correct select.def entry
        let defEntry = findCharacterDefEntry(charName: charName, in: destPath)
        
        // Add to select.def if not already present
        if !isUpdate {
            try addCharacterToSelectDef(defEntry, in: workingDir)
        }
        
        // Check for portrait issues and generate warning
        let warnings = validateCharacterPortrait(in: destPath)
        
        if !warnings.isEmpty {
            return "Installed character: \(displayName) ⚠️ \(warnings.joined(separator: ", "))"
        }
        return "Installed character: \(displayName)"
    }
    
    /// Find the correct select.def entry for a character folder
    private func findCharacterDefEntry(in charPath: URL) -> String? {
        let charName = charPath.lastPathComponent
        return findCharacterDefEntry(charName: charName, in: charPath)
    }
    
    /// Find the correct select.def entry for a character
    private func findCharacterDefEntry(charName: String, in charPath: URL) -> String {
        guard let contents = try? fileManager.contentsOfDirectory(at: charPath, includingPropertiesForKeys: nil) else {
            return charName
        }
        
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // If there's exactly one .def file and its name doesn't match the folder
        if defFiles.count == 1, let defFile = defFiles.first {
            let defName = defFile.deletingPathExtension().lastPathComponent
            if defName.lowercased() != charName.lowercased() {
                return "\(charName)/\(defFile.lastPathComponent)"
            }
        }
        
        // If there's a .def file matching the folder name, just use folder name
        let matchingDef = defFiles.first { $0.deletingPathExtension().lastPathComponent.lowercased() == charName.lowercased() }
        if matchingDef != nil {
            return charName
        }
        
        // If no exact match but there are def files, use the first one
        if let firstDef = defFiles.first {
            return "\(charName)/\(firstDef.lastPathComponent)"
        }
        
        return charName
    }
    
    // MARK: - Stage Installation
    
    /// Install a stage from a folder
    public func installStage(from source: URL, to workingDir: URL) throws -> String {
        let stagesDir = workingDir.appendingPathComponent("stages")
        
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        var installedStages: [String] = []
        
        for file in contents {
            let ext = file.pathExtension.lowercased()
            let destPath = stagesDir.appendingPathComponent(file.lastPathComponent)
            
            // Remove existing file if present
            if fileManager.fileExists(atPath: destPath.path) {
                try fileManager.removeItem(at: destPath)
            }
            
            try fileManager.copyItem(at: file, to: destPath)
            
            if ext == "def" {
                let stageName = file.deletingPathExtension().lastPathComponent
                installedStages.append(stageName)
                // Clear cached images
                ImageCache.shared.clearStage(stageName)
            }
        }
        
        // Add stages to select.def
        for stageName in installedStages {
            try addStageToSelectDef(stageName, in: workingDir)
        }
        
        if installedStages.count == 1 {
            return "Installed stage: \(installedStages[0])"
        } else if installedStages.count > 1 {
            return "Installed \(installedStages.count) stages: \(installedStages.joined(separator: ", "))"
        } else {
            return "No stages found to install"
        }
    }
    
    // MARK: - select.def Management
    
    /// Add a character to all select.def files (main and screenpacks)
    public func addCharacterToSelectDef(_ charEntry: String, in workingDir: URL) throws {
        // Add to main select.def
        let mainSelectDef = workingDir.appendingPathComponent("data/select.def")
        try addCharacterToSelectDefFile(charEntry, selectDefPath: mainSelectDef)
        
        // Also add to all screenpack select.def files
        let dataDir = workingDir.appendingPathComponent("data")
        if let contents = try? fileManager.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: [.isDirectoryKey]) {
            for item in contents {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    let screenpackSelectDef = item.appendingPathComponent("select.def")
                    if fileManager.fileExists(atPath: screenpackSelectDef.path) {
                        try? addCharacterToSelectDefFile(charEntry, selectDefPath: screenpackSelectDef)
                    }
                }
            }
        }
    }
    
    /// Add a character to a specific select.def file
    private func addCharacterToSelectDefFile(_ charEntry: String, selectDefPath: URL) throws {
        guard fileManager.fileExists(atPath: selectDefPath.path) else {
            print("Warning: select.def not found at \(selectDefPath.path)")
            return
        }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        // Check if character is already in the file
        // Handle both forward slashes (Unix) and backslashes (Windows screenpacks)
        let folderName = charEntry.contains("/") ? String(charEntry.split(separator: "/").first!) : charEntry
        // Match folder name followed by slash (either direction), whitespace, comma, or end of line
        let charPattern = "(?m)^\\s*\(NSRegularExpression.escapedPattern(for: folderName))(/|\\\\|\\s|,|$)"
        if let regex = try? NSRegularExpression(pattern: charPattern, options: .caseInsensitive),
           regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
            print("Character \(charEntry) already in \(selectDefPath.lastPathComponent)")
            return
        }
        
        // Find the [Characters] section and add the character right after the header
        // This puts new characters at the top of the roster where they're easy to find
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        var insertedCharacter = false
        
        for line in lines {
            newLines.append(line)
            
            // Insert right after [Characters] header
            if !insertedCharacter && line.trimmingCharacters(in: .whitespaces).lowercased() == "[characters]" {
                newLines.append(charEntry)
                insertedCharacter = true
            }
        }
        
        content = newLines.joined(separator: "\n")
        try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
        print("Added \(charEntry) to \(selectDefPath.path)")
    }
    
    /// Add a stage to select.def
    public func addStageToSelectDef(_ stageName: String, in workingDir: URL) throws {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path) else { return }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        let stageEntry = "stages/\(stageName).def"
        if content.contains(stageEntry) { return }
        
        // Find [ExtraStages] section and add the stage
        if let range = content.range(of: "[ExtraStages]", options: .caseInsensitive) {
            if let lineEnd = content.range(of: "\n", range: range.upperBound..<content.endIndex) {
                let insertPosition = lineEnd.upperBound
                content.insert(contentsOf: "\(stageEntry)\n", at: insertPosition)
                try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
                print("Added stage \(stageName) to select.def")
            }
        }
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
