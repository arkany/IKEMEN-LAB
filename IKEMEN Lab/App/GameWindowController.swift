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
    case collections = "Collections"
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
        case .collections: return "folder.fill"
        case .duplicates: return "doc.on.doc"
        case .soundpacks: return "music.note"
        case .settings: return "gearshape"
        }
    }
    
    /// Whether this item should show a count badge
    var showsCount: Bool {
        switch self {
        case .characters, .stages, .collections: return true
        default: return false
        }
    }
    
    /// Whether this item is hidden from the sidebar
    var isHidden: Bool {
        switch self {
        case .soundpacks: return true
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
        case .collections: return "collections"
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
    private let sidebarWidth: CGFloat = 256  // w-64 from HTML
    private let sidebarPadding: CGFloat = 12 // p-3 from HTML
    
    // UI Elements - Sidebar
    private var contentView: NSView!
    private var sidebarView: NSView!
    private var mainAreaView: NSView!
    private var launchButton: NSButton!
    private var statusLabel: NSTextField!
    private var charactersCountLabel: NSTextField!
    private var stagesCountLabel: NSTextField!
    
    // VRAM monitoring
    private var vramFillView: NSView!
    private var vramPercentLabel: NSTextField!
    private var vramFillWidthConstraint: NSLayoutConstraint!
    private var navButtons: [NavItem: NSButton] = [:]
    private var navLabels: [NavItem: NSTextField] = [:]  // For updating counts
    private var selectedNavItem: NavItem? = nil
    
    // UI Elements - Main Area
    private var contentHeaderView: ContentHeaderView!
    private var dashboardView: DashboardView!
    private var dropZoneView: DropZoneView!
    private var characterBrowserView: CharacterBrowserView!
    private var characterDetailsView: CharacterDetailsView!
    private var characterDetailsWidthConstraint: NSLayoutConstraint!
    private var stageBrowserView: StageBrowserView!
    private var screenpackBrowserView: ScreenpackBrowserView!
    private var collectionsBrowserView: CollectionsBrowserView!
    private var duplicatesView: DuplicatesView!
    private var createStageButton: NSButton!
    
    // Search state
    private var currentSearchQuery: String = ""
    
    // View mode state
    private var currentViewMode: BrowserViewMode = .grid
    
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
        
        window.title = "IKEMEN Lab"
        window.center()
        window.backgroundColor = DesignColors.background
        window.minSize = NSSize(width: 900, height: 600)
        window.delegate = self
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
        
        // Initialize toast notifications with main area as parent
        ToastManager.shared.setParentView(mainAreaView)
        
        // Select dashboard by default (after all views are initialized)
        selectNavItem(.dashboard)
        
        // Show FRE if needed (after short delay to let window appear)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showFirstRunExperienceIfNeeded()
        }
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
        
        freView.onComplete = { [weak self] selectedPath in
            self?.handleFREComplete(with: selectedPath)
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
    
    private func handleFREComplete(with path: URL) {
        let settings = AppSettings.shared
        settings.ikemenGOPath = path
        settings.hasCompletedFRE = true
        
        // Update the bridge to use the new path
        ikemenBridge.setWorkingDirectory(path)
        
        // Refresh content
        ikemenBridge.loadContent()
        
        // Restore main UI
        restoreMainUIAfterFRE()
        
        // Show success toast
        ToastManager.shared.showSuccess(title: "IKEMEN GO linked successfully!")
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
        sidebarView.layer?.backgroundColor = DesignColors.background.cgColor
        contentView.addSubview(sidebarView)
        
        // === Right Border ===
        let rightBorder = NSView()
        rightBorder.translatesAutoresizingMaskIntoConstraints = false
        rightBorder.wantsLayer = true
        rightBorder.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        sidebarView.addSubview(rightBorder)
        
        // === Logo/Header Area ===
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        sidebarView.addSubview(headerView)
        
        // Bottom border for header
        let headerBorder = NSView()
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBorder.wantsLayer = true
        headerBorder.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        headerView.addSubview(headerBorder)
        
        // Logo icon (white box with icon)
        let logoContainer = NSView()
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.wantsLayer = true
        logoContainer.layer?.backgroundColor = NSColor.white.cgColor
        logoContainer.layer?.cornerRadius = 6
        headerView.addSubview(logoContainer)
        
        let logoIcon = NSImageView()
        logoIcon.translatesAutoresizingMaskIntoConstraints = false
        logoIcon.image = NSImage(systemSymbolName: "flask.fill", accessibilityDescription: nil)
        logoIcon.contentTintColor = DesignColors.background
        logoIcon.symbolConfiguration = .init(pointSize: 12, weight: .bold)
        logoContainer.addSubview(logoIcon)
        
        // App name
        let appNameLabel = NSTextField(labelWithString: "IKEMEN")
        appNameLabel.translatesAutoresizingMaskIntoConstraints = false
        appNameLabel.font = DesignFonts.body(size: 14)
        appNameLabel.textColor = DesignColors.textPrimary
        headerView.addSubview(appNameLabel)
        
        let appSubLabel = NSTextField(labelWithString: "Lab")
        appSubLabel.translatesAutoresizingMaskIntoConstraints = false
        appSubLabel.font = DesignFonts.label(size: 14)
        appSubLabel.textColor = DesignColors.textDisabled
        headerView.addSubview(appSubLabel)
        
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
        
        // === Bottom Section ===
        let bottomStack = NSStackView()
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.orientation = .vertical
        bottomStack.spacing = 12
        bottomStack.alignment = .leading
        sidebarView.addSubview(bottomStack)
        
        // System info section
        let systemLabel = NSTextField(labelWithString: "SYSTEM")
        systemLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        systemLabel.textColor = DesignColors.textDisabled
        let kerning: [NSAttributedString.Key: Any] = [.kern: 2.0]
        systemLabel.attributedStringValue = NSAttributedString(string: "SYSTEM", attributes: kerning)
        bottomStack.addArrangedSubview(systemLabel)
        
        // VRAM progress bar
        let vramContainer = NSView()
        vramContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.addArrangedSubview(vramContainer)
        
        let vramTrack = NSView()
        vramTrack.translatesAutoresizingMaskIntoConstraints = false
        vramTrack.wantsLayer = true
        vramTrack.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        vramTrack.layer?.cornerRadius = 3
        vramContainer.addSubview(vramTrack)
        
        vramFillView = NSView()
        vramFillView.translatesAutoresizingMaskIntoConstraints = false
        vramFillView.wantsLayer = true
        vramFillView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
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
            headerView.topAnchor.constraint(equalTo: sidebarView.topAnchor),
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
            
            // Bottom stack
            bottomStack.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: sidebarPadding),
            bottomStack.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -sidebarPadding),
            bottomStack.bottomAnchor.constraint(equalTo: sidebarView.bottomAnchor, constant: -sidebarPadding),
            
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
        
        // Start VRAM monitoring
        updateVRAMUsage()
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
            badgeContainer.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
            badgeContainer.layer?.cornerRadius = 4
            badgeContainer.layer?.borderWidth = 1
            badgeContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
            badgeContainer.setContentHuggingPriority(.required, for: .horizontal)
            
            let badge = NSTextField(labelWithString: "0")
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            badge.textColor = DesignColors.textDisabled
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
        
        guard let container = button.subviews.first(where: { $0.identifier?.rawValue == "navContainer" }) else { return }
        
        if isSelected {
            container.layer?.backgroundColor = DesignColors.selectedBackground.cgColor
            container.layer?.borderWidth = 1
            container.layer?.borderColor = DesignColors.borderSubtle.cgColor
        } else if isHovered {
            container.layer?.backgroundColor = DesignColors.hoverBackground.cgColor
            container.layer?.borderWidth = 0
        } else {
            container.layer?.backgroundColor = NSColor.clear.cgColor
            container.layer?.borderWidth = 0
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
        
        // Update button appearances using new styling
        for (navItem, button) in navButtons {
            let isSelected = navItem == item
            
            guard let container = button.subviews.first(where: { $0.identifier?.rawValue == "navContainer" }) else { continue }
            
            // Apply selected/default background
            if isSelected {
                container.layer?.backgroundColor = DesignColors.selectedBackground.cgColor
                container.layer?.borderWidth = 1
                container.layer?.borderColor = DesignColors.borderSubtle.cgColor
            } else {
                container.layer?.backgroundColor = NSColor.clear.cgColor
                container.layer?.borderWidth = 0
            }
            
            // Update icon and label colors
            if let stack = container.subviews.compactMap({ $0 as? NSStackView }).first {
                for view in stack.arrangedSubviews {
                    if let iconView = view as? NSImageView, iconView.identifier?.rawValue == "navIcon" {
                        iconView.contentTintColor = isSelected ? DesignColors.textPrimary : DesignColors.textSecondary
                    }
                    if let label = view as? NSTextField, label.identifier?.rawValue == "navLabel" {
                        label.textColor = isSelected ? DesignColors.textPrimary : DesignColors.textSecondary
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
        mainAreaView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor // bg-black/20 from HTML
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
        mainAreaView.addSubview(contentHeaderView)
        
        // Dashboard View
        dashboardView = DashboardView(frame: .zero)
        dashboardView.translatesAutoresizingMaskIntoConstraints = false
        dashboardView.isHidden = true
        dashboardView.onLaunchGame = { [weak self] in
            self?.launchIkemen()
        }
        dashboardView.onFilesDropped = { [weak self] urls in
            self?.handleDroppedFiles(urls)
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
        mainAreaView.addSubview(dashboardView)
        
        // Drop Zone (visible in empty state - legacy, kept for other views)
        dropZoneView = DropZoneView(frame: .zero)
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.onFilesDropped = { [weak self] urls in
            self?.handleDroppedFiles(urls)
        }
        // Apply new design styling
        dropZoneView.applyFigmaStyle(borderColor: DesignColors.borderDashed, textColor: DesignColors.textTertiary, font: DesignFonts.body(size: 14))
        mainAreaView.addSubview(dropZoneView)
        
        // Create Stage from PNG button (hidden by default, shown when on stages tab)
        createStageButton = NSButton(title: "Create from PNG", target: self, action: #selector(createStageFromPNG(_:)))
        createStageButton.translatesAutoresizingMaskIntoConstraints = false
        createStageButton.bezelStyle = .rounded
        createStageButton.isHidden = true
        createStageButton.toolTip = "Create a new stage from a PNG image"
        mainAreaView.addSubview(createStageButton)
        
        // Character Browser (hidden initially)
        characterBrowserView = CharacterBrowserView(frame: .zero)
        characterBrowserView.translatesAutoresizingMaskIntoConstraints = false
        characterBrowserView.isHidden = true
        characterBrowserView.onCharacterSelected = { [weak self] character in
            self?.statusLabel.stringValue = character.displayName
            self?.showCharacterDetails(character)
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
            guard let workingDir = bridge.workingDirectory else { return }
            
            // Sync characters to this screenpack's select.def before activating
            // defFile is system.def, so its parent directory contains select.def
            let screenpackDir = screenpack.defFile.deletingLastPathComponent()
            let selectDefPath = screenpackDir.appendingPathComponent("select.def")
            if FileManager.default.fileExists(atPath: selectDefPath.path) {
                ContentManager.shared.syncCharactersToScreenpack(selectDefPath: selectDefPath, workingDir: workingDir)
            }
            
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
        
        // Collections Browser (hidden initially)
        collectionsBrowserView = CollectionsBrowserView(frame: .zero)
        collectionsBrowserView.translatesAutoresizingMaskIntoConstraints = false
        collectionsBrowserView.isHidden = true
        collectionsBrowserView.onCollectionSelected = { [weak self] collection in
            // TODO: Show collection details view
            self?.statusLabel.stringValue = "Collection: \(collection.name)"
        }
        collectionsBrowserView.onCreateCollection = { [weak self] in
            self?.showCreateCollectionDialog()
        }
        mainAreaView.addSubview(collectionsBrowserView)
        
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
            
            // Collections browser fills main area (below header)
            collectionsBrowserView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
            collectionsBrowserView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            collectionsBrowserView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            collectionsBrowserView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
        ])
    }
    
    private func handleViewModeChanged(_ mode: ViewModeToggle.Mode) {
        currentViewMode = mode == .grid ? .grid : .list
        characterBrowserView.viewMode = currentViewMode
        screenpackBrowserView.viewMode = currentViewMode
        // Note: stageBrowserView is always list view, doesn't support grid/list toggle
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
        case .collections:
            contentHeaderView?.setCurrentPage("Collections")
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
            collectionsBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
            updateDashboardStats()
        case .characters:
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = false
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            collectionsBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
            characterBrowserView?.viewMode = currentViewMode
        case .stages:
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = false
            screenpackBrowserView?.isHidden = true
            collectionsBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
        case .soundpacks:
            // TODO: Implement soundpacks browser
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = false
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            collectionsBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
        case .addons:
            // Screenpacks browser (add-ons tab)
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = false
            collectionsBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
            screenpackBrowserView?.viewMode = currentViewMode
        case .collections:
            // Collections browser
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            collectionsBrowserView?.isHidden = false
            duplicatesView?.isHidden = true
            collectionsBrowserView?.refresh()
        case .duplicates:
            // Duplicates view
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            collectionsBrowserView?.isHidden = true
            duplicatesView?.isHidden = false
            duplicatesView?.refresh()
        case .settings:
            // Show settings panel
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = true
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            collectionsBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
            showSettingsContent()
        case nil:
            // Empty state - show drop zone
            dashboardView?.isHidden = true
            dropZoneView?.isHidden = false
            characterBrowserView?.isHidden = true
            stageBrowserView?.isHidden = true
            screenpackBrowserView?.isHidden = true
            collectionsBrowserView?.isHidden = true
            duplicatesView?.isHidden = true
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
                do {
                    let results = try MetadataStore.shared.searchCharacters(query: query)
                    let matchingPaths = Set(results.map { $0.folderPath })
                    
                    // Filter to matching ones (use directory.path to match against MetadataStore's folderPath)
                    let filtered = allCharacters.filter { char in
                        matchingPaths.contains(char.directory.path) ||
                        char.displayName.localizedCaseInsensitiveContains(query) ||
                        char.author.localizedCaseInsensitiveContains(query)
                    }
                    characterBrowserView?.setCharacters(filtered)
                } catch {
                    // Fallback to simple filtering
                    let filtered = allCharacters.filter {
                        $0.displayName.localizedCaseInsensitiveContains(query) ||
                        $0.author.localizedCaseInsensitiveContains(query)
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
        guard let content = try? String(contentsOf: character.defFile, encoding: .utf8) else {
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
    
    // MARK: - Collection Management
    
    private func showCreateCollectionDialog() {
        let alert = NSAlert()
        alert.messageText = "Create Collection"
        alert.informativeText = "Enter details for the new collection:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        // Create a container for input fields
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        
        // Collection name field
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.frame = NSRect(x: 0, y: 36, width: 70, height: 20)
        container.addSubview(nameLabel)
        
        let nameInput = NSTextField(frame: NSRect(x: 75, y: 34, width: 225, height: 24))
        nameInput.placeholderString = "e.g., Marvel, SNK Bosses"
        container.addSubview(nameInput)
        
        // Description field
        let descLabel = NSTextField(labelWithString: "Description:")
        descLabel.frame = NSRect(x: 0, y: 4, width: 70, height: 20)
        container.addSubview(descLabel)
        
        let descInput = NSTextField(frame: NSRect(x: 75, y: 2, width: 225, height: 24))
        descInput.placeholderString = "Optional"
        container.addSubview(descInput)
        
        alert.accessoryView = container
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            
            let name = nameInput.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                self?.showAlert(title: "Invalid Name", message: "Please enter a collection name.")
                return
            }
            
            let description = descInput.stringValue.trimmingCharacters(in: .whitespaces)
            
            do {
                _ = try MetadataStore.shared.createCollection(name: name, description: description)
                ToastManager.shared.showSuccess(
                    title: "Collection created",
                    subtitle: "\(name) is ready for content."
                )
                self?.collectionsBrowserView?.refresh()
                self?.updateCollectionsCount()
            } catch {
                self?.showAlert(title: "Failed to Create Collection", message: error.localizedDescription)
            }
        }
    }
    
    private func updateCollectionsCount() {
        do {
            let count = try MetadataStore.shared.allCollections().count
            updateNavItemCount(.collections, count: count)
        } catch {
            print("Failed to update collections count: \(error)")
        }
    }
    
    // MARK: - Character Finder
    
    private func revealCharacterInFinder(_ character: CharacterInfo) {
        NSWorkspace.shared.activateFileViewerSelecting([character.path])
    }
    
    // MARK: - Character Removal
    
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
        
        let settingsView = createSettingsView()
        settingsView.identifier = NSUserInterfaceItemIdentifier("settingsView")
        mainAreaView.addSubview(settingsView)
        
        NSLayoutConstraint.activate([
            settingsView.topAnchor.constraint(equalTo: mainAreaView.topAnchor, constant: 24),
            settingsView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
            settingsView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
            settingsView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
        ])
    }
    
    private func createSettingsView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        container.addSubview(scrollView)
        
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 32
        stackView.alignment = .leading
        contentView.addSubview(stackView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = DesignFonts.header(size: 32)
        titleLabel.textColor = DesignColors.textPrimary
        stackView.addArrangedSubview(titleLabel)
        
        // Video Settings Section
        let videoSection = createSettingsSection(title: "Video", settings: [
            createResolutionSetting(),
            createToggleSetting(label: "Fullscreen", key: "Fullscreen", section: "Video"),
            createToggleSetting(label: "VSync", key: "VSync", section: "Video"),
            createToggleSetting(label: "Borderless", key: "Borderless", section: "Video"),
        ])
        stackView.addArrangedSubview(videoSection)
        
        // Audio Settings Section
        let audioSection = createSettingsSection(title: "Audio", settings: [
            createVolumeSetting(label: "Master Volume", key: "MasterVolume"),
            createVolumeSetting(label: "Music Volume", key: "BGMVolume"),
            createVolumeSetting(label: "Sound Effects", key: "WavVolume"),
        ])
        stackView.addArrangedSubview(audioSection)
        
        // Advanced Features Section
        let advancedSection = createSettingsSection(title: "Advanced", settings: [
            createAppToggleSetting(
                label: "EXPERIMENTAL: Create Stage from PNG",
                description: "Enable creating stages from PNG images (experimental feature)",
                getValue: { AppSettings.shared.enablePNGStageCreation },
                setValue: { AppSettings.shared.enablePNGStageCreation = $0 }
            ),
        ])
        stackView.addArrangedSubview(advancedSection)
        
        // Maintenance Section
        let maintenanceSection = createSettingsSection(title: "Maintenance", settings: [
            createButtonSetting(
                label: "Image Cache",
                buttonTitle: "Clear Cache",
                description: "Clears cached character portraits and stage previews. Use if images appear outdated.",
                action: #selector(clearImageCache(_:))
            ),
        ])
        stackView.addArrangedSubview(maintenanceSection)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
        
        return container
    }
    
    private func createSettingsSection(title: String, settings: [NSView]) -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.spacing = 16
        section.alignment = .leading
        
        let sectionTitle = NSTextField(labelWithString: title)
        sectionTitle.font = DesignFonts.header(size: 20)
        sectionTitle.textColor = DesignColors.textSecondary
        section.addArrangedSubview(sectionTitle)
        
        for setting in settings {
            section.addArrangedSubview(setting)
        }
        
        return section
    }
    
    private func createResolutionSetting() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let label = NSTextField(labelWithString: "Resolution")
        label.font = DesignFonts.body(size: 16)
        label.textColor = DesignColors.textPrimary
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(label)
        
        let popup = NSPopUpButton()
        popup.addItems(withTitles: [
            "640×480 (4:3 SD)",
            "1280×720 (720p HD)",
            "1920×1080 (1080p Full HD)",
            "2560×1440 (1440p QHD)",
        ])
        popup.tag = 1000
        popup.target = self
        popup.action = #selector(resolutionChanged(_:))
        
        // Load current value
        if let config = loadIkemenConfig(),
           let width = config["Video"]?["GameWidth"],
           let height = config["Video"]?["GameHeight"] {
            let resString = "\(width)×\(height)"
            for (index, title) in popup.itemTitles.enumerated() {
                if title.hasPrefix(resString) {
                    popup.selectItem(at: index)
                    break
                }
            }
        }
        
        row.addArrangedSubview(popup)
        return row
    }
    
    private func createToggleSetting(label: String, key: String, section: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 16)
        labelField.textColor = DesignColors.textPrimary
        labelField.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(labelField)
        
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(toggleSettingChanged(_:))
        toggle.identifier = NSUserInterfaceItemIdentifier("\(section).\(key)")
        
        // Load current value
        if let config = loadIkemenConfig(),
           let value = config[section]?[key] {
            toggle.state = value == "1" ? .on : .off
        }
        
        row.addArrangedSubview(toggle)
        return row
    }
    
    private func createVolumeSetting(label: String, key: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 16)
        labelField.textColor = DesignColors.textPrimary
        labelField.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(labelField)
        
        let slider = NSSlider()
        slider.minValue = 0
        slider.maxValue = 100
        slider.intValue = 100
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        slider.target = self
        slider.action = #selector(volumeSliderChanged(_:))
        slider.identifier = NSUserInterfaceItemIdentifier("Sound.\(key)")
        
        // Load current value
        if let config = loadIkemenConfig(),
           let value = config["Sound"]?[key],
           let intValue = Int(value) {
            slider.intValue = Int32(intValue)
        }
        
        let valueLabel = NSTextField(labelWithString: "\(slider.intValue)%")
        valueLabel.font = DesignFonts.body(size: 14)
        valueLabel.textColor = DesignColors.textSecondary
        valueLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        valueLabel.identifier = NSUserInterfaceItemIdentifier("Sound.\(key).label")
        
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }
    
    /// Create a toggle setting backed by AppSettings (not Ikemen config)
    private func createAppToggleSetting(label: String, description: String, getValue: @escaping () -> Bool, setValue: @escaping (Bool) -> Void) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 4
        container.alignment = .leading
        
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 16)
        labelField.textColor = DesignColors.textPrimary
        labelField.widthAnchor.constraint(equalToConstant: 200).isActive = true
        row.addArrangedSubview(labelField)
        
        let toggle = NSSwitch()
        toggle.state = getValue() ? .on : .off
        
        // Create a wrapper to handle the toggle action
        let handler = AppToggleHandler(getValue: getValue, setValue: setValue)
        toggle.target = handler
        toggle.action = #selector(AppToggleHandler.toggleChanged(_:))
        objc_setAssociatedObject(toggle, &AppToggleHandler.associatedKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        row.addArrangedSubview(toggle)
        container.addArrangedSubview(row)
        
        // Add description label
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = DesignColors.textSecondary
        container.addArrangedSubview(descLabel)
        
        return container
    }
    
    /// Create a button setting with label and description
    private func createButtonSetting(label: String, buttonTitle: String, description: String, action: Selector) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 4
        container.alignment = .leading
        
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 16)
        labelField.textColor = DesignColors.textPrimary
        labelField.widthAnchor.constraint(equalToConstant: 200).isActive = true
        row.addArrangedSubview(labelField)
        
        let button = NSButton(title: buttonTitle, target: self, action: action)
        button.bezelStyle = .rounded
        row.addArrangedSubview(button)
        
        container.addArrangedSubview(row)
        
        // Add description label
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = DesignColors.textSecondary
        container.addArrangedSubview(descLabel)
        
        return container
    }
    
    // MARK: - Settings Actions
    
    @objc private func resolutionChanged(_ sender: NSPopUpButton) {
        let resolutions = [(640, 480), (1280, 720), (1920, 1080), (2560, 1440)]
        let selected = resolutions[sender.indexOfSelectedItem]
        saveIkemenConfigValue(section: "Video", key: "GameWidth", value: "\(selected.0)")
        saveIkemenConfigValue(section: "Video", key: "GameHeight", value: "\(selected.1)")
    }
    
    @objc private func toggleSettingChanged(_ sender: NSSwitch) {
        guard let id = sender.identifier?.rawValue else { return }
        let parts = id.split(separator: ".")
        guard parts.count == 2 else { return }
        let section = String(parts[0])
        let key = String(parts[1])
        saveIkemenConfigValue(section: section, key: key, value: sender.state == .on ? "1" : "0")
    }
    
    @objc private func volumeSliderChanged(_ sender: NSSlider) {
        guard let id = sender.identifier?.rawValue else { return }
        let parts = id.split(separator: ".")
        guard parts.count == 2 else { return }
        let section = String(parts[0])
        let key = String(parts[1])
        
        // Update label
        let labelId = NSUserInterfaceItemIdentifier("\(section).\(key).label")
        if let label = mainAreaView.viewWithIdentifier(labelId) as? NSTextField {
            label.stringValue = "\(sender.intValue)%"
        }
        
        saveIkemenConfigValue(section: section, key: key, value: "\(sender.intValue)")
    }
    
    @objc private func clearImageCache(_ sender: NSButton) {
        ImageCache.shared.clear()
        
        // Show confirmation
        let alert = NSAlert()
        alert.messageText = "Cache Cleared"
        alert.informativeText = "The image cache has been cleared. Character portraits and stage previews will be reloaded."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        // Refresh the current view to reload images
        NotificationCenter.default.post(name: NSNotification.Name("ImageCacheCleared"), object: nil)
    }
    
    // MARK: - Stage Creation
    
    @objc private func createStageFromPNG(_ sender: NSButton) {
        // Check if feature is enabled
        guard AppSettings.shared.enablePNGStageCreation else {
            showAlert(title: "Feature Disabled", message: "PNG stage creation is disabled. Enable it in Settings → Advanced.")
            return
        }
        
        // Open file picker for PNG
        let openPanel = NSOpenPanel()
        openPanel.title = "Select a PNG Image"
        openPanel.message = "Choose a PNG image to use as a stage background"
        openPanel.allowedContentTypes = [.png]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            self?.showStageCreationDialog(forImage: url)
        }
    }
    
    private func showStageCreationDialog(forImage imageURL: URL) {
        // Get the stage name and author from the user
        let alert = NSAlert()
        alert.messageText = "Create Stage"
        alert.informativeText = "Enter details for the new stage:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        // Create a container for multiple fields
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        
        // Stage name field
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.frame = NSRect(x: 0, y: 36, width: 50, height: 20)
        container.addSubview(nameLabel)
        
        let nameInput = NSTextField(frame: NSRect(x: 55, y: 34, width: 245, height: 24))
        nameInput.stringValue = imageURL.deletingPathExtension().lastPathComponent
        nameInput.placeholderString = "Stage Name"
        container.addSubview(nameInput)
        
        // Author field
        let authorLabel = NSTextField(labelWithString: "Author:")
        authorLabel.frame = NSRect(x: 0, y: 4, width: 50, height: 20)
        container.addSubview(authorLabel)
        
        let authorInput = NSTextField(frame: NSRect(x: 55, y: 2, width: 245, height: 24))
        authorInput.stringValue = NSFullUserName()
        authorInput.placeholderString = "Your Name"
        container.addSubview(authorInput)
        
        alert.accessoryView = container
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            
            let stageName = nameInput.stringValue.trimmingCharacters(in: .whitespaces)
            guard !stageName.isEmpty else {
                self?.showAlert(title: "Invalid Name", message: "Please enter a stage name.")
                return
            }
            
            let author = authorInput.stringValue.trimmingCharacters(in: .whitespaces)
            self?.createStage(from: imageURL, name: stageName, author: author.isEmpty ? "Unknown" : author)
        }
    }
    
    private func createStage(from imageURL: URL, name: String, author: String = "MacMugen") {
        // Find the stages directory
        guard let workingDir = ikemenBridge.workingDirectory else {
            showAlert(title: "Error", message: "Ikemen GO directory not found.")
            return
        }
        
        let stagesDir = workingDir.appendingPathComponent("stages")
        
        // Create the stage with default options
        var options = StageGenerator.StageOptions.withDefaults(name: name)
        options.author = author
        
        let result = StageGenerator.generate(from: imageURL, in: stagesDir, options: options)
        
        switch result {
        case .success(let generated):
            // Register stage in select.def so it appears in Ikemen GO
            let dataDir = workingDir.appendingPathComponent("data")
            let relativePath = generated.stageDirectory.lastPathComponent + "/" + generated.defFile.lastPathComponent
            StageGenerator.registerStageInSelectDef(stagePath: relativePath, dataDirectory: dataDir)
            
            // Refresh stages list
            ikemenBridge.refreshStages()
            stageBrowserView.refresh()
            
            // Show success message
            showAlert(title: "Stage Created", message: "Successfully created stage '\(generated.stageName)' at:\n\(generated.stageDirectory.path)")
            statusLabel.stringValue = "Created stage: \(generated.stageName)"
            
        case .failure(let error):
            showAlert(title: "Stage Creation Failed", message: error.localizedDescription)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window!, completionHandler: nil)
    }
    
    // MARK: - Config File Helpers
    
    private var ikemenConfigPath: URL {
        URL(fileURLWithPath: "/Users/davidphillips/Sites/macmame/Ikemen-GO/save/config.ini")
    }
    
    private func loadIkemenConfig() -> [String: [String: String]]? {
        guard FileManager.default.fileExists(atPath: ikemenConfigPath.path) else { return nil }
        
        do {
            let content = try String(contentsOf: ikemenConfigPath, encoding: .utf8)
            var config: [String: [String: String]] = [:]
            var currentSection = ""
            
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix(";") { continue }
                
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    currentSection = String(trimmed.dropFirst().dropLast())
                    if config[currentSection] == nil {
                        config[currentSection] = [:]
                    }
                    continue
                }
                
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let key = trimmed[..<equalsIndex].trimmingCharacters(in: .whitespaces)
                    let value = trimmed[trimmed.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
                    config[currentSection]?[key] = value
                }
            }
            return config
        } catch {
            print("Error loading config: \(error)")
            return nil
        }
    }
    
    private func saveIkemenConfigValue(section: String, key: String, value: String) {
        guard FileManager.default.fileExists(atPath: ikemenConfigPath.path) else { return }
        
        do {
            var content = try String(contentsOf: ikemenConfigPath, encoding: .utf8)
            var lines = content.components(separatedBy: "\n")
            var inSection = false
            
            for i in 0..<lines.count {
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    let sectionName = String(trimmed.dropFirst().dropLast())
                    inSection = (sectionName == section)
                    continue
                }
                
                if inSection && trimmed.hasPrefix(key) {
                    if let equalsIndex = trimmed.firstIndex(of: "=") {
                        let keyPart = trimmed[..<equalsIndex].trimmingCharacters(in: .whitespaces)
                        if keyPart == key {
                            let leadingWhitespace = String(lines[i].prefix(while: { $0 == " " || $0 == "\t" }))
                            lines[i] = "\(leadingWhitespace)\(key) = \(value)"
                            break
                        }
                    }
                }
            }
            
            content = lines.joined(separator: "\n")
            try content.write(to: ikemenConfigPath, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving config: \(error)")
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
        
        // Initialize metadata database
        if let workingDir = ikemenBridge.workingDirectory {
            do {
                try MetadataStore.shared.initialize(workingDir: workingDir)
                // Do initial reindex if database is empty
                if try MetadataStore.shared.characterCount() == 0 {
                    try MetadataStore.shared.reindexAll(from: workingDir)
                }
                
                // Initialize collections count
                updateCollectionsCount()
            } catch {
                print("Failed to initialize MetadataStore: \(error)")
            }
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
    }
    
    private func updateNavItemCount(_ item: NavItem, count: Int) {
        // In the new design, counts are shown in separate badge labels
        guard let badge = navLabels[item] else { return }
        badge.stringValue = "\(count)"
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
            statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
            
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
        
        let fileName = url.deletingPathExtension().lastPathComponent
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try self?.ikemenBridge.installContent(from: url)
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = result ?? "Installed!"
                    self?.statusLabel.textColor = DesignColors.positive
                    
                    // Show success toast
                    let contentName = result?.replacingOccurrences(of: "Installed ", with: "").replacingOccurrences(of: "!", with: "") ?? fileName
                    ToastManager.shared.showSuccess(
                        title: "Successfully installed!",
                        subtitle: "\(contentName) has been added to your library."
                    )
                    
                    // Refresh dashboard stats
                    self?.dashboardView.refreshStats()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = "Failed"
                    self?.statusLabel.textColor = DesignColors.redAccent
                    
                    // Show error toast
                    ToastManager.shared.showError(
                        title: "Installation failed",
                        subtitle: error.localizedDescription
                    )
                }
            }
        }
    }
    
    private func installFromFolder(_ url: URL) {
        statusLabel.stringValue = "Installing..."
        statusLabel.textColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        
        let folderName = url.lastPathComponent
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try self?.ikemenBridge.installContentFolder(from: url)
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = result ?? "Installed!"
                    self?.statusLabel.textColor = DesignColors.positive
                    
                    // Show success toast
                    let contentName = result?.replacingOccurrences(of: "Installed ", with: "").replacingOccurrences(of: "!", with: "") ?? folderName
                    ToastManager.shared.showSuccess(
                        title: "Successfully installed!",
                        subtitle: "\(contentName) has been added to your library."
                    )
                    
                    // Refresh dashboard stats
                    self?.dashboardView.refreshStats()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.statusLabel.stringValue = "Failed"
                    self?.statusLabel.textColor = DesignColors.redAccent
                    
                    // Show error toast
                    ToastManager.shared.showError(
                        title: "Installation failed",
                        subtitle: error.localizedDescription
                    )
                }
            }
        }
    }
    
    // MARK: - VRAM Monitoring
    
    private func updateVRAMUsage() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            vramPercentLabel.stringValue = "N/A"
            return
        }
        
        // Get recommended working set size (available VRAM for this process)
        let recommendedWorkingSet = device.recommendedMaxWorkingSetSize
        // Get current allocated memory
        let currentAllocated = device.currentAllocatedSize
        
        // Calculate percentage
        let percentage: Double
        if recommendedWorkingSet > 0 {
            percentage = Double(currentAllocated) / Double(recommendedWorkingSet) * 100.0
        } else {
            percentage = 0
        }
        
        // Update UI
        let percentText = String(format: "%.0f%%", min(percentage, 100))
        vramPercentLabel.stringValue = percentText
        
        // Update fill bar width
        if let superview = vramFillView.superview {
            let trackWidth = superview.bounds.width
            let fillWidth = trackWidth * CGFloat(min(percentage, 100)) / 100.0
            vramFillWidthConstraint.constant = fillWidth
        }
        
        // Color based on usage
        if percentage > 90 {
            vramFillView.layer?.backgroundColor = DesignColors.redAccent.cgColor
        } else if percentage > 70 {
            vramFillView.layer?.backgroundColor = NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1.0).cgColor
        } else {
            vramFillView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        }
        
        // Schedule next update (every 2 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updateVRAMUsage()
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

