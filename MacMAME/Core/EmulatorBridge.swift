import Foundation

/// Error types for emulator operations
enum EmulatorError: LocalizedError {
    case notInitialized
    case gameNotFound(String)
    case biosRequired(String)
    case loadFailed(String)
    case saveStateFailed(String)
    case loadStateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Emulator not initialized"
        case .gameNotFound(let name):
            return "Game file not found: \(name)"
        case .biosRequired(let bios):
            return "Required system file missing: \(bios)"
        case .loadFailed(let reason):
            return "Failed to load game: \(reason)"
        case .saveStateFailed(let reason):
            return "Failed to save state: \(reason)"
        case .loadStateFailed(let reason):
            return "Failed to load state: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notInitialized:
            return "Try restarting the application."
        case .gameNotFound:
            return "Make sure the game file exists and try again."
        case .biosRequired:
            return "Add the required system file in Preferences → Firmware & BIOS."
        case .loadFailed:
            return "The file may be corrupted or unsupported."
        case .saveStateFailed, .loadStateFailed:
            return "Try a different save slot."
        }
    }
}

/// Game metadata
struct GameInfo {
    let name: String
    let title: String
    let manufacturer: String
    let year: String
    let screenWidth: Int
    let screenHeight: Int
    let refreshRate: Double
    
    static let placeholder = GameInfo(
        name: "unknown",
        title: "Unknown Game",
        manufacturer: "Unknown",
        year: "????",
        screenWidth: 320,
        screenHeight: 240,
        refreshRate: 60.0
    )
}

/// Performance metrics
struct PerformanceMetrics {
    var fps: Double = 0
    var frameTimeMs: Double = 0
    var emulationSpeed: Double = 1.0 // 1.0 = 100%
}

/// Bridge between Swift app and MAME core
/// This is a stub implementation - will be connected to MAMECore.framework in Phase 2
class EmulatorBridge {
    
    // MARK: - State
    
    private(set) var isInitialized: Bool = false
    private(set) var isGameLoaded: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var currentGame: GameInfo?
    private(set) var metrics: PerformanceMetrics = PerformanceMetrics()
    
    // MARK: - Paths
    
    private let appSupportURL: URL
    private let romPath: URL
    private let biosPath: URL
    private let savePath: URL
    
    // MARK: - Initialization
    
    init() {
        // Setup application support directories
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportURL = appSupport.appendingPathComponent("MacMAME", isDirectory: true)
        
        romPath = appSupportURL.appendingPathComponent("Games", isDirectory: true)
        biosPath = appSupportURL.appendingPathComponent("BIOS", isDirectory: true)
        savePath = appSupportURL.appendingPathComponent("SaveStates", isDirectory: true)
        
        createDirectoriesIfNeeded()
        initialize()
    }
    
    deinit {
        shutdown()
    }
    
    // MARK: - Directory Setup
    
    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default
        let directories = [appSupportURL, romPath, biosPath, savePath]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Lifecycle
    
    private func initialize() {
        // TODO: Initialize MAMECore.framework
        // mame_create()
        // mame_configure(...)
        
        isInitialized = true
        print("EmulatorBridge initialized (stub)")
        print("ROM path: \(romPath.path)")
        print("BIOS path: \(biosPath.path)")
        print("Save path: \(savePath.path)")
    }
    
    private func shutdown() {
        if isGameLoaded {
            stop()
        }
        
        // TODO: Cleanup MAMECore.framework
        // mame_destroy()
        
        isInitialized = false
    }
    
    // MARK: - Game Loading
    
    func loadGame(at url: URL) throws {
        guard isInitialized else {
            throw EmulatorError.notInitialized
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EmulatorError.gameNotFound(url.lastPathComponent)
        }
        
        // TODO: Call MAMECore to load game
        // let result = mame_load_game(instance, url.path)
        
        // For now, simulate successful load
        currentGame = GameInfo(
            name: url.deletingPathExtension().lastPathComponent,
            title: url.deletingPathExtension().lastPathComponent,
            manufacturer: "Unknown",
            year: "????",
            screenWidth: 320,
            screenHeight: 240,
            refreshRate: 60.0
        )
        
        isGameLoaded = true
        isPaused = false
        
        print("Loaded game: \(url.lastPathComponent) (stub)")
    }
    
    func unloadGame() {
        // TODO: Call MAMECore to unload
        // mame_unload_game(instance)
        
        currentGame = nil
        isGameLoaded = false
        isPaused = false
    }
    
    // MARK: - Emulation Control
    
    func runFrame() {
        guard isGameLoaded, !isPaused else { return }
        
        // TODO: Call MAMECore to run one frame
        // mame_run_frame(instance)
    }
    
    func pause() {
        guard isGameLoaded else { return }
        isPaused = true
        
        // TODO: Call MAMECore
        // mame_pause(instance)
    }
    
    func resume() {
        guard isGameLoaded else { return }
        isPaused = false
        
        // TODO: Call MAMECore
        // mame_resume(instance)
    }
    
    func reset() {
        guard isGameLoaded else { return }
        
        // TODO: Call MAMECore
        // mame_reset(instance)
        
        print("Reset game (stub)")
    }
    
    func stop() {
        unloadGame()
    }
    
    // MARK: - Input
    
    func keyDown(keyCode: UInt16) {
        guard isGameLoaded else { return }
        
        // TODO: Map keyCode to MAME input and call MAMECore
        // let mameInput = mapKeyToInput(keyCode)
        // mame_set_input(instance, 0, mameInput, true)
        
        #if DEBUG
        print("Key down: \(keyCode)")
        #endif
    }
    
    func keyUp(keyCode: UInt16) {
        guard isGameLoaded else { return }
        
        // TODO: Map keyCode to MAME input and call MAMECore
        // let mameInput = mapKeyToInput(keyCode)
        // mame_set_input(instance, 0, mameInput, false)
        
        #if DEBUG
        print("Key up: \(keyCode)")
        #endif
    }
    
    // MARK: - Save States
    
    func saveState(slot: Int) throws {
        guard isGameLoaded, let game = currentGame else {
            throw EmulatorError.notInitialized
        }
        
        let stateURL = savePath
            .appendingPathComponent(game.name, isDirectory: true)
            .appendingPathComponent("slot-\(slot).state")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // TODO: Call MAMECore to save state
        // mame_save_state(instance, stateURL.path)
        
        print("Saved state to slot \(slot) (stub)")
    }
    
    func loadState(slot: Int) throws {
        guard isGameLoaded, let game = currentGame else {
            throw EmulatorError.notInitialized
        }
        
        let stateURL = savePath
            .appendingPathComponent(game.name, isDirectory: true)
            .appendingPathComponent("slot-\(slot).state")
        
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            throw EmulatorError.loadStateFailed("Save file not found")
        }
        
        // TODO: Call MAMECore to load state
        // mame_load_state(instance, stateURL.path)
        
        print("Loaded state from slot \(slot) (stub)")
    }
    
    // MARK: - Video Output
    
    // TODO: Return MTLTexture from MAMECore when integrated
    // func getVideoTexture() -> MTLTexture? { ... }
}
