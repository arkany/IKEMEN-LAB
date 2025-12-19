import Cocoa
import Combine
import UniformTypeIdentifiers

/// Main game window controller
/// Manages the launcher UI and coordinates with Ikemen GO
class GameWindowController: NSWindowController {
    
    private var ikemenBridge: IkemenBridge!
    private var cancellables = Set<AnyCancellable>()
    
    // UI Elements
    private var contentView: NSView!
    private var dropZoneView: DropZoneView!
    private var launchButton: NSButton!
    private var statusLabel: NSTextField!
    private var charactersLabel: NSTextField!
    private var stagesLabel: NSTextField!
    
    // Character Browser
    private var characterBrowserView: CharacterBrowserView!
    private var browserToggleButton: NSButton!
    private var isBrowserVisible = false
    private var mainContentContainer: NSView!
    private var browserHeightConstraint: NSLayoutConstraint!
    
    // MARK: - State
    
    var isGameLoaded: Bool { ikemenBridge.isEngineRunning }
    var isPaused: Bool = false  // Not applicable for Ikemen GO
    
    // MARK: - Initialization
    
    convenience init() {
        // Create window programmatically
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        
        configureWindow()
        setupUI()
        setupBridge()
    }
    
    // MARK: - Window Configuration
    
    private func configureWindow() {
        guard let window = window else { return }
        
        window.title = "Ikemen Load"
        window.center()
        
        // Appearance
        window.backgroundColor = NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        
        // Minimum size
        window.minSize = NSSize(width: 500, height: 400)
        
        window.delegate = self
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.15, alpha: 1.0).cgColor
        
