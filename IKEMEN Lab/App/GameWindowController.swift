import Cocoa
import Combine
import Metal
import UniformTypeIdentifiers

/// Navigation item for the sidebar
enum NavItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case characters = "Characters"
    case stages = "Stages"
    case addons = "Screenpacks"
    case duplicates = "Duplicates"
    case soundpacks = "Soundpacks"  // Hidden for now
    case settings = "Settings"
    
    /// SF Symbol name for each nav item
    var sfSymbolName: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .characters: return "figure.fencing"
        case .stages: return "photo"
        case .addons: return "square.stack.3d.up"
        case .duplicates: return "doc.on.doc"
        case .soundpacks: return "music.note"
        case .settings: return "gearshape"
        }
    }
    
    /// Whether this item should show a count badge
    var showsCount: Bool {
        switch self {
        case .characters, .stages: return true
        default: return false
        }
    }
    
    /// Whether this item is hidden from the sidebar
    var isHidden: Bool {
        switch self {
        case .soundpacks, .duplicates: return true
        default: return false
        }
    }
    
    /// Legacy icon name (for compatibility)
    var iconName: String {
        switch self {
        case .dashboard: return "collections"
        case .characters: return "characters"
        case .stages: return "stages"
        case .addons: return "lifebars"
        case .duplicates: return "duplicates"
        case .soundpacks: return "screenpacks"
        case .settings: return "settings"
        }
    }
}

/// Main game window controller
/// Manages the launcher UI and coordinates with Ikemen GO
class GameWindowController: NSWindowController {
    
    private var ikemenBridge: IkemenBridge!
    private var cancellables = Set<AnyCancellable>()
    
    // Layout constants - New design system
    private let sidebarWidth: CGFloat = 220  // Narrower sidebar for better small window support
    private let sidebarPadding: CGFloat = 12 // p-3 from HTML
    
    // UI Elements - Sidebar
    private var contentView: NSView!
    private var sidebarView: NSView!
    private var sidebarHeaderView: NSView!
    private var mainAreaView: NSView!
    private var launchButton: NSButton!
    private var statusLabel: NSTextField!
    private var charactersCountLabel: NSTextField!
    private var stagesCountLabel: NSTextField!
    private var logoContainerView: NSView!
    private var logoIconView: NSImageView!
    private var vramTrackView: NSView!
    private var appNameLabelView: NSTextField!
    private var appSubLabelView: NSTextField!
    private var systemLabelView: NSTextField!
    private var vramLabelView: NSTextField!
    private var bottomAreaView: NSView!
    
    // VRAM monitoring
    private var vramFillView: NSView!
    private var vramPercentLabel: NSTextField!
    private var vramFillWidthConstraint: NSLayoutConstraint!
    private var navButtons: [NavItem: NSButton] = [:]
    private var navLabels: [NavItem: NSTextField] = [:]  // For updating counts
    private var selectedNavItem: NavItem? = nil
    
    // Collections sidebar section
    private var collectionsSidebarSection: CollectionsSidebarSection!
    private var collectionEditorView: CollectionEditorView!
    private var editingCollection: Collection?
    
    // UI Elements - Main Area
    private var contentHeaderView: ContentHeaderView!
    private var dashboardView: DashboardView!
    private var dropZoneView: DropZoneView!
    private var characterBrowserView: CharacterBrowserView!
    private var characterDetailsView: CharacterDetailsView!
    private var characterDetailsWidthConstraint: NSLayoutConstraint!
    private var stageBrowserView: StageBrowserView!
    private var screenpackBrowserView: ScreenpackBrowserView!
    private var duplicatesView: DuplicatesView!
    private var createStageButton: NSButton!
    
    // Search state
    private var currentSearchQuery: String = ""
    
    // View mode state
    private var currentViewMode: BrowserViewMode = .grid
    
    // Extracted coordinators
    private let installCoordinator = InstallCoordinator()
    private let stageCreationController = StageCreationController()
    private let vramMonitor = VRAMMonitor()
    
    // MARK: - State
    
    var isGameLoaded: Bool { ikemenBridge.isEngineRunning }
    var isPaused: Bool = false    
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
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
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
        
        window.title = "IKEMEN Lab"
        window.center()
        window.backgroundColor = DesignColors.background
        window.minSize = NSSize(width: 700, height: 600)
        window.delegate = self
        
        // Hide title bar but keep traffic light buttons
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = DesignColors.background.cgColor
        window.contentView = contentView
        
        setupSidebar()
        setupMainArea()
        setupConstraints()
        setupCoordinators()
        applyTheme()
        
        // Initialize toast notifications with main area as parent
        ToastManager.shared.setParentView(mainAreaView)
        
        // Select dashboard by default (after all views are initialized)
        selectNavItem(.dashboard)
        
