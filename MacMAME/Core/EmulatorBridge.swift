import Foundation
import Metal

// MARK: - Errors

/// Error types for emulator operations
enum EmulatorError: LocalizedError {
    case notInitialized
    case gameNotFound(String)
    case coreNotFound(String)
    case coreLoadFailed(String)
    case gameLoadFailed(String)
    case biosRequired(String)
    case saveStateFailed(String)
    case loadStateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Emulator not initialized"
        case .gameNotFound(let name):
            return "Game file not found: \(name)"
        case .coreNotFound(let name):
            return "Emulation core not found: \(name)"
        case .coreLoadFailed(let reason):
            return "Failed to load emulation core: \(reason)"
        case .gameLoadFailed(let reason):
            return "Failed to load game: \(reason)"
        case .biosRequired(let bios):
            return "Required system file missing: \(bios)"
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
        case .coreNotFound:
            return "The emulation core may be missing from the app bundle."
        case .coreLoadFailed:
            return "Try a different emulation core."
        case .gameLoadFailed:
            return "The file may be corrupted or unsupported by this core."
        case .biosRequired:
            return "Add the required system file in Preferences → Firmware & BIOS."
        case .saveStateFailed, .loadStateFailed:
            return "Try a different save slot."
        }
    }
}

// MARK: - Core Type

enum EmulatorCoreType: String, CaseIterable {
    case fbneo = "fbneo_libretro"
    case mame = "mame_libretro"
    
    var displayName: String {
        switch self {
        case .fbneo: return "FBNeo (Fighting Games)"
        case .mame: return "MAME (Full Arcade)"
        }
    }
    
    var filename: String {
        return rawValue + ".dylib"
    }
}

// MARK: - Game Info

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

// MARK: - Performance Metrics

/// Performance metrics
struct PerformanceMetrics {
    var fps: Double = 0
    var frameTimeMs: Double = 0
    var emulationSpeed: Double = 1.0 // 1.0 = 100%
}

// MARK: - Input Mapping

/// Maps macOS key codes to libretro joypad buttons
struct InputMapping {
    // Player 1 default mapping
    static let player1: [UInt16: Int32] = [
        126: RETRO_DEVICE_ID_JOYPAD_UP,      // Up arrow
        125: RETRO_DEVICE_ID_JOYPAD_DOWN,    // Down arrow
        123: RETRO_DEVICE_ID_JOYPAD_LEFT,    // Left arrow
        124: RETRO_DEVICE_ID_JOYPAD_RIGHT,   // Right arrow
        6:   RETRO_DEVICE_ID_JOYPAD_A,       // Z
        7:   RETRO_DEVICE_ID_JOYPAD_B,       // X
        0:   RETRO_DEVICE_ID_JOYPAD_X,       // A
        1:   RETRO_DEVICE_ID_JOYPAD_Y,       // S
        12:  RETRO_DEVICE_ID_JOYPAD_L,       // Q
        14:  RETRO_DEVICE_ID_JOYPAD_R,       // E
        36:  RETRO_DEVICE_ID_JOYPAD_START,   // Return
        49:  RETRO_DEVICE_ID_JOYPAD_SELECT,  // Space
    ]
    
    // Player 2 default mapping (numpad + letters)
    static let player2: [UInt16: Int32] = [
        13:  RETRO_DEVICE_ID_JOYPAD_UP,      // W
        1:   RETRO_DEVICE_ID_JOYPAD_DOWN,    // S  (conflicts with P1 Y)
        0:   RETRO_DEVICE_ID_JOYPAD_LEFT,    // A  (conflicts with P1 X)
        2:   RETRO_DEVICE_ID_JOYPAD_RIGHT,   // D
        38:  RETRO_DEVICE_ID_JOYPAD_A,       // J
        40:  RETRO_DEVICE_ID_JOYPAD_B,       // K
        37:  RETRO_DEVICE_ID_JOYPAD_X,       // L
        41:  RETRO_DEVICE_ID_JOYPAD_Y,       // ;
        34:  RETRO_DEVICE_ID_JOYPAD_L,       // I
        31:  RETRO_DEVICE_ID_JOYPAD_R,       // O
        45:  RETRO_DEVICE_ID_JOYPAD_START,   // N
        46:  RETRO_DEVICE_ID_JOYPAD_SELECT,  // M
    ]
    
    // Coin insert
    static let coin1: UInt16 = 8   // C
    static let coin2: UInt16 = 9   // V
}

// MARK: - Emulator Bridge

/// Bridge between Swift app and libretro cores
class EmulatorBridge {
    
    // MARK: - Singleton
    
    static let shared = EmulatorBridge()
    
    // MARK: - State
    
    private(set) var isInitialized: Bool = false
    private(set) var isCoreLoaded: Bool = false
    private(set) var isGameLoaded: Bool = false
    private(set) var isPaused: Bool = false
    private(set) var currentGame: GameInfo?
    private(set) var currentCore: EmulatorCoreType?
    private(set) var metrics: PerformanceMetrics = PerformanceMetrics()
    
