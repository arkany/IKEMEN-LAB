import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var gameWindowController: GameWindowController?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainWindow()
        
        #if DEBUG
        print("MacMAME launched in DEBUG mode")
        #endif
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up emulator resources
        gameWindowController?.stopEmulation()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Window Setup
    
    private func setupMainWindow() {
        gameWindowController = GameWindowController()
        gameWindowController?.showWindow(self)
    }
    
    // MARK: - Menu Actions
    
    @IBAction func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a game file to play"
        panel.prompt = "Open"
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.gameWindowController?.loadGame(at: url)
            }
        }
    }
    
    @IBAction func togglePause(_ sender: Any?) {
        gameWindowController?.togglePause()
    }
    
    @IBAction func resetGame(_ sender: Any?) {
        gameWindowController?.resetGame()
    }
    
    @IBAction func toggleFullScreen(_ sender: Any?) {
        gameWindowController?.window?.toggleFullScreen(sender)
    }
    
    // MARK: - Menu Validation
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else { return true }
        
        switch action {
        case #selector(togglePause(_:)):
            let isPaused = gameWindowController?.isPaused ?? false
            menuItem.title = isPaused ? "Resume" : "Pause"
            return gameWindowController?.isGameLoaded ?? false
            
        case #selector(resetGame(_:)):
            return gameWindowController?.isGameLoaded ?? false
            
        default:
            return true
        }
    }
}
