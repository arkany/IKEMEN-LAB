import Cocoa
import Combine
import UniformTypeIdentifiers

/// Navigation item for the sidebar
enum NavItem: String, CaseIterable {
    case collections = "Collections"
    case characters = "Characters"
    case stages = "Stages"
    case lifebars = "Lifebars"
    case addons = "Add-ons"
    
    var iconName: String {
        switch self {
        case .collections: return "collections"
        case .characters: return "characters"
        case .stages: return "stages"
        case .lifebars: return "lifebars"
        case .addons: return "addons"
        }
    }
}

/// Main game window controller
/// Manages the launcher UI and coordinates with Ikemen GO
class GameWindowController: NSWindowController {
    
    private var ikemenBridge: IkemenBridge!
    private var cancellables = Set<AnyCancellable>()
    
    // Colors from Figma design
    private let bgColor = NSColor(red: 0x11/255.0, green: 0x1d/255.0, blue: 0x29/255.0, alpha: 1.0)
    private let greenAccent = NSColor(red: 0x4e/255.0, green: 0xfd/255.0, blue: 0x60/255.0, alpha: 1.0)
    private let redAccent = NSColor(red: 0xfd/255.0, green: 0x4e/255.0, blue: 0x5b/255.0, alpha: 1.0)
    private let grayText = NSColor(red: 0x7a/255.0, green: 0x84/255.0, blue: 0x8f/255.0, alpha: 1.0)
    private let creamText = NSColor(red: 0xff/255.0, green: 0xf0/255.0, blue: 0xe5/255.0, alpha: 1.0)
    
    // Layout constants
    private let sidebarWidth: CGFloat = 320
    private let sidebarPadding: CGFloat = 24
    
    // UI Elements - Sidebar
    private var contentView: NSView!
    private var sidebarView: NSView!
    private var mainAreaView: NSView!
    private var launchButton: NSButton!
    private var statusLabel: NSTextField!
    private var charactersCountLabel: NSTextField!
    private var stagesCountLabel: NSTextField!
    private var navButtons: [NavItem: NSButton] = [:]
    private var navLabels: [NavItem: NSTextField] = [:]  // For updating counts
    private var selectedNavItem: NavItem? = nil
    
    // UI Elements - Main Area
    private var dropZoneView: DropZoneView!
    private var characterBrowserView: CharacterBrowserView!
    
    // MARK: - State
    
    var isGameLoaded: Bool { ikemenBridge.isEngineRunning }
    var isPaused: Bool = false
    
    // MARK: - Fonts
    
    private func jerseyFont(size: CGFloat) -> NSFont {
        // Try Jersey 15 first (has more character coverage)
        if let font = NSFont(name: "Jersey15-Regular", size: size) {
            return font
        }
        // Try Jersey 10
        if let font = NSFont(name: "Jersey10-Regular", size: size) {
            return font
        }
        // Fallback to monospace system font for retro feel
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
    
    // MARK: - Icons
    
    private func loadIcon(named name: String, tintColor: NSColor? = nil) -> NSImage? {
        guard let iconPath = Bundle.main.path(forResource: name, ofType: "svg", inDirectory: "Icons"),
              let image = NSImage(contentsOfFile: iconPath) else {
            return nil
        }
        
        // If tint color specified, create a tinted copy
        if let tint = tintColor {
            let tinted = NSImage(size: image.size)
            tinted.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: image.size))
            tint.set()
            NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            return tinted
        }
        
