import Cocoa

// MARK: - URL Scheme Payload Models

/// Payload structure from browser extension
struct InstallPayload: Codable {
    let downloadUrl: String?
    let fileData: String?  // Base64-encoded file data
    let fileName: String?
    let metadata: InstallMetadata
}

/// Metadata scraped from web page
struct InstallMetadata: Codable {
    let name: String?
    let author: String?
    let version: String?
    let description: String?
    let tags: [String]?
    let sourceUrl: String
    let scrapedAt: String  // ISO 8601 date string
}

// MARK: - AppDelegate

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
    
    // MARK: - URL Scheme Handling
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURLScheme(url)
        }
    }
    
    /// Handle ikemenlab:// URL scheme from browser extension
    private func handleURLScheme(_ url: URL) {
        guard url.scheme == "ikemenlab" else { return }
        
        // Parse URL: ikemenlab://install?data={payload}
        if url.host == "install" {
            handleInstallRequest(from: url)
        }
    }
    
    /// Handle installation request from browser extension
    private func handleInstallRequest(from url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let payloadString = dataItem.value,
              let payloadData = payloadString.removingPercentEncoding?.data(using: .utf8) else {
            showError("Invalid installation URL format")
            return
        }
        
        // Parse JSON payload
        guard let payload = try? JSONDecoder().decode(InstallPayload.self, from: payloadData) else {
            showError("Failed to parse installation data")
            return
        }
        
        // Download and install content in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Check if file data is included directly (from fetch with credentials)
            if let fileData = payload.fileData,
               let data = Data(base64Encoded: fileData) {
                self?.installFromData(data, fileName: payload.fileName ?? "download.zip", metadata: payload.metadata)
            } else if let downloadUrl = payload.downloadUrl {
                // Fall back to downloading from URL
                var modifiedPayload = payload
                self?.downloadAndInstall(payload: modifiedPayload)
            } else {
                DispatchQueue.main.async {
                    self?.showError("No download URL or file data provided")
                }
            }
        }
    }
    
    /// Install content from data (base64 decoded from extension)
    private func installFromData(_ data: Data, fileName: String, metadata: InstallMetadata) {
        let tempDir = FileManager.default.temporaryDirectory
        let destFile = tempDir.appendingPathComponent(fileName)
        
        do {
            // Write data to temp file
            if FileManager.default.fileExists(atPath: destFile.path) {
                try FileManager.default.removeItem(at: destFile)
            }
            try data.write(to: destFile)
            
            // Install the content
            installDownloadedContent(at: destFile, metadata: metadata)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.showError("Failed to save file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Download content from URL and install it
    private func downloadAndInstall(payload: InstallPayload) {
        guard let urlString = payload.downloadUrl,
              let downloadURL = URL(string: urlString) else {
            DispatchQueue.main.async { [weak self] in
                self?.showError("Invalid download URL")
            }
            return
        }
        
        // Show notification that download is starting
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = "IKEMEN Lab"
            notification.informativeText = "Downloading \(payload.metadata.name ?? "content")..."
            NSUserNotificationCenter.default.deliver(notification)
        }
        
        // Download file to temporary location
        let tempDir = FileManager.default.temporaryDirectory
        
        // Create URL request with cookies from shared cookie storage (Safari shares cookies)
        var request = URLRequest(url: downloadURL)
        request.httpShouldHandleCookies = true
        
        // Get cookies for the domain
        if let cookies = HTTPCookieStorage.shared.cookies(for: downloadURL) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Use URLSession with shared cookie storage
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        let session = URLSession(configuration: config)
        
        let task = session.downloadTask(with: request) { [weak self] tempLocation, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.showError("Download failed: \(error.localizedDescription)")
                }
                return
            }
            
            guard let tempLocation = tempLocation else {
                DispatchQueue.main.async {
                    self.showError("Download failed: No data received")
                }
                return
            }
            
            // Get filename from Content-Disposition header or suggested filename
            var filename = "download.zip"
            if let httpResponse = response as? HTTPURLResponse,
               let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition") {
                // Parse filename from Content-Disposition: attachment; filename="something.zip"
                if let range = contentDisposition.range(of: "filename=") {
                    var extractedName = String(contentDisposition[range.upperBound...])
                    extractedName = extractedName.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    if !extractedName.isEmpty {
                        filename = extractedName
                    }
                }
            } else if let suggestedFilename = response?.suggestedFilename,
                      !suggestedFilename.hasSuffix(".php") && !suggestedFilename.hasSuffix(".html") {
                filename = suggestedFilename
            } else if let name = payload.metadata.name {
                // Use metadata name as fallback
                filename = name.replacingOccurrences(of: " ", with: "_") + ".zip"
            }
            
            let destFile = tempDir.appendingPathComponent(filename)
            
            // Move downloaded file to temp directory
            do {
                if FileManager.default.fileExists(atPath: destFile.path) {
                    try FileManager.default.removeItem(at: destFile)
                }
                try FileManager.default.moveItem(at: tempLocation, to: destFile)
                
                // Check if we got an HTML error page instead of the actual file
                if let fileData = try? Data(contentsOf: destFile, options: .mappedIfSafe) {
                    // Check for HTML content (login page, error page, etc.)
                    if let content = String(data: fileData.prefix(1000), encoding: .utf8),
                       content.contains("<html") || content.contains("<!DOCTYPE") || content.contains("<HTML") {
                        DispatchQueue.main.async {
                            self.showError("Download requires login. Please download the file manually from mugenarchive.com, then drag it into IKEMEN Lab.")
                        }
                        return
                    }
                    
                    // Check if it's a valid archive by magic bytes
                    let bytes = [UInt8](fileData.prefix(16))
                    let isZip = bytes.count >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B
                    let isRar = bytes.count >= 4 && bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 && bytes[3] == 0x21
                    let is7z = bytes.count >= 4 && bytes[0] == 0x37 && bytes[1] == 0x7A && bytes[2] == 0xBC && bytes[3] == 0xAF
                    let isAce = bytes.count >= 14 && bytes[7] == 0x2A && bytes[8] == 0x2A && bytes[9] == 0x41 && bytes[10] == 0x43 && bytes[11] == 0x45 && bytes[12] == 0x2A && bytes[13] == 0x2A
                    
                    if !isZip && !isRar && !is7z && !isAce {
                        DispatchQueue.main.async {
                            self.showError("Download requires login. Please download the file manually from mugenarchive.com, then drag it into IKEMEN Lab.")
                        }
                        return
                    }
                }
                
                // Install the content
                self.installDownloadedContent(at: destFile, metadata: payload.metadata)
            } catch {
                DispatchQueue.main.async {
                    self.showError("Failed to save download: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }
    
    /// Install downloaded content and store scraped metadata
    private func installDownloadedContent(at fileURL: URL, metadata: InstallMetadata) {
        guard let workingDir = IkemenBridge.shared.workingDirectory else {
            DispatchQueue.main.async { [weak self] in
                self?.showError("Working directory not set. Please configure IKEMEN GO path in Settings.")
            }
            return
        }
        
        do {
            // Install the content using ContentManager
            let result = try ContentManager.shared.installContent(from: fileURL, to: workingDir, overwrite: false)
            
            // Extract character ID from result
            let isCharacter = result.contains("character:")
            
            if isCharacter {
                // Get the most recently installed character from database
                // This is more reliable than trying to parse the folder name
                if let recentCharacters = try? MetadataStore.shared.allCharacters(),
                   let newestCharacter = recentCharacters.sorted(by: { $0.installedAt > $1.installedAt }).first {
                    
                    // Store scraped metadata linked to the actual character ID
                    let scrapedMetadata = ScrapedMetadata(
                        characterId: newestCharacter.id,
                        name: metadata.name,
                        author: metadata.author,
                        version: metadata.version,
                        description: metadata.description,
                        tags: metadata.tags,
                        sourceUrl: metadata.sourceUrl,
                        scrapedAt: Date()
                    )
                    
                    try? MetadataStore.shared.storeScrapedMetadata(scrapedMetadata)
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.showSuccess(result)
                // Post notification to refresh content views
                NotificationCenter.default.post(name: .contentChanged, object: nil)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.showError("Installation failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Show error alert
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Installation Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Show success notification
    private func showSuccess(_ message: String) {
        let notification = NSUserNotification()
        notification.title = "IKEMEN Lab"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
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
