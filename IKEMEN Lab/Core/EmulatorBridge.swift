import Foundation
import Combine
import AppKit

// MARK: - Notifications

extension Notification.Name {
    static let contentChanged = Notification.Name("ContentChanged")
    static let gameStatusChanged = Notification.Name("GameStatusChanged")
}

// MARK: - Errors

/// Error types for Ikemen GO operations
enum IkemenError: LocalizedError {
    case engineNotFound
    case engineLaunchFailed(String)
    case contentNotFound(String)
    case installFailed(String)
    case invalidContent(String)
    case duplicateContent(String)
    
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
        case .duplicateContent(let name):
            return "Content already exists: \(name)"
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
        case .duplicateContent:
            return "Do you want to replace the existing content?"
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
    
    /// Public accessor for the Ikemen GO working directory
    public var workingDirectory: URL? {
        return engineWorkingDirectory
    }
    
    /// Set the working directory (used by FRE when user selects IKEMEN GO location)
    public func setWorkingDirectory(_ url: URL) {
        engineWorkingDirectory = url
        
        // Try to find the engine binary in the new location
        let fm = FileManager.default
        let possibleBinaries = [
            url.appendingPathComponent("Ikemen_GO_MacOSARM"),
            url.appendingPathComponent("Ikemen_GO_MacOS"),
            url.appendingPathComponent("I.K.E.M.E.N-Go.app/Contents/MacOS/Ikemen_GO_MacOSARM"),
            url.appendingPathComponent("I.K.E.M.E.N-Go.app/Contents/MacOS/Ikemen_GO_MacOS"),
        ]
        
        for binary in possibleBinaries {
            if fm.fileExists(atPath: binary.path) {
                enginePath = binary
                print("Found engine at: \(binary.path)")
                break
            }
        }
    }
    
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
        setupCollectionObserver()
        
        print("IkemenBridge initialized")
        print("Content path: \(contentPath.path)")
        if let enginePath = enginePath {
            print("Engine path: \(enginePath.path)")
        }
        
