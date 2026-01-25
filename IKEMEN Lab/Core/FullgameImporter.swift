import Foundation
import AppKit

// MARK: - Fullgame Import Types

/// Result of scanning a folder for fullgame content
struct FullgameManifest {
    let sourceURL: URL
    let sourceFolderName: String
    
    // Discovered content
    var characters: [CharacterEntry] = []
    var stages: [StageEntry] = []
    var screenpack: ScreenpackEntry?
    var fonts: [URL] = []
    var sounds: [URL] = []
    
    /// Whether this looks like a fullgame package (has multiple content types)
    var isFullgame: Bool {
        let hasChars = !characters.isEmpty
        let hasStages = !stages.isEmpty
        let hasScreenpack = screenpack != nil
        // Consider it a fullgame if it has at least 2 content types
        let contentTypes = [hasChars, hasStages, hasScreenpack].filter { $0 }.count
        return contentTypes >= 2
    }
    
    /// Best name for the collection (screenpack name > folder name)
    var suggestedCollectionName: String {
        if let screenpackName = screenpack?.displayName, !screenpackName.isEmpty {
            return screenpackName
        }
        return CollectionNameResolver.deriveNameFromFolder(sourceFolderName)
    }
    
    struct CharacterEntry {
        let folderURL: URL
        let folderName: String
        let defFile: String?
    }
    
    struct StageEntry {
        let url: URL
        let name: String
        let isLooseFile: Bool  // True if .def is not in a subfolder
    }
    
    struct ScreenpackEntry {
        let url: URL
        let displayName: String
    }
}

/// Result of a fullgame import operation
struct FullgameImportResult {
    var charactersInstalled: [String] = []
    var charactersFailed: [(name: String, error: String)] = []
    var stagesInstalled: [String] = []
    var stagesFailed: [(name: String, error: String)] = []
    var screenpackInstalled: String?
    var screenpackFailed: String?
    var fontsInstalled: [String] = []       // Font filenames installed
    var soundsInstalled: [String] = []      // Sound filenames installed
    var collectionCreated: Collection?
    
    var totalInstalled: Int {
        charactersInstalled.count + stagesInstalled.count + (screenpackInstalled != nil ? 1 : 0)
    }
    
    var totalFailed: Int {
        charactersFailed.count + stagesFailed.count + (screenpackFailed != nil ? 1 : 0)
    }
    
