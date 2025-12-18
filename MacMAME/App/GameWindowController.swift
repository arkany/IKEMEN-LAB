import Cocoa

/// Main game window controller
/// Manages the game rendering window and coordinates with the emulator
class GameWindowController: NSWindowController {
    
    private var metalView: MetalView!
    private var emulatorBridge: EmulatorBridge?
    
    // MARK: - State
    
    private(set) var isGameLoaded: Bool = false
    private(set) var isPaused: Bool = false
    
    // MARK: - Initialization
    
    convenience init() {
        // Create window programmatically
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        
        configureWindow()
        setupMetalView()
        setupEmulator()
    }
    
    // MARK: - Window Configuration
    
    private func configureWindow() {
        guard let window = window else { return }
        
        window.title = "MacMAME"
        window.center()
        
        // Enable native fullscreen
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        
        // Appearance
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        
        // Minimum size (NES resolution as baseline)
        window.minSize = NSSize(width: 320, height: 240)
        
        // Aspect ratio preservation (optional, can be disabled per-game)
        window.contentAspectRatio = NSSize(width: 4, height: 3)
        
        window.delegate = self
    }
    
    private func setupMetalView() {
        guard let window = window else { return }
        
        metalView = MetalView(frame: window.contentView?.bounds ?? .zero)
        metalView.autoresizingMask = [.width, .height]
        
        window.contentView = metalView
    }
    
    private func setupEmulator() {
        emulatorBridge = EmulatorBridge()
        metalView.emulatorBridge = emulatorBridge
        
        // Start rendering test pattern immediately
        metalView.startRendering()
    }
    
    // MARK: - Game Control
    
    func loadGame(at url: URL) {
        guard let emulatorBridge = emulatorBridge else { return }
        
        do {
            try emulatorBridge.loadGame(at: url)
            isGameLoaded = true
            isPaused = false
            
            window?.title = url.deletingPathExtension().lastPathComponent
            
            metalView.startRendering()
            
            print("Loaded game: \(url.lastPathComponent)")
        } catch {
            showError("Failed to load game", detail: error.localizedDescription)
        }
    }
    
    func togglePause() {
        guard isGameLoaded else { return }
        
        isPaused.toggle()
        
        if isPaused {
            metalView.stopRendering()
            emulatorBridge?.pause()
        } else {
            metalView.startRendering()
            emulatorBridge?.resume()
        }
    }
    
    func resetGame() {
        guard isGameLoaded else { return }
        
        emulatorBridge?.reset()
    }
    
    func stopEmulation() {
        metalView.stopRendering()
        emulatorBridge?.stop()
        isGameLoaded = false
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        if let window = window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}

// MARK: - NSWindowDelegate

extension GameWindowController: NSWindowDelegate {
    
    func windowWillEnterFullScreen(_ notification: Notification) {
        // Pause briefly during transition to avoid dropped frames
        metalView.pauseForTransition()
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        metalView.resumeFromTransition()
    }
    
    func windowWillExitFullScreen(_ notification: Notification) {
        metalView.pauseForTransition()
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        metalView.resumeFromTransition()
    }
    
    func windowWillClose(_ notification: Notification) {
        stopEmulation()
    }
}
