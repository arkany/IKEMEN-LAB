import Cocoa

/// Coordinates content installation from archives, folders, and fullgame packages.
/// Handles file dialogs, duplicate detection, progress reporting, and fullgame import.
final class InstallCoordinator {
    
    // MARK: - Properties
    
    private let supportedArchiveExtensions = ["zip", "rar", "7z", "ace"]
    
    /// The window to present dialogs in.
    weak var window: NSWindow?
    
    /// Called on status changes (message, color).
    var onStatusUpdate: ((String, NSColor) -> Void)?
    
    /// Called when content changes and views should refresh.
    var onContentChanged: (() -> Void)?
    
    // MARK: - Install Dialog
    
    /// Show the file open panel for installing content.
    func showInstallDialog() {
        guard let window = window else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.title = "Install Content"
        openPanel.prompt = "Install"
        openPanel.message = "Select ZIP archives or folders containing characters, stages, or screenpacks."
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        
        // Create accessory view with fullgame toggle
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
        let fullgameToggle = NSButton(checkboxWithTitle: "Fullgame mode (import as collection)", target: nil, action: nil)
        fullgameToggle.state = AppSettings.shared.fullgameImportEnabled ? .on : .off
        fullgameToggle.toolTip = "Import entire MUGEN/IKEMEN packages as collections, including characters, stages, screenpack, fonts, and sounds."
        fullgameToggle.frame = NSRect(x: 10, y: 4, width: 280, height: 24)
        accessoryView.addSubview(fullgameToggle)
        openPanel.accessoryView = accessoryView
        
        openPanel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            
            // Update setting based on toggle state
            AppSettings.shared.fullgameImportEnabled = (fullgameToggle.state == .on)
            
            self?.handleDroppedFiles(openPanel.urls)
        }
    }
    
    // MARK: - Handle Dropped Files
    
    /// Process dropped files — routes to archive, folder, or fullgame handlers.
    func handleDroppedFiles(_ urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            
            if supportedArchiveExtensions.contains(ext) {
                installFromArchive(url)
            } else if FileManager.default.fileExists(atPath: url.path) {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    // Check if fullgame mode is enabled and this looks like a fullgame
                    print("[InstallCoordinator] Dropped folder: \(url.path)")
                    print("[InstallCoordinator] Fullgame mode enabled: \(AppSettings.shared.fullgameImportEnabled)")
                    if AppSettings.shared.fullgameImportEnabled {
                        let manifest = FullgameImporter.shared.scanFullgamePackage(at: url)
                        print("[InstallCoordinator] Is fullgame: \(manifest.isFullgame)")
                        if manifest.isFullgame {
                            print("[InstallCoordinator] Starting fullgame install...")
                            installFullgame(manifest: manifest)
                            continue
                        }
                    }
                    installFromFolder(url)
                }
            }
        }
    }
    
    // MARK: - Archive Installation
    
    private func installFromArchive(_ url: URL, overwrite: Bool = false) {
        onStatusUpdate?("Installing...", DesignColors.warning)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try IkemenBridge.shared.installContent(from: url, overwrite: overwrite)
                DispatchQueue.main.async {
                    self?.onStatusUpdate?(result, DesignColors.positive)
                    
                    let contentName = result.replacingOccurrences(of: "Installed ", with: "").replacingOccurrences(of: "!", with: "")
                    ToastManager.shared.showSuccess(
                        title: "Successfully installed!",
                        subtitle: "\(contentName) has been added to your library."
                    )
                    
                    self?.onContentChanged?()
                }
            } catch let error as IkemenError {
                if case .duplicateContent(let name) = error {
                    DispatchQueue.main.async {
                        self?.promptToOverwrite(name: name) { shouldOverwrite in
                            if shouldOverwrite {
                                self?.installFromArchive(url, overwrite: true)
                            } else {
                                self?.onStatusUpdate?("Cancelled", DesignColors.textTertiary)
                            }
                        }
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.onStatusUpdate?("Failed", DesignColors.redAccent)
                    ToastManager.shared.showError(title: "Installation failed", subtitle: error.localizedDescription)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.onStatusUpdate?("Failed", DesignColors.redAccent)
                    ToastManager.shared.showError(title: "Installation failed", subtitle: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Folder Installation
    
    private func installFromFolder(_ url: URL, overwrite: Bool = false) {
        onStatusUpdate?("Installing...", DesignColors.warning)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try IkemenBridge.shared.installContentFolder(from: url, overwrite: overwrite)
                DispatchQueue.main.async {
                    self?.onStatusUpdate?(result, DesignColors.positive)
                    
                    let contentName = result.replacingOccurrences(of: "Installed ", with: "").replacingOccurrences(of: "!", with: "")
                    ToastManager.shared.showSuccess(
                        title: "Successfully installed!",
                        subtitle: "\(contentName) has been added to your library."
                    )
                    
                    self?.onContentChanged?()
                }
            } catch let error as IkemenError {
                if case .duplicateContent(let name) = error {
                    DispatchQueue.main.async {
                        self?.promptToOverwrite(name: name) { shouldOverwrite in
                            if shouldOverwrite {
                                self?.installFromFolder(url, overwrite: true)
                            } else {
                                self?.onStatusUpdate?("Cancelled", DesignColors.textTertiary)
                            }
                        }
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.onStatusUpdate?("Failed", DesignColors.redAccent)
                    ToastManager.shared.showError(title: "Installation failed", subtitle: error.localizedDescription)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.onStatusUpdate?("Failed", DesignColors.redAccent)
                    ToastManager.shared.showError(title: "Installation failed", subtitle: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Fullgame Installation
    
    func installFullgame(manifest: FullgameManifest) {
        guard let workingDir = IkemenBridge.shared.workingDirectory else {
            ToastManager.shared.showError(title: "No IKEMEN GO folder", subtitle: "Please set up IKEMEN GO first.")
            return
        }
        
        let totalItems = manifest.characters.count + manifest.stages.count + (manifest.screenpack != nil ? 1 : 0)
        onStatusUpdate?("Installing fullgame (0/\(totalItems))...", DesignColors.warning)
        
        // Track duplicate handling choice
        var duplicateAction: DuplicateAction = .ask
        let duplicateLock = NSLock()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try FullgameImporter.shared.installFullgame(
                    manifest: manifest,
                    to: workingDir
                ) { [weak self] itemName, itemType in
                    var action: DuplicateAction = .ask
                    
                    duplicateLock.lock()
                    let currentAction = duplicateAction
                    duplicateLock.unlock()
                    
                    if currentAction == .overwriteAll || currentAction == .skipAll {
                        return currentAction
                    }
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    
                    DispatchQueue.main.async {
                        self?.promptForDuplicateAction(name: itemName, type: itemType) { chosenAction in
                            action = chosenAction
                            
                            if chosenAction == .overwriteAll || chosenAction == .skipAll {
                                duplicateLock.lock()
                                duplicateAction = chosenAction
                                duplicateLock.unlock()
                            }
                            
                            semaphore.signal()
                        }
                    }
                    
                    semaphore.wait()
                    return action
                }
                
                DispatchQueue.main.async {
                    self?.onStatusUpdate?("Installed!", DesignColors.positive)
                    
                    if result.totalInstalled > 0 {
                        var title = "Fullgame imported!"
                        if let collection = result.collectionCreated {
                            title = "Created \"\(collection.name)\""
                        }
                        
                        ToastManager.shared.showSuccess(title: title, subtitle: "Installed \(result.summary)")
                    }
                    
                    if result.totalFailed > 0 {
                        var failedItems: [String] = []
                        failedItems.append(contentsOf: result.charactersFailed.map { "\($0.name) (character)" })
                        failedItems.append(contentsOf: result.stagesFailed.map { "\($0.name) (stage)" })
                        if let screenpackError = result.screenpackFailed {
                            failedItems.append("Screenpack: \(screenpackError)")
                        }
                        
                        ToastManager.shared.showError(
                            title: "\(result.totalFailed) item(s) failed",
                            subtitle: failedItems.prefix(3).joined(separator: ", ")
                        )
                    }
                    
                    self?.onContentChanged?()
                    IkemenBridge.shared.loadContent()
                    NotificationCenter.default.post(name: .contentChanged, object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.onStatusUpdate?("Failed", DesignColors.redAccent)
                    ToastManager.shared.showError(title: "Fullgame import failed", subtitle: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Duplicate Prompts
    
    private func promptForDuplicateAction(name: String, type: String, completion: @escaping (DuplicateAction) -> Void) {
        guard let window = window else {
            completion(.skip)
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Duplicate \(type.capitalized)"
        alert.informativeText = "'\(name)' is already installed. What would you like to do?"
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Skip")
        alert.addButton(withTitle: "Overwrite All")
        alert.addButton(withTitle: "Skip All")
        alert.alertStyle = .warning
        
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn:
                completion(.overwrite)
            case .alertSecondButtonReturn:
                completion(.skip)
            case .alertThirdButtonReturn:
                completion(.overwriteAll)
            default:
                completion(.skipAll)
            }
        }
    }
    
    private func promptToOverwrite(name: String, completion: @escaping (Bool) -> Void) {
        guard let window = window else {
            completion(false)
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Duplicate Content"
        alert.informativeText = "'\(name)' is already installed. Do you want to overwrite it?"
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        alert.beginSheetModal(for: window) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }
}
