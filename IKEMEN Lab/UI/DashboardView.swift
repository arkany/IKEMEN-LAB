import Cocoa

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
    private var contentObserver: NSObjectProtocol?
    private var gameStatusObserver: NSObjectProtocol?
    
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
        contentObserver = NotificationCenter.default.addObserver(forName: .contentChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        
        gameStatusObserver = NotificationCenter.default.addObserver(forName: .gameStatusChanged, object: nil, queue: .main) { [weak self] _ in
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
        // Load from Ikemen config via IkemenConfigManager
        guard let config = IkemenConfigManager.shared.loadConfig() else { return }
        
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
        let vsyncValue = vsyncToggle?.state == .on ? "1" : "0"
        let fullscreenValue = fullscreenToggle?.state == .on ? "1" : "0"
        let volumeValue = "\(volumeSlider?.intValue ?? 100)"
        
        IkemenConfigManager.shared.saveValue(section: "Video", key: "VSync", value: vsyncValue)
        IkemenConfigManager.shared.saveValue(section: "Video", key: "Fullscreen", value: fullscreenValue)
        IkemenConfigManager.shared.saveValue(section: "Sound", key: "MasterVolume", value: volumeValue)
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
        [themeObserver, contentObserver, gameStatusObserver].compactMap { $0 }.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }
}