    var summary: String {
        var parts: [String] = []
        if !charactersInstalled.isEmpty {
            parts.append("\(charactersInstalled.count) character\(charactersInstalled.count == 1 ? "" : "s")")
        }
        if !stagesInstalled.isEmpty {
            parts.append("\(stagesInstalled.count) stage\(stagesInstalled.count == 1 ? "" : "s")")
        }
        if screenpackInstalled != nil {
            parts.append("1 screenpack")
        }
        if !fontsInstalled.isEmpty {
            parts.append("\(fontsInstalled.count) font\(fontsInstalled.count == 1 ? "" : "s")")
        }
        if !soundsInstalled.isEmpty {
            parts.append("\(soundsInstalled.count) sound file\(soundsInstalled.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }
}

/// Duplicate handling choice for batch imports
enum DuplicateAction: Equatable {
    case ask           // Ask for each item
    case overwrite     // Overwrite this and optionally remaining
    case skip          // Skip this and optionally remaining
    case overwriteAll  // Overwrite all remaining without asking
    case skipAll       // Skip all remaining without asking
}

// MARK: - Fullgame Importer

/// Service for detecting and importing complete MUGEN/IKEMEN fullgame packages
final class FullgameImporter {
    
    static let shared = FullgameImporter()
    
    private let fileManager = FileManager.default
    private let contentManager = ContentManager.shared
    
    private init() {}
    
    // MARK: - Scanning
    
    /// Scan a folder to detect fullgame content
    func scanFullgamePackage(at url: URL) -> FullgameManifest {
        var manifest = FullgameManifest(sourceURL: url, sourceFolderName: url.lastPathComponent)
        
        print("[FullgameImporter] Scanning: \(url.path)")
        
        // Scan for characters (chars/ subfolder)
        let charsDir = url.appendingPathComponent("chars")
        print("[FullgameImporter] Checking chars at: \(charsDir.path), exists: \(fileManager.fileExists(atPath: charsDir.path))")
        if fileManager.fileExists(atPath: charsDir.path) {
            manifest.characters = scanCharactersFolder(charsDir)
            print("[FullgameImporter] Found \(manifest.characters.count) characters: \(manifest.characters.map { $0.folderName })")
        }
        
        // Scan for stages (stages/ subfolder)
        let stagesDir = url.appendingPathComponent("stages")
        if fileManager.fileExists(atPath: stagesDir.path) {
            manifest.stages = scanStagesFolder(stagesDir)
        }
        
        // Scan for screenpack (data/ subfolder with system.def)
        let dataDir = url.appendingPathComponent("data")
        if fileManager.fileExists(atPath: dataDir.path) {
            manifest.screenpack = scanDataFolder(dataDir)
        }
        
        // Scan for fonts (font/ subfolder)
        let fontDir = url.appendingPathComponent("font")
        if fileManager.fileExists(atPath: fontDir.path) {
            manifest.fonts = scanFontsFolder(fontDir)
        }
        
        // Scan for sounds (sound/ subfolder)
        let soundDir = url.appendingPathComponent("sound")
        if fileManager.fileExists(atPath: soundDir.path) {
            manifest.sounds = scanSoundsFolder(soundDir)
        }
        
        return manifest
    }
    
    private func scanCharactersFolder(_ url: URL) -> [FullgameManifest.CharacterEntry] {
        var entries: [FullgameManifest.CharacterEntry] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return entries
        }
        
        for item in contents {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }
            
            // Skip common non-character folders
            let name = item.lastPathComponent.lowercased()
            if name.hasPrefix(".") || name == "template" || name == "readme" {
                continue
            }
            
            // Look for .def file in the folder
            let folderContents = (try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)) ?? []
            let defFile = folderContents.first { $0.pathExtension.lowercased() == "def" }
            
            // Validate it's a character (has .def with character markers)
            if let def = defFile,
               let content = try? String(contentsOf: def, encoding: .utf8).lowercased(),
               content.contains("[files]") && (content.contains(".cmd") || content.contains(".cns") || content.contains(".air")) {
                entries.append(FullgameManifest.CharacterEntry(
                    folderURL: item,
                    folderName: item.lastPathComponent,
                    defFile: def.lastPathComponent
                ))
            }
        }
        
        return entries
    }
    
    private func scanStagesFolder(_ url: URL) -> [FullgameManifest.StageEntry] {
        var entries: [FullgameManifest.StageEntry] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return entries
        }
        
        for item in contents {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory)
            
