import Foundation
import AppKit

// MARK: - Folder Sanitizer

/// Handles folder naming conventions, sanitization, and misnamed folder detection/fixing.
/// Also manages stage display name editing.
public final class FolderSanitizer {
    
    // MARK: - Singleton
    
    public static let shared = FolderSanitizer()
    
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
                SelectDefManager.shared.updateSelectDefEntry(from: originalName, to: uniquePath.lastPathComponent, in: workDir)
            }
            
            return uniquePath.lastPathComponent
        }
        
        // Rename the folder
        try fileManager.moveItem(at: folderURL, to: newPath)
        
        // Update select.def if requested
        if updateSelectDef, let workDir = workingDir {
            SelectDefManager.shared.updateSelectDefEntry(from: originalName, to: sanitizedName, in: workDir)
        }
        
        // Clear image cache for old name
        ImageCache.shared.clearCharacter(originalName)
        
        return sanitizedName
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
    
    // MARK: - Misnamed Folder Detection & Fixing
    
    /// Check if a character folder name doesn't match its actual character name
    /// Returns the suggested name if mismatched, nil if OK
    public func detectMismatchedCharacterFolder(_ folder: URL) -> String? {
        // Find the character def file
        guard let defFile = findCharacterDefFile(in: folder) else { return nil }
        
        // Parse the def file
        guard let parsed = DEFParser.parse(url: defFile) else { return nil }
        
        // Get the character name from the def file
        let characterName = parsed.name ?? parsed.displayName ?? defFile.deletingPathExtension().lastPathComponent
        
        // Sanitize it for use as a folder name
        let idealFolderName = sanitizeFolderName(characterName)
        let currentFolderName = folder.lastPathComponent
        
        // Check if they match (case-insensitive)
        if currentFolderName.lowercased() == idealFolderName.lowercased() {
            return nil  // Already matches
        }
        
        // Check if current folder name looks like a generic/temporary name
        let genericPatterns = ["intro", "ending", "temp", "new", "untitled", "character", "char"]
        let lowerFolderName = currentFolderName.lowercased()
        
        // Check if folder starts with a generic pattern or is numbered (like Intro_2)
        let isMisnamed = genericPatterns.contains { lowerFolderName.hasPrefix($0) } ||
                        lowerFolderName.first?.isNumber == true
        
        if isMisnamed {
            return idealFolderName
        }
        
        return nil
    }
    
    /// Find misnamed character folders in the chars directory
    /// Returns array of (folder URL, suggested name)
    public func findMisnamedCharacterFolders(in workingDir: URL) -> [(URL, String)] {
        let charsDir = workingDir.appendingPathComponent("chars")
        var misnamed: [(URL, String)] = []
        
        guard let folders = try? fileManager.contentsOfDirectory(at: charsDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return misnamed
        }
        
        for folder in folders {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            
            if folder.lastPathComponent.hasPrefix(".") { continue }
            
            if let suggestedName = detectMismatchedCharacterFolder(folder) {
                misnamed.append((folder, suggestedName))
            }
        }
        
        return misnamed
    }
    
    /// Rename a character folder to match its character name
    /// Returns the new folder URL if renamed, nil if failed
    @discardableResult
    public func fixMisnamedCharacterFolder(_ folder: URL, suggestedName: String, workingDir: URL) throws -> URL? {
        let currentName = folder.lastPathComponent
        var newName = suggestedName
        let parentDir = folder.deletingLastPathComponent()
        var newPath = parentDir.appendingPathComponent(newName)
        
        // Handle collisions
        var counter = 2
        while fileManager.fileExists(atPath: newPath.path) {
            newName = "\(suggestedName)_\(counter)"
            newPath = parentDir.appendingPathComponent(newName)
            counter += 1
        }
        
        // Rename the folder
        try fileManager.moveItem(at: folder, to: newPath)
        
        // Update select.def
        SelectDefManager.shared.updateSelectDefEntry(from: currentName, to: newName, in: workingDir)
        
        // Clear image cache for old name
        ImageCache.shared.clearCharacter(currentName)
        
        print("Renamed character folder: \(currentName) → \(newName)")
        
        return newPath
    }
    
    /// Fix all misnamed character folders
    /// Returns array of (oldName, newName) for renamed folders
    public func fixAllMisnamedCharacterFolders(in workingDir: URL) throws -> [(String, String)] {
        let misnamed = findMisnamedCharacterFolders(in: workingDir)
        var renamed: [(String, String)] = []
        
        for (folder, suggestedName) in misnamed {
            let oldName = folder.lastPathComponent
            if let newPath = try fixMisnamedCharacterFolder(folder, suggestedName: suggestedName, workingDir: workingDir) {
                renamed.append((oldName, newPath.lastPathComponent))
            }
        }
        
        return renamed
    }
    
    /// Find the valid character def file in a folder (skips storyboards, fonts, stages)
    func findCharacterDefFile(in folder: URL) -> URL? {
        // First check for def file matching folder name
        let folderName = folder.lastPathComponent
        let matchingDef = folder.appendingPathComponent("\(folderName).def")
        
        if fileManager.fileExists(atPath: matchingDef.path) && DEFParser.isValidCharacterDefFile(matchingDef) {
            return matchingDef
        }
        
        // Fall back to finding any valid character def
        guard let contents = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        let validDefFiles = defFiles.filter { DEFParser.isValidCharacterDefFile($0) }
        
        // Prefer def file that matches folder name pattern, otherwise take first
        return validDefFiles.first { file in
            file.deletingPathExtension().lastPathComponent.lowercased() == folderName.lowercased()
        } ?? validDefFiles.first
    }
    
    // MARK: - Stage Name Editing
    
    /// Rename a stage by editing its DEF file's name field
    /// This changes the display name in both IKEMEN GO and IKEMEN Lab
    public func renameStage(_ stage: StageInfo, to newName: String) throws {
        let defFile = stage.defFile
        
        guard fileManager.fileExists(atPath: defFile.path) else {
            throw NSError(domain: "FolderSanitizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Stage DEF file not found"])
        }
        
        // Read the current content
        var content = try String(contentsOf: defFile, encoding: .utf8)
        
        // Find and replace the name line
        // Handles various formats:
        // name = "Old Name"
        // name= "Old Name"
        // name = "X";"Real Name"
        let namePattern = #"(?m)^(name\s*=\s*).*$"#
        
        if let regex = try? NSRegularExpression(pattern: namePattern, options: .caseInsensitive) {
            let range = NSRange(content.startIndex..., in: content)
            let replacement = "$1\"\(newName)\""
            content = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
        }
        
        // Write back
        try content.write(to: defFile, atomically: true, encoding: .utf8)
        
        print("Renamed stage: \(stage.name) → \(newName)")
    }
    
    /// Check if a stage has a suspicious name (single letter, etc.)
    public func stageNeedsBetterName(_ stage: StageInfo) -> Bool {
        let name = stage.name
        // Suspicious if: single char, all caps 1-2 chars, or matches common placeholder patterns
        return name.count <= 2 || 
               (name.count <= 3 && name == name.uppercased() && !name.contains(" "))
    }
    
    /// Suggest a better name for a stage based on its filename
    public func suggestStageName(_ stage: StageInfo) -> String {
        let filename = stage.defFile.deletingPathExtension().lastPathComponent
        // Clean up filename: replace underscores with spaces, title case
        return filename
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}