        // Title Label
        let titleLabel = NSTextField(labelWithString: "Ikemen Load")
        titleLabel.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "MUGEN/Ikemen GO Launcher")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = NSColor(white: 0.6, alpha: 1.0)
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        // Stats container (horizontal)
        let statsContainer = NSStackView()
        statsContainer.orientation = .horizontal
        statsContainer.spacing = 20
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsContainer)
        
        // Characters count
        charactersLabel = NSTextField(labelWithString: "Characters: 0")
        charactersLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        charactersLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
        charactersLabel.alignment = .center
        statsContainer.addArrangedSubview(charactersLabel)
        
        // Stages count
        stagesLabel = NSTextField(labelWithString: "Stages: 0")
        stagesLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        stagesLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
        stagesLabel.alignment = .center
        statsContainer.addArrangedSubview(stagesLabel)
        
        // Buttons container (horizontal)
        let buttonsContainer = NSStackView()
        buttonsContainer.orientation = .horizontal
        buttonsContainer.spacing = 12
        buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonsContainer)
        
        // Launch Button
        launchButton = NSButton(title: "Launch Ikemen GO", target: self, action: #selector(launchIkemen))
        launchButton.bezelStyle = .rounded
        launchButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        launchButton.controlSize = .large
        buttonsContainer.addArrangedSubview(launchButton)
        
        // Browse Characters Button
        browserToggleButton = NSButton(title: "Browse Characters", target: self, action: #selector(toggleBrowser))
        browserToggleButton.bezelStyle = .rounded
        browserToggleButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        browserToggleButton.controlSize = .large
        buttonsContainer.addArrangedSubview(browserToggleButton)
        
        // Status Label
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = NSColor(white: 0.5, alpha: 1.0)
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)
        
        // Drop Zone
        dropZoneView = DropZoneView(frame: .zero)
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.onFilesDropped = { [weak self] urls in
            self?.handleDroppedFiles(urls)
        }
        contentView.addSubview(dropZoneView)
        
        // Character Browser
        characterBrowserView = CharacterBrowserView(frame: .zero)
        characterBrowserView.translatesAutoresizingMaskIntoConstraints = false
        characterBrowserView.isHidden = true
        characterBrowserView.wantsLayer = true
        characterBrowserView.layer?.cornerRadius = 12
        characterBrowserView.onCharacterSelected = { [weak self] character in
            self?.statusLabel.stringValue = "Selected: \(character.displayName) by \(character.author)"
        }
        contentView.addSubview(characterBrowserView)
        
        window.contentView = contentView
        
        // Browser height constraint (for collapsed state only)
        browserHeightConstraint = characterBrowserView.heightAnchor.constraint(equalToConstant: 0)
        
        // Browser bottom constraint (for expanded state - fills to status bar)
        let browserBottomConstraint = characterBrowserView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -15)
        browserBottomConstraint.priority = .defaultLow // Lower priority when collapsed
        
        // Layout
        NSLayoutConstraint.activate([
            // Title
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            
            // Subtitle
            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            // Stats
            statsContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statsContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            
            // Buttons
            buttonsContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonsContainer.topAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: 20),
            
            // Drop Zone
            dropZoneView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            dropZoneView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            dropZoneView.topAnchor.constraint(equalTo: buttonsContainer.bottomAnchor, constant: 20),
            dropZoneView.heightAnchor.constraint(equalToConstant: 70),
            
            // Character Browser - expands to fill space below drop zone
            characterBrowserView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            characterBrowserView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            characterBrowserView.topAnchor.constraint(equalTo: dropZoneView.bottomAnchor, constant: 15),
            browserBottomConstraint, // Fills to status bar
            browserHeightConstraint, // Overrides when collapsed (height = 0)
            
            // Status - anchor to bottom
            statusLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15),
        ])
        
        // Set initial state - browser collapsed
        browserHeightConstraint.isActive = true
    }
    
    private func setupBridge() {
        ikemenBridge = IkemenBridge.shared
        
        // Observe state changes
        ikemenBridge.$engineState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(for: state)
            }
            .store(in: &cancellables)
        
        ikemenBridge.$characters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] characters in
                self?.charactersLabel.stringValue = "Characters: \(characters.count)"
            }
            .store(in: &cancellables)
        
        ikemenBridge.$stages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stages in
                self?.stagesLabel.stringValue = "Stages: \(stages.count)"
            }
            .store(in: &cancellables)
    }
    
    private func updateUI(for state: EngineState) {
        switch state {
        case .idle:
            launchButton.title = "Launch Ikemen GO"
            launchButton.isEnabled = true
            statusLabel.stringValue = "Ready"
            statusLabel.textColor = NSColor(white: 0.5, alpha: 1.0)
            
        case .launching:
            launchButton.title = "Launching..."
            launchButton.isEnabled = false
            statusLabel.stringValue = "Starting Ikemen GO..."
            statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
            
        case .running:
            launchButton.title = "Stop Ikemen GO"
            launchButton.isEnabled = true
            statusLabel.stringValue = "Ikemen GO is running"
            statusLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
            
        case .terminated(let exitCode):
            launchButton.title = "Launch Ikemen GO"
            launchButton.isEnabled = true
            if exitCode == 0 {
                statusLabel.stringValue = "Ikemen GO closed normally"
            } else {
                statusLabel.stringValue = "Ikemen GO exited with code \(exitCode)"
            }
            statusLabel.textColor = NSColor(white: 0.5, alpha: 1.0)
            
        case .error(let error):
            launchButton.title = "Launch Ikemen GO"
            launchButton.isEnabled = true
            statusLabel.stringValue = "Error: \(error.localizedDescription)"
            statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        }
    }
    
    // MARK: - Actions
    
    @objc private func launchIkemen() {
        if ikemenBridge.isEngineRunning {
            ikemenBridge.terminateEngine()
        } else {
            do {
                try ikemenBridge.launchEngine()
            } catch {
                showError("Launch Failed", detail: error.localizedDescription)
            }
        }
    }
    
    @objc private func toggleBrowser() {
        isBrowserVisible.toggle()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            
            if isBrowserVisible {
                characterBrowserView.isHidden = false
                browserHeightConstraint.isActive = false // Disable height constraint, let bottom constraint take over
                browserToggleButton.title = "Hide Characters"
                
                // Expand window if needed
                if let window = window {
                    var frame = window.frame
                    let minHeight: CGFloat = 550
                    if frame.size.height < minHeight {
                        let diff = minHeight - frame.size.height
                        frame.size.height = minHeight
                        frame.origin.y -= diff
                        window.setFrame(frame, display: true, animate: true)
                    }
                }
            } else {
                browserHeightConstraint.isActive = true // Enable height=0 constraint to collapse
                browserHeightConstraint.constant = 0
                browserToggleButton.title = "Browse Characters"
            }
            
            contentView.layoutSubtreeIfNeeded()
        }, completionHandler: { [weak self] in
            if !(self?.isBrowserVisible ?? true) {
                self?.characterBrowserView.isHidden = true
            }
        })
    }
    
    // MARK: - Game Control (Legacy API compatibility)
    
    func loadGame(at url: URL) {
        // For now, just launch Ikemen GO
        // Future: Install content from zip files
        if url.pathExtension.lowercased() == "zip" {
            // TODO: Install character/stage from zip
            showError("Content Installation", detail: "Drag & drop content installation coming soon!")
        } else {
            do {
                try ikemenBridge.launchEngine()
            } catch {
                showError("Launch Failed", detail: error.localizedDescription)
            }
        }
    }
    
    func togglePause() {
        // Not applicable - Ikemen GO handles its own pause
    }
    
    func resetGame() {
        // Not applicable - Ikemen GO handles its own reset
    }
    
    func stopEmulation() {
        ikemenBridge.terminateEngine()
    }
    
    // MARK: - Drag & Drop
    
    private let supportedArchiveExtensions = ["zip", "rar", "7z"]
    
    private func handleDroppedFiles(_ urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            
            if supportedArchiveExtensions.contains(ext) {
                installFromArchive(url)
            } else if FileManager.default.fileExists(atPath: url.path) {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    installFromFolder(url)
                }
            }
        }
    }
    
    private func installFromArchive(_ url: URL) {
        statusLabel.stringValue = "Installing \(url.lastPathComponent)..."
        statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try self?.ikemenBridge.installContent(from: url)
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = result ?? "Installed successfully!"
                    self?.statusLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = "Install failed: \(error.localizedDescription)"
                    self?.statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
                }
            }
        }
    }
    
    private func installFromFolder(_ url: URL) {
        statusLabel.stringValue = "Installing \(url.lastPathComponent)..."
        statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try self?.ikemenBridge.installContentFolder(from: url)
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = result ?? "Installed successfully!"
                    self?.statusLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = "Install failed: \(error.localizedDescription)"
                    self?.statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
                }
            }
        }
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

