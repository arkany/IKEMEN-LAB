import Cocoa

fileprivate enum ThemeTextRole: String {
    case primary
    case secondary
    case tertiary
}

fileprivate enum ThemeBackgroundRole: String {
    case card
    case cardTransparent
    case panel
    case zinc900
    case zinc800
    case borderSubtle
    case featureCard
    case featureCardIcon
    case buttonSecondary
}

fileprivate enum ThemeBorderRole: String {
    case subtle
    case hover
}

fileprivate var themeLabelRoleKey: UInt8 = 0
fileprivate var themeBackgroundRoleKey: UInt8 = 0
fileprivate var themeBorderRoleKey: UInt8 = 0

fileprivate func themeTextColor(for role: ThemeTextRole) -> NSColor {
    switch role {
    case .primary:
        return DesignColors.textPrimary
    case .secondary:
        return DesignColors.textSecondary
    case .tertiary:
        return DesignColors.textTertiary
    }
}

fileprivate func themeBackgroundColor(for role: ThemeBackgroundRole) -> NSColor {
    switch role {
    case .card:
        return DesignColors.cardBackground
    case .cardTransparent:
        return DesignColors.cardBackgroundTransparent
    case .panel:
        return DesignColors.panelBackground
    case .zinc900:
        return DesignColors.zinc900
    case .zinc800:
        return DesignColors.zinc800
    case .borderSubtle:
        return DesignColors.borderSubtle
    case .featureCard:
        return DesignColors.panelBackground
    case .featureCardIcon:
        return DesignColors.inputBackground
    case .buttonSecondary:
        return DesignColors.buttonSecondaryBackground
    }
}

fileprivate func themeBorderColor(for role: ThemeBorderRole) -> NSColor {
    switch role {
    case .subtle:
        return DesignColors.borderSubtle
    case .hover:
        return DesignColors.borderHover
    }
}