// MARK: - Nav Button with Hover Support

class NavButton: NSButton {
    
    var isHovered = false {
        didSet {
            if isHovered != oldValue {
                onHoverChanged?(isHovered)
            }
        }
    }
    
    var onHoverChanged: ((Bool) -> Void)?
    
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func drawFocusRingMask() {
        bounds.fill()
    }
    
    override var focusRingMaskBounds: NSRect {
        return bounds
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
        
        // Main label - Montserrat header style
        label = NSTextField(labelWithString: "Drop characters or\nstages here")
        label.font = DesignFonts.header(size: 20)
        label.textColor = creamColor
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        // Subline label - body style
        sublineLabel = NSTextField(labelWithString: "(.zip, .rar, .7z or folder)")
        sublineLabel.font = DesignFonts.body(size: 14)
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
        label.font = DesignFonts.header(size: 20)
        sublineLabel.textColor = creamColor
        sublineLabel.font = DesignFonts.body(size: 14)
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

// MARK: - NSView Extension

extension NSView {
    func viewWithIdentifier(_ identifier: NSUserInterfaceItemIdentifier) -> NSView? {
        if self.identifier == identifier { return self }
        for subview in subviews {
            if let found = subview.viewWithIdentifier(identifier) {
                return found
            }
        }
        return nil
    }
}

// MARK: - App Toggle Handler

/// Helper class to handle app settings toggle callbacks with closures
private class AppToggleHandler: NSObject {
    static var associatedKey: UInt8 = 0
    
    let getValue: () -> Bool
    let setValue: (Bool) -> Void
    
    init(getValue: @escaping () -> Bool, setValue: @escaping (Bool) -> Void) {
        self.getValue = getValue
        self.setValue = setValue
    }
    
    @objc func toggleChanged(_ sender: NSSwitch) {
        setValue(sender.state == .on)
    }
}