// MARK: - Drop Zone View

class DropZoneView: NSView {
    
    var onFilesDropped: (([URL]) -> Void)?
    
    private var isDragging = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var label: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 2
        layer?.borderColor = NSColor(white: 0.3, alpha: 1.0).cgColor
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        
        // Register for drag types
        registerForDraggedTypes([.fileURL])
        
        // Label
        label = NSTextField(labelWithString: "Drop characters or stages here (.zip, .rar, .7z or folder)")
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor(white: 0.5, alpha: 1.0)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if isDragging {
            layer?.borderColor = NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
            layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.3, blue: 0.4, alpha: 0.5).cgColor
        } else {
            layer?.borderColor = NSColor(white: 0.3, alpha: 1.0).cgColor
            layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor
        }
    }
    
    // MARK: - Drag & Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasValidFiles(sender) {
            isDragging = true
            return .copy
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return hasValidFiles(sender) ? .copy : []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return hasValidFiles(sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return false
        }
        
        let archiveExts = ["zip", "rar", "7z"]
        let validURLs = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            if archiveExts.contains(ext) { return true }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                return isDirectory.boolValue
            }
            return false
        }
        
        if !validURLs.isEmpty {
            onFilesDropped?(validURLs)
            return true
        }
        
        return false
    }
    
    private func hasValidFiles(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return false
        }
        
        let archiveExts = ["zip", "rar", "7z"]
        return urls.contains { url in
            let ext = url.pathExtension.lowercased()
            if archiveExts.contains(ext) { return true }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                return isDirectory.boolValue
            }
            return false
        }
    }
}

// MARK: - NSWindowDelegate

extension GameWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        stopEmulation()
    }
}