fileprivate func tagThemeLabel(_ label: NSTextField, role: ThemeTextRole) {
    objc_setAssociatedObject(label, &themeLabelRoleKey, role.rawValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    label.textColor = themeTextColor(for: role)
}

fileprivate func tagThemeBackground(_ view: NSView, role: ThemeBackgroundRole) {
    objc_setAssociatedObject(view, &themeBackgroundRoleKey, role.rawValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    view.wantsLayer = true
    view.layer?.backgroundColor = themeBackgroundColor(for: role).cgColor
}

fileprivate func tagThemeBorder(_ view: NSView, role: ThemeBorderRole) {
    objc_setAssociatedObject(view, &themeBorderRoleKey, role.rawValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    view.wantsLayer = true
    view.layer?.borderColor = themeBorderColor(for: role).cgColor
}

fileprivate func refreshThemeLabels(in view: NSView) {
    if let label = view as? NSTextField,
       let rawRole = objc_getAssociatedObject(label, &themeLabelRoleKey) as? String,
       let role = ThemeTextRole(rawValue: rawRole) {
        label.textColor = themeTextColor(for: role)
    }
    
    for subview in view.subviews {
        refreshThemeLabels(in: subview)
    }
}

fileprivate func refreshThemeLayers(in view: NSView) {
    if let rawRole = objc_getAssociatedObject(view, &themeBackgroundRoleKey) as? String,
       let role = ThemeBackgroundRole(rawValue: rawRole) {
        view.layer?.backgroundColor = themeBackgroundColor(for: role).cgColor
    }
    
    if let rawRole = objc_getAssociatedObject(view, &themeBorderRoleKey) as? String,
       let role = ThemeBorderRole(rawValue: rawRole) {
        view.layer?.borderColor = themeBorderColor(for: role).cgColor
    }
    
    for subview in view.subviews {
        refreshThemeLayers(in: subview)
    }
}

fileprivate protocol ThemeApplicable: AnyObject {
    func applyTheme()
}

/// A flipped NSView that draws content from top-left instead of bottom-left
/// Used for scroll view document views to align content to top
private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Dashboard view - the main landing page with stats, quick actions, and recent activity
class DashboardView: NSView {
    
    // MARK: - Callbacks
    var onLaunchGame: (() -> Void)?
    var onFilesDropped: (([URL]) -> Void)?
    var onRefreshStats: (() -> Void)?
    var onNavigateToCharacters: (() -> Void)?
    var onNavigateToStages: (() -> Void)?
    var onValidateContent: (() -> Void)?
    var onInstallContent: (() -> Void)?
    
    // MARK: - UI Elements
    private var scrollView: NSScrollView!
    private var contentStack: NSStackView!
    
    // Stats cards
    private var fightersCountLabel: NSTextField!
    private var stagesCountLabel: NSTextField!
    private var storageLabel: NSTextField!
    private var lastPlayedLabel: NSTextField!
    private var launchIconView: NSImageView!
    private var launchIconContainer: NSView!
    private var launchTitleLabel: NSTextField!
    
    // Drop zone
    private var dropZoneView: DashboardDropZone!
    
    // Quick settings
    private var vsyncToggle: NSSwitch!
    private var fullscreenToggle: NSSwitch!
    private var volumeSlider: NSSlider!
    private var volumeLabel: NSTextField!
    
    // Recently Installed
    private var recentlyInstalledStack: NSStackView!
    private var recentInstalls: [RecentInstall] = []
    
    // Content Health
    private var healthStatusLabel: NSTextField!
    private var healthBadge: NSView!
    private var healthBadgeLabel: NSTextField!
    private var fixAllButton: NSButton!
    private var healthDetailStack: NSStackView!
    private var healthDetailContainer: NSView!
    private var healthCardBottomConstraint: NSLayoutConstraint!
    private var healthDetailHeightConstraint: NSLayoutConstraint!
    private var isHealthDetailExpanded = false
    private var themeObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Scroll view for dashboard content
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        
        // Content view - flipped so content starts at top
        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        
        // Main stack
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .leading
        documentView.addSubview(contentStack)
        
        // Build sections
        setupHeader()
        setupStatsCards()
        setupTwoColumnLayout()
        setupObservers()
        updateLaunchCardUI() // Initial state
        applyTheme()
        
        // Layout
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -32),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -64),
            
            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: .contentChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        
        NotificationCenter.default.addObserver(forName: .gameStatusChanged, object: nil, queue: .main) { [weak self] _ in
            self?.updateLaunchCardUI()
        }
        
        themeObserver = NotificationCenter.default.addObserver(forName: .themeChanged, object: nil, queue: .main) { [weak self] _ in
            self?.applyTheme()
        }
    }
    
    private func updateLaunchCardUI() {
        let isRunning: Bool
        if case .running = IkemenBridge.shared.engineState {
            isRunning = true
        } else {
            isRunning = false
        }
        
        if isRunning {
            launchTitleLabel.stringValue = "Stop Game"
            launchIconView.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: nil)
            lastPlayedLabel.stringValue = "Game is running"
            lastPlayedLabel.textColor = DesignColors.positive
        } else {
            launchTitleLabel.stringValue = "Launch Game"
            launchIconView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
            lastPlayedLabel.stringValue = "Ready to play"
            lastPlayedLabel.textColor = DesignColors.textTertiary
        }
    }
    
    private func applyTheme() {
        refreshThemeLabels(in: self)
        refreshThemeLayers(in: self)
        applyThemeToSubviews(in: self)
        
        launchIconContainer?.layer?.backgroundColor = DesignColors.borderStrong.cgColor
        launchIconContainer?.layer?.borderColor = DesignColors.borderSubtle.cgColor
        launchIconContainer?.layer?.shadowColor = DesignColors.borderStrong.cgColor
        launchIconView?.contentTintColor = DesignColors.textPrimary
        
        if healthStatusLabel.textColor != DesignColors.positive &&
           healthStatusLabel.textColor != DesignColors.negative &&
           healthStatusLabel.textColor != DesignColors.warning {
            healthStatusLabel.textColor = themeTextColor(for: .tertiary)
        }
        
        updateLaunchCardUI()
    }
    
    private func applyThemeToSubviews(in view: NSView) {
        for subview in view.subviews {
            if let themedView = subview as? ThemeApplicable {
                themedView.applyTheme()
            }
            applyThemeToSubviews(in: subview)
        }
    }
    
    // MARK: - Header
    
    private func setupHeader() {
        let headerStack = NSStackView()
        headerStack.orientation = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .leading
        
        let titleLabel = NSTextField(labelWithString: "Dashboard")
        titleLabel.font = DesignFonts.header(size: 28)
        tagThemeLabel(titleLabel, role: .primary)
        headerStack.addArrangedSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Manage your local IKEMEN GO assets and configuration")
        subtitleLabel.font = DesignFonts.body(size: 14)
        tagThemeLabel(subtitleLabel, role: .secondary)
        headerStack.addArrangedSubview(subtitleLabel)
        
        contentStack.addArrangedSubview(headerStack)
    }
    
    // MARK: - Stats Cards
    
    private func setupStatsCards() {
        let cardsContainer = NSStackView()
        cardsContainer.orientation = .horizontal
        cardsContainer.spacing = 16
        cardsContainer.distribution = .fillEqually
        cardsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Fighters card - clickable to navigate to Characters
        let (fCard, fightersLabel) = createStatCard(
            icon: "person.2.fill",
            title: "Active Fighters",
            value: "0"
        )
        fightersCountLabel = fightersLabel
        fCard.onClick = { [weak self] in
            self?.onNavigateToCharacters?()
        }
        cardsContainer.addArrangedSubview(fCard)
        
        // Stages card - clickable to navigate to Stages
        let (sCard, stagesLabel) = createStatCard(
            icon: "photo.fill",
            title: "Installed Stages",
            value: "0"
        )
        stagesCountLabel = stagesLabel
        sCard.onClick = { [weak self] in
            self?.onNavigateToStages?()
        }
        cardsContainer.addArrangedSubview(sCard)
        
        // Storage card (display only)
        let (storageCard, storageValueLabel) = createStatCard(
            icon: "externaldrive.fill",
            title: "Storage Used",
            value: "—"
        )
        storageLabel = storageValueLabel
        cardsContainer.addArrangedSubview(storageCard)
        
        // Launch card (special - has button)
        let launchCard = createLaunchCard()
        cardsContainer.addArrangedSubview(launchCard)
        
        contentStack.addArrangedSubview(cardsContainer)
        
        // Make cards container fill the width of the content stack
        NSLayoutConstraint.activate([
            cardsContainer.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            cardsContainer.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])
    }
    
    private func createStatCard(icon: String, title: String, value: String) -> (HoverableStatCard, NSTextField) {
        let card = HoverableStatCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        card.addSubview(stack)
        
        // Icon container - w-8 h-8 rounded bg-zinc-900 border border-white/5
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        tagThemeBackground(iconContainer, role: .card)
        iconContainer.layer?.cornerRadius = 4  // rounded (not rounded-lg)
        iconContainer.layer?.borderWidth = 1
        tagThemeBorder(iconContainer, role: .subtle)
        iconContainer.identifier = NSUserInterfaceItemIdentifier("iconContainer")
        stack.addArrangedSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textSecondary  // zinc-400, changes to white on hover
        iconView.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        iconView.identifier = NSUserInterfaceItemIdentifier("iconView")
        iconContainer.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 32),  // w-8
            iconContainer.heightAnchor.constraint(equalToConstant: 32), // h-8
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
        ])
        
        // Spacer to push value down (mb-4 = margin-bottom 16px on icon row)
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 12).isActive = true
        stack.addArrangedSubview(spacer)
        
        // Value - text-2xl (24px) font-montserrat font-semibold tracking-wider
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = DesignFonts.header(size: 24)
        tagThemeLabel(valueLabel, role: .primary)
        stack.addArrangedSubview(valueLabel)
        
        // Title - text-xs (12px) text-zinc-500
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignFonts.caption(size: 12)
        tagThemeLabel(titleLabel, role: .tertiary)
        stack.addArrangedSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),  // p-5
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20),
        ])
        
        return (card, valueLabel)
    }
    
    private func createLaunchCard() -> NSView {
        // Launch card matches CSS: glass-panel with special white icon and hover effect
        let card = HoverableLaunchCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        card.addSubview(stack)
        
        // Icon container - w-8 h-8 rounded with glow
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = DesignColors.borderStrong.cgColor
        iconContainer.layer?.cornerRadius = 4
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        iconContainer.layer?.shadowColor = DesignColors.borderStrong.cgColor
        iconContainer.layer?.shadowOpacity = 0.15
        iconContainer.layer?.shadowRadius = 15
        iconContainer.layer?.shadowOffset = .zero
        stack.addArrangedSubview(iconContainer)
        self.launchIconContainer = iconContainer
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textPrimary
        iconView.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        iconContainer.addSubview(iconView)
        self.launchIconView = iconView
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 32),
            iconContainer.heightAnchor.constraint(equalToConstant: 32),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
        ])
        
        // Spacer (mt-6 in HTML)
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stack.addArrangedSubview(spacer)
        
        // Title - text-lg font-medium tracking-tight
        let titleLabel = NSTextField(labelWithString: "Launch Game")
        titleLabel.font = DesignFonts.body(size: 16)
        tagThemeLabel(titleLabel, role: .primary)
        stack.addArrangedSubview(titleLabel)
        self.launchTitleLabel = titleLabel
        
        // Last played - text-xs text-zinc-500
        lastPlayedLabel = NSTextField(labelWithString: "Ready to play")
        lastPlayedLabel.font = DesignFonts.caption(size: 12)
        tagThemeLabel(lastPlayedLabel, role: .tertiary)
        stack.addArrangedSubview(lastPlayedLabel)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20),
        ])
        
        // Add click callback to entire card
        card.onClick = { [weak self] in
            print("[DashboardView] Launch card onClick triggered")
            self?.launchButtonClicked()
        }
        
        return card
    }
    
    // MARK: - Two Column Layout
    
    private var leftColumn: NSStackView!
    private var rightColumn: NSStackView!
    
    private func setupTwoColumnLayout() {
        // Create horizontal container for two columns
        let columnsContainer = NSStackView()
        columnsContainer.translatesAutoresizingMaskIntoConstraints = false
        columnsContainer.orientation = .horizontal
        columnsContainer.spacing = 24
        columnsContainer.alignment = .top
        columnsContainer.distribution = .fill
        
        // Left column (2/3 width) - Drop zone, Recently Installed
        leftColumn = NSStackView()
        leftColumn.translatesAutoresizingMaskIntoConstraints = false
        leftColumn.orientation = .vertical
        leftColumn.spacing = 24
        leftColumn.alignment = .leading
        columnsContainer.addArrangedSubview(leftColumn)
        
        // Right column (1/3 width) - Quick Settings, Content Health
        rightColumn = NSStackView()
        rightColumn.translatesAutoresizingMaskIntoConstraints = false
        rightColumn.orientation = .vertical
        rightColumn.spacing = 24
        rightColumn.alignment = .leading
        columnsContainer.addArrangedSubview(rightColumn)
        
        // Set width proportions
        leftColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leftColumn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rightColumn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        rightColumn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Right column preferred width ~280px, but can compress
        let rightWidthConstraint = rightColumn.widthAnchor.constraint(equalToConstant: 280)
        rightWidthConstraint.priority = .defaultHigh
        rightWidthConstraint.isActive = true
        
        // Minimum width for right column
        rightColumn.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        
        contentStack.addArrangedSubview(columnsContainer)
        
        // Make columns container fill width
        columnsContainer.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        columnsContainer.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
        
        // Build left column content
        setupDropZone()
        setupRecentlyInstalled()
        
        // Build right column content
        setupBrowserExtensionCard()
        setupQuickSettings()
        setupTools()
        
        // Add flexible spacer to absorb extra vertical space
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        rightColumn.addArrangedSubview(spacer)
    }
    
    // MARK: - Drop Zone
    
    private func setupDropZone() {
        let sectionLabel = NSTextField(labelWithString: "INSTALL CONTENT")
        sectionLabel.font = DesignFonts.caption(size: 11)
        tagThemeLabel(sectionLabel, role: .tertiary)
        leftColumn.addArrangedSubview(sectionLabel)
        
        dropZoneView = DashboardDropZone(frame: .zero)
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.onFilesDropped = { [weak self] urls in
            self?.onFilesDropped?(urls)
        }
        dropZoneView.onClick = { [weak self] in
            self?.onInstallContent?()
        }
        
        NSLayoutConstraint.activate([
            dropZoneView.heightAnchor.constraint(equalToConstant: 170),
        ])
        
        leftColumn.addArrangedSubview(dropZoneView)
        
        // Make drop zone fill width of left column
        dropZoneView.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor).isActive = true
        dropZoneView.trailingAnchor.constraint(equalTo: leftColumn.trailingAnchor).isActive = true
    }
    
    // MARK: - Recently Installed
    
    private func setupRecentlyInstalled() {
        let sectionLabel = NSTextField(labelWithString: "RECENTLY INSTALLED")
        sectionLabel.font = DesignFonts.caption(size: 11)
        tagThemeLabel(sectionLabel, role: .tertiary)
        leftColumn.addArrangedSubview(sectionLabel)
        
        // Container card - transparent background (zinc-900/20)
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        tagThemeBackground(card, role: .cardTransparent)
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        tagThemeBorder(card, role: .subtle)
        
        // Table header row
        let headerRow = createRecentlyInstalledHeader()
        card.addSubview(headerRow)
        
        // Stack for rows
        recentlyInstalledStack = NSStackView()
        recentlyInstalledStack.translatesAutoresizingMaskIntoConstraints = false
        recentlyInstalledStack.orientation = .vertical
        recentlyInstalledStack.spacing = 0
        recentlyInstalledStack.alignment = .leading
        card.addSubview(recentlyInstalledStack)
        
        // Empty state label (shown when no recent installs)
        let emptyLabel = NSTextField(labelWithString: "No recent installations")
        emptyLabel.font = DesignFonts.body(size: 13)
        tagThemeLabel(emptyLabel, role: .tertiary)
        emptyLabel.alignment = .center
        emptyLabel.identifier = NSUserInterfaceItemIdentifier("emptyLabel")
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: card.topAnchor),
            headerRow.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            headerRow.heightAnchor.constraint(equalToConstant: 40),
            
            recentlyInstalledStack.topAnchor.constraint(equalTo: headerRow.bottomAnchor),
            recentlyInstalledStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            recentlyInstalledStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            recentlyInstalledStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 20),
        ])
        
        leftColumn.addArrangedSubview(card)
        
        // Card fills width of left column with min height for 10 rows
        card.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor).isActive = true
        card.trailingAnchor.constraint(equalTo: leftColumn.trailingAnchor).isActive = true
        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
    }
    
    private func createRecentlyInstalledHeader() -> NSView {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.wantsLayer = true
        
        // Bottom border
        let border = NSView()
        border.translatesAutoresizingMaskIntoConstraints = false
        border.wantsLayer = true
        tagThemeBackground(border, role: .borderSubtle)
        header.addSubview(border)
        
        // Column headers - matching HTML: Name | Type | Date | Status
        let nameHeader = createColumnHeader("Name")
        let typeHeader = createColumnHeader("Type")
        let dateHeader = createColumnHeader("Date")
        let statusHeader = createColumnHeader("Status")
        
        header.addSubview(nameHeader)
        header.addSubview(typeHeader)
        header.addSubview(dateHeader)
        header.addSubview(statusHeader)
        
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
            
            // Name column (left)
            nameHeader.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            nameHeader.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            // Status column - align left edge with toggle (toggle is ~38px, at trailing -16, so leading ~-54)
            statusHeader.leadingAnchor.constraint(equalTo: header.trailingAnchor, constant: -54),
            statusHeader.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            // Date column - positioned to the left of status, aligned with date text
            dateHeader.leadingAnchor.constraint(equalTo: statusHeader.leadingAnchor, constant: -110),
            dateHeader.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            // Type column - positioned to the left of date, aligned with type badge
            typeHeader.leadingAnchor.constraint(equalTo: dateHeader.leadingAnchor, constant: -100),
            typeHeader.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        
        return header
    }
    
    private func createColumnHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        tagThemeLabel(label, role: .tertiary)
        return label
    }
    
    private func createRecentInstallRow(_ install: RecentInstall, isLast: Bool) -> RecentInstallRow {
        let row = RecentInstallRow(install: install, showBorder: !isLast)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.onClick = { [weak self] in
            // Navigate to the item
            if install.type == "character" {
                self?.onNavigateToCharacters?()
            } else {
                self?.onNavigateToStages?()
            }
        }
        return row
    }
    
    /// Refresh all dashboard data
    func refresh() {
        refreshRecentlyInstalled()
        refreshStats()
    }
    
    /// Refresh recently installed data from database
    func refreshRecentlyInstalled() {
        do {
            recentInstalls = try MetadataStore.shared.recentlyInstalled(limit: 10)
            updateRecentlyInstalledUI()
        } catch {
            print("Failed to load recent installs: \(error)")
        }
    }
    
    private func updateRecentlyInstalledUI() {
        // Remove existing rows
        recentlyInstalledStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Find empty label in card
        let card = recentlyInstalledStack.superview
        let emptyLabel = card?.subviews.first { $0.identifier?.rawValue == "emptyLabel" }
        
        if recentInstalls.isEmpty {
            emptyLabel?.isHidden = false
        } else {
            emptyLabel?.isHidden = true
            
            for (index, install) in recentInstalls.enumerated() {
                let isLast = index == recentInstalls.count - 1
                let row = createRecentInstallRow(install, isLast: isLast)
                recentlyInstalledStack.addArrangedSubview(row)
                
                // Make row fill width
                row.leadingAnchor.constraint(equalTo: recentlyInstalledStack.leadingAnchor).isActive = true
                row.trailingAnchor.constraint(equalTo: recentlyInstalledStack.trailingAnchor).isActive = true
                row.heightAnchor.constraint(equalToConstant: 72).isActive = true
            }
        }
    }
    
    // MARK: - Quick Settings
    
    private func setupQuickSettings() {
        let sectionLabel = NSTextField(labelWithString: "QUICK SETTINGS")
        sectionLabel.font = DesignFonts.caption(size: 11)
        tagThemeLabel(sectionLabel, role: .tertiary)
        rightColumn.addArrangedSubview(sectionLabel)
        
        let settingsCard = NSView()
        settingsCard.translatesAutoresizingMaskIntoConstraints = false
        settingsCard.wantsLayer = true
        tagThemeBackground(settingsCard, role: .cardTransparent)
        settingsCard.layer?.cornerRadius = 12
        settingsCard.layer?.borderWidth = 1
        tagThemeBorder(settingsCard, role: .subtle)
        
        let settingsStack = NSStackView()
        settingsStack.translatesAutoresizingMaskIntoConstraints = false
        settingsStack.orientation = .vertical
        settingsStack.spacing = 16
        settingsCard.addSubview(settingsStack)
        
        // V-Sync toggle
        let vsyncRow = createSettingRow(label: "V-Sync", type: .toggle)
        vsyncToggle = vsyncRow.1 as? NSSwitch
        settingsStack.addArrangedSubview(vsyncRow.0)
        
        // Fullscreen toggle
        let fullscreenRow = createSettingRow(label: "Fullscreen", type: .toggle)
        fullscreenToggle = fullscreenRow.1 as? NSSwitch
        settingsStack.addArrangedSubview(fullscreenRow.0)
        
        // Volume slider
        let volumeRow = createVolumeRow()
        settingsStack.addArrangedSubview(volumeRow)
        
        NSLayoutConstraint.activate([
            settingsStack.topAnchor.constraint(equalTo: settingsCard.topAnchor, constant: 16),
            settingsStack.leadingAnchor.constraint(equalTo: settingsCard.leadingAnchor, constant: 16),
            settingsStack.trailingAnchor.constraint(equalTo: settingsCard.trailingAnchor, constant: -16),
            settingsStack.bottomAnchor.constraint(equalTo: settingsCard.bottomAnchor, constant: -16),
        ])
        
        rightColumn.addArrangedSubview(settingsCard)
        
        // Make settings card fill width of right column
        settingsCard.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor).isActive = true
        settingsCard.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor).isActive = true
        
        // Load current settings
        loadSettings()
    }
    
    private enum SettingType {
        case toggle
    }
    
    private func createSettingRow(label: String, type: SettingType) -> (NSView, NSControl) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 14)
        tagThemeLabel(labelField, role: .primary)
        row.addArrangedSubview(labelField)
        
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(settingToggled(_:))
        row.addArrangedSubview(toggle)
        
        return (row, toggle)
    }
    
    private func createVolumeRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: "Master Volume")
        labelField.font = DesignFonts.body(size: 14)
        tagThemeLabel(labelField, role: .primary)
        row.addArrangedSubview(labelField)
        
        volumeSlider = NSSlider()
        volumeSlider.minValue = 0
        volumeSlider.maxValue = 100
        volumeSlider.intValue = 100
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged(_:))
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(volumeSlider)
        
        volumeLabel = NSTextField(labelWithString: "100%")
        volumeLabel.font = DesignFonts.caption(size: 12)
        tagThemeLabel(volumeLabel, role: .secondary)
        volumeLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
        row.addArrangedSubview(volumeLabel)
        
        return row
    }
    
    // MARK: - Actions
    
    @objc private func launchButtonClicked() {
        if case .running = IkemenBridge.shared.engineState {
            IkemenBridge.shared.terminateEngine()
        } else {
            onLaunchGame?()
        }
    }
    
    @objc private func settingToggled(_ sender: NSSwitch) {
        saveSettings()
    }
    
    @objc private func volumeChanged(_ sender: NSSlider) {
        volumeLabel.stringValue = "\(sender.intValue)%"
        saveSettings()
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        // Load from Ikemen config
        guard let configPath = getIkemenConfigPath(),
              let config = parseIniFile(at: configPath) else { return }
        
        if let vsync = config["Video"]?["VSync"] {
            vsyncToggle?.state = vsync == "1" ? .on : .off
        }
        if let fullscreen = config["Video"]?["Fullscreen"] {
            fullscreenToggle?.state = fullscreen == "1" ? .on : .off
        }
        if let volume = config["Sound"]?["MasterVolume"], let intVal = Int(volume) {
            volumeSlider?.intValue = Int32(intVal)
            volumeLabel?.stringValue = "\(intVal)%"
        }
    }
    
    private func saveSettings() {
        guard let configPath = getIkemenConfigPath() else { return }
        guard var config = parseIniFile(at: configPath) else { return }
        
        // Update values
        if config["Video"] == nil { config["Video"] = [:] }
        if config["Sound"] == nil { config["Sound"] = [:] }
        
        config["Video"]?["VSync"] = vsyncToggle?.state == .on ? "1" : "0"
        config["Video"]?["Fullscreen"] = fullscreenToggle?.state == .on ? "1" : "0"
        config["Sound"]?["MasterVolume"] = "\(volumeSlider?.intValue ?? 100)"
        
        writeIniFile(config, to: configPath)
    }
    
    private func getIkemenConfigPath() -> String? {
        // Hardcoded for now - should use EmulatorBridge.shared.workingDirectory in production
        let configPath = "/Users/davidphillips/Sites/macmame/Ikemen-GO/save/config.ini"
        return FileManager.default.fileExists(atPath: configPath) ? configPath : nil
    }
    
    private func parseIniFile(at path: String) -> [String: [String: String]]? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        
        var result: [String: [String: String]] = [:]
        var currentSection = ""
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                if result[currentSection] == nil {
                    result[currentSection] = [:]
                }
            } else if trimmed.contains("=") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    result[currentSection]?[key] = value
                }
            }
        }
        return result
    }
    
    private func writeIniFile(_ config: [String: [String: String]], to path: String) {
        var content = ""
        for (section, values) in config.sorted(by: { $0.key < $1.key }) {
            content += "[\(section)]\n"
            for (key, value) in values.sorted(by: { $0.key < $1.key }) {
                content += "\(key) = \(value)\n"
            }
            content += "\n"
        }
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Tools Section
    
    private func setupTools() {
        let sectionLabel = NSTextField(labelWithString: "CONTENT HEALTH")
        sectionLabel.font = DesignFonts.caption(size: 11)
        tagThemeLabel(sectionLabel, role: .tertiary)
        rightColumn.addArrangedSubview(sectionLabel)
        
        let healthCard = NSView()
        healthCard.translatesAutoresizingMaskIntoConstraints = false
        healthCard.wantsLayer = true
        tagThemeBackground(healthCard, role: .cardTransparent)
        healthCard.layer?.cornerRadius = 12
        healthCard.layer?.borderWidth = 1
        tagThemeBorder(healthCard, role: .subtle)
        
        // Vertical container for header + details
        let cardStack = NSStackView()
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardStack.orientation = .vertical
        cardStack.spacing = 0
        healthCard.addSubview(cardStack)
        
        // Header row (icon, status, buttons)
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Main horizontal stack for header
        let mainStack = NSStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.orientation = .horizontal
        mainStack.spacing = 16
        mainStack.alignment = .centerY
        headerView.addSubview(mainStack)
        
        // Left side: Icon with badge
        let iconWrapper = NSView()
        iconWrapper.translatesAutoresizingMaskIntoConstraints = false
        
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        tagThemeBackground(iconContainer, role: .card)
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.borderWidth = 1
        tagThemeBorder(iconContainer, role: .subtle)
        iconWrapper.addSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "checkmark.shield.fill", accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textSecondary
        iconView.symbolConfiguration = .init(pointSize: 18, weight: .medium)
        iconContainer.addSubview(iconView)
        
        // Error badge (hidden by default)
        healthBadge = NSView()
        healthBadge.translatesAutoresizingMaskIntoConstraints = false
        healthBadge.wantsLayer = true
        healthBadge.layer?.backgroundColor = DesignColors.negative.cgColor
        healthBadge.layer?.cornerRadius = 10
        healthBadge.isHidden = true
        iconWrapper.addSubview(healthBadge)
        
        healthBadgeLabel = NSTextField(labelWithString: "0")
        healthBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        healthBadgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        healthBadgeLabel.textColor = .white
        healthBadgeLabel.alignment = .center
        healthBadge.addSubview(healthBadgeLabel)
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            iconContainer.leadingAnchor.constraint(equalTo: iconWrapper.leadingAnchor),
            iconContainer.topAnchor.constraint(equalTo: iconWrapper.topAnchor),
            iconContainer.bottomAnchor.constraint(equalTo: iconWrapper.bottomAnchor),
            
            healthBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            healthBadge.heightAnchor.constraint(equalToConstant: 20),
            healthBadge.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 6),
            healthBadge.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: -6),
            healthBadge.trailingAnchor.constraint(equalTo: iconWrapper.trailingAnchor),
            
            healthBadgeLabel.centerXAnchor.constraint(equalTo: healthBadge.centerXAnchor),
            healthBadgeLabel.centerYAnchor.constraint(equalTo: healthBadge.centerYAnchor),
            healthBadgeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: healthBadge.leadingAnchor, constant: 4),
            healthBadgeLabel.trailingAnchor.constraint(lessThanOrEqualTo: healthBadge.trailingAnchor, constant: -4),
        ])
        
        mainStack.addArrangedSubview(iconWrapper)
        
        // Center: Status text (clickable to expand)
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        
        let titleLabel = NSTextField(labelWithString: "Content Validator")
        titleLabel.font = DesignFonts.body(size: 14)
        tagThemeLabel(titleLabel, role: .primary)
        textStack.addArrangedSubview(titleLabel)
        
        healthStatusLabel = NSTextField(labelWithString: "Click 'Scan' to check for issues")
        healthStatusLabel.font = DesignFonts.caption(size: 12)
        healthStatusLabel.textColor = themeTextColor(for: .tertiary)
        textStack.addArrangedSubview(healthStatusLabel)
        
        mainStack.addArrangedSubview(textStack)
        
        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mainStack.addArrangedSubview(spacer)
        
        // Right side: Buttons
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        
        // Fix All button (hidden by default)
        fixAllButton = NSButton(title: "Fix All", target: self, action: #selector(fixAllClicked))
        fixAllButton.bezelStyle = .rounded
        fixAllButton.isHidden = true
        buttonStack.addArrangedSubview(fixAllButton)
        
        // Scan button
        let scanButton = NSButton(title: "Scan", target: self, action: #selector(validateContentClicked))
        scanButton.bezelStyle = .rounded
        scanButton.keyEquivalent = ""
        buttonStack.addArrangedSubview(scanButton)
        
        mainStack.addArrangedSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
        ])
        
        cardStack.addArrangedSubview(headerView)
        
        // Details section (expandable)
        healthDetailContainer = NSView()
        healthDetailContainer.translatesAutoresizingMaskIntoConstraints = false
        healthDetailContainer.wantsLayer = true
        tagThemeBackground(healthDetailContainer, role: .panel)
        healthDetailContainer.isHidden = true
        
        // Separator line
        let separator = NSView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.wantsLayer = true
        tagThemeBackground(separator, role: .borderSubtle)
        healthDetailContainer.addSubview(separator)
        
        // Scrollable stack for issues
        let detailScrollView = NSScrollView()
        detailScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailScrollView.hasVerticalScroller = true
        detailScrollView.hasHorizontalScroller = false
        detailScrollView.autohidesScrollers = true
        detailScrollView.drawsBackground = false
        detailScrollView.backgroundColor = .clear
        healthDetailContainer.addSubview(detailScrollView)
        
        let detailDocumentView = FlippedView()
        detailDocumentView.translatesAutoresizingMaskIntoConstraints = false
        detailScrollView.documentView = detailDocumentView
        
        healthDetailStack = NSStackView()
        healthDetailStack.translatesAutoresizingMaskIntoConstraints = false
        healthDetailStack.orientation = .vertical
        healthDetailStack.spacing = 8
        healthDetailStack.alignment = .leading
        detailDocumentView.addSubview(healthDetailStack)
        
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: healthDetailContainer.topAnchor),
            separator.leadingAnchor.constraint(equalTo: healthDetailContainer.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: healthDetailContainer.trailingAnchor, constant: -16),
            separator.heightAnchor.constraint(equalToConstant: 1),
            
            detailScrollView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            detailScrollView.leadingAnchor.constraint(equalTo: healthDetailContainer.leadingAnchor, constant: 16),
            detailScrollView.trailingAnchor.constraint(equalTo: healthDetailContainer.trailingAnchor, constant: -16),
            detailScrollView.bottomAnchor.constraint(equalTo: healthDetailContainer.bottomAnchor, constant: -12),
            
            healthDetailStack.topAnchor.constraint(equalTo: detailDocumentView.topAnchor),
            healthDetailStack.leadingAnchor.constraint(equalTo: detailDocumentView.leadingAnchor),
            healthDetailStack.trailingAnchor.constraint(equalTo: detailDocumentView.trailingAnchor),
            healthDetailStack.widthAnchor.constraint(equalTo: detailScrollView.widthAnchor),
        ])
        
        healthDetailHeightConstraint = healthDetailContainer.heightAnchor.constraint(equalToConstant: 0)
        healthDetailHeightConstraint.isActive = true
        
        cardStack.addArrangedSubview(healthDetailContainer)
        
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: healthCard.topAnchor),
            cardStack.leadingAnchor.constraint(equalTo: healthCard.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: healthCard.trailingAnchor),
            cardStack.bottomAnchor.constraint(equalTo: healthCard.bottomAnchor),
        ])
        
        rightColumn.addArrangedSubview(healthCard)
        
        // Make card fill width of right column
        healthCard.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor).isActive = true
        healthCard.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor).isActive = true
    }
    
    // MARK: - Browser Extension Card
    
    private func setupBrowserExtensionCard() {
        let sectionLabel = NSTextField(labelWithString: "BROWSER EXTENSION")
        sectionLabel.font = DesignFonts.caption(size: 11)
        tagThemeLabel(sectionLabel, role: .tertiary)
        rightColumn.addArrangedSubview(sectionLabel)
        
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        tagThemeBackground(card, role: .featureCard)
        tagThemeBorder(card, role: .subtle)
        
        let cardStack = NSStackView()
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardStack.orientation = .vertical
        cardStack.spacing = 16
        cardStack.alignment = .centerX
        cardStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        card.addSubview(cardStack)
        
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        
        // Header row with icon and title (centered)
        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.spacing = 16
        headerRow.alignment = .centerY
        
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 12
        iconContainer.layer?.borderWidth = 1
        tagThemeBackground(iconContainer, role: .featureCardIcon)
        tagThemeBorder(iconContainer, role: .subtle)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "safari.fill", accessibilityDescription: "Safari")
        iconView.contentTintColor = DesignColors.emerald400
        iconView.symbolConfiguration = .init(pointSize: 20, weight: .medium)
        iconContainer.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
        ])
        
        let titleLabel = NSTextField(labelWithString: "One-Click Installs")
        titleLabel.font = DesignFonts.header(size: 16)
        tagThemeLabel(titleLabel, role: .primary)
        
        headerRow.addArrangedSubview(iconContainer)
        headerRow.addArrangedSubview(titleLabel)
        cardStack.addArrangedSubview(headerRow)
        
        // Description (centered)
        let descLabel = NSTextField(wrappingLabelWithString: "Install characters and stages from MUGEN Archive directly into your library with one click.")
        descLabel.font = DesignFonts.body(size: 13)
        descLabel.alignment = .center
        tagThemeLabel(descLabel, role: .secondary)
        descLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        cardStack.addArrangedSubview(descLabel)
        
        // Supported sites (centered)
        let sitesRow = NSStackView()
        sitesRow.orientation = .horizontal
        sitesRow.spacing = 8
        sitesRow.alignment = .centerY
        
        let checkIcon = NSImageView()
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        checkIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        checkIcon.contentTintColor = DesignColors.emerald500
        checkIcon.symbolConfiguration = .init(pointSize: 14, weight: .medium)
        
        let siteLabel = NSTextField(labelWithString: "mugenarchive.com")
        siteLabel.font = DesignFonts.caption(size: 13)
        tagThemeLabel(siteLabel, role: .tertiary)
        
        sitesRow.addArrangedSubview(checkIcon)
        sitesRow.addArrangedSubview(siteLabel)
        cardStack.addArrangedSubview(sitesRow)
        
        // Enable button (full width, styled, 42px height)
        let enableButton = NSButton(title: "Enable in Safari Settings  →", target: self, action: #selector(openSafariExtensionSettings))
        enableButton.bezelStyle = .smallSquare
        enableButton.isBordered = false
        enableButton.wantsLayer = true
        enableButton.layer?.cornerRadius = 8
        enableButton.layer?.borderWidth = 1
        enableButton.font = DesignFonts.body(size: 13)
        enableButton.contentTintColor = DesignColors.textPrimary
        enableButton.translatesAutoresizingMaskIntoConstraints = false
        tagThemeBackground(enableButton, role: .buttonSecondary)
        tagThemeBorder(enableButton, role: .subtle)
        let heightConstraint = enableButton.heightAnchor.constraint(equalToConstant: 42)
        heightConstraint.priority = .required
        heightConstraint.isActive = true
        cardStack.addArrangedSubview(enableButton)
        
        // Make button fill width
        enableButton.leadingAnchor.constraint(equalTo: cardStack.leadingAnchor, constant: 24).isActive = true
        enableButton.trailingAnchor.constraint(equalTo: cardStack.trailingAnchor, constant: -24).isActive = true
        
        rightColumn.addArrangedSubview(card)
        
        // Make card fill width but NOT stretch vertically
        card.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor).isActive = true
        card.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor).isActive = true
        card.setContentHuggingPriority(.required, for: .vertical)
        card.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    @objc private func openSafariExtensionSettings() {
        // Open Safari Extensions preferences
        // This URL opens Safari and navigates to the Extensions tab in Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.Safari-Extensions-Preferences") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // Store last validation results for Fix All
    private var lastValidationResults: [ContentValidator.ValidationResult] = []
    
    @objc private func fixAllClicked() {
        guard !lastValidationResults.isEmpty else { return }
        
        let fixableCount = lastValidationResults.reduce(0) { total, result in
            total + result.issues.filter { $0.isFixable }.count
        }
        
        guard fixableCount > 0 else {
            ToastManager.shared.showError(title: "No fixable issues")
            return
        }
        
        // Confirm with user
        let alert = NSAlert()
        alert.messageText = "Fix \(fixableCount) Issues?"
        alert.informativeText = "This will update .def files to reference the correct filenames. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Fix All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let (fixed, failed) = ContentValidator.shared.fixAllIssues(in: lastValidationResults)
            
            if fixed > 0 {
                ToastManager.shared.showSuccess(title: "Fixed \(fixed) issue(s)")
            }
            if failed > 0 {
                ToastManager.shared.showError(title: "Failed to fix \(failed) issue(s)")
            }
            
            // Re-run validation
            validateContentClicked()
        }
    }
    
    /// Update health card with validation results
    func updateHealthStatus(results: [ContentValidator.ValidationResult]) {
        lastValidationResults = results
        
        let errorCount = results.reduce(0) { $0 + $1.errorCount }
        let warningCount = results.reduce(0) { $0 + $1.warningCount }
        let fixableCount = results.reduce(0) { total, result in
            total + result.issues.filter { $0.isFixable }.count
        }
        let totalIssues = errorCount + warningCount
        
        // Update status text
        if errorCount == 0 && warningCount == 0 {
            healthStatusLabel.stringValue = "✓ All content validated successfully"
            healthStatusLabel.textColor = DesignColors.positive
            healthBadge.isHidden = true
            fixAllButton.isHidden = true
            hideHealthDetails()
        } else {
            var status = ""
            if errorCount > 0 {
                status += "\(errorCount) error(s)"
            }
            if warningCount > 0 {
                if !status.isEmpty { status += ", " }
                status += "\(warningCount) warning(s)"
            }
            status += " — click to expand"
            healthStatusLabel.stringValue = status
            healthStatusLabel.textColor = errorCount > 0 ? DesignColors.negative : DesignColors.warning
            
            // Show badge with error count
            healthBadge.isHidden = false
            healthBadgeLabel.stringValue = "\(totalIssues)"
            healthBadge.layer?.backgroundColor = errorCount > 0 ? DesignColors.negative.cgColor : DesignColors.warning.cgColor
            
            // Show Fix All button if there are fixable issues
            fixAllButton.isHidden = fixableCount == 0
            if fixableCount > 0 {
                fixAllButton.title = "Fix \(fixableCount)"
            }
            
            // Populate detail panel
            populateHealthDetails(results: results)
            
            // Auto-expand if there are issues
            showHealthDetails()
        }
    }
    
    private func populateHealthDetails(results: [ContentValidator.ValidationResult]) {
        // Clear existing items
        healthDetailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for result in results {
            if result.issues.isEmpty { continue }
            
            // Content name header
            let headerStack = NSStackView()
            headerStack.orientation = .horizontal
            headerStack.spacing = 8
            headerStack.alignment = .centerY
            
            let typeIcon = NSImageView()
            typeIcon.translatesAutoresizingMaskIntoConstraints = false
            let iconName = result.contentType == "character" ? "person.fill" : "photo.fill"
            typeIcon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            typeIcon.contentTintColor = DesignColors.textSecondary
            typeIcon.symbolConfiguration = .init(pointSize: 12, weight: .medium)
            NSLayoutConstraint.activate([
                typeIcon.widthAnchor.constraint(equalToConstant: 16),
                typeIcon.heightAnchor.constraint(equalToConstant: 16),
            ])
            headerStack.addArrangedSubview(typeIcon)
            
            let nameLabel = NSTextField(labelWithString: result.contentName)
            nameLabel.font = DesignFonts.body(size: 13)
            tagThemeLabel(nameLabel, role: .primary)
            headerStack.addArrangedSubview(nameLabel)
            
            let typeBadge = NSTextField(labelWithString: result.contentType.uppercased())
            typeBadge.font = DesignFonts.caption(size: 9)
            tagThemeLabel(typeBadge, role: .tertiary)
            typeBadge.wantsLayer = true
            tagThemeBackground(typeBadge, role: .card)
            typeBadge.layer?.cornerRadius = 3
            // Add padding via alignment rect insets
            headerStack.addArrangedSubview(typeBadge)
            
            healthDetailStack.addArrangedSubview(headerStack)
            
            // Issues for this content
            for issue in result.issues {
                let issueRow = createIssueRow(issue: issue)
                healthDetailStack.addArrangedSubview(issueRow)
            }
            
            // Add spacer between content items
            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
            healthDetailStack.addArrangedSubview(spacer)
        }
    }
    
    private func createIssueRow(issue: ContentValidator.ValidationIssue) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .top
        
        // Severity icon
        let severityIcon = NSImageView()
        severityIcon.translatesAutoresizingMaskIntoConstraints = false
        let (iconName, iconColor): (String, NSColor) = {
            switch issue.severity {
            case .error: return ("xmark.circle.fill", DesignColors.negative)
            case .warning: return ("exclamationmark.triangle.fill", DesignColors.warning)
            case .info: return ("info.circle.fill", DesignColors.info)
            }
        }()
        severityIcon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        severityIcon.contentTintColor = iconColor
        severityIcon.symbolConfiguration = .init(pointSize: 11, weight: .medium)
        NSLayoutConstraint.activate([
            severityIcon.widthAnchor.constraint(equalToConstant: 14),
            severityIcon.heightAnchor.constraint(equalToConstant: 14),
        ])
        row.addArrangedSubview(severityIcon)
        
        // Message and suggestion
        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        
        let messageLabel = NSTextField(wrappingLabelWithString: issue.message)
        messageLabel.font = DesignFonts.caption(size: 11)
        tagThemeLabel(messageLabel, role: .secondary)
        messageLabel.preferredMaxLayoutWidth = 400
        textStack.addArrangedSubview(messageLabel)
        
        if let suggestion = issue.suggestion {
            let suggestionLabel = NSTextField(wrappingLabelWithString: "→ \(suggestion)")
            suggestionLabel.font = DesignFonts.caption(size: 10)
            tagThemeLabel(suggestionLabel, role: .tertiary)
            suggestionLabel.preferredMaxLayoutWidth = 400
            textStack.addArrangedSubview(suggestionLabel)
        }
        
        row.addArrangedSubview(textStack)
        
        // Fixable badge
        if issue.isFixable {
            let fixBadge = NSTextField(labelWithString: "FIXABLE")
            fixBadge.font = NSFont.systemFont(ofSize: 8, weight: .bold)
            fixBadge.textColor = DesignColors.positive
            fixBadge.wantsLayer = true
            fixBadge.layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.15).cgColor
            fixBadge.layer?.cornerRadius = 3
            row.addArrangedSubview(fixBadge)
        }
        
        return row
    }
    
    private func showHealthDetails() {
        guard !isHealthDetailExpanded else { return }
        isHealthDetailExpanded = true
        
        healthDetailContainer.isHidden = false
        
        // Calculate height based on content (max 500px to allow more errors to be visible)
        let contentHeight = min(healthDetailStack.fittingSize.height + 30, 500)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            healthDetailHeightConstraint.animator().constant = contentHeight
        }
    }
    
    private func hideHealthDetails() {
        guard isHealthDetailExpanded else { return }
        isHealthDetailExpanded = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            healthDetailHeightConstraint.animator().constant = 0
        }, completionHandler: {
            self.healthDetailContainer.isHidden = true
        })
    }
    
    @objc private func toggleHealthDetails() {
        if isHealthDetailExpanded {
            hideHealthDetails()
        } else {
            showHealthDetails()
        }
    }
    
    @objc private func validateContentClicked() {
        onValidateContent?()
    }
    
    // MARK: - Public Methods
    
    func updateStats(characters: Int, stages: Int, storageBytes: Int64?) {
        fightersCountLabel?.stringValue = "\(characters)"
        stagesCountLabel?.stringValue = "\(stages)"
        
        if let bytes = storageBytes {
            storageLabel?.stringValue = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } else {
            storageLabel?.stringValue = "—"
        }
        
        // Also refresh recently installed table
        refreshRecentlyInstalled()
    }
    
    func refreshStats() {
        onRefreshStats?()
    }
    
    deinit {
        if let themeObserver = themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }
}