    // Framebuffer for Metal rendering
    private var framebufferWidth: Int = 0
    private var framebufferHeight: Int = 0
    private var framebufferPitch: Int = 0
    
    // Input state (indexed by player, then button)
    private var inputState: [[Bool]] = [
        Array(repeating: false, count: 16),  // Player 1
        Array(repeating: false, count: 16),  // Player 2
    ]
    
    // MARK: - Paths
    
    private let appSupportURL: URL
    private let romPath: URL
    private let biosPath: URL
    private let savePath: URL
    private let coresPath: URL
    
    // MARK: - Initialization
    
    private init() {
        // Setup application support directories
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportURL = appSupport.appendingPathComponent("MacMAME", isDirectory: true)
        
        romPath = appSupportURL.appendingPathComponent("Games", isDirectory: true)
        biosPath = appSupportURL.appendingPathComponent("BIOS", isDirectory: true)
        savePath = appSupportURL.appendingPathComponent("SaveStates", isDirectory: true)
        
        // Cores can be in the app bundle or in Application Support
        if let bundleCores = Bundle.main.resourceURL?.appendingPathComponent("Cores") {
            coresPath = bundleCores
        } else {
            coresPath = appSupportURL.appendingPathComponent("Cores", isDirectory: true)
        }
        
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
        // Initialize libretro wrapper
        libretro_init()
        
        isInitialized = true
        print("EmulatorBridge initialized")
        print("Cores path: \(coresPath.path)")
        print("ROM path: \(romPath.path)")
        print("BIOS path: \(biosPath.path)")
        print("Save path: \(savePath.path)")
    }
    
    private func shutdown() {
        if isGameLoaded {
            stop()
        }
        
        if isCoreLoaded {
            unloadCore()
        }
        
        libretro_deinit()
        isInitialized = false
    }
    
    // MARK: - Core Management
    
    /// Load a libretro core
    func loadCore(_ coreType: EmulatorCoreType) throws {
        guard isInitialized else {
            throw EmulatorError.notInitialized
        }
        
        // If a different core is loaded, unload it first
        if isCoreLoaded && currentCore != coreType {
            unloadCore()
        }
        
        // Check if core exists in bundle
        var corePath = coresPath.appendingPathComponent(coreType.filename)
        
        // Fallback to development path (for debugging)
        if !FileManager.default.fileExists(atPath: corePath.path) {
            // Try the workspace Cores directory during development
            let devPath = URL(fileURLWithPath: "/Users/davidphillips/Sites/macmame/Cores/\(coreType.filename)")
            if FileManager.default.fileExists(atPath: devPath.path) {
                corePath = devPath
            } else {
                throw EmulatorError.coreNotFound(coreType.filename)
            }
        }
        
        print("Loading core: \(corePath.path)")
        
        let result = libretro_load_core(corePath.path)
        guard result else {
            throw EmulatorError.coreLoadFailed("libretro_load_core failed")
        }
        
        // Get system info
        var systemInfo = retro_system_info()
        libretro_get_system_info(&systemInfo)
        
        print("Core loaded: \(String(cString: systemInfo.library_name)) v\(String(cString: systemInfo.library_version))")
        
        isCoreLoaded = true
        currentCore = coreType
    }
    
    /// Unload the current core
    func unloadCore() {
        guard isCoreLoaded else { return }
        
        if isGameLoaded {
            unloadGame()
        }
        
        libretro_unload_core()
        isCoreLoaded = false
        currentCore = nil
        
        print("Core unloaded")
    }
    
    // MARK: - Game Loading
    
    /// Load a game ROM
    func loadGame(at url: URL) throws {
        guard isInitialized else {
            throw EmulatorError.notInitialized
        }
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EmulatorError.gameNotFound(url.lastPathComponent)
        }
        
        // Auto-load FBNeo core if no core loaded
        if !isCoreLoaded {
            try loadCore(.fbneo)
        }
        
        // Load the game
        let result = libretro_load_game(url.path)
        guard result else {
            throw EmulatorError.gameLoadFailed("libretro_load_game failed")
        }
        
        // Get AV info
        var avInfo = retro_system_av_info()
        libretro_get_system_av_info(&avInfo)
        
        framebufferWidth = Int(avInfo.geometry.base_width)
        framebufferHeight = Int(avInfo.geometry.base_height)
        framebufferPitch = framebufferWidth * 4 // XRGB8888
        
        currentGame = GameInfo(
            name: url.deletingPathExtension().lastPathComponent,
            title: url.deletingPathExtension().lastPathComponent,
            manufacturer: "Unknown",
            year: "????",
            screenWidth: framebufferWidth,
            screenHeight: framebufferHeight,
            refreshRate: avInfo.timing.fps
        )
        
        isGameLoaded = true
        isPaused = false
        
