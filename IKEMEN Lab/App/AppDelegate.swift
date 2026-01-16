import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    
    private var gameWindowController: GameWindowController?
    private var aboutWindowController: AboutWindowController?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainWindow()
        
        // Check for updates in background (respects 24-hour interval)
        UpdateChecker.shared.checkOnLaunchIfNeeded()
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
    
    // MARK: - URL Scheme Handling (Browser Extension Integration)
    
    // TODO: Implement URL scheme handler for browser extension
    // When browser extension sends ikemenlab:// URLs, handle installation here
    // Use MetadataStore.shared.mostRecentlyInstalledCharacter() to efficiently
    // get the most recent character after installation, instead of loading all characters
    //
    // Example implementation:
    // func application(_ application: NSApplication, open urls: [URL]) {
    //     for url in urls {
    //         if url.scheme == "ikemenlab" {
    //             // Parse URL, download content, install
    //             // After install: let recent = try? MetadataStore.shared.mostRecentlyInstalledCharacter()
    //             // Show notification or navigate to the newly installed character
    //         }
    //     }
    // }
    
    // MARK: - Window Setup
    
    private func setupMainWindow() {
        gameWindowController = GameWindowController()
        gameWindowController?.showWindow(self)
        gameWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
    
    @IBAction func showSettings(_ sender: Any?) {
        // Select the Settings nav item in the main window
        gameWindowController?.selectSettingsNavItem()
    }
    
    @IBAction func checkForUpdates(_ sender: Any?) {
        UpdateChecker.shared.checkForUpdatesInteractively()
    }
    
    @IBAction func showAboutWindow(_ sender: Any?) {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.showAboutWindow()
    }
    
    // MARK: - Menu Validation
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
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