// MARK: - Dashboard Drop Zone

class DashboardDropZone: NSView, ThemeApplicable {
    
    var onFilesDropped: (([URL]) -> Void)?
    var onClick: (() -> Void)?
    
    private var isDragging = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    private var trackingArea: NSTrackingArea?
    private var dashedBorderLayer: CAShapeLayer?
    private var iconContainer: NSView!
    private var iconView: NSImageView!
    private var label: NSTextField!
    private var subLabel: NSTextField!
    private var fullgameToggle: NSButton!

    override func mouseDown(with event: NSEvent) {
        if let onClick = onClick {
            onClick()
        } else {
            super.mouseDown(with: event)
        }
    }
    
    // Design colors - now using semantic theme-aware colors
    private var borderDefault: NSColor { DesignColors.borderSubtle }
    private var borderHover: NSColor { DesignColors.borderHover }
    private var bgDefault: NSColor { DesignColors.cardBackground.withAlphaComponent(0.2) }
    private var bgHover: NSColor { DesignColors.cardBackground.withAlphaComponent(0.4) }
    
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
        layer?.backgroundColor = bgDefault.cgColor  // bg-zinc-900/20 default
        
        // Dashed border - zinc-800 default
        let dashedBorder = CAShapeLayer()
        dashedBorder.strokeColor = borderDefault.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [8, 6]
        dashedBorder.lineWidth = 1
        layer?.addSublayer(dashedBorder)
        self.dashedBorderLayer = dashedBorder
        