            if isDirectory.boolValue {
                // Stage in subfolder (standard structure)
                let folderContents = (try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)) ?? []
                if let defFile = folderContents.first(where: { $0.pathExtension.lowercased() == "def" }) {
                    if isValidStageFile(defFile) {
                        entries.append(FullgameManifest.StageEntry(
                            url: item,
                            name: item.lastPathComponent,
                            isLooseFile: false
                        ))
                    }
                }
            } else if item.pathExtension.lowercased() == "def" {
                // Loose .def file (needs restructuring)
                if isValidStageFile(item) {
                    let name = item.deletingPathExtension().lastPathComponent
                    entries.append(FullgameManifest.StageEntry(
                        url: item,
                        name: name,
                        isLooseFile: true
                    ))
                }
            }
        }
        
        return entries
    }
    
    private func isValidStageFile(_ url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8).lowercased() else {
            return false
        }
        return content.contains("[stageinfo]") || content.contains("[bgdef]") || content.contains("[bg ")
    }
    
    private func scanDataFolder(_ url: URL) -> FullgameManifest.ScreenpackEntry? {
        let systemDef = url.appendingPathComponent("system.def")
        guard fileManager.fileExists(atPath: systemDef.path) else {
            return nil
        }
        
        // Parse system.def to get the screenpack name
        var displayName = url.deletingLastPathComponent().lastPathComponent // Fallback to parent folder name
        
        if let parsed = DEFParser.parse(url: systemDef) {
            if let name = parsed.name ?? parsed.value(for: "name", inSection: "info") {
                displayName = name
            }
        }
        
        return FullgameManifest.ScreenpackEntry(url: url, displayName: displayName)
    }
    
    private func scanFontsFolder(_ url: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }
        return contents.filter { $0.pathExtension.lowercased() == "fnt" }
    }
    
    private func scanSoundsFolder(_ url: URL) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }
        let audioExtensions = ["mp3", "ogg", "wav", "flac"]
        return contents.filter { audioExtensions.contains($0.pathExtension.lowercased()) }
    }
    
    // MARK: - Installation
    
    /// Install a fullgame package with per-item duplicate handling
    /// - Parameters:
    ///   - manifest: The scanned fullgame manifest
    ///   - workingDir: The IKEMEN GO working directory
    ///   - duplicateHandler: Callback to ask user about duplicates. Returns the action to take.
    /// - Returns: The import result with installed/failed items
    func installFullgame(
        manifest: FullgameManifest,
        to workingDir: URL,
        duplicateHandler: @escaping (String, String) -> DuplicateAction  // (itemName, itemType) -> action
    ) throws -> FullgameImportResult {
        var result = FullgameImportResult()
        var currentAction: DuplicateAction = .ask
        
        print("[FullgameImporter] Starting installation to: \(workingDir.path)")
        print("[FullgameImporter] Found \(manifest.characters.count) characters, \(manifest.stages.count) stages")
        
        // 1. Install characters
        for character in manifest.characters {
            print("[FullgameImporter] Installing character: \(character.folderName)")
            do {
                let installed = try installCharacterWithDuplicateHandling(
                    character: character,
                    to: workingDir,
                    currentAction: &currentAction,
                    duplicateHandler: duplicateHandler
                )
                if let name = installed {
                    print("[FullgameImporter] Character installed as: \(name)")
                    result.charactersInstalled.append(name)
                } else {
                    print("[FullgameImporter] Character skipped")
                }
            } catch {
                print("[FullgameImporter] Character failed: \(error.localizedDescription)")
                result.charactersFailed.append((character.folderName, error.localizedDescription))
            }
        }
        
        print("[FullgameImporter] Characters installed: \(result.charactersInstalled)")
        
        // Reset action for stages
        if currentAction != .overwriteAll && currentAction != .skipAll {
            currentAction = .ask
        }
        
        // 2. Install stages
        for stage in manifest.stages {
            print("[FullgameImporter] Installing stage: \(stage.name), isLoose: \(stage.isLooseFile)")
            do {
                let installed = try installStageWithDuplicateHandling(
                    stage: stage,
                    sourceURL: manifest.sourceURL,
                    to: workingDir,
                    currentAction: &currentAction,
                    duplicateHandler: duplicateHandler
                )
                if let name = installed {
                    print("[FullgameImporter] Stage installed as: \(name)")
                    result.stagesInstalled.append(name)
                } else {
                    print("[FullgameImporter] Stage skipped")
                }
            } catch {
                print("[FullgameImporter] Stage failed: \(error.localizedDescription)")
                result.stagesFailed.append((stage.name, error.localizedDescription))
            }
        }
        
        print("[FullgameImporter] Stages installed: \(result.stagesInstalled)")
        
        // 3. Install screenpack
        if let screenpack = manifest.screenpack {
            do {
                // Use folder name based on manifest name for consistency
                let screenpackFolderName = CollectionNameResolver.sanitizeForFolder(manifest.suggestedCollectionName)
                print("[FullgameImporter] Installing screenpack to: \(screenpackFolderName)")
                let _ = try installScreenpack(from: screenpack.url, to: workingDir, folderName: screenpackFolderName)
                result.screenpackInstalled = screenpack.displayName
                print("[FullgameImporter] Screenpack installed")
            } catch {
                print("[FullgameImporter] Screenpack failed: \(error.localizedDescription)")
                result.screenpackFailed = error.localizedDescription
            }
        }
        
        // 4. Install fonts
        result.fontsInstalled = installFonts(manifest.fonts, to: workingDir)
        print("[FullgameImporter] Fonts installed: \(result.fontsInstalled.count) - \(result.fontsInstalled)")
        
        // 5. Install sounds
        result.soundsInstalled = installSounds(manifest.sounds, to: workingDir)
        print("[FullgameImporter] Sounds installed: \(result.soundsInstalled.count) - \(result.soundsInstalled)")
        
        // 6. Create collection
        print("[FullgameImporter] Total installed: \(result.totalInstalled)")
        if result.totalInstalled > 0 {
            print("[FullgameImporter] Creating collection with \(result.charactersInstalled.count) chars, \(result.stagesInstalled.count) stages")
            let collection = createCollectionFromResult(
                result: result,
                name: manifest.suggestedCollectionName,
                screenpackPath: manifest.screenpack != nil ? "data/\(CollectionNameResolver.sanitizeForFolder(manifest.suggestedCollectionName))" : nil
            )
            result.collectionCreated = collection
            print("[FullgameImporter] Collection created: \(collection.name)")
        }
        
        return result
    }
    
    private func installCharacterWithDuplicateHandling(
        character: FullgameManifest.CharacterEntry,
        to workingDir: URL,
        currentAction: inout DuplicateAction,
        duplicateHandler: (String, String) -> DuplicateAction
    ) throws -> String? {
        // Get the sanitized folder name that ContentManager will use
        let sanitizedName = contentManager.sanitizeFolderName(character.folderName)
        
        do {
            let _ = try contentManager.installCharacter(from: character.folderURL, to: workingDir, overwrite: false)
            return sanitizedName
        } catch let error as IkemenError {
            if case .duplicateContent(let name) = error {
                // Handle duplicate
                var action = currentAction
                if action == .ask {
                    action = duplicateHandler(name, "character")
                    if action == .overwriteAll || action == .skipAll {
                        currentAction = action
                    }
                }
                
                switch action {
                case .overwrite, .overwriteAll:
                    let _ = try contentManager.installCharacter(from: character.folderURL, to: workingDir, overwrite: true)
                    return sanitizedName
                case .skip, .skipAll:
                    return nil
                case .ask:
                    return nil
                }
            }
            throw error
        }
    }
    
    private func installStageWithDuplicateHandling(
        stage: FullgameManifest.StageEntry,
        sourceURL: URL,
        to workingDir: URL,
        currentAction: inout DuplicateAction,
        duplicateHandler: (String, String) -> DuplicateAction
    ) throws -> String? {
        // Handle loose stage files by creating a proper folder structure
        let stageURL: URL
        if stage.isLooseFile {
            stageURL = try restructureLooseStage(stage, from: sourceURL, to: workingDir)
        } else {
            stageURL = stage.url
        }
        
        // Get the sanitized folder name that ContentManager will use
        let sanitizedName = contentManager.sanitizeFolderName(stageURL.lastPathComponent)
        
        do {
            let _ = try contentManager.installStage(from: stageURL, to: workingDir, overwrite: false)
            return sanitizedName
        } catch let error as IkemenError {
            if case .duplicateContent(let name) = error {
                var action = currentAction
                if action == .ask {
                    action = duplicateHandler(name, "stage")
                    if action == .overwriteAll || action == .skipAll {
                        currentAction = action
                    }
                }
                
                switch action {
                case .overwrite, .overwriteAll:
                    let _ = try contentManager.installStage(from: stageURL, to: workingDir, overwrite: true)
                    return sanitizedName
                case .skip, .skipAll:
                    return nil
                case .ask:
                    return nil
                }
            }
            throw error
        }
    }
    
    /// Restructure a loose stage file into a proper folder structure
    private func restructureLooseStage(_ stage: FullgameManifest.StageEntry, from sourceURL: URL, to workingDir: URL) throws -> URL {
        let stagesDir = sourceURL.appendingPathComponent("stages")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let stageFolder = tempDir.appendingPathComponent(stage.name)
        
        print("[FullgameImporter] Restructuring loose stage: \(stage.name)")
        print("[FullgameImporter] Source stages dir: \(stagesDir.path)")
        
        try fileManager.createDirectory(at: stageFolder, withIntermediateDirectories: true)
        
        // Copy the .def file
        let defFile = stage.url
        try fileManager.copyItem(at: defFile, to: stageFolder.appendingPathComponent(defFile.lastPathComponent))
        print("[FullgameImporter] Copied .def file: \(defFile.lastPathComponent)")
        
        // Get all files in stages directory for case-insensitive matching
        let allStageFiles = (try? fileManager.contentsOfDirectory(at: stagesDir, includingPropertiesForKeys: nil)) ?? []
        
        // Look for associated .sff files by parsing the .def
        if let defContent = try? String(contentsOf: defFile, encoding: .utf8) {
            let lines = defContent.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Only match "spr = filename.sff" not "spriteno = 0,0"
                let lowered = trimmed.lowercased()
                if lowered.hasPrefix("spr") && !lowered.hasPrefix("spriteno") {
                    // Extract the filename
                    if let equalIndex = trimmed.firstIndex(of: "=") {
                        var filename = String(trimmed[trimmed.index(after: equalIndex)...])
                            .trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "\"", with: "")
                        
                        // Remove any comments
                        if let commentIndex = filename.firstIndex(of: ";") {
                            filename = String(filename[..<commentIndex]).trimmingCharacters(in: .whitespaces)
                        }
                        
                        // Skip if this doesn't look like a filename (no extension or contains comma)
                        guard filename.lowercased().hasSuffix(".sff") || 
                              (!filename.contains(",") && !filename.isEmpty) else {
                            continue
                        }
                        
                        print("[FullgameImporter] DEF references SFF: '\(filename)'")
                        
                        // Case-insensitive search for the file
                        let filenameLower = filename.lowercased()
                        if let matchingFile = allStageFiles.first(where: { $0.lastPathComponent.lowercased() == filenameLower }) {
                            let destPath = stageFolder.appendingPathComponent(matchingFile.lastPathComponent)
                            if !fileManager.fileExists(atPath: destPath.path) {
                                try fileManager.copyItem(at: matchingFile, to: destPath)
                                print("[FullgameImporter] Copied SFF: \(matchingFile.lastPathComponent)")
                            }
                        } else {
                            print("[FullgameImporter] WARNING: SFF not found: \(filename)")
                        }
                    }
                }
            }
        }
        
        // Also copy any .sff with matching base name (fallback)
        let baseName = stage.name.lowercased()
        for file in allStageFiles {
            let fileName = file.deletingPathExtension().lastPathComponent.lowercased()
            if file.pathExtension.lowercased() == "sff" && (fileName == baseName || fileName.contains(baseName)) {
                let destPath = stageFolder.appendingPathComponent(file.lastPathComponent)
                if !fileManager.fileExists(atPath: destPath.path) {
                    try? fileManager.copyItem(at: file, to: destPath)
                    print("[FullgameImporter] Copied matching SFF: \(file.lastPathComponent)")
                }
            }
        }
        
        return stageFolder
    }
    
    private func installScreenpack(from dataURL: URL, to workingDir: URL, folderName: String) throws -> String {
        let destDir = workingDir.appendingPathComponent("data").appendingPathComponent(folderName)
        
        // Remove existing if present
        if fileManager.fileExists(atPath: destDir.path) {
            try fileManager.removeItem(at: destDir)
        }
        
        // Copy the data folder contents
        try fileManager.copyItem(at: dataURL, to: destDir)
        
        // Redirect to global select.def (IKEMEN Lab manages the roster)
        contentManager.redirectScreenpackToGlobalSelectDef(screenpackPath: destDir)
        
        return folderName
    }
    
    private func installFonts(_ fonts: [URL], to workingDir: URL) -> [String] {
        let fontDir = workingDir.appendingPathComponent("font")
        
        // Create font directory if needed
        try? fileManager.createDirectory(at: fontDir, withIntermediateDirectories: true)
        
        var installed: [String] = []
        for fontURL in fonts {
            let filename = fontURL.lastPathComponent
            let destPath = fontDir.appendingPathComponent(filename)
            do {
                // Only install if no conflicting file exists
                if !fileManager.fileExists(atPath: destPath.path) {
                    try fileManager.copyItem(at: fontURL, to: destPath)
                    installed.append(filename)
                }
            } catch {
                // Continue on font install failure
            }
        }
        return installed
    }
    
    private func installSounds(_ sounds: [URL], to workingDir: URL) -> [String] {
        let soundDir = workingDir.appendingPathComponent("sound")
        
        // Create sound directory if needed
        try? fileManager.createDirectory(at: soundDir, withIntermediateDirectories: true)
        
        var installed: [String] = []
        for soundURL in sounds {
            let filename = soundURL.lastPathComponent
            let destPath = soundDir.appendingPathComponent(filename)
            do {
                // Only install if no conflicting file exists
                if !fileManager.fileExists(atPath: destPath.path) {
                    try fileManager.copyItem(at: soundURL, to: destPath)
                    installed.append(filename)
                }
            } catch {
                // Continue on sound install failure
            }
        }
        return installed
    }
    
    private func createCollectionFromResult(result: FullgameImportResult, name: String, screenpackPath: String?) -> Collection {
        var collection = CollectionStore.shared.createCollection(name: name, icon: "gamecontroller.fill")
        
        // Set screenpack, fonts, and sounds FIRST (before adding content, so update doesn't overwrite)
        if let path = screenpackPath {
            collection.screenpackPath = path
        }
        collection.fonts = result.fontsInstalled
        collection.sounds = result.soundsInstalled
        CollectionStore.shared.update(collection)
        
        // Add characters (these modify the collection in the store)
        for characterFolder in result.charactersInstalled {
            CollectionStore.shared.addCharacter(folder: characterFolder, def: nil, to: collection.id)
        }
        
        // Add stages
        for stageFolder in result.stagesInstalled {
            CollectionStore.shared.addStage(folder: stageFolder, to: collection.id)
        }
        
        // Return the updated collection from the store
        return CollectionStore.shared.collection(withId: collection.id) ?? collection
    }
}

