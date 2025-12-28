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
    
    // MARK: - Folder Name Sanitization
    
    /// Sanitize a folder name to be filesystem-friendly and consistent
    /// Rules:
    /// - Replace spaces with underscores
    /// - Remove special characters except hyphens and underscores
    /// - Collapse multiple underscores/hyphens
    /// - Trim leading/trailing underscores/hyphens
    /// - Convert to Title_Case for consistency (preserving acronyms and hyphenated words)
    public func sanitizeFolderName(_ name: String) -> String {
        var sanitized = name
        
        // Replace spaces with underscores
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        
        // Remove characters that aren't alphanumeric, underscore, or hyphen
        sanitized = sanitized.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
            scalar == "_" ||
            scalar == "-"
        }.map { String($0) }.joined()
        
        // Collapse multiple underscores/hyphens into single underscore
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        while sanitized.contains("--") {
            sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
        }
        sanitized = sanitized.replacingOccurrences(of: "_-", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "-_", with: "_")
        
        // Trim leading/trailing underscores and hyphens
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        
        // Convert to Title_Case: capitalize first letter and letters after underscores/hyphens
        // Process underscore-separated segments
        sanitized = sanitized.components(separatedBy: "_")
            .map { segment in
                // Process hyphen-separated parts within each segment
                segment.components(separatedBy: "-")
                    .map { word in
                        guard !word.isEmpty else { return word }
                        // Check if it's all caps (like "KFM", "MVD", "FIX") - keep as-is
                        if word.uppercased() == word && word.count <= 4 {
                            return word
                        }
                        // Check if it's a version number or has digits at end (like "man2") - preserve structure
                        if word.last?.isNumber == true {
                            let letters = word.prefix(while: { !$0.isNumber })
                            let numbers = word.suffix(from: letters.endIndex)
                            if letters.isEmpty {
                                return word
                            }
                            return letters.prefix(1).uppercased() + letters.dropFirst().lowercased() + numbers
                        }
                        // Otherwise capitalize first letter, lowercase rest
                        return word.prefix(1).uppercased() + word.dropFirst().lowercased()
                    }
                    .joined(separator: "-")
            }
            .joined(separator: "_")
        
        // Handle empty result
        if sanitized.isEmpty {
            sanitized = "Unnamed"
        }
        
        return sanitized
    }
    
    /// Check if a folder name needs sanitization
    public func needsSanitization(_ name: String) -> Bool {
        return sanitizeFolderName(name) != name
    }
    
    /// Rename a content folder to its sanitized name
    /// Returns the new name if renamed, nil if no rename needed or failed
    @discardableResult
    public func sanitizeContentFolder(at folderURL: URL, updateSelectDef: Bool = true, workingDir: URL? = nil) throws -> String? {
        let originalName = folderURL.lastPathComponent
        let sanitizedName = sanitizeFolderName(originalName)
        
        // No change needed
        if sanitizedName == originalName {
            return nil
        }
        
        let parentDir = folderURL.deletingLastPathComponent()
        let newPath = parentDir.appendingPathComponent(sanitizedName)
        
        // Check if target already exists
        if fileManager.fileExists(atPath: newPath.path) {
            // Target exists - append number to avoid collision
            var counter = 2
            var uniquePath = parentDir.appendingPathComponent("\(sanitizedName)_\(counter)")
            while fileManager.fileExists(atPath: uniquePath.path) {
                counter += 1
                uniquePath = parentDir.appendingPathComponent("\(sanitizedName)_\(counter)")
            }
            try fileManager.moveItem(at: folderURL, to: uniquePath)
            
            // Update select.def if requested
            if updateSelectDef, let workDir = workingDir {
                updateSelectDefEntry(from: originalName, to: uniquePath.lastPathComponent, in: workDir)
            }
            
            return uniquePath.lastPathComponent
        }
        
        // Rename the folder
        try fileManager.moveItem(at: folderURL, to: newPath)
        
        // Update select.def if requested
        if updateSelectDef, let workDir = workingDir {
            updateSelectDefEntry(from: originalName, to: sanitizedName, in: workDir)
        }
        
        // Clear image cache for old name
        ImageCache.shared.clearCharacter(originalName)
        
        return sanitizedName
    }
    
    /// Update select.def when a character/stage is renamed
    private func updateSelectDefEntry(from oldName: String, to newName: String, in workingDir: URL) {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path),
              var content = try? String(contentsOf: selectDefPath, encoding: .utf8) else {
            return
        }
        
        // Replace entries (handle both "charname" and "charname/def.def" formats)
        // Case-insensitive replacement for the folder name part
        let patterns = [
            (oldName, newName),                              // Exact match
            ("\(oldName)/", "\(newName)/"),                  // With path separator
        ]
        
        for (old, new) in patterns {
            // Case-insensitive search and replace
            if let range = content.range(of: old, options: .caseInsensitive) {
                content = content.replacingCharacters(in: range, with: new)
            }
        }
        
        try? content.write(to: selectDefPath, atomically: true, encoding: .utf8)
    }
    
    /// Batch sanitize all character folders
    /// Returns array of (oldName, newName) for renamed folders
    public func sanitizeAllCharacters(in workingDir: URL) throws -> [(String, String)] {
        let charsDir = workingDir.appendingPathComponent("chars")
        var renamed: [(String, String)] = []
        
        guard let folders = try? fileManager.contentsOfDirectory(at: charsDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return renamed
        }
        
        for folder in folders {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            
            let oldName = folder.lastPathComponent
            if oldName.hasPrefix(".") { continue }  // Skip hidden
            
            if let newName = try sanitizeContentFolder(at: folder, updateSelectDef: true, workingDir: workingDir) {
                renamed.append((oldName, newName))
            }
        }
        
        return renamed
    }
    
    /// Batch sanitize all stage folders
    /// Returns array of (oldName, newName) for renamed folders
    public func sanitizeAllStages(in workingDir: URL) throws -> [(String, String)] {
        let stagesDir = workingDir.appendingPathComponent("stages")
        var renamed: [(String, String)] = []
        
        guard let folders = try? fileManager.contentsOfDirectory(at: stagesDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return renamed
        }
        
        for folder in folders {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            
            let oldName = folder.lastPathComponent
            if oldName.hasPrefix(".") { continue }  // Skip hidden
            
            if let newName = try sanitizeContentFolder(at: folder, updateSelectDef: true, workingDir: workingDir) {
                renamed.append((oldName, newName))
            }
        }
        
        return renamed
    }
    
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
        
        // Sanitize the folder name for consistency
        var sanitizedName = sanitizeFolderName(charName)
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
            try addCharacterToSelectDef(defEntry, in: workingDir)
        }
        
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
        var renamedFiles: [(String, String)] = []
        
        for file in contents {
            let ext = file.pathExtension.lowercased()
            let originalName = file.deletingPathExtension().lastPathComponent
            
            // Sanitize the filename (without extension)
            var sanitizedBaseName = sanitizeFolderName(originalName)
            var sanitizedFileName = ext.isEmpty ? sanitizedBaseName : "\(sanitizedBaseName).\(ext)"
            var destPath = stagesDir.appendingPathComponent(sanitizedFileName)
            
            // Check for collision with different file
            if fileManager.fileExists(atPath: destPath.path) {
                // For stages, we can't easily compare "same stage" vs "different stage"
                // So we check if the original name matches (case-insensitive)
                let existingIsUpdate = originalName.lowercased() == sanitizedBaseName.lowercased()
                
                if !existingIsUpdate {
                    // Collision - append number to make unique
                    var counter = 2
                    var uniqueBase = "\(sanitizedBaseName)_\(counter)"
                    var uniqueFile = ext.isEmpty ? uniqueBase : "\(uniqueBase).\(ext)"
                    var uniquePath = stagesDir.appendingPathComponent(uniqueFile)
                    while fileManager.fileExists(atPath: uniquePath.path) {
                        counter += 1
                        uniqueBase = "\(sanitizedBaseName)_\(counter)"
                        uniqueFile = ext.isEmpty ? uniqueBase : "\(uniqueBase).\(ext)"
                        uniquePath = stagesDir.appendingPathComponent(uniqueFile)
                    }
                    sanitizedBaseName = uniqueBase
                    sanitizedFileName = uniqueFile
                    destPath = uniquePath
                } else {
                    // True update - remove old file
                    try fileManager.removeItem(at: destPath)
                }
            }
            
            // Track if we renamed
            if sanitizedFileName != file.lastPathComponent {
                renamedFiles.append((file.lastPathComponent, sanitizedFileName))
            }
            
            try fileManager.copyItem(at: file, to: destPath)
            
            if ext == "def" {
                installedStages.append(sanitizedBaseName)
                // Clear cached images
                ImageCache.shared.clearStage(sanitizedBaseName)
            }
        }
        
        // Add stages to select.def
        for stageName in installedStages {
            try addStageToSelectDef(stageName, in: workingDir)
        }
        
        var result: String
        if installedStages.count == 1 {
            result = "Installed stage: \(installedStages[0])"
        } else if installedStages.count > 1 {
            result = "Installed \(installedStages.count) stages: \(installedStages.joined(separator: ", "))"
        } else {
            result = "No stages found to install"
        }
        
        // Note any renamed files
        if !renamedFiles.isEmpty {
            let renamedNote = renamedFiles.map { "\($0.0) → \($0.1)" }.joined(separator: ", ")
            result += " (renamed: \(renamedNote))"
        }
        
        return result
    }
    
    // MARK: - select.def Management
    
    /// Read the character order from select.def
    /// Returns an array of character folder names in the order they appear
    public func readCharacterOrder(from workingDir: URL) -> [String] {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard let content = try? String(contentsOf: selectDefPath, encoding: .utf8) else {
            return []
        }
        
        var characters: [String] = []
        var inCharactersSection = false
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix(";") {
                continue
            }
            
            // Check for section headers
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let section = trimmed.dropFirst().dropLast().lowercased()
                inCharactersSection = (section == "characters")
                continue
            }
            
            // If we're in [Characters] section, extract character names
            if inCharactersSection {
                // Skip "empty" entries used for grid spacing
                if trimmed.lowercased() == "empty" {
                    continue
                }
                
                // Extract character name (before any comma for stage assignment)
                let charPart = trimmed.split(separator: ",").first ?? Substring(trimmed)
                var charName = String(charPart).trimmingCharacters(in: .whitespaces)
                
                // Handle path separators - extract folder name
                // Could be "kfm" or "kfm/alt.def" or "chars/kfm/kfm.def"
                charName = charName.replacingOccurrences(of: "\\", with: "/")
                if charName.contains("/") {
                    // Get the first component (folder name)
                    charName = String(charName.split(separator: "/").first ?? Substring(charName))
                }
                
                if !charName.isEmpty && !characters.contains(charName) {
                    characters.append(charName)
                }
            }
        }
        
        return characters
    }
    
    /// Reorder characters in select.def to match the given order
    /// - Parameters:
    ///   - newOrder: Array of character folder names in desired order
    ///   - workingDir: The Ikemen GO working directory
    public func reorderCharacters(_ newOrder: [String], in workingDir: URL) throws {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path) else {
            throw NSError(domain: "ContentManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "select.def not found"])
        }
        
        let content = try String(contentsOf: selectDefPath, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")
        
        var newLines: [String] = []
        var inCharactersSection = false
        var characterLines: [(name: String, line: String)] = []
        
        // First pass: collect all character lines and their names
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for section headers
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let section = String(trimmed.dropFirst().dropLast()).lowercased()
                
                if inCharactersSection && section != "characters" {
                    // We're leaving [Characters] section - write reordered characters first
                    inCharactersSection = false
                    
                    // Sort character lines according to newOrder
                    let sortedCharLines = sortCharacterLines(characterLines, order: newOrder)
                    newLines.append(contentsOf: sortedCharLines)
                }
                
                inCharactersSection = (section == "characters")
                newLines.append(line)
                continue
            }
            
            if inCharactersSection {
                // Skip comments and empty content lines (but keep them)
                if trimmed.isEmpty || trimmed.hasPrefix(";") {
                    newLines.append(line)
                    continue
                }
                
                // Skip "empty" entries - they're for grid spacing, preserve them at end
                if trimmed.lowercased() == "empty" {
                    // We'll handle empty entries differently - keep them in place
                    newLines.append(line)
                    continue
                }
                
                // Extract character name for sorting
                let charPart = trimmed.split(separator: ",").first ?? Substring(trimmed)
                var charName = String(charPart).trimmingCharacters(in: .whitespaces)
                charName = charName.replacingOccurrences(of: "\\", with: "/")
                if charName.contains("/") {
                    charName = String(charName.split(separator: "/").first ?? Substring(charName))
                }
                
                characterLines.append((name: charName, line: line))
            } else {
                newLines.append(line)
            }
        }
        
        // Handle case where file ends while still in [Characters] section
        if inCharactersSection && !characterLines.isEmpty {
            let sortedCharLines = sortCharacterLines(characterLines, order: newOrder)
            newLines.append(contentsOf: sortedCharLines)
        }
        
        let newContent = newLines.joined(separator: "\n")
        try newContent.write(to: selectDefPath, atomically: true, encoding: .utf8)
        print("Reordered characters in select.def")
    }
    
    /// Sort character lines according to the specified order
    private func sortCharacterLines(_ lines: [(name: String, line: String)], order: [String]) -> [String] {
        var result: [String] = []
        var remaining = lines
        
        // First, add characters in the specified order
        for name in order {
            if let index = remaining.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
                result.append(remaining[index].line)
                remaining.remove(at: index)
            }
        }
        
        // Add any remaining characters (not in the order list) at the end
        for item in remaining {
            result.append(item.line)
        }
        
        return result
    }
    
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
    
    // MARK: - Stage Management
    
    /// Disable a stage in select.def by commenting it out
    /// - Parameters:
    ///   - stage: The stage to disable
    ///   - workingDir: The Ikemen GO working directory
    /// - Returns: true if successfully disabled
    @discardableResult
    public func disableStage(_ stage: StageInfo, in workingDir: URL) throws -> Bool {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path) else {
            throw IkemenError.installFailed("select.def not found")
        }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        // Build possible paths for this stage
        let stageDefPath = stage.defFile.path
        let possiblePaths = buildStagePaths(for: stage, in: workingDir)
        
        var modified = false
        
        // Find and comment out the stage entry
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip already commented lines
            if trimmedLine.hasPrefix(";") {
                newLines.append(line)
                continue
            }
            
            // Check if this line contains our stage
            var isOurStage = false
            for path in possiblePaths {
                if trimmedLine.lowercased().hasPrefix(path.lowercased()) {
                    isOurStage = true
                    break
                }
            }
            
            if isOurStage {
                // Comment out the line
                newLines.append(";\(line)")
                modified = true
                print("Disabled stage: \(trimmedLine)")
            } else {
                newLines.append(line)
            }
        }
        
        if modified {
            content = newLines.joined(separator: "\n")
            try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
        }
        
        return modified
    }
    
    /// Enable a previously disabled stage in select.def by uncommenting it
    /// - Parameters:
    ///   - stage: The stage to enable
    ///   - workingDir: The Ikemen GO working directory
    /// - Returns: true if successfully enabled
    @discardableResult
    public func enableStage(_ stage: StageInfo, in workingDir: URL) throws -> Bool {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path) else {
            throw IkemenError.installFailed("select.def not found")
        }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        let possiblePaths = buildStagePaths(for: stage, in: workingDir)
        
        var modified = false
        
        // Find and uncomment the stage entry
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check if this is a commented stage line
            if trimmedLine.hasPrefix(";") {
                let uncommented = String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                
                var isOurStage = false
                for path in possiblePaths {
                    if uncommented.lowercased().hasPrefix(path.lowercased()) {
                        isOurStage = true
                        break
                    }
                }
                
                if isOurStage {
                    // Uncomment the line
                    newLines.append(uncommented)
                    modified = true
                    print("Enabled stage: \(uncommented)")
                } else {
                    newLines.append(line)
                }
            } else {
                newLines.append(line)
            }
        }
        
        if modified {
            content = newLines.joined(separator: "\n")
            try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
        }
        
        return modified
    }
    
    /// Remove a stage completely (delete files and remove from select.def)
    /// - Parameters:
    ///   - stage: The stage to remove
    ///   - workingDir: The Ikemen GO working directory
    public func removeStage(_ stage: StageInfo, in workingDir: URL) throws {
        // First remove from select.def
        try removeStageFromSelectDef(stage, in: workingDir)
        
        // Then move the stage files to Trash
        let stageDir = stage.defFile.deletingLastPathComponent()
        let stageParentDir = stageDir.deletingLastPathComponent()
        
        // Check if the stage is in its own subdirectory or at root of stages/
        let stagesDir = workingDir.appendingPathComponent("stages")
        
        if stageDir.path == stagesDir.path {
            // Stage files are at root of stages/ - just trash the .def and .sff files
            try? fileManager.trashItem(at: stage.defFile, resultingItemURL: nil)
            if let sffFile = stage.sffFile {
                try? fileManager.trashItem(at: sffFile, resultingItemURL: nil)
            }
            print("Moved stage files to Trash: \(stage.defFile.lastPathComponent)")
        } else {
            // Stage is in its own subdirectory - trash the whole directory
            try fileManager.trashItem(at: stageDir, resultingItemURL: nil)
            print("Moved stage directory to Trash: \(stageDir.lastPathComponent)")
        }
    }
    
    /// Remove a stage entry from select.def
    private func removeStageFromSelectDef(_ stage: StageInfo, in workingDir: URL) throws {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path) else { return }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        let possiblePaths = buildStagePaths(for: stage, in: workingDir)
        
        // Find and remove the stage entry (whether commented or not)
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        
        for line in lines {
            var trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Remove comment prefix for matching
            if trimmedLine.hasPrefix(";") {
                trimmedLine = String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            
            var isOurStage = false
            for path in possiblePaths {
                if trimmedLine.lowercased().hasPrefix(path.lowercased()) {
                    isOurStage = true
                    break
                }
            }
            
            if !isOurStage {
                newLines.append(line)
            } else {
                print("Removed stage from select.def: \(trimmedLine)")
            }
        }
        
        content = newLines.joined(separator: "\n")
        try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
    }
    
    /// Check if a stage is disabled (commented out) in select.def
    public func isStageDisabled(_ stage: StageInfo, in workingDir: URL) -> Bool {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard let content = try? String(contentsOf: selectDefPath, encoding: .utf8) else {
            return false
        }
        
        let possiblePaths = buildStagePaths(for: stage, in: workingDir)
        
        let lines = content.components(separatedBy: "\n")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check commented lines
            if trimmedLine.hasPrefix(";") {
                let uncommented = String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                
                for path in possiblePaths {
                    if uncommented.lowercased().hasPrefix(path.lowercased()) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Build possible path variations for a stage to match in select.def
    private func buildStagePaths(for stage: StageInfo, in workingDir: URL) -> [String] {
        var paths: [String] = []
        
        let stagesDir = workingDir.appendingPathComponent("stages")
        let defPath = stage.defFile.path
        
        // Try to get relative path from stages directory
        if defPath.hasPrefix(stagesDir.path) {
            let relativePath = String(defPath.dropFirst(stagesDir.path.count + 1)) // +1 for "/"
            paths.append("stages/\(relativePath)")
            paths.append(relativePath)
        }
        
        // Also try just the filename
        paths.append(stage.defFile.lastPathComponent)
        
        // Try folder/filename format for stages in subdirectories
        let parentDir = stage.defFile.deletingLastPathComponent().lastPathComponent
        if parentDir != "stages" {
            paths.append("stages/\(parentDir)/\(stage.defFile.lastPathComponent)")
            paths.append("\(parentDir)/\(stage.defFile.lastPathComponent)")
        }
        
        return paths
    }
    
    // MARK: - Character Management
    
    /// Remove a character from select.def and move files to Trash
    /// - Parameters:
    ///   - character: The character to remove
    ///   - workingDir: The Ikemen GO working directory
    public func removeCharacter(_ character: CharacterInfo, in workingDir: URL) throws {
        // First remove from select.def
        try removeCharacterFromSelectDef(character, in: workingDir)
        
        // Then move the character directory to Trash
        try fileManager.trashItem(at: character.path, resultingItemURL: nil)
        print("Moved character directory to Trash: \(character.path.lastPathComponent)")
    }
    
    /// Remove a character entry from select.def
    private func removeCharacterFromSelectDef(_ character: CharacterInfo, in workingDir: URL) throws {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path) else { return }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        let possiblePaths = buildCharacterPaths(for: character, in: workingDir)
        
        // Find and remove the character entry
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        var inCharactersSection = false
        
        for line in lines {
            var trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Track section
            if trimmedLine.lowercased().hasPrefix("[characters]") {
                inCharactersSection = true
                newLines.append(line)
                continue
            } else if trimmedLine.hasPrefix("[") && !trimmedLine.lowercased().hasPrefix("[characters]") {
                inCharactersSection = false
            }
            
            // Only match in characters section
            if !inCharactersSection {
                newLines.append(line)
                continue
            }
            
            var isOurCharacter = false
            for path in possiblePaths {
                if trimmedLine.lowercased().hasPrefix(path.lowercased()) {
                    isOurCharacter = true
                    break
                }
            }
            
            if !isOurCharacter {
                newLines.append(line)
            } else {
                print("Removed character from select.def: \(trimmedLine)")
            }
        }
        
        content = newLines.joined(separator: "\n")
        try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
    }
    
    /// Build possible path variations for a character to match in select.def
    private func buildCharacterPaths(for character: CharacterInfo, in workingDir: URL) -> [String] {
        var paths: [String] = []
        
        // Common formats in select.def:
        // kfm (folder name only)
        // chars/kfm (with chars prefix)
        // kfm/kfm.def (folder/def)
        // chars/kfm/kfm.def
        
        let folderName = character.path.lastPathComponent
        paths.append(folderName)
        paths.append("chars/\(folderName)")
        
        // Use the def file name
        let defFileName = character.defFile.lastPathComponent
        paths.append("\(folderName)/\(defFileName)")
        paths.append("chars/\(folderName)/\(defFileName)")
        
        return paths
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