        print("Loaded game: \(url.lastPathComponent)")
        print("Resolution: \(framebufferWidth)x\(framebufferHeight) @ \(avInfo.timing.fps) Hz")
        print("Audio: \(avInfo.timing.sample_rate) Hz")
    }
    
    /// Unload the current game
    func unloadGame() {
        guard isGameLoaded else { return }
        
        // Save SRAM before unloading
        if let game = currentGame {
            let sramPath = savePath
                .appendingPathComponent(game.name, isDirectory: true)
                .appendingPathComponent("sram.srm")
            
            try? FileManager.default.createDirectory(
                at: sramPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            
            libretro_save_sram(sramPath.path)
        }
        
        libretro_unload_game()
        
        currentGame = nil
        isGameLoaded = false
        isPaused = false
        framebufferWidth = 0
        framebufferHeight = 0
        
        print("Game unloaded")
    }
    
    // MARK: - Emulation Control
    
    /// Run one frame of emulation
    func runFrame() {
        guard isGameLoaded, !isPaused else { return }
        
        libretro_run_frame()
    }
    
    /// Pause emulation
    func pause() {
        guard isGameLoaded else { return }
        isPaused = true
    }
    
    /// Resume emulation
    func resume() {
        guard isGameLoaded else { return }
        isPaused = false
    }
    
    /// Reset the game
    func reset() {
        guard isGameLoaded else { return }
        libretro_reset()
        print("Game reset")
    }
    
    /// Stop emulation and unload game
    func stop() {
        unloadGame()
    }
    
    // MARK: - Input
    
    /// Handle key down event
    func keyDown(keyCode: UInt16) {
        // Check player 1 mapping
        if let button = InputMapping.player1[keyCode] {
            inputState[0][Int(button)] = true
            libretro_set_input(0, button, true)
        }
        
        // Coin insert
        if keyCode == InputMapping.coin1 {
            // Insert coin for P1 (usually SELECT in many arcade games)
            libretro_set_input(0, RETRO_DEVICE_ID_JOYPAD_SELECT, true)
        }
        
        #if DEBUG
        print("Key down: \(keyCode)")
        #endif
    }
    
    /// Handle key up event
    func keyUp(keyCode: UInt16) {
        // Check player 1 mapping
        if let button = InputMapping.player1[keyCode] {
            inputState[0][Int(button)] = false
            libretro_set_input(0, button, false)
        }
        
        // Coin insert release
        if keyCode == InputMapping.coin1 {
            libretro_set_input(0, RETRO_DEVICE_ID_JOYPAD_SELECT, false)
        }
        
        #if DEBUG
        print("Key up: \(keyCode)")
        #endif
    }
    
    // MARK: - Save States
    
    /// Save state to slot
    func saveState(slot: Int) throws {
        guard isGameLoaded, let game = currentGame else {
            throw EmulatorError.notInitialized
        }
        
        let stateURL = savePath
            .appendingPathComponent(game.name, isDirectory: true)
            .appendingPathComponent("slot-\(slot).state")
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        let result = libretro_save_state_to_file(stateURL.path)
        guard result else {
            throw EmulatorError.saveStateFailed("libretro_save_state_to_file failed")
        }
        
        print("Saved state to slot \(slot)")
    }
    
    /// Load state from slot
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
        
        let result = libretro_load_state_from_file(stateURL.path)
        guard result else {
            throw EmulatorError.loadStateFailed("libretro_load_state_from_file failed")
        }
        
        print("Loaded state from slot \(slot)")
    }
    
    // MARK: - Video Output
    
    /// Get the current frame's pixel data
    /// Returns XRGB8888 pixel data suitable for uploading to Metal texture
    func getFramebuffer() -> (data: UnsafeRawPointer?, width: Int, height: Int, pitch: Int) {
        guard isGameLoaded else {
            return (nil, 0, 0, 0)
        }
        
        let width = libretro_get_width()
        let height = libretro_get_height()
        let pitch = libretro_get_framebuffer_pitch()
        let data = libretro_get_framebuffer()
        
        return (data, Int(width), Int(height), Int(pitch))
    }
    
    /// Get current screen dimensions
    func getScreenSize() -> (width: Int, height: Int) {
        return (framebufferWidth, framebufferHeight)
    }
    
    // MARK: - Audio Output
    
    /// Get audio sample rate
    func getAudioSampleRate() -> Double {
        guard isGameLoaded else { return 48000 }
        
        var avInfo = retro_system_av_info()
        libretro_get_system_av_info(&avInfo)
        return avInfo.timing.sample_rate
    }
    
    // MARK: - Paths
    
    /// Get the ROM directory URL
    func getROMPath() -> URL {
        return romPath
    }
    
    /// Get the BIOS directory URL
    func getBIOSPath() -> URL {
        return biosPath
    }
    
    /// Get the save states directory URL
    func getSavePath() -> URL {
        return savePath
    }
}