// MARK: - Collection Name Resolver

/// Helper for deriving nice collection names from screenpacks and folders
enum CollectionNameResolver {
    
    /// Derive a display name from a folder name
    static func deriveNameFromFolder(_ folderName: String) -> String {
        var name = folderName
        
        // Remove common suffixes
        let suffixesToRemove = ["_v1", "_v2", "_v2a", "_v3", "_fullgame", "_full", "_complete", "_final"]
        for suffix in suffixesToRemove {
            if name.lowercased().hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
            }
        }
        
        // Replace underscores and hyphens with spaces
        name = name.replacingOccurrences(of: "_", with: " ")
        name = name.replacingOccurrences(of: "-", with: " ")
        
        // Remove non-letter/number characters except spaces
        name = name.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == " "
        }.map { String($0) }.joined()
        
        // Collapse multiple spaces
        while name.contains("  ") {
            name = name.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Trim and title case
        name = name.trimmingCharacters(in: .whitespaces)
        name = name.localizedCapitalized
        
        // Handle empty result
        if name.isEmpty {
            name = "Imported Collection"
        }
        
        return name
    }
    
    /// Sanitize a name for use as a folder name
    static func sanitizeForFolder(_ name: String) -> String {
        var sanitized = name
        
        // Replace spaces with underscores
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        
        // Remove characters that aren't alphanumeric, underscore, or hyphen
        sanitized = sanitized.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-"
        }.map { String($0) }.joined()
        
        // Collapse multiple underscores
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        
        // Trim leading/trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        
        if sanitized.isEmpty {
            sanitized = "imported_collection"
        }
        
        return sanitized
    }
}
