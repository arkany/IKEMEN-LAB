import Foundation
import Combine
import AppKit

// MARK: - Errors

/// Error types for Ikemen GO operations
enum IkemenError: LocalizedError {
    case engineNotFound
    case engineLaunchFailed(String)
    case contentNotFound(String)
    case installFailed(String)
    case invalidContent(String)
    
    var errorDescription: String? {
        switch self {
        case .engineNotFound:
            return "Ikemen GO engine not found"
        case .engineLaunchFailed(let reason):
            return "Failed to launch Ikemen GO: \(reason)"
        case .contentNotFound(let name):
            return "Content not found: \(name)"
        case .installFailed(let reason):
            return "Failed to install content: \(reason)"
        case .invalidContent(let reason):
            return "Invalid content: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .engineNotFound:
            return "Make sure Ikemen GO is bundled with the application."
        case .engineLaunchFailed:
            return "Try restarting the application."
        case .contentNotFound:
            return "Check that the content files exist in the content directory."
        case .installFailed:
            return "Make sure you have write permissions and enough disk space."
        case .invalidContent:
            return "The content file may be corrupted or in an unsupported format."
        }
    }
}

// MARK: - Content Types

/// Types of MUGEN/Ikemen GO content
enum ContentType: String, CaseIterable {
    case character = "chars"
    case stage = "stages"
    case screenpack = "data"
    case font = "font"
    case sound = "sound"
    
    var displayName: String {
        switch self {
        case .character: return "Characters"
        case .stage: return "Stages"
        case .screenpack: return "Screenpacks"
        case .font: return "Fonts"
        case .sound: return "Sounds"
        }
    }
    
    var directoryName: String {
        return rawValue
    }
}

// MARK: - Models (see Models/ folder)
// CharacterInfo -> Models/CharacterInfo.swift
// StageInfo -> Models/StageInfo.swift
// SFF parsing -> Core/SFFParser.swift

// MARK: - Engine State

/// Current state of the Ikemen GO engine
enum EngineState {
    case idle
    case launching
    case running
    case terminated(Int32)  // Exit code
    case error(Error)
}

// MARK: - Ikemen Bridge