        // Show FRE if needed (after short delay to let window appear)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showFirstRunExperienceIfNeeded()
        }
    }
    
    private func setupCoordinators() {
        // Install coordinator
        installCoordinator.window = window
        installCoordinator.onStatusUpdate = { [weak self] message, color in
            self?.statusLabel.stringValue = message
            self?.statusLabel.textColor = color
        }
        installCoordinator.onContentChanged = { [weak self] in
            self?.dashboardView.refreshStats()
        }
        
        // Stage creation controller
        stageCreationController.window = window
        stageCreationController.onStatusUpdate = { [weak self] message in
            self?.statusLabel.stringValue = message
        }
        stageCreationController.onStageCreated = { [weak self] in
            self?.ikemenBridge.refreshStages()
            self?.stageBrowserView.refresh()
        }
        
        // VRAM monitor
        vramMonitor.onUpdate = { [weak self] percentage, text in
            guard let self = self else { return }
            self.vramPercentLabel.stringValue = text
            
            if let superview = self.vramFillView.superview {
                let trackWidth = superview.bounds.width
                self.vramFillWidthConstraint.constant = trackWidth * CGFloat(percentage) / 100.0
            }
            
            if percentage > 90 {
                self.vramFillView.layer?.backgroundColor = DesignColors.redAccent.cgColor
            } else if percentage > 70 {
                self.vramFillView.layer?.backgroundColor = DesignColors.warning.cgColor
            } else {
                self.vramFillView.layer?.backgroundColor = AppSettings.shared.useLightTheme ? DesignColors.zinc400.cgColor : NSColor.white.withAlphaComponent(0.2).cgColor
            }
        }
        vramMonitor.start()
    }
    
    // MARK: - First Run Experience
    
    private var firstRunView: FirstRunView?
    
    private func showFirstRunExperienceIfNeeded() {
        let settings = AppSettings.shared
        
        // Skip if already completed FRE and has valid installation
        if settings.hasCompletedFRE && settings.hasValidIkemenGOInstallation {
            return
        }
        
        // Also skip if development environment already has working directory
        if ikemenBridge.workingDirectory != nil && settings.hasCompletedFRE {
            return
        }
        
        showFirstRunExperience()
    }
    
    private func showFirstRunExperience() {
        guard let window = window, let contentView = window.contentView else { return }
        
        // Apply blur to main content
        sidebarView.alphaValue = 0.5
        mainAreaView.alphaValue = 0.5
        
        // Create and show FRE overlay
        let freView = FirstRunView(frame: contentView.bounds)
        freView.translatesAutoresizingMaskIntoConstraints = false
        firstRunView = freView
        
        freView.onComplete = { [weak self] selectedPath, importMode in
            self?.handleFREComplete(with: selectedPath, importMode: importMode)
        }
        
        freView.onSkip = { [weak self] in
            self?.handleFRESkipped()
        }
        
        contentView.addSubview(freView)
        
        NSLayoutConstraint.activate([
            freView.topAnchor.constraint(equalTo: contentView.topAnchor),
            freView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            freView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            freView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        
        // Animate in
        freView.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            freView.animator().alphaValue = 1
        }
    }
    
    private func handleFREComplete(with path: URL, importMode: ImportMode) {
        let settings = AppSettings.shared
        settings.ikemenGOPath = path
        settings.importMode = importMode
        settings.hasCompletedFRE = true
        
        // Update the bridge to use the new path
        ikemenBridge.setWorkingDirectory(path)
        
        // Initialize the metadata store (database)
        initializeMetadataStore(at: path)
        
        // Refresh content
        ikemenBridge.loadContent()
        
        // Restore main UI
        restoreMainUIAfterFRE()
        
        // Show success toast with mode-specific message
        let modeText = importMode == .freshStart ? "Full automation enabled" : "Preserving your existing setup"
        ToastManager.shared.showSuccess(title: "IKEMEN GO linked successfully!", subtitle: modeText)
    }
    
    private func handleFRESkipped() {
        AppSettings.shared.hasCompletedFRE = true
        restoreMainUIAfterFRE()
    }
    
    private func restoreMainUIAfterFRE() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            sidebarView.animator().alphaValue = 1
            mainAreaView.animator().alphaValue = 1
        }
        firstRunView = nil
    }
    
    // MARK: - Sidebar Setup
    
    private func setupSidebar() {
        sidebarView = NSView()
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.wantsLayer = true
        sidebarView.layer?.backgroundColor = DesignColors.sidebarBackground.cgColor
        contentView.addSubview(sidebarView)
        
        // === Right Border ===
        let rightBorder = NSView()
        rightBorder.translatesAutoresizingMaskIntoConstraints = false
        rightBorder.wantsLayer = true
        rightBorder.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        rightBorder.identifier = NSUserInterfaceItemIdentifier("sidebarBorder")
        sidebarView.addSubview(rightBorder)
        
        // === Logo/Header Area ===
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(headerView)
        sidebarHeaderView = headerView
        
        // Bottom border for header
        let headerBorder = NSView()
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBorder.wantsLayer = true
        headerBorder.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        headerBorder.identifier = NSUserInterfaceItemIdentifier("sidebarBorder")
        headerView.addSubview(headerBorder)
        
        // Logo icon (white box with icon)
        let logoContainer = NSView()
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.wantsLayer = true
        logoContainer.layer?.cornerRadius = 6
        headerView.addSubview(logoContainer)
        logoContainerView = logoContainer
        
        let logoIcon = NSImageView()
        logoIcon.translatesAutoresizingMaskIntoConstraints = false
        logoIcon.image = NSImage(systemSymbolName: "flask.fill", accessibilityDescription: nil)
        logoIcon.symbolConfiguration = .init(pointSize: 12, weight: .bold)
        logoContainer.addSubview(logoIcon)
        logoIconView = logoIcon
        
        // App name
        let appNameLabel = NSTextField(labelWithString: "IKEMEN")
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        appNameLabel.font = DesignFonts.body(size: 14)
        appNameLabel.textColor = DesignColors.textPrimary
        headerView.addSubview(appNameLabel)
        appNameLabelView = appNameLabel
        
        let appSubLabel = NSTextField(labelWithString: "Lab")
        appSubLabel.translatesAutoresizingMaskIntoConstraints = false
        appSubLabel.font = DesignFonts.label(size: 14)
        appSubLabel.textColor = DesignColors.textDisabled
        headerView.addSubview(appSubLabel)
        appSubLabelView = appSubLabel
        
        // === Navigation Items ===
        let navStack = NSStackView()
        navStack.translatesAutoresizingMaskIntoConstraints = false
        navStack.orientation = .vertical
        navStack.spacing = 4  // space-y-1 = 4px
        navStack.alignment = .leading
        sidebarView.addSubview(navStack)
        
        // Add nav items (except Settings and hidden items)
        for item in NavItem.allCases where item != .settings && !item.isHidden {
            let button = createNewNavButton(for: item)
            navButtons[item] = button
            navStack.addArrangedSubview(button)
        }
        
        // === Collections Section ===
        collectionsSidebarSection = CollectionsSidebarSection()
        collectionsSidebarSection.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(collectionsSidebarSection)
        
        // Handle collection selection
        collectionsSidebarSection.onCollectionSelected = { [weak self] collection in
            self?.handleCollectionSelected(collection)
        }
        
        // Handle new collection request
        collectionsSidebarSection.onNewCollectionClicked = { [weak self] in
            self?.showNewCollectionDialog()
        }
        
        // Handle new smart collection request
        collectionsSidebarSection.onNewSmartCollectionClicked = { [weak self] in
            self?.showSmartCollectionDialog()
        }
        
        // Handle edit smart collection request
        collectionsSidebarSection.onEditSmartCollectionClicked = { [weak self] collection in
            self?.showSmartCollectionDialog(editing: collection)
        }
        
        // === Bottom Section ===
        let bottomArea = NSView()
        bottomArea.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.addSubview(bottomArea)
        bottomAreaView = bottomArea
        
        let bottomStack = NSStackView()
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.orientation = .vertical
        bottomStack.spacing = 12
        bottomStack.alignment = .leading
        bottomArea.addSubview(bottomStack)
        
        // System info section
        let systemLabel = NSTextField(labelWithString: "SYSTEM")
        systemLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        systemLabel.textColor = DesignColors.textDisabled
        let kerning: [NSAttributedString.Key: Any] = [.kern: 2.0]
        systemLabel.attributedStringValue = NSAttributedString(string: "SYSTEM", attributes: kerning)
        bottomStack.addArrangedSubview(systemLabel)
        systemLabelView = systemLabel
        
        // VRAM progress bar
        let vramContainer = NSView()
        vramContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.addArrangedSubview(vramContainer)
        
        let vramTrack = NSView()
        vramTrack.translatesAutoresizingMaskIntoConstraints = false
        vramTrack.wantsLayer = true
        vramTrack.layer?.cornerRadius = 3
        vramContainer.addSubview(vramTrack)
        vramTrackView = vramTrack
        
        vramFillView = NSView()
        vramFillView.translatesAutoresizingMaskIntoConstraints = false
        vramFillView.wantsLayer = true
        vramFillView.layer?.backgroundColor = DesignColors.textSecondary.cgColor
        vramFillView.layer?.cornerRadius = 3
        vramTrack.addSubview(vramFillView)
        
        // VRAM labels
        let vramLabelStack = NSStackView()
        vramLabelStack.translatesAutoresizingMaskIntoConstraints = false
        vramLabelStack.orientation = .horizontal
        vramLabelStack.distribution = .equalSpacing
        vramContainer.addSubview(vramLabelStack)
        
        let vramLabel = NSTextField(labelWithString: "GPU")
        vramLabel.font = NSFont.systemFont(ofSize: 11)
        vramLabel.textColor = DesignColors.textTertiary
        vramLabelStack.addArrangedSubview(vramLabel)
        vramLabelView = vramLabel
        
        vramPercentLabel = NSTextField(labelWithString: "—")
        vramPercentLabel.font = NSFont.systemFont(ofSize: 11)
        vramPercentLabel.textColor = DesignColors.textTertiary
        vramLabelStack.addArrangedSubview(vramPercentLabel)
        
        // Settings nav button
        let settingsButton = createNewNavButton(for: .settings)
        navButtons[.settings] = settingsButton
        bottomStack.addArrangedSubview(settingsButton)
        
        // === Status Label (hidden by default, reserved for future use) ===
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = DesignFonts.caption(size: 12)
        statusLabel.textColor = DesignColors.positive
        statusLabel.alignment = .left
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.isHidden = true  // Hidden - using toast notifications instead
        sidebarView.addSubview(statusLabel)
        
        // === Constraints ===
        NSLayoutConstraint.activate([
            // Right border
            rightBorder.topAnchor.constraint(equalTo: sidebarView.topAnchor),
            rightBorder.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor),
            rightBorder.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            rightBorder.widthAnchor.constraint(equalToConstant: 1),
            
            // Header
            headerView.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 64),
            
            headerBorder.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            headerBorder.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerBorder.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerBorder.heightAnchor.constraint(equalToConstant: 1),
            
            logoContainer.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            logoContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
            logoContainer.widthAnchor.constraint(equalToConstant: 24),
            logoContainer.heightAnchor.constraint(equalToConstant: 24),
            
            logoIcon.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            logoIcon.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor),
            
            appNameLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            appNameLabel.leadingAnchor.constraint(equalTo: logoContainer.trailingAnchor, constant: 8),
            
            appSubLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            appSubLabel.leadingAnchor.constraint(equalTo: appNameLabel.trailingAnchor, constant: 4),
            
            // Nav stack
            navStack.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            navStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding),
            navStack.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -sidebarPadding),
            
            // Collections section
            collectionsSidebarSection.topAnchor.constraint(equalTo: navStack.bottomAnchor, constant: 20),
            collectionsSidebarSection.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding),
            collectionsSidebarSection.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -sidebarPadding),
            
            // Bottom stack
            bottomArea.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor),
            bottomArea.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            bottomArea.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor),
            bottomArea.topAnchor.constraint(greaterThanOrEqualTo: collectionsSidebarSection.bottomAnchor, constant: 20),
            
            bottomStack.leadingAnchor.constraint(equalTo: bottomArea.leadingAnchor, constant: sidebarPadding),
            bottomStack.trailingAnchor.constraint(equalTo: bottomArea.trailingAnchor, constant: -sidebarPadding),
            bottomStack.bottomAnchor.constraint(equalTo: bottomArea.bottomAnchor, constant: -sidebarPadding),
            
            // VRAM container
            vramContainer.widthAnchor.constraint(equalTo: bottomStack.widthAnchor),
            vramContainer.heightAnchor.constraint(equalToConstant: 30),
            
        vramTrack.topAnchor.constraint(equalTo: vramContainer.topAnchor),
        vramTrack.leadingAnchor.constraint(equalTo: vramContainer.leadingAnchor),
        vramTrack.trailingAnchor.constraint(equalTo: vramContainer.trailingAnchor),
        vramTrack.heightAnchor.constraint(equalToConstant: 6),
            
            vramFillView.topAnchor.constraint(equalTo: vramTrack.topAnchor),
            vramFillView.bottomAnchor.constraint(equalTo: vramTrack.bottomAnchor),
            vramFillView.leadingAnchor.constraint(equalTo: vramTrack.leadingAnchor),
            
            vramLabelStack.topAnchor.constraint(equalTo: vramTrack.bottomAnchor, constant: 6),
            vramLabelStack.leadingAnchor.constraint(equalTo: vramContainer.leadingAnchor),
            vramLabelStack.trailingAnchor.constraint(equalTo: vramContainer.trailingAnchor),
            
            // Status label
            statusLabel.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding),
            statusLabel.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -sidebarPadding),
            statusLabel.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -12),
        ])
        
        // Dynamic VRAM fill width constraint (start at 0)
        vramFillWidthConstraint = vramFillView.widthAnchor.constraint(equalToConstant: 0)
        vramFillWidthConstraint.isActive = true
        
        // VRAM monitoring is handled by vramMonitor (initialized in setupCoordinators)
    }
    
    /// Create a new-style nav button matching the HTML design
    private func createNewNavButton(for item: NavItem) -> NSButton {
        let button = NavButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""
        button.isBordered = false
        button.bezelStyle = .inline
        button.target = self
        button.action = #selector(navItemClicked(_:))
        button.wantsLayer = true
        button.focusRingType = .none
        
        // Container for background
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        container.identifier = NSUserInterfaceItemIdentifier("navContainer")
        button.addSubview(container)
        
        // Create horizontal stack for icon + text + badge
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon (SF Symbol)
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.identifier = NSUserInterfaceItemIdentifier("navIcon")
        iconView.image = NSImage(systemSymbolName: item.sfSymbolName, accessibilityDescription: item.rawValue)
        iconView.contentTintColor = DesignColors.textSecondary
        iconView.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        stack.addArrangedSubview(iconView)
        
        // Label
        let label = NSTextField(labelWithString: item.rawValue)
        label.font = DesignFonts.body(size: 14)
        label.textColor = DesignColors.textSecondary
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.identifier = NSUserInterfaceItemIdentifier("navLabel")
        stack.addArrangedSubview(label)
        
        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)
        
        // Count badge (for Characters/Stages)
        if item.showsCount {
            // Create a container for proper vertical centering
            let badgeContainer = NSView()
            badgeContainer.translatesAutoresizingMaskIntoConstraints = false
            badgeContainer.wantsLayer = true
            badgeContainer.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
            badgeContainer.layer?.cornerRadius = 4
            badgeContainer.layer?.borderWidth = 1
            badgeContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
            badgeContainer.identifier = NSUserInterfaceItemIdentifier("navBadgeContainer")
            badgeContainer.setContentHuggingPriority(.required, for: .horizontal)
            
            let badge = NSTextField(labelWithString: "0")
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            badge.textColor = DesignColors.textTertiary
            badge.alignment = .center
            badge.backgroundColor = .clear
            badge.isBordered = false
            badge.identifier = NSUserInterfaceItemIdentifier("navBadge")
            badge.setContentHuggingPriority(.required, for: .horizontal)
            
            badgeContainer.addSubview(badge)
            
            // Store reference for updating
            navLabels[item] = badge
            
            NSLayoutConstraint.activate([
                badgeContainer.heightAnchor.constraint(equalToConstant: 20),
                badge.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 8),
                badge.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -8),
                badge.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            ])
            stack.addArrangedSubview(badgeContainer)
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            container.topAnchor.constraint(equalTo: button.topAnchor),
            container.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            button.heightAnchor.constraint(equalToConstant: 36),
            button.widthAnchor.constraint(equalToConstant: sidebarWidth - (sidebarPadding * 2)),
        ])
        
        // Store item reference
        button.tag = NavItem.allCases.firstIndex(of: item) ?? 0
        
        // Setup hover handling
        button.onHoverChanged = { [weak self, weak button] isHovered in
            guard let self = self, let button = button else { return }
            self.updateNewNavButtonAppearance(button, for: item, isHovered: isHovered)
        }
        
        return button
    }
    
    private func updateNewNavButtonAppearance(_ button: NSButton, for item: NavItem, isHovered: Bool) {
        let isSelected = selectedNavItem == item
        let unselectedTextColor = AppSettings.shared.useLightTheme ? DesignColors.textTertiary : DesignColors.textSecondary
        
        guard let container = button.subviews.first(where: { $0.identifier?.rawValue == "navContainer" }) else { return }
        
        if isSelected {
            container.layer?.backgroundColor = DesignColors.selectedBackground.cgColor
            container.layer?.borderWidth = 1
            container.layer?.borderColor = DesignColors.borderSubtle.cgColor
            applyNavSelectionShadow(to: container, isSelected: true)
        } else if isHovered {
            container.layer?.backgroundColor = DesignColors.hoverBackground.cgColor
            container.layer?.borderWidth = 0
            applyNavSelectionShadow(to: container, isSelected: false)
        } else {
            container.layer?.backgroundColor = NSColor.clear.cgColor
            container.layer?.borderWidth = 0
            applyNavSelectionShadow(to: container, isSelected: false)
        }
        
        if let stack = container.subviews.compactMap({ $0 as? NSStackView }).first {
            for view in stack.arrangedSubviews {
                if let iconView = view as? NSImageView, iconView.identifier?.rawValue == "navIcon" {
                    iconView.contentTintColor = isSelected || isHovered ? DesignColors.textPrimary : unselectedTextColor
                }
                if let label = view as? NSTextField, label.identifier?.rawValue == "navLabel" {
                    label.textColor = isSelected || isHovered ? DesignColors.textPrimary : unselectedTextColor
                }
            }
        }
    }
    
    @objc private func navItemClicked(_ sender: NSButton) {
        let item = NavItem.allCases[sender.tag]
        selectNavItem(item)
    }
    
    /// Public method to select the Settings nav item (called from menu)
    func selectSettingsNavItem() {
        selectNavItem(.settings)
    }
    
    private func selectNavItem(_ item: NavItem?) {
        selectedNavItem = item
        
        let unselectedTextColor = AppSettings.shared.useLightTheme ? DesignColors.textTertiary : DesignColors.textSecondary
        
        // Update button appearances using new styling
        for (navItem, button) in navButtons {
            let isSelected = navItem == item
            
            guard let container = button.subviews.first(where: { $0.identifier?.rawValue == "navContainer" }) else { continue }
            
            // Apply selected/default background
            if isSelected {
                container.layer?.backgroundColor = DesignColors.selectedBackground.cgColor
                container.layer?.borderWidth = 1
                container.layer?.borderColor = DesignColors.borderSubtle.cgColor
                applyNavSelectionShadow(to: container, isSelected: true)
            } else {
                container.layer?.backgroundColor = NSColor.clear.cgColor
                container.layer?.borderWidth = 0
                applyNavSelectionShadow(to: container, isSelected: false)
            }
            
            // Update icon and label colors
            if let stack = container.subviews.compactMap({ $0 as? NSStackView }).first {
                for view in stack.arrangedSubviews {
                    if let iconView = view as? NSImageView, iconView.identifier?.rawValue == "navIcon" {
                        iconView.contentTintColor = isSelected ? DesignColors.textPrimary : unselectedTextColor
                    }
                    if let label = view as? NSTextField, label.identifier?.rawValue == "navLabel" {
                        label.textColor = isSelected ? DesignColors.textPrimary : unselectedTextColor
                    }
                }
            }
        }
        
        // Update main area content
        updateMainAreaContent()
    }

    private func applyNavSelectionShadow(to view: NSView, isSelected: Bool) {
        guard AppSettings.shared.useLightTheme else {
            view.layer?.shadowOpacity = 0
            return
        }
        
        if isSelected {
            view.layer?.shadowColor = NSColor.black.withAlphaComponent(0.08).cgColor
            view.layer?.shadowOffset = CGSize(width: 0, height: 1)
            view.layer?.shadowRadius = 2
            view.layer?.shadowOpacity = 1
        } else {
            view.layer?.shadowOpacity = 0
        }
    }
    
    // MARK: - Main Area Setup
    
    private func setupMainArea() {
        mainAreaView = NSView()
        mainAreaView.translatesAutoresizingMaskIntoConstraints = false
        mainAreaView.wantsLayer = true
        mainAreaView.layer?.backgroundColor = DesignColors.background.cgColor
        contentView.addSubview(mainAreaView)
        
        // Content Header (shared across all views)
        contentHeaderView = ContentHeaderView(frame: .zero)
        contentHeaderView.translatesAutoresizingMaskIntoConstraints = false
        contentHeaderView.isHidden = true // Hidden on dashboard
        contentHeaderView.onSearch = { [weak self] query in
            self?.performSearch(query)
        }
        contentHeaderView.onHomeClicked = { [weak self] in
            self?.selectNavItem(.dashboard)
        }
        contentHeaderView.onViewModeChanged = { [weak self] mode in
            self?.handleViewModeChanged(mode)
        }
        contentHeaderView.onRefresh = { [weak self] in
            self?.refreshCurrentView()
        }
        mainAreaView.addSubview(contentHeaderView)
        
        // Dashboard View
        dashboardView = DashboardView(frame: .zero)
        dashboardView.translatesAutoresizingMaskIntoConstraints = false
        dashboardView.isHidden = true
        dashboardView.onLaunchGame = { [weak self] in
            self?.launchIkemen()
        }
        dashboardView.onFilesDropped = { [weak self] urls in
            self?.installCoordinator.handleDroppedFiles(urls)
        }
        dashboardView.onRefreshStats = { [weak self] in
            self?.updateDashboardStats()
        }
        dashboardView.onNavigateToCharacters = { [weak self] in
            self?.selectNavItem(.characters)
        }
        dashboardView.onNavigateToStages = { [weak self] in
            self?.selectNavItem(.stages)
        }
        dashboardView.onValidateContent = { [weak self] in
            self?.runContentValidation()
        }
        dashboardView.onInstallContent = { [weak self] in
            self?.installCoordinator.showInstallDialog()
        }
        mainAreaView.addSubview(dashboardView)
        
        // Drop Zone (visible in empty state - legacy, kept for other views)
        dropZoneView = DropZoneView(frame: .zero)
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.onFilesDropped = { [weak self] urls in
            self?.installCoordinator.handleDroppedFiles(urls)
        }
        // Apply new design styling
        dropZoneView.applyFigmaStyle(borderColor: DesignColors.borderDashed, textColor: DesignColors.textTertiary, font: DesignFonts.body(size: 14))
        mainAreaView.addSubview(dropZoneView)
        
        // Create Stage from PNG button (hidden by default, shown when on stages tab)
        createStageButton = NSButton(title: "Create from PNG", target: self, action: #selector(createStageFromPNGAction(_:)))
        createStageButton.translatesAutoresizingMaskIntoConstraints = false
        createStageButton.bezelStyle = .rounded
        createStageButton.isHidden = true
        createStageButton.toolTip = "Create a new stage from a PNG image"
        mainAreaView.addSubview(createStageButton)
        
        // Character Browser (hidden initially)
        characterBrowserView = CharacterBrowserView(frame: .zero)
        characterBrowserView.translatesAutoresizingMaskIntoConstraints = false
        characterBrowserView.isHidden = true
        characterBrowserView.onSelectionChanged = { [weak self] selection in
            guard let self else { return }
            if selection.count == 1, let character = selection.first {
                self.statusLabel.stringValue = character.displayName
                self.showCharacterDetails(character)
            } else if selection.isEmpty {
                self.characterDetailsView.showPlaceholder()
            } else {
                self.characterDetailsView.showMultiSelection(count: selection.count)
            }
        }
        characterBrowserView.onCharacterRevealInFinder = { [weak self] character in
            self?.revealCharacterInFinder(character)
        }
        characterBrowserView.onCharacterRemove = { [weak self] character in
            self?.confirmRemoveCharacter(character)
        }
        characterBrowserView.onCharacterDisableToggle = { [weak self] character in
            self?.toggleCharacterDisabled(character)
        }
        mainAreaView.addSubview(characterBrowserView)
        
        // Character Details Panel (always visible on right side when Characters tab is active)
        characterDetailsView = CharacterDetailsView(frame: .zero)
        characterDetailsView.translatesAutoresizingMaskIntoConstraints = false
        characterDetailsView.isHidden = true  // Hidden until Characters tab is shown
        characterDetailsView.showPlaceholder()  // Show placeholder initially
        characterDetailsView.onNameChanged = { [weak self] character, newName in
            self?.updateCharacterName(character, newName: newName)
        }
        characterDetailsView.onOpenFolder = { character in
            NSWorkspace.shared.activateFileViewerSelecting([character.directory])
        }
        characterDetailsView.onDeleteCharacter = { [weak self] character in
            self?.confirmRemoveCharacter(character)
        }
        characterDetailsView.onAddTag = { [weak self] character in
            self?.promptForCustomTag(for: [character.id])
        }
        characterDetailsView.onApplyTag = { [weak self] character, tag in
            self?.applyTagDirectly(tag, to: [character.id])
        }
        mainAreaView.addSubview(characterDetailsView)
        
        // Stage Browser (hidden initially)
        stageBrowserView = StageBrowserView(frame: .zero)
        stageBrowserView.translatesAutoresizingMaskIntoConstraints = false
        stageBrowserView.isHidden = true
        stageBrowserView.onStageSelected = { [weak self] stage in
            self?.statusLabel.stringValue = stage.name
        }
        stageBrowserView.onStageDisableToggle = { [weak self] stage in
            self?.toggleStageDisabled(stage)
        }
        stageBrowserView.onStageRemove = { [weak self] stage in
            self?.confirmRemoveStage(stage)
        }
        stageBrowserView.onStageRevealInFinder = { stage in
            NSWorkspace.shared.activateFileViewerSelecting([stage.defFile])
        }
        mainAreaView.addSubview(stageBrowserView)
        
        // Screenpack Browser (hidden initially)
        screenpackBrowserView = ScreenpackBrowserView(frame: .zero)
        screenpackBrowserView.translatesAutoresizingMaskIntoConstraints = false
        screenpackBrowserView.isHidden = true
        screenpackBrowserView.onScreenpackSelected = { [weak self] screenpack in
            let status = screenpack.isActive ? "\(screenpack.name) (Active)" : screenpack.name
            self?.statusLabel.stringValue = status
        }
        screenpackBrowserView.onScreenpackActivate = { [weak self] screenpack in
            let bridge = IkemenBridge.shared
            guard bridge.workingDirectory != nil else { return }
            
            // Sync characters to this screenpack's select.def before activating
            // defFile is system.def, so its parent directory contains select.def
            let screenpackDir = screenpack.defFile.deletingLastPathComponent()
            
            // Redirect screenpack to use global select.def
            ContentManager.shared.redirectScreenpackToGlobalSelectDef(screenpackPath: screenpackDir)
            
            bridge.setActiveScreenpack(screenpack)
            self?.statusLabel.stringValue = "Activated: \(screenpack.name)"
        }
        mainAreaView.addSubview(screenpackBrowserView)
        
        // Duplicates View (hidden initially)
        duplicatesView = DuplicatesView(frame: .zero)
        duplicatesView.translatesAutoresizingMaskIntoConstraints = false
        duplicatesView.isHidden = true
        duplicatesView.onCharacterRemove = { [weak self] character in
            self?.removeCharacter(character)
        }
        duplicatesView.onStageRemove = { [weak self] stage in
            self?.removeStage(stage)
        }
        mainAreaView.addSubview(duplicatesView)
        
        // Collection Editor View (hidden initially)
        collectionEditorView = CollectionEditorView(frame: .zero)
        collectionEditorView.translatesAutoresizingMaskIntoConstraints = false
        collectionEditorView.isHidden = true
        collectionEditorView.onBackClicked = { [weak self] in
            self?.closeCollectionEditor()
        }
        collectionEditorView.onActivateClicked = { [weak self] collection in
            CollectionStore.shared.setActive(collection)
            ToastManager.shared.showSuccess(
                title: "Activated: \(collection.name)",
                actionTitle: "Launch",
                action: { [weak self] in
                    self?.launchIkemen()
                }
            )
        }
        collectionEditorView.onAddCharactersClicked = { [weak self] collection in
            self?.showCharacterPicker(for: collection)
        }
        collectionEditorView.onAddStagesClicked = { [weak self] collection in
            self?.showStagePicker(for: collection)
        }
        collectionEditorView.onChangeScreenpackClicked = { [weak self] collection in
            self?.showScreenpackPicker(for: collection)
        }
        mainAreaView.addSubview(collectionEditorView)
        
        // Character details panel width constraint (420px per HTML design)
        characterDetailsWidthConstraint = characterDetailsView.widthAnchor.constraint(equalToConstant: 420)
        
        NSLayoutConstraint.activate([
            // Content header at top of main area (hidden on dashboard)
            contentHeaderView.topAnchor.constraint(equalTo: mainAreaView.topAnchor),
            contentHeaderView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor),
            contentHeaderView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor),
            
            // Dashboard fills main area
            dashboardView.topAnchor.constraint(equalTo: mainAreaView.topAnchor),
            dashboardView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor),
            dashboardView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor),
            dashboardView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor),
            
            // Create stage button - top-right of content area (below header)
            createStageButton.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
            createStageButton.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            
            // Drop zone fills main area with padding
            dropZoneView.topAnchor.constraint(equalTo: mainAreaView.topAnchor, constant: 24),
            dropZoneView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            dropZoneView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            dropZoneView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
            
            // Character browser - left side, stops at detail panel
            characterBrowserView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
            characterBrowserView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            characterBrowserView.trailingAnchor.constraint(equalTo: characterDetailsView.leadingAnchor, constant: -16),
            characterBrowserView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
            
            // Character details panel - always visible on right side (420px width)
            characterDetailsView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
            characterDetailsView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            characterDetailsView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
            characterDetailsWidthConstraint,
            
            // Stage browser fills main area (below header)
            stageBrowserView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
            stageBrowserView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            stageBrowserView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            stageBrowserView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
            
            // Screenpack browser fills main area (below header)
            screenpackBrowserView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
            screenpackBrowserView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            screenpackBrowserView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            screenpackBrowserView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
            
            // Duplicates view fills main area (below header)
            duplicatesView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
            duplicatesView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            duplicatesView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            duplicatesView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
            
            // Collection editor fills main area (has its own header)
            collectionEditorView.topAnchor.constraint(equalTo: mainAreaView.topAnchor),
            collectionEditorView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor),
            collectionEditorView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor),
            collectionEditorView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor),
        ])
    }
    
    private func handleViewModeChanged(_ mode: ViewModeToggle.Mode) {
        currentViewMode = mode == .grid ? .grid : .list
        characterBrowserView.viewMode = currentViewMode
        screenpackBrowserView.viewMode = currentViewMode
        // Note: stageBrowserView is always list view, doesn't support grid/list toggle
    }
    
    private func refreshCurrentView() {
        // Capture counts before refresh
        let previousCharacterCount = IkemenBridge.shared.characters.count
        let previousStageCount = IkemenBridge.shared.stages.count
        let previousScreenpackCount = IkemenBridge.shared.screenpacks.count
        
        // Rescan content from disk
        IkemenBridge.shared.loadContent()
        
        // Get new counts
        let newCharacterCount = IkemenBridge.shared.characters.count
        let newStageCount = IkemenBridge.shared.stages.count
        let newScreenpackCount = IkemenBridge.shared.screenpacks.count
        
        // Then refresh the current view with updated data
        switch selectedNavItem {
        case .characters:
            characterBrowserView?.refresh()
            showRefreshNotification(
                contentType: "character",
                previous: previousCharacterCount,
                current: newCharacterCount
            )
        case .stages:
            stageBrowserView?.refresh()
            showRefreshNotification(
                contentType: "stage",
                previous: previousStageCount,
                current: newStageCount
            )
        case .addons:
            screenpackBrowserView?.refresh()
            showRefreshNotification(
                contentType: "screenpack",
                previous: previousScreenpackCount,
                current: newScreenpackCount
            )
        default:
            break
        }
    }
    
    private func showRefreshNotification(contentType: String, previous: Int, current: Int) {
        let diff = current - previous
        guard diff != 0 else { return }  // No changes, no notification
        
        let notification = NSUserNotification()
        notification.title = "IKEMEN Lab"
        
        if diff > 0 {
            let plural = diff == 1 ? contentType : "\(contentType)s"
            notification.informativeText = "Found \(diff) new \(plural)"
        } else {
            let removed = abs(diff)
            let plural = removed == 1 ? contentType : "\(contentType)s"
            notification.informativeText = "Removed \(removed) \(plural)"
        }
        
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func updateMainAreaContent() {
        // Guard against being called before UI is fully initialized
        guard mainAreaView != nil else { return }
        
        // Remove settings view if not on settings tab
        if selectedNavItem != .settings {
            mainAreaView.subviews.filter { $0.identifier?.rawValue == "settingsView" }.forEach { $0.removeFromSuperview() }
        }
        
        // Show/hide character details panel (only visible on Characters tab)
        let showDetailsPanel = selectedNavItem == .characters
        characterDetailsView?.isHidden = !showDetailsPanel
        if showDetailsPanel {
            // Show placeholder if no character selected
            characterDetailsView?.showPlaceholder()
        }
        
        // Show/hide content header (hidden on dashboard)
        let showHeader = selectedNavItem != .dashboard && selectedNavItem != nil
        contentHeaderView?.isHidden = !showHeader
        
        // Show/hide view mode toggle in header for content browsers
        // Note: stages is list-only so doesn't need toggle
        let showToggle = selectedNavItem == .characters || selectedNavItem == .addons
        contentHeaderView?.setViewModeToggleVisible(showToggle)
        
        // Show refresh button for content browsers (characters, stages, add-ons)
        let showRefresh = selectedNavItem == .characters || selectedNavItem == .stages || selectedNavItem == .addons
        contentHeaderView?.setRefreshButtonVisible(showRefresh)
        
        // Sync toggle state with current view mode
        contentHeaderView?.setViewMode(currentViewMode == .grid ? .grid : .list)
        
        // Update breadcrumb based on current view
        switch selectedNavItem {
        case .characters:
            contentHeaderView?.setCurrentPage("Characters")
        case .stages:
            contentHeaderView?.setCurrentPage("Stages")
        case .soundpacks:
            contentHeaderView?.setCurrentPage("Screenpacks")
        case .addons:
            contentHeaderView?.setCurrentPage("Add-ons")
        case .duplicates:
            contentHeaderView?.setCurrentPage("Duplicates")
        case .settings:
            contentHeaderView?.setCurrentPage("Settings")
        default:
            break
        }
        
        // Clear search when switching views
        contentHeaderView?.clearSearch()
        currentSearchQuery = ""
        
        // Show/hide create stage button (only on stages tab and when feature is enabled)
        let showCreateStageButton = selectedNavItem == .stages && AppSettings.shared.enablePNGStageCreation
        createStageButton?.isHidden = !showCreateStageButton
        
        // Show/hide appropriate views based on selection
        switch selectedNavItem {
        case .dashboard:
            // Dashboard view
            dashboardView?.isHidden = false
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
            updateDashboardStats()
        case .characters:
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = false
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
            characterBrowserView?.viewMode = currentViewMode
        case .stages:
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = false
            screenpackBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
        case .soundpacks:
            // TODO: Implement soundpacks browser
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = false
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
        case .addons:
            // Screenpacks browser (add-ons tab)
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = false
            duplicatesView?.isHidden = true
            screenpackBrowserView?.viewMode = currentViewMode
        case .duplicates:
            // Duplicates view
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            duplicatesView?.isHidden = false
            duplicatesView?.refresh()
        case .settings:
            // Show settings panel
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
            collectionEditorView?.isHidden = true
            showSettingsContent()
        case nil:
            // Empty state or collection editor
            // If editing a collection, keep the editor visible
            if editingCollection != nil {
                // Collection editor is already shown, don't change
                return
            }
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = false
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
            collectionEditorView?.isHidden = true
        }
        
        // Always hide collection editor when a nav item is selected (except nil case handled above)
        if selectedNavItem != nil {
            collectionEditorView?.isHidden = true
            editingCollection = nil
        }
    }
    
    private func updateDashboardStats() {
        guard dashboardView != nil, ikemenBridge != nil else { return }
        
        // Get counts from nav label badges
        let characterCount = Int(navLabels[.characters]?.stringValue ?? "0") ?? 0
        let stageCount = Int(navLabels[.stages]?.stringValue ?? "0") ?? 0
        
        // Calculate storage size
        var storageBytes: Int64? = nil
        let ikemenPath = ikemenBridge.workingDirectory?.path ?? "/Users/davidphillips/Sites/macmame/Ikemen-GO"
        let charsPath = ikemenPath + "/chars"
        let stagesPath = ikemenPath + "/stages"
        
        if let charsSize = folderSize(at: charsPath), let stagesSize = folderSize(at: stagesPath) {
            storageBytes = charsSize + stagesSize
        }
        
        dashboardView?.updateStats(characters: characterCount, stages: stageCount, storageBytes: storageBytes)
    }

    private func promptForCustomTag(for characterIds: [String]) {
        guard !characterIds.isEmpty else { return }
        
        let alert = NSAlert()
        alert.messageText = characterIds.count > 1 ? "Add Tag to Selected" : "Add Tag"
        alert.informativeText = "Enter a custom tag name:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        input.placeholderString = "Tag name"
        alert.accessoryView = input
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let tag = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else {
            ToastManager.shared.showError(title: "Tag cannot be empty")
            return
        }
        
        applyTagDirectly(tag, to: characterIds)
    }
    
    private func applyTagDirectly(_ tag: String, to characterIds: [String]) {
        do {
            try MetadataStore.shared.assignCustomTag(tag, to: characterIds)
            let title = characterIds.count > 1 ? "Added tag to selected" : "Tag added"
            ToastManager.shared.showSuccess(title: title, subtitle: tag)
        } catch {
            ToastManager.shared.showError(title: "Failed to add tag", subtitle: error.localizedDescription)
        }
    }
    
    // MARK: - Search
    
    private func performSearch(_ query: String) {
        currentSearchQuery = query
        
        // Filter current view based on search query
        switch selectedNavItem {
        case .characters:
            if query.isEmpty {
                // Show all characters
                refreshCharacters()
            } else {
                // Filter using MetadataStore first, then fallback to simple search
                let allCharacters = ikemenBridge.characters
                let customTagsMap = (try? MetadataStore.shared.customTagsMap(for: allCharacters.map { $0.id })) ?? [:]
                do {
                    let results = try MetadataStore.shared.searchCharacters(query: query)
                    let matchingPaths = Set(results.map { $0.folderPath })
                    
                    // Filter to matching ones (use directory.path to match against MetadataStore's folderPath)
                    let filtered = allCharacters.filter { char in
                        matchingPaths.contains(char.directory.path) ||
                        char.displayName.localizedCaseInsensitiveContains(query) ||
                        char.author.localizedCaseInsensitiveContains(query) ||
                        char.inferredTags.contains { $0.localizedCaseInsensitiveContains(query) } ||
                        (customTagsMap[char.id] ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
                    }
                    characterBrowserView?.setCharacters(filtered)
                } catch {
                    // Fallback to simple filtering (includes tags)
                    let filtered = allCharacters.filter {
                        $0.displayName.localizedCaseInsensitiveContains(query) ||
                        $0.author.localizedCaseInsensitiveContains(query) ||
                        $0.inferredTags.contains { $0.localizedCaseInsensitiveContains(query) } ||
                        (customTagsMap[$0.id] ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
                    }
                    characterBrowserView?.setCharacters(filtered)
                }
            }
            
        case .stages:
            if query.isEmpty {
                // Show all stages
                refreshStages()
            } else {
                // Filter using MetadataStore first, then fallback to simple search
                let allStages = ikemenBridge.stages
                do {
                    let results = try MetadataStore.shared.searchStages(query: query)
                    let matchingPaths = Set(results.map { $0.filePath })
                    
                    // Filter to matching ones
                    let filtered = allStages.filter { stage in
                        matchingPaths.contains(stage.defFile.path) ||
                        stage.name.localizedCaseInsensitiveContains(query) ||
                        stage.author.localizedCaseInsensitiveContains(query)
                    }
                    stageBrowserView?.setStages(filtered)
                } catch {
                    // Fallback to simple filtering
                    let filtered = allStages.filter {
                        $0.name.localizedCaseInsensitiveContains(query) ||
                        $0.author.localizedCaseInsensitiveContains(query)
                    }
                    stageBrowserView?.setStages(filtered)
                }
            }
            
        case .soundpacks:
            // Soundpacks don't have MetadataStore yet, use simple filtering
            let allScreenpacks = ikemenBridge.screenpacks
            if query.isEmpty {
                screenpackBrowserView?.setScreenpacks(allScreenpacks)
            } else {
                let filtered = allScreenpacks.filter {
                    $0.name.localizedCaseInsensitiveContains(query)
                }
                screenpackBrowserView?.setScreenpacks(filtered)
            }
            
        default:
            break
        }
    }
    
    private func refreshCharacters() {
        characterBrowserView?.setCharacters(ikemenBridge.characters)
    }
    
    private func refreshStages() {
        stageBrowserView?.setStages(ikemenBridge.stages)
    }
    
    private func folderSize(at path: String) -> Int64? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return nil }
        
        var totalSize: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }
    
    // MARK: - Character Details Panel
    
    private func showCharacterDetails(_ character: CharacterInfo) {
        // Just update the content - panel is always visible
        characterDetailsView.configure(with: character)
    }
    
    // hideCharacterDetails is no longer needed - panel stays visible
    // Keep method stub for compatibility if called elsewhere
    
    private func updateCharacterName(_ character: CharacterInfo, newName: String) {
        // Update the name in the .def file
        guard let content = DEFParser.readFileContent(from: character.defFile) else {
            statusLabel.stringValue = "Failed to read character file"
            return
        }
        
        var lines = content.components(separatedBy: "\n")
        var modified = false
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            // Look for name= or displayname= line
            if (trimmed.hasPrefix("name") || trimmed.hasPrefix("displayname")) && trimmed.contains("=") {
                if let eqIdx = line.firstIndex(of: "=") {
                    let key = String(line[..<eqIdx]).trimmingCharacters(in: .whitespaces)
                    lines[index] = "\(key)=\"\(newName)\""
                    modified = true
                    // Only modify 'name' if there's no displayname, or modify displayname
                    if trimmed.hasPrefix("displayname") {
                        break // Prefer displayname
                    }
                }
            }
        }
        
        if modified {
            let newContent = lines.joined(separator: "\n")
            do {
                try newContent.write(to: character.defFile, atomically: true, encoding: .utf8)
                statusLabel.stringValue = "Renamed to \"\(newName)\""
                
                // Refresh the character list
                IkemenBridge.shared.loadContent()
            } catch {
                statusLabel.stringValue = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Stage Management
    
    private func toggleStageDisabled(_ stage: StageInfo) {
        guard let workingDir = IkemenBridge.shared.workingDirectory else {
            statusLabel.stringValue = "No working directory set"
            return
        }
        
        do {
            if stage.isDisabled {
                // Enable the stage
                try ContentManager.shared.enableStage(stage, in: workingDir)
                statusLabel.stringValue = "Enabled: \(stage.name)"
            } else {
                // Disable the stage
                try ContentManager.shared.disableStage(stage, in: workingDir)
                statusLabel.stringValue = "Disabled: \(stage.name)"
            }
            
            // Refresh the stage list
            IkemenBridge.shared.loadContent()
            
            // Refresh dashboard's recently installed table
            dashboardView.refresh()
        } catch {
            statusLabel.stringValue = "Failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Character Management
    
    private func toggleCharacterDisabled(_ character: CharacterInfo) {
        guard let workingDir = IkemenBridge.shared.workingDirectory else {
            statusLabel.stringValue = "No working directory set"
            return
        }
        
        do {
            if character.isDisabled {
                // Enable the character
                try ContentManager.shared.enableCharacter(character, in: workingDir)
                statusLabel.stringValue = "Enabled: \(character.displayName)"
            } else {
                // Disable the character
                try ContentManager.shared.disableCharacter(character, in: workingDir)
                statusLabel.stringValue = "Disabled: \(character.displayName)"
            }
            
            // Refresh the character list
            IkemenBridge.shared.loadContent()
            
            // Refresh dashboard's recently installed table
            dashboardView.refresh()
        } catch {
            statusLabel.stringValue = "Failed: \(error.localizedDescription)"
        }
    }
    
    private func confirmRemoveStage(_ stage: StageInfo) {
        let alert = NSAlert()
        alert.messageText = "Remove \"\(stage.name)\"?"
        alert.informativeText = "This will move the stage files to Trash and remove it from select.def."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        guard let window = self.window else { return }
        
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.removeStage(stage)
            }
        }
    }
    
    private func removeStage(_ stage: StageInfo) {
        guard let workingDir = IkemenBridge.shared.workingDirectory else {
            statusLabel.stringValue = "No working directory set"
            return
        }
        
        do {
            try ContentManager.shared.removeStage(stage, in: workingDir)
            statusLabel.stringValue = "Removed: \(stage.name)"
            
            // Refresh the stage list
            IkemenBridge.shared.loadContent()
        } catch {
            statusLabel.stringValue = "Failed to remove: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Character Management
    
    private func revealCharacterInFinder(_ character: CharacterInfo) {
        NSWorkspace.shared.activateFileViewerSelecting([character.path])
    }
    
    private func confirmRemoveCharacter(_ character: CharacterInfo) {
        let alert = NSAlert()
        alert.messageText = "Remove \"\(character.displayName)\"?"
        alert.informativeText = "This will move the character files to Trash and remove it from select.def."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        guard let window = self.window else { return }
        
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.removeCharacter(character)
            }
        }
    }
    
    private func removeCharacter(_ character: CharacterInfo) {
        guard let workingDir = IkemenBridge.shared.workingDirectory else {
            statusLabel.stringValue = "No working directory set"
            return
        }
        
        do {
            try ContentManager.shared.removeCharacter(character, in: workingDir)
            statusLabel.stringValue = "Removed: \(character.displayName)"
            
            // Refresh the character list
            IkemenBridge.shared.loadContent()
        } catch {
            statusLabel.stringValue = "Failed to remove: \(error.localizedDescription)"
        }
    }
    
    private func showSettingsContent() {
        // Remove any existing settings view
        mainAreaView.subviews.filter { $0.identifier?.rawValue == "settingsView" }.forEach { $0.removeFromSuperview() }
        
        let settingsView = SettingsView()
        settingsView.identifier = NSUserInterfaceItemIdentifier("settingsView")
        settingsView.parentView = mainAreaView
        mainAreaView.addSubview(settingsView)
        
        NSLayoutConstraint.activate([
            settingsView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
            settingsView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            settingsView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            settingsView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
        ])
    }
    
    // MARK: - Collections
    
    private func handleCollectionSelected(_ collection: Collection) {
        // Deselect nav items when a collection is selected
        selectNavItem(nil)
        
        // Show collection editor
        editingCollection = collection
        collectionEditorView.configure(with: collection)
        showCollectionEditor()
    }
    
    private func showCollectionEditor() {
        // Hide all other views
        dashboardView?.isHidden = true
        dropZoneView?.isHidden = true
        characterBrowserView?.isHidden = true
        characterDetailsView?.isHidden = true
        stageBrowserView?.isHidden = true
        screenpackBrowserView?.isHidden = true
        duplicatesView?.isHidden = true
        contentHeaderView?.isHidden = true
        createStageButton?.isHidden = true
        
        // Show collection editor
        collectionEditorView?.isHidden = false
    }
    
    private func closeCollectionEditor() {
        editingCollection = nil
        collectionEditorView?.isHidden = true
        
        // Return to dashboard
        selectNavItem(.dashboard)
    }
    
    private func showCharacterPicker(for collection: Collection) {
        let picker = CharacterPickerSheet(collection: collection)
        picker.onDismiss = { [weak self] in
            // Refresh the editor with updated collection
            if let updated = CollectionStore.shared.collection(withId: collection.id) {
                self?.collectionEditorView.configure(with: updated)
            }
        }
        
        // Present as sheet using beginSheet on window
        guard let window = window else { return }
        let sheetWindow = NSWindow(contentViewController: picker)
        sheetWindow.styleMask = [.titled, .closable]
        window.beginSheet(sheetWindow) { _ in }
    }
    
    private func showStagePicker(for collection: Collection) {
        let picker = StagePickerSheet(collection: collection)
        picker.onDismiss = { [weak self] in
            // Refresh the editor with updated collection
            if let updated = CollectionStore.shared.collection(withId: collection.id) {
                self?.collectionEditorView.configure(with: updated)
            }
        }
        
        // Present as sheet using beginSheet on window
        guard let window = window else { return }
        let sheetWindow = NSWindow(contentViewController: picker)
        sheetWindow.styleMask = [.titled, .closable]
        window.beginSheet(sheetWindow) { _ in }
    }
    
    private func showScreenpackPicker(for collection: Collection) {
        let picker = ScreenpackPickerSheet(collection: collection)
        picker.onDismiss = { [weak self] in
            // Refresh the editor with updated collection
            if let updated = CollectionStore.shared.collection(withId: collection.id) {
                self?.collectionEditorView.configure(with: updated)
            }
        }
        
        // Present as sheet using beginSheet on window
        guard let window = window else { return }
        let sheetWindow = NSWindow(contentViewController: picker)
        sheetWindow.styleMask = [.titled, .closable]
        window.beginSheet(sheetWindow) { _ in }
    }
    
    private var newCollectionOverlay: NSView?
    private var newCollectionSheet: NewCollectionSheet?
    private var smartCollectionSheet: SmartCollectionSheet?
    
    private func showNewCollectionDialog() {
        guard let window = window, let contentView = window.contentView else { return }
        
        // Create dimming overlay
        let overlay = NSView(frame: contentView.bounds)
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        overlay.alphaValue = 0
        overlay.autoresizingMask = [.width, .height]
        contentView.addSubview(overlay)
        newCollectionOverlay = overlay
        
        // Create the sheet
        let sheetWidth: CGFloat = 400
        let sheetHeight: CGFloat = 360
        let sheetX = (contentView.bounds.width - sheetWidth) / 2
        let sheetY = (contentView.bounds.height - sheetHeight) / 2
        
        let sheet = NewCollectionSheet(frame: NSRect(x: sheetX, y: sheetY, width: sheetWidth, height: sheetHeight))
        sheet.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        
        sheet.onCancel = { [weak self] in
            self?.dismissNewCollectionSheet()
        }
        
        sheet.onCreateCollection = { [weak self] name, icon in
            let collection = CollectionStore.shared.createCollection(name: name, icon: icon)
            ToastManager.shared.showSuccess(title: "Created collection: \(name)")
            
            self?.dismissNewCollectionSheet()
            
            // Select the new collection
            self?.collectionsSidebarSection.selectCollection(collection)
            self?.handleCollectionSelected(collection)
        }
        
        contentView.addSubview(sheet)
        newCollectionSheet = sheet
        
        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            overlay.animator().alphaValue = 1
        }
        sheet.animateAppear()
        
        // Click overlay to dismiss
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(overlayClicked))
        overlay.addGestureRecognizer(clickGesture)
    }
    
    @objc private func overlayClicked() {
        dismissNewCollectionSheet()
    }
    
    private func dismissNewCollectionSheet() {
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 0.2
            self?.newCollectionOverlay?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.newCollectionOverlay?.removeFromSuperview()
            self?.newCollectionSheet?.removeFromSuperview()
            self?.newCollectionOverlay = nil
            self?.newCollectionSheet = nil
        }
    }
    
    // MARK: - Smart Collection Dialog
    
    private func showSmartCollectionDialog(editing collection: Collection? = nil) {
        guard let window = window, let contentView = window.contentView else { return }
        
        // Create blur + dimming overlay that blocks clicks
        let overlay = ClickBlockingView(frame: contentView.bounds)
        overlay.wantsLayer = true
        overlay.autoresizingMask = [.width, .height]
        
        // Add visual effect view for blur
        let blurView = NSVisualEffectView(frame: overlay.bounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.blendingMode = .behindWindow
        blurView.material = .fullScreenUI
        blurView.state = .active
        blurView.alphaValue = 0.85
        overlay.addSubview(blurView)
        
        // Add dark tint on top of blur
        let tintView = NSView(frame: overlay.bounds)
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        tintView.autoresizingMask = [.width, .height]
        overlay.addSubview(tintView)
        
        overlay.alphaValue = 0
        contentView.addSubview(overlay)
        newCollectionOverlay = overlay
        
        // Create the smart collection sheet
        let sheet = SmartCollectionSheet(collection: collection)
        sheet.delegate = self
        
        // Present as child view controller for proper lifecycle
        let sheetView = sheet.view
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sheetView)
        
        NSLayoutConstraint.activate([
            sheetView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            sheetView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            sheetView.widthAnchor.constraint(equalToConstant: 640),
            sheetView.heightAnchor.constraint(equalToConstant: 500),
        ])
        
        smartCollectionSheet = sheet
        
        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            overlay.animator().alphaValue = 1
        }
        
        // Scale animation for the sheet
        sheetView.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1)
        sheetView.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            sheetView.animator().alphaValue = 1
            sheetView.layer?.transform = CATransform3DIdentity
        }
        
        // Click overlay to dismiss
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(smartCollectionOverlayClicked))
        overlay.addGestureRecognizer(clickGesture)
    }
    
    @objc private func smartCollectionOverlayClicked() {
        dismissSmartCollectionSheet()
    }
    
    private func dismissSmartCollectionSheet() {
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 0.2
            self?.newCollectionOverlay?.animator().alphaValue = 0
            self?.smartCollectionSheet?.view.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.newCollectionOverlay?.removeFromSuperview()
            self?.smartCollectionSheet?.view.removeFromSuperview()
            self?.newCollectionOverlay = nil
            self?.smartCollectionSheet = nil
        }
    }
    
    // MARK: - Stage Creation (delegated to StageCreationController)
    
    @objc private func createStageFromPNGAction(_ sender: NSButton) {
        stageCreationController.createStageFromPNG()
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
    
    private func initializeMetadataStore(at workingDir: URL) {
        do {
            try MetadataStore.shared.initialize(workingDir: workingDir)
            // Do initial reindex if database is empty or if we specifically want to ensure consistency
            // For now, we rely on the count check to avoid re-indexing on every launch
            if try MetadataStore.shared.characterCount() == 0 {
                print("Database empty. Performing initial content index...")
                try MetadataStore.shared.reindexAll(from: workingDir)
            }
        } catch {
            print("Failed to initialize MetadataStore: \(error)")
        }
    }
    
    private func setupBridge() {
        ikemenBridge = IkemenBridge.shared
        
        // Initialize metadata database
        if let workingDir = ikemenBridge.workingDirectory {
            initializeMetadataStore(at: workingDir)
        }
        
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
                self?.updateDashboardStats()
            }
            .store(in: &cancellables)
        
        ikemenBridge.$stages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stages in
                self?.stagesCountLabel?.stringValue = "\(stages.count)"
                self?.updateNavItemCount(.stages, count: stages.count)
                self?.updateDashboardStats()
            }
            .store(in: &cancellables)
        
        // Observe settings changes to update UI
        NotificationCenter.default.publisher(for: .settingsChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMainAreaContent()
            }
            .store(in: &cancellables)
        
        // Observe theme changes to update UI colors
        NotificationCenter.default.publisher(for: .themeChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }
    
    private func updateNavItemCount(_ item: NavItem, count: Int) {
        // In the new design, counts are shown in separate badge labels
        guard let badge = navLabels[item] else { return }
        badge.stringValue = "\(count)"
    }
    
    // MARK: - Theme Application
    
    /// Apply current theme colors to all UI elements
    private func applyTheme() {
        guard let window = window else { return }
        
        window.appearance = AppSettings.shared.useLightTheme ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        
        // Window background
        window.backgroundColor = DesignColors.background
        contentView?.layer?.backgroundColor = DesignColors.background.cgColor
        sidebarView?.layer?.backgroundColor = DesignColors.sidebarBackground.cgColor
        mainAreaView?.layer?.backgroundColor = DesignColors.background.cgColor

        if AppSettings.shared.useLightTheme {
            logoContainerView?.layer?.backgroundColor = DesignColors.zinc900.cgColor
            logoIconView?.contentTintColor = NSColor.white
        } else {
            logoContainerView?.layer?.backgroundColor = NSColor.white.cgColor
            logoIconView?.contentTintColor = DesignColors.background
        }
        
        vramTrackView?.layer?.backgroundColor = AppSettings.shared.useLightTheme ? DesignColors.zinc200.cgColor : DesignColors.cardBackground.cgColor
        vramFillView?.layer?.backgroundColor = AppSettings.shared.useLightTheme ? DesignColors.zinc400.cgColor : NSColor.white.withAlphaComponent(0.2).cgColor
        appNameLabelView?.textColor = DesignColors.textPrimary
        appSubLabelView?.textColor = DesignColors.textDisabled
        systemLabelView?.textColor = DesignColors.textDisabled
        vramLabelView?.textColor = DesignColors.textTertiary
        vramPercentLabel?.textColor = DesignColors.textTertiary
        
        // Update all nav buttons and labels
        let unselectedTextColor = AppSettings.shared.useLightTheme ? DesignColors.textTertiary : DesignColors.textSecondary
        
        for (item, button) in navButtons {
            let isSelected = selectedNavItem == item
            if let container = button.subviews.first(where: { $0.identifier?.rawValue == "navContainer" }) {
                container.layer?.backgroundColor = isSelected ? DesignColors.selectedBackground.cgColor : NSColor.clear.cgColor
                container.layer?.borderColor = isSelected ? DesignColors.borderSubtle.cgColor : NSColor.clear.cgColor
                applyNavSelectionShadow(to: container, isSelected: isSelected)
            }
            if let iconView = button.subviews.compactMap({ $0 as? NSImageView }).first {
                iconView.contentTintColor = isSelected ? DesignColors.textPrimary : unselectedTextColor
            }
            if let badgeContainer = button.viewWithIdentifier(NSUserInterfaceItemIdentifier("navBadgeContainer")) {
                badgeContainer.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
                badgeContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
            }
        }
        
        for (_, label) in navLabels {
            // Badge labels are small count indicators
            label.textColor = DesignColors.textTertiary
        }
        
        // Update sidebar borders - thin views are borders (check recursively)
        updateBorderColors(in: sidebarView)
        
        // Refresh the current view to rebuild with new colors
        if let selected = selectedNavItem {
            selectNavItem(selected)
        }
        
        // Force redraw
        window.contentView?.needsDisplay = true
    }
    
    private func updateBorderColors(in view: NSView?) {
        guard let view = view else { return }
        for subview in view.subviews {
            if subview.identifier?.rawValue == "sidebarBorder" {
                subview.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
            }
            updateBorderColors(in: subview)
        }
    }
    
    private func updateTextColorsRecursively(in view: NSView?) {
        guard let view = view else { return }
        for subview in view.subviews {
            if let textField = subview as? NSTextField {
                // Check if it's likely a primary/header text (white in dark, dark in light)
                let currentAlpha = textField.textColor?.alphaComponent ?? 1.0
                if currentAlpha < 0.5 {
                    // Disabled/placeholder
                    textField.textColor = DesignColors.textDisabled
                } else {
                    // Assume primary text for now; labels will be rebuilt anyway
                    textField.textColor = DesignColors.textPrimary
                }
            }
            updateTextColorsRecursively(in: subview)
        }
    }
    
    private func updateUI(for state: EngineState) {
        switch state {
        case .idle:
            updateLaunchButton(title: "Start IKEMEN GO", enabled: true, isRunning: false)
            statusLabel.stringValue = "Ready"
            statusLabel.textColor = DesignColors.positive
            
        case .launching:
            updateLaunchButton(title: "Starting...", enabled: false, isRunning: false)
            statusLabel.stringValue = "Starting..."
            statusLabel.textColor = DesignColors.warning
            
        case .running:
            updateLaunchButton(title: "Stop IKEMEN GO", enabled: true, isRunning: true)
            statusLabel.stringValue = "Running"
            statusLabel.textColor = DesignColors.positive
            
        case .terminated(let exitCode):
            updateLaunchButton(title: "Start IKEMEN GO", enabled: true, isRunning: false)
            statusLabel.stringValue = exitCode == 0 ? "Ready" : "Exited (\(exitCode))"
            statusLabel.textColor = exitCode == 0 ? DesignColors.positive : DesignColors.redAccent
            
        case .error(let error):
            updateLaunchButton(title: "Start IKEMEN GO", enabled: true, isRunning: false)
            statusLabel.stringValue = "Error"
            statusLabel.textColor = DesignColors.redAccent
            showError("Error", detail: error.localizedDescription)
        }
    }
    
    private func updateLaunchButton(title: String, enabled: Bool, isRunning: Bool = false) {
        // launchButton may be nil if not yet created or using new dashboard design
        guard let launchButton = launchButton else { return }
        
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
            launchButton.layer?.backgroundColor = DesignColors.redAccent.cgColor
        } else if enabled {
            launchButton.layer?.backgroundColor = DesignColors.positive.cgColor
        } else {
            launchButton.layer?.backgroundColor = DesignColors.textSecondary.cgColor
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
    
    // MARK: - Menu Actions
    
    /// Launch IKEMEN GO (Game menu, ⌘L)
    @objc func launchGame(_ sender: Any?) {
        launchIkemen()
    }
    
    /// Refresh library content (Game menu, ⌘R)
    @objc func refreshLibrary(_ sender: Any?) {
        updateDashboardStats()
        ToastManager.shared.showInfo(title: "Library Refreshed", subtitle: "Content statistics updated")
    }
    
    /// Install content from file/folder (File menu, ⌘I)
    @objc func installContent(_ sender: Any?) {
        installCoordinator.showInstallDialog()
    }
    
    /// Reveal IKEMEN GO folder in Finder (File menu)
    @objc func revealInFinder(_ sender: Any?) {
        guard let workingDir = ikemenBridge.workingDirectory else {
            showError("Not Configured", detail: "IKEMEN GO directory not set")
            return
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: workingDir.path)
    }
    
    /// Navigate to Dashboard (View menu, ⌘1)
    @objc func showDashboard(_ sender: Any?) {
        selectNavItem(.dashboard)
    }
    
    /// Navigate to Characters (View menu, ⌘2)
    @objc func showCharacters(_ sender: Any?) {
        selectNavItem(.characters)
    }
    
    /// Navigate to Stages (View menu, ⌘3)
    @objc func showStages(_ sender: Any?) {
        selectNavItem(.stages)
    }
    
    /// Navigate to Screenpacks (View menu, ⌘4)
    @objc func showScreenpacks(_ sender: Any?) {
        selectNavItem(.addons)
    }
    
    /// Navigate to Collections (View menu, ⌘5)
    @objc func showCollections(_ sender: Any?) {
        // Collections not in NavItem yet - for future use
        // For now, show a placeholder message
        ToastManager.shared.showInfo(title: "Coming Soon", subtitle: "Collections view will be available in a future update")
    }
    
    /// Open IKEMEN Lab Help (user's GitHub page)
    @objc func showHelp(_ sender: Any?) {
        if let url = URL(string: "https://github.com/arkany/IKEMEN-LAB") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Open IKEMEN GO Wiki
    @objc func openIkemenWiki(_ sender: Any?) {
        if let url = URL(string: "https://github.com/ikemen-engine/Ikemen-GO/wiki") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Report an issue on GitHub
    @objc func reportIssue(_ sender: Any?) {
        if let url = URL(string: "https://github.com/arkany/IKEMEN-LAB/issues/new") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Content Validation
    
    private func runContentValidation() {
        guard let workingDir = ikemenBridge.workingDirectory else {
            showError("Validation Failed", detail: "IKEMEN GO directory not configured")
            return
        }
        
        // Run validation in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let validator = ContentValidator.shared
            
            let stageResults = validator.validateAllStages(in: workingDir)
            let charResults = validator.validateAllCharacters(in: workingDir)
            let placementResults = validator.validateContentPlacement(in: workingDir)
            
            DispatchQueue.main.async {
                self?.showValidationResults(stages: stageResults, characters: charResults, placement: placementResults)
            }
        }
    }
    
    private func showValidationResults(stages: [ContentValidator.ValidationResult], characters: [ContentValidator.ValidationResult], placement: [ContentValidator.ValidationResult] = []) {
        let allResults = stages + characters + placement
        
        // Update dashboard health status
        dashboardView?.updateHealthStatus(results: allResults)
        
        let errorCount = allResults.reduce(0) { $0 + $1.errorCount }
        let warningCount = allResults.reduce(0) { $0 + $1.warningCount }
        
        if errorCount == 0 && warningCount == 0 {
            // Show success toast (health card already updated)
            ToastManager.shared.showSuccess(title: "All content validated successfully!")
            return
        }
        
        // For now, just show toast - the dashboard card shows the count
        // User can click "Fix All" on the dashboard if there are fixable issues
        let fixableCount = allResults.reduce(0) { total, result in
            total + result.issues.filter { $0.isFixable }.count
        }
        
        var message = "Found \(errorCount) error(s), \(warningCount) warning(s)"
        if fixableCount > 0 {
            message += ". \(fixableCount) can be auto-fixed."
        }
        
        if errorCount > 0 {
            ToastManager.shared.showError(title: "Validation Issues Found", subtitle: message)
        } else {
            ToastManager.shared.showInfo(title: "Validation Complete", subtitle: message)
        }
    }
    
    // MARK: - Game Control (Legacy API compatibility)
    
    func loadGame(at url: URL) {
        if url.pathExtension.lowercased() == "zip" {
            installCoordinator.handleDroppedFiles([url])
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

// MARK: - SmartCollectionSheetDelegate

extension GameWindowController: SmartCollectionSheetDelegate {
    
    func smartCollectionSheet(_ sheet: SmartCollectionSheet, didCreateCollectionNamed name: String, rules: [FilterRule], ruleOperator: RuleOperator) {
        // Create smart collection
        var collection = CollectionStore.shared.createCollection(name: name, icon: "wand.and.stars")
        collection.isSmartCollection = true
        collection.smartRules = rules
        collection.smartRuleOperator = ruleOperator
        collection.includeCharacters = true
        collection.includeStages = true
        
        CollectionStore.shared.update(collection)
        
        ToastManager.shared.showSuccess(title: "Created smart collection: \(name)")
        
        dismissSmartCollectionSheet()
        
        // Select the new collection
        collectionsSidebarSection.selectCollection(collection)
        handleCollectionSelected(collection)
    }
    
    func smartCollectionSheet(_ sheet: SmartCollectionSheet, didUpdateCollection id: UUID, name: String, rules: [FilterRule], ruleOperator: RuleOperator) {
        guard var collection = CollectionStore.shared.collection(withId: id) else { return }
        
        collection.name = name
        collection.smartRules = rules
        collection.smartRuleOperator = ruleOperator
        
        CollectionStore.shared.update(collection)
        
        ToastManager.shared.showSuccess(title: "Updated smart collection: \(name)")
        
        dismissSmartCollectionSheet()
    }
    
    func smartCollectionSheetDidCancel(_ sheet: SmartCollectionSheet) {
        dismissSmartCollectionSheet()
    }
}

// MARK: - NSWindowDelegate

extension GameWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        stopEmulation()
    }
}
