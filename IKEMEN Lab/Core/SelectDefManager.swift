import Foundation
import AppKit

// MARK: - Select Def Manager

/// Manages all reading and writing of select.def — the configuration file that controls
/// which characters and stages appear in IKEMEN GO.
/// Handles adding, removing, enabling/disabling, and reordering entries.
public final class SelectDefManager {
    
    // MARK: - Singleton
    
    public static let shared = SelectDefManager()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Entry Updates
    
    /// Update select.def when a character/stage is renamed
    func updateSelectDefEntry(from oldName: String, to newName: String, in workingDir: URL) {
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
    
    // MARK: - Character Order
    
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
            throw NSError(domain: "SelectDefManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "select.def not found"])
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
    
    // MARK: - Adding Entries
    
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
    func addCharacterToSelectDefFile(_ charEntry: String, selectDefPath: URL) throws {
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
        
        // Remove from metadata database
        try? MetadataStore.shared.deleteStage(id: stage.id)
        
        // Then move the stage files to Trash
        let stageDir = stage.defFile.deletingLastPathComponent()
        
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
        
        NotificationCenter.default.post(name: .contentChanged, object: nil)
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
            var matchLine = line.trimmingCharacters(in: .whitespaces)
            
            // Remove comment prefix for matching
            if matchLine.hasPrefix(";") {
                matchLine = String(matchLine.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            
            var isOurStage = false
            for path in possiblePaths {
                if matchLine.lowercased().hasPrefix(path.lowercased()) {
                    isOurStage = true
                    break
                }
            }
            
            if !isOurStage {
                newLines.append(line)
            } else {
                print("Removed stage from select.def: \(matchLine)")
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
    
    /// Disable a character in select.def by commenting it out
    /// - Parameters:
    ///   - character: The character to disable
    ///   - workingDir: The Ikemen GO working directory
    /// - Returns: true if successfully disabled
    @discardableResult
    public func disableCharacter(_ character: CharacterInfo, in workingDir: URL) throws -> Bool {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path) else {
            throw IkemenError.installFailed("select.def not found")
        }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        let possiblePaths = buildCharacterPaths(for: character, in: workingDir)
        
        var modified = false
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        var inCharactersSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
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
            
            // Skip already commented lines
            if trimmedLine.hasPrefix(";") {
                newLines.append(line)
                continue
            }
            
            // Check if this line contains our character
            var isOurCharacter = false
            for path in possiblePaths {
                if trimmedLine.lowercased().hasPrefix(path.lowercased()) {
                    isOurCharacter = true
                    break
                }
            }
            
            if isOurCharacter {
                // Comment out the line
                newLines.append(";\(line)")
                modified = true
                print("Disabled character: \(trimmedLine)")
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
    
    /// Enable a previously disabled character in select.def by uncommenting it
    /// - Parameters:
    ///   - character: The character to enable
    ///   - workingDir: The Ikemen GO working directory
    /// - Returns: true if successfully enabled
    @discardableResult
    public func enableCharacter(_ character: CharacterInfo, in workingDir: URL) throws -> Bool {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard fileManager.fileExists(atPath: selectDefPath.path) else {
            throw IkemenError.installFailed("select.def not found")
        }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        let possiblePaths = buildCharacterPaths(for: character, in: workingDir)
        
        var modified = false
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        var inCharactersSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
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
            
            // Check if this is a commented character line
            if trimmedLine.hasPrefix(";") {
                let uncommented = String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                
                var isOurCharacter = false
                for path in possiblePaths {
                    if uncommented.lowercased().hasPrefix(path.lowercased()) {
                        isOurCharacter = true
                        break
                    }
                }
                
                if isOurCharacter {
                    // Uncomment the line
                    newLines.append(uncommented)
                    modified = true
                    print("Enabled character: \(uncommented)")
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
    
    /// Check if a character is disabled (commented out) in select.def
    public func isCharacterDisabled(_ character: CharacterInfo, in workingDir: URL) -> Bool {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard let content = try? String(contentsOf: selectDefPath, encoding: .utf8) else {
            return false
        }
        
        let possiblePaths = buildCharacterPaths(for: character, in: workingDir)
        let lines = content.components(separatedBy: "\n")
        var inCharactersSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Track section
            if trimmedLine.lowercased().hasPrefix("[characters]") {
                inCharactersSection = true
                continue
            } else if trimmedLine.hasPrefix("[") && !trimmedLine.lowercased().hasPrefix("[characters]") {
                inCharactersSection = false
            }
            
            if !inCharactersSection { continue }
            
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
    
    /// Remove a character from select.def and move files to Trash
    /// - Parameters:
    ///   - character: The character to remove
    ///   - workingDir: The Ikemen GO working directory
    public func removeCharacter(_ character: CharacterInfo, in workingDir: URL) throws {
        // First remove from select.def
        try removeCharacterFromSelectDef(character, in: workingDir)
        
        // Remove from metadata database
        try? MetadataStore.shared.deleteCharacter(id: character.id)
        
        // Then move the character directory to Trash
        try fileManager.trashItem(at: character.path, resultingItemURL: nil)
        print("Moved character directory to Trash: \(character.path.lastPathComponent)")
        
        // Notify that content has changed
        NotificationCenter.default.post(name: .contentChanged, object: nil)
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
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
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
}