        // Register for drag
        registerForDraggedTypes([.fileURL])
        
        // Icon container - use Auto Layout, scale via bounds-center transform
        iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        iconContainer.layer?.cornerRadius = 24  // rounded-full for 48px container
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        // Add shadow
        iconContainer.layer?.shadowColor = NSColor.black.cgColor
        iconContainer.layer?.shadowOpacity = 0.3
        iconContainer.layer?.shadowOffset = CGSize(width: 0, height: 2)
        iconContainer.layer?.shadowRadius = 4
        addSubview(iconContainer)
        
        // Icon (cloud download style from HTML)
        iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "icloud.and.arrow.down", accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textSecondary
        iconView.symbolConfiguration = .init(pointSize: 20, weight: .regular)
        iconContainer.addSubview(iconView)
        
        // Label - "Install Content"
        label = NSTextField(labelWithString: "Install Content")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.body(size: 14)
        tagThemeLabel(label, role: .secondary)
        label.alignment = .center
        addSubview(label)
        
        // Sub-label
        subLabel = NSTextField(labelWithString: "Drag and drop .zip, .rar, or .def files here to automatically\ninstall characters or stages.")
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.font = DesignFonts.caption(size: 12)
        tagThemeLabel(subLabel, role: .tertiary)
        subLabel.alignment = .center
        subLabel.maximumNumberOfLines = 2
        addSubview(subLabel)
        