        // Listen for collection activation
    }
    
    deinit {
        if let observer = terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self, name: .collectionActivated, object: nil)
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
            NotificationCenter.default.post(name: .gameStatusChanged, object: nil)
        } else if let executableURL = app.executableURL,
                  executableURL.lastPathComponent.contains("Ikemen") {
            // Fallback check by name
            print("Ikemen GO terminated: \(app.localizedName ?? "unknown")")
            launchedAppPID = nil
            engineState = .idle
            NotificationCenter.default.post(name: .gameStatusChanged, object: nil)
        }
    }
    
    private func setupCollectionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCollectionActivated(_:)),
            name: .collectionActivated,
            object: nil
        )
    }
    
    @objc private func handleCollectionActivated(_ notification: Notification) {
        guard let collection = notification.object as? Collection,
              let engineDir = workingDirectory else {
            return
        }
        
        // Validate collection first
        let missing = SelectDefGenerator.validateCollection(collection, ikemenPath: engineDir)
        if !missing.isEmpty {
            let message = "Collection includes \(missing.count) missing characters: \(missing.joined(separator: ", "))"
            print("Activation Warning: \(message)")
            // Future: Show alert to user? For now proceed but log it.
        }
        
        // Generate select.def
        let result = SelectDefGenerator.writeSelectDef(for: collection, ikemenPath: engineDir)
        
        switch result {
        case .success(let url):
            print("Successfully activated collection: \(collection.name)")
            DispatchQueue.main.async {
                ToastManager.shared.showSuccess(title: "Collection activated", subtitle: collection.name)
            }
            // If screenpack also changed, we might need to update config.json (not implemented yet)
            
        case .failure(let error):
            print("Failed to activate collection: \(error)")
            DispatchQueue.main.async {
                ToastManager.shared.showError(title: "Failed to activate collection", subtitle: error.localizedDescription)
            }
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
    
    /// Refresh stages list from disk
    func refreshStages() {
        loadStages()
    }
    
    /// Load all characters from the chars directory
    private func loadCharacters() {
        var foundCharacters: [CharacterInfo] = []
        let fileManager = FileManager.default
        
        // Scan the chars directory in the engine's working directory
        guard let workingDir = engineWorkingDirectory else { return }
        let engineCharsPath = workingDir.appendingPathComponent("chars")
        
        // Parse select.def status
        let (activeSet, disabledSet, selectDefOrder) = parseSelectDefStatus(in: workingDir)
        
        guard let charDirs = try? fileManager.contentsOfDirectory(at: engineCharsPath, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for charDir in charDirs {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: charDir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            
            // Look for .def file
            let defName = charDir.lastPathComponent + ".def"
            let directDefFile = charDir.appendingPathComponent(defName)
            var targetDefFile: URL?

            if fileManager.fileExists(atPath: directDefFile.path) && DEFParser.isValidCharacterDefFile(directDefFile) {
                targetDefFile = directDefFile
            } else {
                // Try to find a suitable .def file in the directory
                if let contents = try? fileManager.contentsOfDirectory(at: charDir, includingPropertiesForKeys: nil) {
                    let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
                    // Filter to only valid character def files
                    let characterDefFiles = defFiles.filter { DEFParser.isValidCharacterDefFile($0) }
                    
                    // Prefer def file matching folder name, otherwise take first valid one
                    let folderName = charDir.lastPathComponent.lowercased()
                    let preferredDef = characterDefFiles.first { file in
                        file.deletingPathExtension().lastPathComponent.lowercased() == folderName
                    } ?? characterDefFiles.first
                    
                    targetDefFile = preferredDef
                }
            }
            
            if let defFile = targetDefFile {
                // determine status
                let folderName = charDir.lastPathComponent
                let fileDefName = defFile.lastPathComponent
                let relativePath = "\(folderName)/\(fileDefName)".lowercased()
                
                var status: ContentStatus = .unregistered
                if activeSet.contains(relativePath) {
                    status = .active
                } else if disabledSet.contains(relativePath) {
                    status = .disabled
                }
                
                let charInfo = CharacterInfo(directory: charDir, defFile: defFile, status: status)
                foundCharacters.append(charInfo)
            }
        }
        
        // Sort characters according to select.def order
        let sortedCharacters = sortCharactersBy(selectDefOrder: selectDefOrder, characters: foundCharacters)
        
        DispatchQueue.main.async {
            self.characters = sortedCharacters
            
            // Sync the default collection with loaded characters
            let charData = sortedCharacters.map { (folder: $0.directory.lastPathComponent, def: $0.defFile.lastPathComponent) }
            CollectionStore.shared.syncDefaultCollectionCharacters(charData)
            
            // If the default collection is active, regenerate select.def with the new content
            if let active = CollectionStore.shared.activeCollection, active.isDefault,
               let workingDir = self.engineWorkingDirectory {
                print("Default collection updated with new characters, regenerating select.def...")
                // Regenerate directly to avoid "Collection Activated" notification
                _ = SelectDefGenerator.writeSelectDef(for: active, ikemenPath: workingDir)
            }
        }
        
        print("Loaded \(foundCharacters.count) characters")
    }
    
    /// Sort characters according to select.def order, with any unlisted characters at the end alphabetically
    private func sortCharactersBy(selectDefOrder: [String], characters: [CharacterInfo]) -> [CharacterInfo] {
        var result: [CharacterInfo] = []
        var remaining = characters
        
        // First, add characters in select.def order
        for name in selectDefOrder {
            if let index = remaining.firstIndex(where: { $0.directory.lastPathComponent.lowercased() == name.lowercased() }) {
                result.append(remaining[index])
                remaining.remove(at: index)
            }
        }
        
        // Add remaining characters (not in select.def) alphabetically at the end
        let sortedRemaining = remaining.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        result.append(contentsOf: sortedRemaining)
        
        return result
    }
    
    /// Load all stages from the stages directory
    private func loadStages() {
        var foundStages: [StageInfo] = []
        let fileManager = FileManager.default
        
        guard let workingDir = engineWorkingDirectory else { return }
        let engineStagesPath = workingDir.appendingPathComponent("stages")

        // Parse select.def for stage status
        let (activeSet, disabledSet) = parseSelectDefStageStatus(in: workingDir)
        
        // Helper to determine status
        func getStatus(for defURL: URL) -> ContentStatus {
             let path = defURL.path
             let root = workingDir.path
             
             if path.hasPrefix(root) {
                 var relative = String(path.dropFirst(root.count))
                 if relative.hasPrefix("/") { relative = String(relative.dropFirst()) }
                 let key = relative.replacingOccurrences(of: "\\", with: "/").lowercased()
                 
                 if activeSet.contains(key) { return .active }
                 if disabledSet.contains(key) { return .disabled }
             }
             return .unregistered
        }
        
        // Search for .def files at top level and one level deep (in subdirectories)
        guard let stageItems = try? fileManager.contentsOfDirectory(at: engineStagesPath, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for item in stageItems {
            // Check if it's a .def file at top level
            if item.pathExtension.lowercased() == "def" {
                if DEFParser.isValidStageDefFile(item) {
                    let status = getStatus(for: item)
                    let stageInfo = StageInfo(defFile: item, status: status)
                    foundStages.append(stageInfo)
                }
            }
            
            // Check if it's a directory - look for .def files inside
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                if let subItems = try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                    for subItem in subItems where subItem.pathExtension.lowercased() == "def" {
                        if DEFParser.isValidStageDefFile(subItem) {
                            let status = getStatus(for: subItem)
                            let stageInfo = StageInfo(defFile: subItem, status: status)
                            foundStages.append(stageInfo)
                        }
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            let sortedStages = foundStages.sorted { $0.name.lowercased() < $1.name.lowercased() }
            self.stages = sortedStages
            
            // Sync default collection
            let stagePaths = sortedStages.map { stage -> String in
                let path = stage.defFile
                // If parent is "stages", return just filename (e.g. "my_stage.def")
                // If parent is subfolder, return subfolder name (e.g. "MyStage")
                if path.deletingLastPathComponent().lastPathComponent == "stages" {
                    return path.lastPathComponent
                } else {
                    return path.deletingLastPathComponent().lastPathComponent
                }
            }
            CollectionStore.shared.syncDefaultCollectionStages(stagePaths)
            
            // If the default collection is active, regenerate select.def with the new content
            if let active = CollectionStore.shared.activeCollection, active.isDefault,
               let workingDir = self.engineWorkingDirectory {
                print("Default collection updated with new stages, regenerating select.def...")
                // Regenerate directly to avoid "Collection Activated" notification
                _ = SelectDefGenerator.writeSelectDef(for: active, ikemenPath: workingDir)
            }
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
                    NotificationCenter.default.post(name: .gameStatusChanged, object: nil)
                }
            } else if let app = runningApp {
                print("Ikemen GO launched successfully: \(app.localizedName ?? "unknown") (PID: \(app.processIdentifier))")
                DispatchQueue.main.async {
                    self?.launchedAppPID = app.processIdentifier
                    self?.engineState = .running
                    NotificationCenter.default.post(name: .gameStatusChanged, object: nil)
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
    func installContent(from archiveURL: URL, overwrite: Bool = false) throws -> String {
        guard let workingDir = engineWorkingDirectory else {
            throw IkemenError.installFailed("Engine directory not found")
        }
        
        let result = try ContentManager.shared.installContent(from: archiveURL, to: workingDir, overwrite: overwrite)
        
        // Reload content after installation
        loadCharacters()
        loadStages()
        loadScreenpacks()
        
        return result
    }
    
    /// Install content from a folder (auto-detects character or stage)
    func installContentFolder(from folderURL: URL, overwrite: Bool = false) throws -> String {
        guard let workingDir = engineWorkingDirectory else {
            throw IkemenError.installFailed("Engine directory not found")
        }
        
        let result = try ContentManager.shared.installContentFolder(from: folderURL, to: workingDir, overwrite: overwrite)
        
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

// MARK: - Select.def Parsing Helper
private extension IkemenBridge {
    func parseSelectDefStatus(in workingDir: URL) -> (active: Set<String>, disabled: Set<String>, order: [String]) {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        var active = Set<String>()
        var disabled = Set<String>()
        var order: [String] = []
        
        guard let content = try? String(contentsOf: selectDefPath, encoding: .utf8) else {
            return (active, disabled, order)
        }
        
        var inChars = false
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.lowercased().hasPrefix("[characters]") {
                inChars = true
                continue
            } else if trimmed.hasPrefix("[") && !trimmed.lowercased().hasPrefix("[characters]") {
                inChars = false
            }
            
            if inChars {
                let isCommented = trimmed.hasPrefix(";")
                let cleanLine = isCommented ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed
                let components = cleanLine.components(separatedBy: ",")
                guard let rawName = components.first?.trimmingCharacters(in: .whitespaces), 
                      !rawName.isEmpty, 
                      rawName.lowercased() != "empty",
                      rawName.lowercased() != "random",
                      rawName.lowercased() != "randomselect" else { continue }
                
                // Normalize to "folder/file.def"
                var normalized: String
                if rawName.contains("/") {
                    normalized = rawName.lowercased()
                } else {
                    normalized = "\(rawName.lowercased())/\(rawName.lowercased()).def"
                }

                // Append .def if missing
                if !normalized.hasSuffix(".def") {
                     normalized += ".def"
                }
                
                if isCommented {
                    disabled.insert(normalized)
                } else {
                    active.insert(normalized)
                    order.append(rawName)
                }
            }
        }
        return (active, disabled, order)
    }

    func parseSelectDefStageStatus(in workingDir: URL) -> (active: Set<String>, disabled: Set<String>) {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        var active = Set<String>()
        var disabled = Set<String>()
        
        guard let content = try? String(contentsOf: selectDefPath, encoding: .utf8) else {
            return (active, disabled)
        }
        
        var inStages = false
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.lowercased().hasPrefix("[extrastages]") {
                inStages = true
                continue
            } else if trimmed.hasPrefix("[") && !trimmed.lowercased().hasPrefix("[extrastages]") {
                inStages = false
            }
            
            if inStages {
                let isCommented = trimmed.hasPrefix(";")
                let cleanLine = isCommented ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces) : trimmed
                
                let components = cleanLine.components(separatedBy: ",")
                guard let rawPath = components.first?.trimmingCharacters(in: .whitespaces), 
                      !rawPath.isEmpty else { continue }
                
                let normalized = rawPath.replacingOccurrences(of: "\\", with: "/").lowercased()
                
                if isCommented {
                    disabled.insert(normalized)
                } else {
                    active.insert(normalized)
                }
            }
        }
        return (active, disabled)
    }
}
