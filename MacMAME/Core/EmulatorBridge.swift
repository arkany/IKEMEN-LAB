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
    @Published private(set) var screenpacks: [ScreenpackInfo] = []
    @Published private(set) var activeScreenpackPath: String?
    
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
        loadScreenpacks()
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
    
    /// Load all screenpacks from the data directory
    private func loadScreenpacks() {
        var foundScreenpacks: [ScreenpackInfo] = []
        let fileManager = FileManager.default
        
        guard let workingDir = engineWorkingDirectory else { return }
        let dataPath = workingDir.appendingPathComponent("data")
        
        // First, read the active screenpack from config
        let activeMotif = readActiveMotifFromConfig(in: workingDir)
        
        // Look for screenpack directories in data/
        guard let dataDirs = try? fileManager.contentsOfDirectory(at: dataPath, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for dir in dataDirs {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: dir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            
            // Look for system.def in the directory
            let systemDef = dir.appendingPathComponent("system.def")
            if fileManager.fileExists(atPath: systemDef.path) {
                // Check if this is the active screenpack
                let relativePath = "data/\(dir.lastPathComponent)/system.def"
                let isActive = (activeMotif == relativePath) || (activeMotif == dir.lastPathComponent)
                
                var screenpackInfo = ScreenpackInfo(defFile: systemDef, isActive: isActive)
                foundScreenpacks.append(screenpackInfo)
            }
        }
        
        // Also check for system.def directly in data/ (default screenpack)
        let defaultSystemDef = dataPath.appendingPathComponent("system.def")
        if fileManager.fileExists(atPath: defaultSystemDef.path) {
            let isActive = (activeMotif == "data/system.def") || (activeMotif == nil) || activeMotif?.isEmpty == true
            var defaultScreenpack = ScreenpackInfo(defFile: defaultSystemDef, isActive: isActive)
            foundScreenpacks.append(defaultScreenpack)
        }
        
        DispatchQueue.main.async {
            self.activeScreenpackPath = activeMotif
            self.screenpacks = foundScreenpacks.sorted { 
                // Active first, then alphabetical
                if $0.isActive != $1.isActive {
                    return $0.isActive
                }
                return $0.name.lowercased() < $1.name.lowercased() 
            }
        }
        
        print("Loaded \(foundScreenpacks.count) screenpacks, active: \(activeMotif ?? "default")")
    }
    
    /// Read the active motif/screenpack path from Ikemen's config
    private func readActiveMotifFromConfig(in workingDir: URL) -> String? {
        // Ikemen GO uses save/config.ini for the Motif setting
        let configIniPath = workingDir.appendingPathComponent("save/config.ini")
        
        if let content = try? String(contentsOf: configIniPath, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Look for "Motif = value" (case-insensitive key)
                if trimmed.lowercased().hasPrefix("motif") && trimmed.contains("=") {
                    if let equalsIndex = trimmed.firstIndex(of: "=") {
                        let value = String(trimmed[trimmed.index(after: equalsIndex)...])
                            .trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "\"", with: "")
                        if !value.isEmpty {
                            return value
                        }
                    }
                }
            }
        }
        
        // Fallback to data/system.def as default
        return "data/system.def"
    }
    
    /// Set the active screenpack
    func setActiveScreenpack(_ screenpack: ScreenpackInfo) {
        guard let workingDir = engineWorkingDirectory else { return }
        
        // Calculate the relative path for the motif
        let relativePath: String
        if screenpack.defFile.deletingLastPathComponent().lastPathComponent == "data" {
            // Default screenpack in data/system.def
            relativePath = "data/system.def"
        } else {
            // Screenpack in subdirectory data/name/system.def
            let folderName = screenpack.defFile.deletingLastPathComponent().lastPathComponent
            relativePath = "data/\(folderName)/system.def"
        }
        
        // Update config.ini (the actual Ikemen GO config file)
        let configPath = workingDir.appendingPathComponent("save/config.ini")
        
        do {
            guard FileManager.default.fileExists(atPath: configPath.path) else {
                print("config.ini not found at \(configPath.path)")
                return
            }
            
            var content = try String(contentsOf: configPath, encoding: .utf8)
            
            // Replace the Motif line in [Config] section
            // Pattern: Motif followed by spaces/tabs, =, spaces/tabs, then the value
            let motifPattern = #"(Motif\s*=\s*).+"#
            if let regex = try? NSRegularExpression(pattern: motifPattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                content = regex.stringByReplacingMatches(
                    in: content,
                    options: [],
                    range: range,
                    withTemplate: "$1\(relativePath)"
                )
            }
            
            try content.write(to: configPath, atomically: true, encoding: .utf8)
            
            print("Set active screenpack to: \(relativePath)")
            
            // Reload screenpacks to update active state
            loadScreenpacks()
            
        } catch {
            print("Failed to set active screenpack: \(error)")
        }
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
        guard let workingDir = engineWorkingDirectory else {
            throw IkemenError.installFailed("Engine directory not found")
        }
        
        let result = try ContentManager.shared.installContent(from: archiveURL, to: workingDir)
        
        // Reload content after installation
        loadCharacters()
        loadStages()
        loadScreenpacks()
        
        return result
    }
    
    /// Install content from a folder (auto-detects character or stage)
    func installContentFolder(from folderURL: URL) throws -> String {
        guard let workingDir = engineWorkingDirectory else {
            throw IkemenError.installFailed("Engine directory not found")
        }
        
        let result = try ContentManager.shared.installContentFolder(from: folderURL, to: workingDir)
        
        // Reload content after installation
        loadCharacters()
        loadStages()
        loadScreenpacks()
        
        return result
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