        // Fullgame mode toggle
        fullgameToggle = NSButton(checkboxWithTitle: "Fullgame mode", target: self, action: #selector(fullgameToggleChanged))
        fullgameToggle.translatesAutoresizingMaskIntoConstraints = false
        fullgameToggle.font = DesignFonts.caption(size: 11)
        fullgameToggle.state = AppSettings.shared.fullgameImportEnabled ? .on : .off
        fullgameToggle.contentTintColor = DesignColors.textTertiary
        fullgameToggle.toolTip = "Import entire MUGEN/IKEMEN packages as collections, including characters, stages, screenpack, fonts, and sounds."
        addSubview(fullgameToggle)
        
        NSLayoutConstraint.activate([
            // Icon container: 48x48 centered
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
            iconContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            
            // Icon centered in container
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 16),
            
            subLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            subLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            subLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            
            // Fullgame toggle below sub-label
            fullgameToggle.centerXAnchor.constraint(equalTo: centerXAnchor),
            fullgameToggle.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 12),
        ])
    }
    
    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 12, cornerHeight: 12, transform: nil)
        dashedBorderLayer?.path = path
        dashedBorderLayer?.frame = bounds
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? 0.2 : 0.0
        
        // Animate border and background colors
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            if isDragging {
                dashedBorderLayer?.strokeColor = DesignColors.positive.cgColor
                layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.15).cgColor
            } else if isHovered {
                dashedBorderLayer?.strokeColor = borderHover.cgColor
                layer?.backgroundColor = bgHover.cgColor
            } else {
                dashedBorderLayer?.strokeColor = borderDefault.cgColor
                layer?.backgroundColor = bgDefault.cgColor
            }
        }
        
        // Determine target scale
        let targetScale: CGFloat
        if isDragging {
            targetScale = 1.15
        } else if isHovered {
            targetScale = 1.1
        } else {
            targetScale = 1.0
        }
        
        // Scale from center using bounds-based transform
        // The key: translate to center, scale, translate back
        let bounds = iconContainer.bounds
        let centerX = bounds.midX
        let centerY = bounds.midY
        
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, centerX, centerY, 0)
        transform = CATransform3DScale(transform, targetScale, targetScale, 1.0)
        transform = CATransform3DTranslate(transform, -centerX, -centerY, 0)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                iconContainer.layer?.transform = transform
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            iconContainer.layer?.transform = transform
            CATransaction.commit()
        }
    }
    
    @objc private func fullgameToggleChanged() {
        AppSettings.shared.fullgameImportEnabled = (fullgameToggle.state == .on)
    }

    func applyTheme() {
        layer?.backgroundColor = bgDefault.cgColor
        dashedBorderLayer?.strokeColor = borderDefault.cgColor
        iconContainer.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        iconContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        iconView.contentTintColor = DesignColors.textSecondary
        fullgameToggle.contentTintColor = DesignColors.textTertiary
        refreshThemeLabels(in: self)
        updateAppearance(animated: false)
    }
    
    // MARK: - Cursor (pointer on hover)
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    // MARK: - Hover Tracking
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    // MARK: - Drag & Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasValidFiles(sender) {
            isDragging = true
            return .copy
        }
        return []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        let validURLs = urls.filter { isValidFile($0) }
        if !validURLs.isEmpty {
            onFilesDropped?(validURLs)
            return true
        }
        return false
    }
    
    private func hasValidFiles(_ info: NSDraggingInfo) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        return urls.contains { isValidFile($0) }
    }
    
    private func isValidFile(_ url: URL) -> Bool {
        let validExtensions = ["zip", "rar", "7z"]
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return true
            }
            return validExtensions.contains(url.pathExtension.lowercased())
        }
        return false
    }
}