/// Bridge between Swift app and Ikemen GO engine
class IkemenBridge: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = IkemenBridge()
    
    // MARK: - Published State
    
    @Published private(set) var engineState: EngineState = .idle
    @Published private(set) var characters: [CharacterInfo] = []
    @Published private(set) var stages: [StageInfo] = []
    
    // MARK: - Process
    
    private var ikemenProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    // MARK: - Paths
    
    private let appSupportURL: URL
    private let contentPath: URL
    private let charsPath: URL
    private let stagesPath: URL
    private let dataPath: URL
    private let fontPath: URL
    private let soundPath: URL
    
    // Engine binary path (bundled or development)
    private var enginePath: URL?
    private var engineWorkingDirectory: URL?
    
    // For tracking the launched app
    private var launchedAppPID: pid_t?
    private var terminationObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    private init() {
        // Setup application support directories
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportURL = appSupport.appendingPathComponent("MacMugen", isDirectory: true)
        
        // Content directories mirror Ikemen GO structure
        contentPath = appSupportURL.appendingPathComponent("Content", isDirectory: true)
        charsPath = contentPath.appendingPathComponent("chars", isDirectory: true)
        stagesPath = contentPath.appendingPathComponent("stages", isDirectory: true)
        dataPath = contentPath.appendingPathComponent("data", isDirectory: true)
        fontPath = contentPath.appendingPathComponent("font", isDirectory: true)
        soundPath = contentPath.appendingPathComponent("sound", isDirectory: true)
        
        createDirectoriesIfNeeded()
        findEngine()
        loadContent()
        setupTerminationObserver()
        
        print("IkemenBridge initialized")
        print("Content path: \(contentPath.path)")
        if let enginePath = enginePath {
            print("Engine path: \(enginePath.path)")
        }
    }
    
    deinit {
        if let observer = terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        terminateEngine()
    }
    
    // MARK: - Termination Observer
    
    private func setupTerminationObserver() {
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppTermination(notification)
        }
    }
    
    private func handleAppTermination(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        // Check if this is the Ikemen GO app we launched
        if let launchedPID = launchedAppPID, app.processIdentifier == launchedPID {
            print("Ikemen GO terminated (PID: \(launchedPID))")
            launchedAppPID = nil
            engineState = .idle
        } else if let executableURL = app.executableURL,
                  executableURL.lastPathComponent.contains("Ikemen") {
            // Fallback check by name
            print("Ikemen GO terminated: \(app.localizedName ?? "unknown")")
            launchedAppPID = nil
            engineState = .idle
        }
    }
    
    // MARK: - Directory Setup
    
    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default
        let directories = [appSupportURL, contentPath, charsPath, stagesPath, dataPath, fontPath, soundPath]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Engine Discovery
    
    private func findEngine() {
        let fileManager = FileManager.default
        
        // Check for bundled engine first
        if let bundledEngine = Bundle.main.url(forResource: "Ikemen_GO_MacOSARM", withExtension: nil, subdirectory: "Ikemen-GO") {
            enginePath = bundledEngine
            engineWorkingDirectory = bundledEngine.deletingLastPathComponent()
            return
        }
        
        // Check for bundled .app
        if let bundledApp = Bundle.main.url(forResource: "I.K.E.M.E.N-Go", withExtension: "app", subdirectory: "Ikemen-GO") {
            let binary = bundledApp.appendingPathComponent("Contents/MacOS/Ikemen_GO_MacOSARM")
            if fileManager.fileExists(atPath: binary.path) {
                enginePath = binary
                // Working directory should be where the content is (parent of .app)
                engineWorkingDirectory = bundledApp.deletingLastPathComponent()
                return
            }
        }
        
        // Development fallback - look in workspace
        let devPaths = [
            URL(fileURLWithPath: "/Users/davidphillips/Sites/macmame/Ikemen-GO/I.K.E.M.E.N-Go.app/Contents/MacOS/Ikemen_GO_MacOSARM"),
        ]
        
        for path in devPaths {
            if fileManager.fileExists(atPath: path.path) {
                enginePath = path
                // For the .app bundle, working directory is where content folders are
                engineWorkingDirectory = URL(fileURLWithPath: "/Users/davidphillips/Sites/macmame/Ikemen-GO")
                print("Found development engine at: \(path.path)")
                return
            }
        }
        
        print("Warning: Ikemen GO engine not found")
    }
    
    // MARK: - Content Management
    
    /// Reload all content from disk
    func loadContent() {
        loadCharacters()
        loadStages()
    }
    
    /// Load all characters from the chars directory
    private func loadCharacters() {
        var foundCharacters: [CharacterInfo] = []
        let fileManager = FileManager.default
        
        // Scan the chars directory in the engine's working directory
        guard let workingDir = engineWorkingDirectory else { return }
        let engineCharsPath = workingDir.appendingPathComponent("chars")
        
        guard let charDirs = try? fileManager.contentsOfDirectory(at: engineCharsPath, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for charDir in charDirs {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: charDir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            
            // Look for .def file with same name as directory
            let defFile = charDir.appendingPathComponent(charDir.lastPathComponent + ".def")
            if fileManager.fileExists(atPath: defFile.path) {
                let charInfo = CharacterInfo(directory: charDir, defFile: defFile)
                foundCharacters.append(charInfo)
            } else {
                // Try to find any .def file in the directory
                if let contents = try? fileManager.contentsOfDirectory(at: charDir, includingPropertiesForKeys: nil) {
                    for file in contents where file.pathExtension.lowercased() == "def" {
                        let charInfo = CharacterInfo(directory: charDir, defFile: file)
                        foundCharacters.append(charInfo)
                        break
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.characters = foundCharacters.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        }
        
        print("Loaded \(foundCharacters.count) characters")
    }
    
    /// Load all stages from the stages directory
    private func loadStages() {
        var foundStages: [StageInfo] = []
        let fileManager = FileManager.default
        
        guard let workingDir = engineWorkingDirectory else { return }
        let engineStagesPath = workingDir.appendingPathComponent("stages")
        
        guard let stageFiles = try? fileManager.contentsOfDirectory(at: engineStagesPath, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in stageFiles where file.pathExtension.lowercased() == "def" {
            let stageInfo = StageInfo(defFile: file)
            foundStages.append(stageInfo)
        }
        
        DispatchQueue.main.async {
            self.stages = foundStages.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        print("Loaded \(foundStages.count) stages")
    }
    
    // MARK: - Engine Control
    
    /// Launch Ikemen GO
    func launchEngine() throws {
        guard let workingDir = engineWorkingDirectory else {
            throw IkemenError.engineNotFound
        }
        
        // Don't launch if already running
        if case .running = engineState {
            print("Engine already running")
            return
        }
        
        DispatchQueue.main.async {
            self.engineState = .launching
        }
        
        // Find the .app bundle in the working directory
        let appBundlePath = workingDir.appendingPathComponent("I.K.E.M.E.N-Go.app")
        
        guard FileManager.default.fileExists(atPath: appBundlePath.path) else {
            throw IkemenError.engineNotFound
        }
        
        // Use NSWorkspace to properly launch the .app bundle
        // This is the correct way to launch macOS apps with proper window server integration
        let workspace = NSWorkspace.shared
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        
        DispatchQueue.main.async {
            self.engineState = .running
        }
        
        workspace.openApplication(at: appBundlePath, configuration: configuration) { [weak self] runningApp, error in
            if let error = error {
                print("Failed to launch Ikemen GO: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.engineState = .error(error)
                    self?.launchedAppPID = nil
                }
            } else if let app = runningApp {
                print("Ikemen GO launched successfully: \(app.localizedName ?? "unknown") (PID: \(app.processIdentifier))")
                DispatchQueue.main.async {
                    self?.launchedAppPID = app.processIdentifier
                }
            }
        }
    }
    
    /// Terminate the running engine
    func terminateEngine() {
        // Find running Ikemen GO instances by name since we launched via NSWorkspace
        let runningApps = NSWorkspace.shared.runningApplications
        
        var terminated = false
        for app in runningApps {
            // Check for Ikemen GO by executable name or bundle name
            if let executableURL = app.executableURL,
               executableURL.lastPathComponent.contains("Ikemen") {
                app.terminate()
                terminated = true
                print("Terminating Ikemen GO: \(app.localizedName ?? "unknown")")
            }
        }
        
        // Also try the old process reference if we have one
        if let process = ikemenProcess, process.isRunning {
            process.terminate()
            terminated = true
        }
        
        ikemenProcess = nil
        launchedAppPID = nil
        
        if terminated {
            DispatchQueue.main.async {
                self.engineState = .idle
            }
            print("Ikemen GO terminated")
        } else {
            print("No running Ikemen GO instance found")
            // Still reset state in case we're out of sync
            DispatchQueue.main.async {
                self.engineState = .idle
            }
        }
    }
    
    /// Check if engine is currently running
    var isEngineRunning: Bool {
        if case .running = engineState {
            return true
        }
        return false
    }
    
    // MARK: - Content Installation
    
    /// Install content from an archive file (zip, rar, 7z - auto-detects character or stage)
    func installContent(from archiveURL: URL) throws -> String {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Create temp directory
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let ext = archiveURL.pathExtension.lowercased()
        
        // Extract based on file type
        if ext == "zip" {
            // Extract zip using ditto (macOS native)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", archiveURL.path, tempDir.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw IkemenError.installFailed("Failed to extract zip file")
            }
        } else if ext == "rar" {
            // Use unrar for RAR files (better RAR5 support than 7z)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/unrar")
            process.arguments = ["x", "-y", archiveURL.path, tempDir.path + "/"]
            
            // Suppress output
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw IkemenError.installFailed("Failed to extract RAR file. Make sure unrar is installed (brew install rar)")
            }
        } else if ext == "7z" {
            // Use 7z for 7z files
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
            process.arguments = ["x", "-o\(tempDir.path)", "-y", archiveURL.path]
            
            // Suppress output
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw IkemenError.installFailed("Failed to extract 7z file. Make sure p7zip is installed (brew install p7zip)")
            }
        } else {
            throw IkemenError.installFailed("Unsupported archive format: \(ext). Supported: zip, rar, 7z")
        }
        
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
        
        return try installContentFolder(from: contentFolder)
    }
    
    /// Install content from a folder (auto-detects character or stage)
    func installContentFolder(from folderURL: URL) throws -> String {
        let fileManager = FileManager.default
        
        guard let workingDir = engineWorkingDirectory else {
            throw IkemenError.installFailed("Engine directory not found")
        }
        
        // Scan the folder to determine content type
        let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
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
                    return try installStageFolder(from: folderURL, to: workingDir)
                } else if isCharacterFile {
                    return try installCharacterFolder(from: folderURL, to: workingDir)
                }
            }
        }
        
        // Fallback: check for character-specific files
        let fileNames = contents.map { $0.lastPathComponent.lowercased() }
        let hasCharacterFiles = fileNames.contains { name in
            name.hasSuffix(".air") || name.hasSuffix(".cmd") || name.hasSuffix(".cns")
        }
        
        if hasCharacterFiles {
            return try installCharacterFolder(from: folderURL, to: workingDir)
        } else if !defFiles.isEmpty {
            // Default to stage if only has .def and .sff
            return try installStageFolder(from: folderURL, to: workingDir)
        }
        
        throw IkemenError.invalidContent("Could not determine content type. Ensure the folder contains character files (.def, .sff, .air, .cmd, .cns) or stage files (.def, .sff).")
    }
    
    private func installCharacterFolder(from source: URL, to workingDir: URL) throws -> String {
        let fileManager = FileManager.default
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
            if let defContent = try? String(contentsOf: defFile, encoding: .utf8) {
                for line in defContent.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.lowercased().hasPrefix("name") && !trimmed.lowercased().hasPrefix("displayname") {
                        if let value = trimmed.split(separator: "=").last {
                            displayName = String(value).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                            break
                        }
                    }
                }
            }
        }
        
        let destPath = charsDir.appendingPathComponent(charName)
        
        // Check if character already exists
        let isUpdate = fileManager.fileExists(atPath: destPath.path)
        if isUpdate {
            // Remove old version
            try fileManager.removeItem(at: destPath)
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
        
        // Reload characters
        loadCharacters()
        
        if !warnings.isEmpty {
            return "Installed character: \(displayName) ⚠️ \(warnings.joined(separator: ", "))"
        }
        return "Installed character: \(displayName)"
    }
    
    /// Validate character portrait and return any warnings
    private func validateCharacterPortrait(in charPath: URL) -> [String] {
        var warnings: [String] = []
        let fileManager = FileManager.default
        
        // Check for SFF file
        guard let contents = try? fileManager.contentsOfDirectory(at: charPath, includingPropertiesForKeys: nil) else {
            return warnings
        }
        
        let sffFiles = contents.filter { $0.pathExtension.lowercased() == "sff" }
        
        guard let sffFile = sffFiles.first else {
            warnings.append("No sprite file found")
            return warnings
        }
        
        // Try to read SFF header to check portrait sprite (9000,0)
        // SFF v1 and v2 have different formats
        if let portraitInfo = checkSFFPortrait(sffFile) {
            if portraitInfo.width > 200 || portraitInfo.height > 200 {
                warnings.append("Large portrait (\(portraitInfo.width)x\(portraitInfo.height))")
            } else if portraitInfo.width == 0 || portraitInfo.height == 0 {
                warnings.append("Missing portrait sprite")
            }
        }
        
        return warnings
    }
    
    /// Check SFF file for portrait sprite dimensions
    /// Returns (width, height) or nil if unable to parse
    private func checkSFFPortrait(_ sffURL: URL) -> (width: Int, height: Int)? {
        guard let data = try? Data(contentsOf: sffURL) else { return nil }
        guard data.count > 32 else { return nil }
        
        // Check SFF signature
        let signature = String(data: data[0..<12], encoding: .ascii) ?? ""
        
        if signature.hasPrefix("ElecbyteSpr") {
            // SFF v1 format
            return parseSFFv1Portrait(data)
        } else if signature.hasPrefix("ElecbyteSpr2") {
            // SFF v2 format - more complex, skip for now
            return nil
        }
        
        return nil
    }
    
    /// Parse SFF v1 to find portrait sprite (group 9000, image 0)
    private func parseSFFv1Portrait(_ data: Data) -> (width: Int, height: Int)? {
        guard data.count > 32 else { return nil }
        
        // Helper for safe unaligned reads
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
        
        // SFF v1 header:
        // 0-11: signature "ElecbyteSpr\0"
        // 12-15: version (little endian)
        // 16-19: number of groups
        // 20-23: number of images
        // 24-27: offset to first subfile
        // 28-31: size of subfile header
        
        let numImages = readUInt32(at: 20)
        let firstSubfileOffset = readUInt32(at: 24)
        
        guard numImages > 0, firstSubfileOffset < data.count else { return nil }
        
        // Each subfile header in v1:
        // 0-3: offset to next subfile
        // 4-7: subfile length
        // 8-9: x axis
        // 10-11: y axis
        // 12-13: group number
        // 14-15: image number
        // 16-17: index of previous image (for linked sprites)
        // 18: same palette flag
        // 19: blank/comment
        // Then: PCX image data
        
        var offset = Int(firstSubfileOffset)
        
        for _ in 0..<min(Int(numImages), 1000) { // Limit iterations
            guard offset + 20 <= data.count else { break }
            
            let nextOffset = readUInt32(at: offset)
            let groupNum = readUInt16(at: offset + 12)
            let imageNum = readUInt16(at: offset + 14)
            
            // Portrait is typically group 9000, image 0
            if groupNum == 9000 && imageNum == 0 {
                // Found portrait, try to get dimensions from PCX header
                let pcxOffset = offset + 32 // Skip subfile header
                if pcxOffset + 12 <= data.count {
                    // PCX header: xmin(2), ymin(2), xmax(2), ymax(2) at offset 4
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
    
    /// Find the correct select.def entry for a character
    /// Returns "folder/name.def" if folder name doesn't match def name, otherwise just "folder"
    private func findCharacterDefEntry(charName: String, in charPath: URL) -> String {
        let fileManager = FileManager.default
        
        // Look for .def files in the character folder
        guard let contents = try? fileManager.contentsOfDirectory(at: charPath, includingPropertiesForKeys: nil) else {
            return charName
        }
        
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // If there's exactly one .def file and its name doesn't match the folder
        if defFiles.count == 1, let defFile = defFiles.first {
            let defName = defFile.deletingPathExtension().lastPathComponent
            if defName.lowercased() != charName.lowercased() {
                // Need to specify the full path: folder/name.def
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
        
        // Fallback to just folder name
        return charName
    }
    
    private func addCharacterToSelectDef(_ charEntry: String, in workingDir: URL) throws {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard FileManager.default.fileExists(atPath: selectDefPath.path) else {
            print("Warning: select.def not found at \(selectDefPath.path)")
            return
        }
        
        // Read current content
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        // Check if character is already in the file (check both full entry and folder name)
        let folderName = charEntry.contains("/") ? String(charEntry.split(separator: "/").first!) : charEntry
        let charPattern = "(?m)^\\s*\(NSRegularExpression.escapedPattern(for: folderName))(/|\\s|,|$)"
        if let regex = try? NSRegularExpression(pattern: charPattern, options: .caseInsensitive),
           regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
            print("Character \(charEntry) already in select.def")
            return
        }
        
        // Find the [Characters] section and add the character after it
        // Look for existing character entries and add after them
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        var foundCharactersSection = false
        var insertedCharacter = false
        
        for line in lines {
            newLines.append(line)
            
            // Check if we're entering the [Characters] section
            if line.trimmingCharacters(in: .whitespaces).lowercased() == "[characters]" {
                foundCharactersSection = true
            }
            
            // If we're in the Characters section and haven't inserted yet,
            // look for a good place to insert (after comment block or after existing chars)
            if foundCharactersSection && !insertedCharacter {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Insert after we see a non-comment, non-empty line that looks like a character entry
                // or after the section header's comment block ends
                if !trimmed.isEmpty && !trimmed.hasPrefix(";") && !trimmed.hasPrefix("[") {
                    // This is likely a character entry, we'll insert after a few of these
                    continue
                }
                // If we hit a new section, insert before it
                if trimmed.hasPrefix("[") && trimmed.lowercased() != "[characters]" {
                    // Insert before this section
                    newLines.insert(charEntry, at: newLines.count - 1)
                    insertedCharacter = true
                }
            }
        }
        
        // If we still haven't inserted (maybe the file structure is different),
        // just append after [Characters] section
        if !insertedCharacter && foundCharactersSection {
            // Find [Characters] and insert after it and its comments
            var insertIndex = 0
            var inCharSection = false
            for (i, line) in newLines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased() == "[characters]" {
                    inCharSection = true
                    insertIndex = i + 1
                    continue
                }
                if inCharSection {
                    // Skip comments and empty lines
                    if trimmed.isEmpty || trimmed.hasPrefix(";") {
                        insertIndex = i + 1
                    } else if trimmed.hasPrefix("[") {
                        // Hit next section, insert here
                        break
                    } else {
                        // Found a character entry, insert after it
                        insertIndex = i + 1
                    }
                }
            }
            newLines.insert(charEntry, at: insertIndex)
        }
        
        // Write back
        content = newLines.joined(separator: "\n")
        try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
        print("Added \(charEntry) to select.def")
    }
    
    private func installStageFolder(from source: URL, to workingDir: URL) throws -> String {
        let fileManager = FileManager.default
        let stagesDir = workingDir.appendingPathComponent("stages")
        
        // For stages, we need to copy the .def file(s) and any associated files
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
                installedStages.append(file.deletingPathExtension().lastPathComponent)
            }
        }
        
        // Add stages to select.def
        for stageName in installedStages {
            try addStageToSelectDef(stageName, in: workingDir)
        }
        
        // Reload stages
        loadStages()
        
        if installedStages.count == 1 {
            return "Installed stage: \(installedStages[0])"
        } else if installedStages.count > 1 {
            return "Installed \(installedStages.count) stages: \(installedStages.joined(separator: ", "))"
        } else {
            return "No stages found to install"
        }
    }
    
    private func addStageToSelectDef(_ stageName: String, in workingDir: URL) throws {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard FileManager.default.fileExists(atPath: selectDefPath.path) else {
            return
        }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        // Check if stage is already in the [ExtraStages] section
        let stageEntry = "stages/\(stageName).def"
        if content.contains(stageEntry) {
            return
        }
        
        // Find [ExtraStages] section and add the stage
        if let range = content.range(of: "[ExtraStages]", options: .caseInsensitive) {
            // Find the end of the line after [ExtraStages]
            if let lineEnd = content.range(of: "\n", range: range.upperBound..<content.endIndex) {
                let insertPosition = lineEnd.upperBound
                content.insert(contentsOf: "\(stageEntry)\n", at: insertPosition)
                try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
                print("Added stage \(stageName) to select.def")
            }
        }
    }
    
    /// Install a character from a zip file
    func installCharacter(from zipURL: URL) throws {
        _ = try installContent(from: zipURL)
    }
    
    /// Install a stage from a zip file
    func installStage(from zipURL: URL) throws {
        _ = try installContent(from: zipURL)
    }
    
    // MARK: - Paths
    
    /// Get the content directory URL
    func getContentPath() -> URL {
        return contentPath
    }
    
    /// Get the characters directory URL
    func getCharsPath() -> URL {
        return charsPath
    }
    
    /// Get the stages directory URL
    func getStagesPath() -> URL {
        return stagesPath
    }
    
    /// Get path for a specific content type
    func getPath(for contentType: ContentType) -> URL {
        switch contentType {
        case .character: return charsPath
        case .stage: return stagesPath
        case .screenpack: return dataPath
        case .font: return fontPath
        case .sound: return soundPath
        }
    }
}