        return image
    }
    
    // MARK: - Initialization
    
    convenience init() {
        // Create window programmatically
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
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
        window.backgroundColor = bgColor
        window.minSize = NSSize(width: 900, height: 600)
        window.delegate = self
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = bgColor.cgColor
        window.contentView = contentView
        
        setupSidebar()
        setupMainArea()
        setupConstraints()
    }
    
    // MARK: - Sidebar Setup
    
    private func setupSidebar() {
        sidebarView = NSView()
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.wantsLayer = true
        sidebarView.layer?.backgroundColor = bgColor.cgColor
        contentView.addSubview(sidebarView)
        
        // === Launch Button Shadow (separate view) ===
        let launchShadow = NSView()
        launchShadow.translatesAutoresizingMaskIntoConstraints = false
        launchShadow.wantsLayer = true
        launchShadow.layer?.backgroundColor = NSColor(red: 15/255, green: 25/255, blue: 35/255, alpha: 1.0).cgColor // #0f1923
        launchShadow.identifier = NSUserInterfaceItemIdentifier("launchShadow")
        sidebarView.addSubview(launchShadow)
        
        // === Launch Button ===
        launchButton = NSButton()
        launchButton.translatesAutoresizingMaskIntoConstraints = false
        launchButton.title = ""
        launchButton.isBordered = false
        launchButton.target = self
        launchButton.action = #selector(launchIkemen)
        launchButton.wantsLayer = true
        launchButton.layer?.backgroundColor = greenAccent.cgColor
        
        // Create content stack with icon + text
        let launchStack = NSStackView()
        launchStack.translatesAutoresizingMaskIntoConstraints = false
        launchStack.orientation = .horizontal
        launchStack.spacing = 10
        launchStack.alignment = .centerY
        launchStack.identifier = NSUserInterfaceItemIdentifier("launchStack")
        
        // Arcade icon (black tinted for green background)
        let launchIcon = NSImageView()
        launchIcon.translatesAutoresizingMaskIntoConstraints = false
        launchIcon.identifier = NSUserInterfaceItemIdentifier("launchIcon")
        if let image = loadIcon(named: "arcade", tintColor: .black) {
            launchIcon.image = image
        }
        NSLayoutConstraint.activate([
            launchIcon.widthAnchor.constraint(equalToConstant: 32),
            launchIcon.heightAnchor.constraint(equalToConstant: 32),
        ])
        launchStack.addArrangedSubview(launchIcon)
        
        // Text label
        let launchLabel = NSTextField(labelWithString: "Start IKEMEN GO")
        launchLabel.font = jerseyFont(size: 36)
        launchLabel.textColor = .black
        launchLabel.isEditable = false
        launchLabel.isBordered = false
        launchLabel.backgroundColor = .clear
        launchLabel.identifier = NSUserInterfaceItemIdentifier("launchLabel")
        launchStack.addArrangedSubview(launchLabel)
        
        launchButton.addSubview(launchStack)
        NSLayoutConstraint.activate([
            launchStack.centerXAnchor.constraint(equalTo: launchButton.centerXAnchor),
            launchStack.centerYAnchor.constraint(equalTo: launchButton.centerYAnchor),
        ])
        
        sidebarView.addSubview(launchButton)
        
        // === Stats Row ===
        let statsStack = NSStackView()
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsStack.orientation = .horizontal
        statsStack.spacing = 24
        statsStack.alignment = .centerY
        sidebarView.addSubview(statsStack)
        
        // Characters stat
        let charsStack = createStatView(icon: "characters", label: "0")
        charactersCountLabel = charsStack.arrangedSubviews.last as? NSTextField
        statsStack.addArrangedSubview(charsStack)
        
        // Stages stat
        let stagesStack = createStatView(icon: "stages", label: "0")
        stagesCountLabel = stagesStack.arrangedSubviews.last as? NSTextField
        statsStack.addArrangedSubview(stagesStack)
        
        // === Navigation Items ===
        let navStack = NSStackView()
        navStack.translatesAutoresizingMaskIntoConstraints = false
        navStack.orientation = .vertical
        navStack.spacing = 8
        navStack.alignment = .leading
        sidebarView.addSubview(navStack)
        
        for item in NavItem.allCases {
            let (button, label) = createNavButton(for: item)
            navButtons[item] = button
            navLabels[item] = label
            navStack.addArrangedSubview(button)
        }
        
        // === Status Label ===
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = jerseyFont(size: 32)
        statusLabel.textColor = greenAccent
        statusLabel.alignment = .left
        sidebarView.addSubview(statusLabel)
        
        // Get reference to shadow view
        guard let launchShadow = sidebarView.subviews.first(where: { $0.identifier?.rawValue == "launchShadow" }) else { return }
        
        // Sidebar internal constraints
        NSLayoutConstraint.activate([
            // Launch shadow (offset 12px right and down from button)
            launchShadow.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: sidebarPadding + 12),
            launchShadow.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding + 12),
            launchShadow.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -sidebarPadding + 4),
            launchShadow.heightAnchor.constraint(equalToConstant: 60),
            
            // Launch button
            launchButton.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: sidebarPadding),
            launchButton.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding),
            launchButton.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -sidebarPadding - 8), // Account for shadow
            launchButton.heightAnchor.constraint(equalToConstant: 60),
            
            // Stats
            statsStack.topAnchor.constraint(equalTo: launchButton.bottomAnchor, constant: 24),
            statsStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding),
            
            // Navigation
            navStack.topAnchor.constraint(equalTo: statsStack.bottomAnchor, constant: 32),
            navStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding),
            navStack.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -sidebarPadding),
            
            // Status
            statusLabel.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding),
            statusLabel.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor, constant: -sidebarPadding),
        ])
    }
    
    private func createStatView(icon iconName: String, label: String) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        
        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let image = loadIcon(named: iconName, tintColor: grayText) {
            iconView.image = image
        }
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
        ])
        stack.addArrangedSubview(iconView)
        
        // Label
        let textLabel = NSTextField(labelWithString: label)
        textLabel.font = jerseyFont(size: 24)
        textLabel.textColor = grayText
        stack.addArrangedSubview(textLabel)
        
        return stack
    }
    
    private func createNavButton(for item: NavItem) -> (NSButton, NSTextField) {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""  // Remove default "Button" text
        button.isBordered = false
        button.bezelStyle = .inline
        button.target = self
        button.action = #selector(navItemClicked(_:))
        button.wantsLayer = true
        
        // Container for gradient background and left border
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        button.addSubview(container)
        
        // Left border indicator
        let leftBorder = NSView()
        leftBorder.translatesAutoresizingMaskIntoConstraints = false
        leftBorder.wantsLayer = true
        leftBorder.layer?.backgroundColor = NSColor.clear.cgColor
        leftBorder.identifier = NSUserInterfaceItemIdentifier("leftBorder")
        container.addSubview(leftBorder)
        
        // Create horizontal stack for icon + text
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.identifier = NSUserInterfaceItemIdentifier("navIcon")
        if let image = loadIcon(named: item.iconName, tintColor: grayText) {
            iconView.image = image
        }
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
        ])
        stack.addArrangedSubview(iconView)
        
        // Label with count placeholder
        let label = NSTextField(labelWithString: item.rawValue)
        label.font = jerseyFont(size: 32)
        label.textColor = grayText
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.identifier = NSUserInterfaceItemIdentifier("navLabel")
        stack.addArrangedSubview(label)
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            container.topAnchor.constraint(equalTo: button.topAnchor),
            container.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            
            // Left border - 4px wide, full height
            leftBorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            leftBorder.topAnchor.constraint(equalTo: container.topAnchor),
            leftBorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leftBorder.widthAnchor.constraint(equalToConstant: 4),
            
            // Stack with padding
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            button.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        // Store item reference
        button.tag = NavItem.allCases.firstIndex(of: item) ?? 0
        
        return (button, label)
    }
    
    @objc private func navItemClicked(_ sender: NSButton) {
        let item = NavItem.allCases[sender.tag]
        selectNavItem(item)
    }
    
    private func selectNavItem(_ item: NavItem?) {
        selectedNavItem = item
        
        // Update button appearances
        for (navItem, button) in navButtons {
            let isSelected = navItem == item
            
            // Find the container view (first subview)
            guard let container = button.subviews.first else { continue }
            
            // Find the left border
            if let leftBorder = container.subviews.first(where: { $0.identifier?.rawValue == "leftBorder" }) {
                leftBorder.layer?.backgroundColor = isSelected ? redAccent.cgColor : NSColor.clear.cgColor
            }
            
            // Apply gradient background for selected state
            if isSelected {
                // Create gradient layer
                let gradient = CAGradientLayer()
                gradient.colors = [
                    redAccent.withAlphaComponent(0.4).cgColor,
                    NSColor.clear.cgColor
                ]
                gradient.locations = [0, 0.09135]
                gradient.startPoint = CGPoint(x: 0, y: 0.5)
                gradient.endPoint = CGPoint(x: 1, y: 0.5)
                gradient.frame = container.bounds
                
                // Remove old gradient if any
                container.layer?.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
                container.layer?.insertSublayer(gradient, at: 0)
            } else {
                // Remove gradient
                container.layer?.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
            }
            
            // Find the stack view and update colors
            if let stack = container.subviews.compactMap({ $0 as? NSStackView }).first {
                for view in stack.arrangedSubviews {
                    if let iconView = view as? NSImageView, iconView.identifier?.rawValue == "navIcon" {
                        // Reload icon with new tint color
                        if let image = loadIcon(named: navItem.iconName, tintColor: isSelected ? redAccent : grayText) {
                            iconView.image = image
                        }
                    }
                    if let label = view as? NSTextField {
                        label.textColor = isSelected ? redAccent : grayText
                    }
                }
            }
        }
        
        // Update main area content
        updateMainAreaContent()
    }
    
    // MARK: - Main Area Setup
    
    private func setupMainArea() {
        mainAreaView = NSView()
        mainAreaView.translatesAutoresizingMaskIntoConstraints = false
        mainAreaView.wantsLayer = true
        mainAreaView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.addSubview(mainAreaView)
        
        // Drop Zone (visible in empty state)
        dropZoneView = DropZoneView(frame: .zero)
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.onFilesDropped = { [weak self] urls in
            self?.handleDroppedFiles(urls)
        }
        // Apply Figma styling
        dropZoneView.applyFigmaStyle(borderColor: redAccent, textColor: grayText, font: jerseyFont(size: 24))
        mainAreaView.addSubview(dropZoneView)
        
        // Character Browser (hidden initially)
        characterBrowserView = CharacterBrowserView(frame: .zero)
        characterBrowserView.translatesAutoresizingMaskIntoConstraints = false
        characterBrowserView.isHidden = true
        characterBrowserView.onCharacterSelected = { [weak self] character in
            self?.statusLabel.stringValue = character.displayName
        }
        mainAreaView.addSubview(characterBrowserView)
        
        NSLayoutConstraint.activate([
            // Drop zone fills main area with padding
            dropZoneView.topAnchor.constraint(equalTo: mainAreaView.topAnchor, constant: 24),
            dropZoneView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            dropZoneView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            dropZoneView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
            
            // Character browser fills main area
            characterBrowserView.topAnchor.constraint(equalTo: mainAreaView.topAnchor, constant: 24),
            characterBrowserView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            characterBrowserView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            characterBrowserView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
        ])
    }
    
    private func updateMainAreaContent() {
        // Show/hide appropriate views based on selection
        switch selectedNavItem {
        case .characters:
            dropZoneView.isHidden = true
            characterBrowserView.isHidden = false
        case .stages, .lifebars, .addons, .collections:
            // TODO: Implement other browsers
            dropZoneView.isHidden = false
            characterBrowserView.isHidden = true
        case nil:
            // Empty state - show drop zone
            dropZoneView.isHidden = false
            characterBrowserView.isHidden = true
        }
    }
    
    // MARK: - Layout Constraints
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Sidebar - fixed width on left
            sidebarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            sidebarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: sidebarWidth),
            
            // Main area - fills remaining space
            mainAreaView.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainAreaView.leadingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            mainAreaView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainAreaView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    
    // MARK: - Bridge Setup
    
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
                self?.charactersCountLabel?.stringValue = "\(characters.count)"
                self?.updateNavItemCount(.characters, count: characters.count)
            }
            .store(in: &cancellables)
        
        ikemenBridge.$stages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stages in
                self?.stagesCountLabel?.stringValue = "\(stages.count)"
                self?.updateNavItemCount(.stages, count: stages.count)
            }
            .store(in: &cancellables)
    }
    
    private func updateNavItemCount(_ item: NavItem, count: Int) {
        guard let label = navLabels[item] else { return }
        if count > 0 {
            label.stringValue = "\(item.rawValue) (\(count))"
        } else {
            label.stringValue = item.rawValue
        }
    }
    
    private func updateUI(for state: EngineState) {
        switch state {
        case .idle:
            updateLaunchButton(title: "Start IKEMEN GO", enabled: true, isRunning: false)
            statusLabel.stringValue = "Ready"
            statusLabel.textColor = greenAccent
            
        case .launching:
            updateLaunchButton(title: "Starting...", enabled: false, isRunning: false)
            statusLabel.stringValue = "Starting..."
            statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
            
        case .running:
            updateLaunchButton(title: "Stop IKEMEN GO", enabled: true, isRunning: true)
            statusLabel.stringValue = "Running"
            statusLabel.textColor = greenAccent
            
        case .terminated(let exitCode):
            updateLaunchButton(title: "Start IKEMEN GO", enabled: true, isRunning: false)
            statusLabel.stringValue = exitCode == 0 ? "Ready" : "Exited (\(exitCode))"
            statusLabel.textColor = exitCode == 0 ? greenAccent : redAccent
            
        case .error(let error):
            updateLaunchButton(title: "Start IKEMEN GO", enabled: true, isRunning: false)
            statusLabel.stringValue = "Error"
            statusLabel.textColor = redAccent
            showError("Error", detail: error.localizedDescription)
        }
    }
    
    private func updateLaunchButton(title: String, enabled: Bool, isRunning: Bool = false) {
        // Find the stack, icon, and label
        if let launchStack = launchButton.subviews.first(where: { $0.identifier?.rawValue == "launchStack" }) as? NSStackView {
            for view in launchStack.arrangedSubviews {
                if let label = view as? NSTextField, label.identifier?.rawValue == "launchLabel" {
                    label.stringValue = title
                }
                if let iconView = view as? NSImageView, iconView.identifier?.rawValue == "launchIcon" {
                    // Use stop (skull) icon when running, arcade icon otherwise
                    let iconName = isRunning ? "stop" : "arcade"
                    if let image = loadIcon(named: iconName, tintColor: .black) {
                        iconView.image = image
                    }
                }
            }
        }
        launchButton.isEnabled = enabled
        
        // Green for start/idle, red for running/stop
        if isRunning {
            launchButton.layer?.backgroundColor = redAccent.cgColor
        } else if enabled {
            launchButton.layer?.backgroundColor = greenAccent.cgColor
        } else {
            launchButton.layer?.backgroundColor = grayText.cgColor
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
    
    // MARK: - Game Control (Legacy API compatibility)
    
    func loadGame(at url: URL) {
        if url.pathExtension.lowercased() == "zip" {
            handleDroppedFiles([url])
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
        statusLabel.stringValue = "Installing..."
        statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try self?.ikemenBridge.installContent(from: url)
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = result ?? "Installed!"
                    self?.statusLabel.textColor = self?.greenAccent
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = "Failed"
                    self?.statusLabel.textColor = self?.redAccent
                    self?.showError("Install Failed", detail: error.localizedDescription)
                }
            }
        }
    }
    
    private func installFromFolder(_ url: URL) {
        statusLabel.stringValue = "Installing..."
        statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try self?.ikemenBridge.installContentFolder(from: url)
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = result ?? "Installed!"
                    self?.statusLabel.textColor = self?.greenAccent
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = "Failed"
                    self?.statusLabel.textColor = self?.redAccent
                    self?.showError("Install Failed", detail: error.localizedDescription)
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
    private var sublineLabel: NSTextField!
    private var dashedBorderLayer: CAShapeLayer?
    
    private func jerseyFont(size: CGFloat) -> NSFont {
        return NSFont(name: "Jersey10-Regular", size: size) ?? NSFont.systemFont(ofSize: size, weight: .medium)
    }
    private var borderColor: NSColor = NSColor(red: 0xfd/255.0, green: 0x4e/255.0, blue: 0x5b/255.0, alpha: 1.0)
    private var textColor: NSColor = NSColor(red: 0x7a/255.0, green: 0x84/255.0, blue: 0x8f/255.0, alpha: 1.0)
    
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
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create dashed border using a shape layer
        let dashedBorder = CAShapeLayer()
        dashedBorder.strokeColor = borderColor.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [12, 8]
        dashedBorder.lineWidth = 4
        layer?.addSublayer(dashedBorder)
        self.dashedBorderLayer = dashedBorder
        
        // Register for drag types
        registerForDraggedTypes([.fileURL])
        
        // Cream text color per Figma
        let creamColor = NSColor(red: 0xff/255.0, green: 0xf0/255.0, blue: 0xe5/255.0, alpha: 1.0)
        
        // Main label - Jersey 10 at 28px per Figma
        label = NSTextField(labelWithString: "Drop characters or\nstages here")
        label.font = jerseyFont(size: 28)
        label.textColor = creamColor
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        // Subline label - Jersey 10 at 20px per Figma
        sublineLabel = NSTextField(labelWithString: "(.zip, .rar, .7z or folder)")
        sublineLabel.font = jerseyFont(size: 20)
        sublineLabel.textColor = creamColor
        sublineLabel.alignment = .center
        sublineLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sublineLabel)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -12),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            
            sublineLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sublineLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
        ])
    }
    
    override func layout() {
        super.layout()
        
        // Update dashed border path to match bounds
        let path = CGPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), cornerWidth: 16, cornerHeight: 16, transform: nil)
        dashedBorderLayer?.path = path
        dashedBorderLayer?.frame = bounds
    }
    
    func applyFigmaStyle(borderColor: NSColor, textColor: NSColor, font: NSFont) {
        self.borderColor = borderColor
        self.textColor = textColor
        
        dashedBorderLayer?.strokeColor = borderColor.cgColor
        // Keep cream color for text per Figma
        let creamColor = NSColor(red: 0xff/255.0, green: 0xf0/255.0, blue: 0xe5/255.0, alpha: 1.0)
        label.textColor = creamColor
        label.font = jerseyFont(size: 28)
        sublineLabel.textColor = creamColor
        sublineLabel.font = jerseyFont(size: 20)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if isDragging {
            dashedBorderLayer?.strokeColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.4, alpha: 1.0).cgColor
            layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.3, blue: 0.2, alpha: 0.2).cgColor
        } else {
            dashedBorderLayer?.strokeColor = borderColor.cgColor
            layer?.backgroundColor = NSColor.clear.cgColor
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