// MARK: - Hoverable Stat Card

/// A stats card with hover effect matching CSS:
/// glass-panel p-5 rounded-lg border border-white/5 hover:border-white/10 transition-colors
class HoverableStatCard: NSView, ThemeApplicable {
    
    var onClick: (() -> Void)?  // Click callback for navigation
    
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    private func setupAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 8  // rounded-lg
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor  // border-white/5
        
        // Glass panel gradient: linear-gradient(180deg, rgba(255,255,255,0.03) 0%, rgba(255,255,255,0) 100%)
        let gradient = CAGradientLayer()
        gradient.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.cornerRadius = 8
        layer?.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }
    
    override func layout() {
        super.layout()
        // Disable implicit animations for frame changes during resize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer?.frame = bounds
        CATransaction.commit()
    }
    
    private func updateAppearance(animated: Bool) {
        // Border: white/5 -> white/10 on hover (transition-colors)
        // Tailwind default: 150ms cubic-bezier(0.4, 0, 0.2, 1)
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        // Tailwind's default timing: cubic-bezier(0.4, 0, 0.2, 1)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = DesignColors.borderHover.cgColor  // hover:border-white/10
        } else {
            layer?.borderColor = DesignColors.borderSubtle.cgColor  // border-white/5
        }
        
        CATransaction.commit()
        
        // Also update icon color (group-hover:text-white)
        updateIconColor(animated: animated)
    }
    
    private func updateIconColor(animated: Bool) {
        // Find icon view and update its color
        guard let iconView = findSubview(withIdentifier: "iconView") as? NSImageView else { return }
        
        let newColor = isHovered ? DesignColors.textPrimary : DesignColors.textSecondary
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                iconView.contentTintColor = newColor
            }
        } else {
            iconView.contentTintColor = newColor
        }
    }
    
    private func findSubview(withIdentifier identifier: String) -> NSView? {
        for subview in subviews {
            if subview.identifier?.rawValue == identifier {
                return subview
            }
            if let found = findInSubviews(of: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
    
    func applyTheme() {
        gradientLayer?.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        updateAppearance(animated: false)
        refreshThemeLayers(in: self)
        refreshThemeLabels(in: self)
    }
    
    private func findInSubviews(of view: NSView, identifier: String) -> NSView? {
        for subview in view.subviews {
            if subview.identifier?.rawValue == identifier {
                return subview
            }
            if let found = findInSubviews(of: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        // .assumeInside ensures mouseExited fires even if mouse was already inside when tracking started
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .assumeInside],
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
    
    override func mouseDown(with event: NSEvent) {
        guard onClick != nil else { return }
        // Visual feedback - slightly dim on press
        alphaValue = 0.8
    }
    
    override func mouseUp(with event: NSEvent) {
        guard onClick != nil else { return }
        alphaValue = 1.0
        
        // Check if still inside bounds (user didn't drag out)
        let localPoint = convert(event.locationInWindow, from: nil)
        if bounds.contains(localPoint) {
            onClick?()
        }
    }
    
    override var acceptsFirstResponder: Bool { onClick != nil }
    
    override func resetCursorRects() {
        if onClick != nil {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}

// MARK: - Hoverable Tool Button

/// Tool button with hover effect for the Tools section
class HoverableToolButton: NSView, ThemeApplicable {
    
    var target: AnyObject?
    var action: Selector?
    
    private var trackingArea: NSTrackingArea?
    
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    private func setupAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = DesignColors.cardBackground.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = DesignColors.borderHover.cgColor
            layer?.backgroundColor = DesignColors.cardBackgroundHover.cgColor
        } else {
            layer?.borderColor = DesignColors.borderSubtle.cgColor
            layer?.backgroundColor = DesignColors.cardBackground.cgColor
        }
        
        CATransaction.commit()
    }
    
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
    
    override func mouseDown(with event: NSEvent) {
        alphaValue = 0.8
    }
    
    override func mouseUp(with event: NSEvent) {
        alphaValue = 1.0
        
        let localPoint = convert(event.locationInWindow, from: nil)
        if bounds.contains(localPoint) {
            if let target = target, let action = action {
                _ = target.perform(action)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    func applyTheme() {
        layer?.backgroundColor = DesignColors.cardBackground.cgColor
        layer?.borderColor = DesignColors.borderSubtle.cgColor
        updateAppearance(animated: false)
    }
}

// MARK: - Hoverable Launch Card

/// Launch card with special hover effect - adds gradient overlay on hover
/// CSS: glass-panel with bg-gradient-to-br from-white/5 to-transparent on hover
class HoverableLaunchCard: NSView, ThemeApplicable {
    
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    private var hoverGradientLayer: CAGradientLayer?
    var onClick: (() -> Void)?  // Click callback
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    private var isPressed = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    // MARK: - Mouse Click Handling
    
    override func mouseDown(with event: NSEvent) {
        guard onClick != nil else {
            super.mouseDown(with: event)
            return
        }
        
        isPressed = true
        
        // Visual press feedback
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.08)
        layer?.setAffineTransform(CGAffineTransform(scaleX: 0.98, y: 0.98))
        CATransaction.commit()
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isPressed else {
            super.mouseUp(with: event)
            return
        }
        
        isPressed = false
        
        // Visual release feedback
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        layer?.setAffineTransform(.identity)
        CATransaction.commit()
        
        // Check if mouse is still inside the card
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            // Trigger click callback
            onClick?()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Accept click without requiring window to be active first
        return true
    }
    
    // Make the entire card clickable by returning self when we have a click handler
    // This prevents subviews (labels, icons, stack views) from intercepting mouse events
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert point from superview coordinates to local coordinates
        let localPoint = convert(point, from: superview)
        
        // If we have an onClick handler and the point is inside our bounds,
        // return self so we receive the mouseDown event
        if onClick != nil && bounds.contains(localPoint) {
            return self
        }
        return super.hitTest(point)
    }
    
    // Show pointer cursor when hoverable
    override func resetCursorRects() {
        if onClick != nil {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
    
    private func setupAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Base glass gradient
        let gradient = CAGradientLayer()
        gradient.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.cornerRadius = 8
        layer?.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
        
        // Hover gradient (initially invisible)
        // bg-gradient-to-br from-white/5 to-transparent
        let hoverGrad = CAGradientLayer()
        hoverGrad.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        hoverGrad.startPoint = CGPoint(x: 0, y: 0)
        hoverGrad.endPoint = CGPoint(x: 1, y: 1)
        hoverGrad.cornerRadius = 8
        hoverGrad.opacity = 0
        layer?.addSublayer(hoverGrad)
        hoverGradientLayer = hoverGrad
    }
    
    override func layout() {
        super.layout()
        // Disable implicit animations for frame changes during resize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer?.frame = bounds
        hoverGradientLayer?.frame = bounds
        CATransaction.commit()
    }
    
    private func updateAppearance(animated: Bool) {
        // Tailwind default: 150ms cubic-bezier(0.4, 0, 0.2, 1)
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        // Tailwind's default timing: cubic-bezier(0.4, 0, 0.2, 1)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = DesignColors.borderHover.cgColor
            hoverGradientLayer?.opacity = 1.0
        } else {
            layer?.borderColor = DesignColors.borderSubtle.cgColor
            hoverGradientLayer?.opacity = 0.0
        }
        
        CATransaction.commit()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        // .assumeInside ensures mouseExited fires even if mouse was already inside when tracking started
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .assumeInside],
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
    
    func applyTheme() {
        gradientLayer?.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        hoverGradientLayer?.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        updateAppearance(animated: false)
    }
}

// MARK: - Recent Install Row

/// A table row for recently installed content
/// Matches HTML: hover:bg-white/5 transition-colors cursor-pointer
class RecentInstallRow: NSView, ThemeApplicable {
    
    var onClick: (() -> Void)?
    var onStatusChanged: ((Bool) -> Void)?
    
    private let install: RecentInstall
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { updateAppearance(animated: true) }
    }
    
    // UI Elements
    private var iconView: NSView!
    private var iconLabel: NSTextField!
    private var thumbnailImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var typeBadge: NSView!
    private var typeDot: NSView!
    private var typeLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var statusToggle: NSSwitch!
    
    // Colors for type badges
    private let charBadgeColor = DesignColors.badgeCharacter
    private let stageBadgeColor = DesignColors.badgeStage
    
    init(install: RecentInstall, showBorder: Bool) {
        self.install = install
        super.init(frame: .zero)
        setupUI(showBorder: showBorder)
        loadThumbnail()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(showBorder: Bool) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Bottom border (if not last row)
        if showBorder {
            let border = NSView()
            border.translatesAutoresizingMaskIntoConstraints = false
            border.wantsLayer = true
            tagThemeBackground(border, role: .borderSubtle)
            addSubview(border)
            
            NSLayoutConstraint.activate([
                border.leadingAnchor.constraint(equalTo: leadingAnchor),
                border.trailingAnchor.constraint(equalTo: trailingAnchor),
                border.bottomAnchor.constraint(equalTo: bottomAnchor),
                border.heightAnchor.constraint(equalToConstant: 1),
            ])
        }
        
        // Icon container (40x40, darker background)
        iconView = NSView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6
        tagThemeBackground(iconView, role: .zinc900)
        iconView.layer?.borderWidth = 1
        tagThemeBorder(iconView, role: .subtle)
        iconView.layer?.masksToBounds = true  // Clip thumbnail to rounded corners
        addSubview(iconView)
        
        // Thumbnail image view (hidden until image loads)
        thumbnailImageView = NSImageView()
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.isHidden = true
        iconView.addSubview(thumbnailImageView)
        
        // Icon initial letter (fallback when no thumbnail)
        let initial = String(install.name.prefix(1)).uppercased()
        iconLabel = NSTextField(labelWithString: initial)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        tagThemeLabel(iconLabel, role: .tertiary)
        iconLabel.alignment = .center
        iconView.addSubview(iconLabel)
        
        // Name + Author stack
        let nameStack = NSStackView()
        nameStack.translatesAutoresizingMaskIntoConstraints = false
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = 2
        addSubview(nameStack)
        
        // Name label
        nameLabel = NSTextField(labelWithString: install.name)
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameStack.addArrangedSubview(nameLabel)
        
        // Author label (from metadata)
        authorLabel = NSTextField(labelWithString: install.author)
        authorLabel.font = DesignFonts.body(size: 12)
        authorLabel.lineBreakMode = .byTruncatingTail
        nameStack.addArrangedSubview(authorLabel)
        
        // Check if content still exists on disk
        let isDeleted = !install.existsOnDisk
        
        // Apply styling based on deletion state
        if isDeleted {
            // Strikethrough for deleted items
            let nameAttr = NSMutableAttributedString(string: install.name)
            nameAttr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: nameAttr.length))
            nameAttr.addAttribute(.foregroundColor, value: DesignColors.textTertiary, range: NSRange(location: 0, length: nameAttr.length))
            nameLabel.attributedStringValue = nameAttr
            
            let authorAttr = NSMutableAttributedString(string: install.author)
            authorAttr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: authorAttr.length))
            authorAttr.addAttribute(.foregroundColor, value: DesignColors.textTertiary, range: NSRange(location: 0, length: authorAttr.length))
            authorLabel.attributedStringValue = authorAttr
        } else {
            tagThemeLabel(nameLabel, role: .primary)
            tagThemeLabel(authorLabel, role: .tertiary)
        }
        
        // Type badge with colored dot
        let isCharacter = install.type == "character"
        let badgeColor = isCharacter ? charBadgeColor : stageBadgeColor
        
        typeBadge = NSView()
        typeBadge.translatesAutoresizingMaskIntoConstraints = false
        typeBadge.wantsLayer = true
        typeBadge.layer?.cornerRadius = 12
        typeBadge.layer?.backgroundColor = badgeColor.withAlphaComponent(0.15).cgColor
        typeBadge.layer?.borderWidth = 1
        typeBadge.layer?.borderColor = badgeColor.withAlphaComponent(0.3).cgColor
        addSubview(typeBadge)
        
        // Colored dot inside badge
        typeDot = NSView()
        typeDot.translatesAutoresizingMaskIntoConstraints = false
        typeDot.wantsLayer = true
        typeDot.layer?.cornerRadius = 3
        typeDot.layer?.backgroundColor = badgeColor.cgColor
        typeBadge.addSubview(typeDot)
        
        let typeText = isCharacter ? "Char" : "Stage"
        typeLabel = NSTextField(labelWithString: typeText)
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        typeLabel.textColor = badgeColor
        typeBadge.addSubview(typeLabel)
        
        // Date label (formatted nicely)
        let dateText = formatDate(install.installedAt)
        dateLabel = NSTextField(labelWithString: dateText)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        tagThemeLabel(dateLabel, role: .tertiary)
        dateLabel.alignment = .left
        addSubview(dateLabel)
        
        // Status toggle (hidden for deleted items)
        statusToggle = NSSwitch()
        statusToggle.translatesAutoresizingMaskIntoConstraints = false
        statusToggle.state = .on  // Default to enabled
        statusToggle.target = self
        statusToggle.action = #selector(statusToggled(_:))
        statusToggle.isHidden = isDeleted  // Hide toggle for deleted items
        addSubview(statusToggle)
        
        NSLayoutConstraint.activate([
            // Icon (40x40)
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            // Thumbnail fills the icon container
            thumbnailImageView.topAnchor.constraint(equalTo: iconView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: iconView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: iconView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: iconView.bottomAnchor),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            // Name stack
            nameStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameStack.trailingAnchor.constraint(lessThanOrEqualTo: typeBadge.leadingAnchor, constant: -12),
            
            // Type badge - positioned relative to date
            typeBadge.trailingAnchor.constraint(equalTo: dateLabel.leadingAnchor, constant: -20),
            typeBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            typeBadge.heightAnchor.constraint(equalToConstant: 24),
            
            typeDot.leadingAnchor.constraint(equalTo: typeBadge.leadingAnchor, constant: 10),
            typeDot.centerYAnchor.constraint(equalTo: typeBadge.centerYAnchor),
            typeDot.widthAnchor.constraint(equalToConstant: 6),
            typeDot.heightAnchor.constraint(equalToConstant: 6),
            
            typeLabel.leadingAnchor.constraint(equalTo: typeDot.trailingAnchor, constant: 6),
            typeLabel.trailingAnchor.constraint(equalTo: typeBadge.trailingAnchor, constant: -12),
            typeLabel.centerYAnchor.constraint(equalTo: typeBadge.centerYAnchor),
            
            // Date
            dateLabel.trailingAnchor.constraint(equalTo: statusToggle.leadingAnchor, constant: -20),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Status toggle (right side)
            statusToggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statusToggle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    @objc private func statusToggled(_ sender: NSSwitch) {
        onStatusChanged?(sender.state == .on)
    }
    
    // MARK: - Thumbnail Loading
    
    private func loadThumbnail() {
        let folderPath = install.folderPath
        let itemType = install.type
        let itemId = install.id
        
        // Check cache first
        let cacheKey = "recent_\(itemType)_\(itemId)"
        if let cached = ImageCache.shared.get(cacheKey) {
            showThumbnail(cached)
            return
        }
        
        // Load asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var thumbnail: NSImage? = nil
            let folderURL = URL(fileURLWithPath: folderPath)
            
            if itemType == "character" {
                // For characters, load portrait from folder
                thumbnail = self?.loadCharacterPortrait(from: folderURL)
            } else {
                // For stages, load preview from SFF
                thumbnail = self?.loadStagePreview(defFileURL: folderURL)
            }
            
            DispatchQueue.main.async { [weak self] in
                if let image = thumbnail {
                    ImageCache.shared.set(image, for: cacheKey)
                    self?.showThumbnail(image)
                }
            }
        }
    }
    
    private func showThumbnail(_ image: NSImage) {
        thumbnailImageView.image = image
        thumbnailImageView.isHidden = false
        iconLabel.isHidden = true
    }
    
    private func loadCharacterPortrait(from folderURL: URL) -> NSImage? {
        let fileManager = FileManager.default
        
        // First check for portrait.png
        let portraitPng = folderURL.appendingPathComponent("portrait.png")
        if fileManager.fileExists(atPath: portraitPng.path),
           let image = NSImage(contentsOf: portraitPng) {
            return image
        }
        
        // Check for any .png file that might be a portrait
        if let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            for file in contents where file.pathExtension.lowercased() == "png" {
                let name = file.deletingPathExtension().lastPathComponent.lowercased()
                if name.contains("portrait") || name.contains("select") {
                    if let image = NSImage(contentsOf: file) {
                        return image
                    }
                }
            }
        }
        
        // Find def file to get sprite reference
        if let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
            if let defFile = defFiles.first {
                let parsed = DEFParser.parse(url: defFile)
                if let spriteFileName = parsed?.spriteFile {
                    let sffFile = folderURL.appendingPathComponent(spriteFileName)
                    if fileManager.fileExists(atPath: sffFile.path) {
                        return SFFParser.extractPortrait(from: sffFile)
                    }
                }
            }
            
            // Fallback: try any SFF file
            let sffFiles = contents.filter { $0.pathExtension.lowercased() == "sff" }
            if let sffFile = sffFiles.first {
                return SFFParser.extractPortrait(from: sffFile)
            }
        }
        
        return nil
    }
    
    private func loadStagePreview(defFileURL: URL) -> NSImage? {
        let fileManager = FileManager.default
        
        // Parse the def file to get SFF reference
        if fileManager.fileExists(atPath: defFileURL.path) {
            let parsed = DEFParser.parse(url: defFileURL)
            if let sprName = parsed?.spriteFile {
                // Normalize path separators
                let normalizedPath = sprName.replacingOccurrences(of: "\\", with: "/")
                
                let sffURL: URL
                if normalizedPath.contains("/") {
                    // Root-relative path
                    let rootDir = defFileURL.deletingLastPathComponent().deletingLastPathComponent()
                    sffURL = rootDir.appendingPathComponent(normalizedPath)
                } else {
                    // File-relative path
                    sffURL = defFileURL.deletingLastPathComponent().appendingPathComponent(normalizedPath)
                }
                
                if fileManager.fileExists(atPath: sffURL.path) {
                    return SFFParser.extractStagePreview(from: sffURL)
                }
            }
        }
        
        return nil
    }
    
    override func layout() {
        super.layout()
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return "\(days) days ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        
        if isHovered {
            layer?.backgroundColor = DesignColors.overlayHighlightStrong.cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        CATransaction.commit()
    }
    
    func applyTheme() {
        refreshThemeLabels(in: self)
        refreshThemeLayers(in: self)
        updateAppearance(animated: false)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .assumeInside],
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
    
    override func mouseDown(with event: NSEvent) {
        // Don't dim if clicking on toggle
        let localPoint = convert(event.locationInWindow, from: nil)
        if !statusToggle.frame.contains(localPoint) {
            alphaValue = 0.8
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        alphaValue = 1.0
        
        let localPoint = convert(event.locationInWindow, from: nil)
        // Don't trigger onClick if clicking on toggle
        if bounds.contains(localPoint) && !statusToggle.frame.contains(localPoint) {
            onClick?()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func resetCursorRects() {
        // Add pointer cursor except over the toggle area
        var cursorRect = bounds
        cursorRect.size.width -= 80  // Exclude toggle area
        addCursorRect(cursorRect, cursor: .pointingHand)
    }
}
