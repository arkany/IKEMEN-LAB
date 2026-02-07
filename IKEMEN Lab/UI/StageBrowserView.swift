import Cocoa
import Combine

// MARK: - Custom Collection View for Context Menu Support

/// NSCollectionView subclass that properly handles right-click/control-click context menus
class StageCollectionView: NSCollectionView {
    
    var menuProvider: ((IndexPath) -> NSMenu?)?
    
    private func showContextMenu(for event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if let indexPath = indexPathForItem(at: point),
           let menu = menuProvider?(indexPath) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }
    
    // Handle Control+Click (sends mouseDown with control modifier)
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showContextMenu(for: event)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    // Handle right-click / two-finger tap
    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(for: event)
    }
    
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - Custom Clip View to forward right-click events

/// Custom clip view that forwards right-click to the document view
class StageClipView: NSClipView {
    override func rightMouseDown(with event: NSEvent) {
        documentView?.rightMouseDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            documentView?.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }
}

/// A visual browser for viewing installed stages with thumbnails
/// Uses shared design system from UIHelpers.swift
class StageBrowserView: NSView {
    
    // MARK: - Properties
    
    private var scrollView: NSScrollView!
    private var collectionView: StageCollectionView!
    private var flowLayout: NSCollectionViewFlowLayout!
    private var allStages: [StageInfo] = []  // All stages from data source
    private var stages: [StageInfo] = []     // Filtered stages for display
    private var cancellables = Set<AnyCancellable>()
    private var themeObserver: NSObjectProtocol?
    
    // Registration status filter
    var registrationFilter: RegistrationFilter = .all {
        didSet {
            applyFilters()
        }
    }
    
    // Layout constants from shared design system
    private let listItemHeight = BrowserLayout.stageListItemHeight
    private let cardSpacing = BrowserLayout.cardSpacing
    private let sectionInset = BrowserLayout.sectionInset
    
    var onStageSelected: ((StageInfo) -> Void)?
    var onStageDisableToggle: ((StageInfo) -> Void)?
    var onStageRemove: ((StageInfo) -> Void)?
    var onStageRevealInFinder: ((StageInfo) -> Void)?
    
    // MARK: - Initialization
    
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
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupCollectionView()
        setupObservers()
    }
    
    // MARK: - Collection View Setup
    
    private func setupCollectionView() {
        // Create scroll view with custom clip view for right-click forwarding
        scrollView = NSScrollView(frame: bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView = StageClipView()  // Use custom clip view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        addSubview(scrollView)
        
        // Create flow layout for list view
        flowLayout = NSCollectionViewFlowLayout()
        // Use max to ensure non-zero size (required by flow layout)
        let initialWidth = max(bounds.width, 100)
        flowLayout.itemSize = NSSize(width: initialWidth, height: listItemHeight)
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 0
        flowLayout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        // Create collection view (using custom subclass)
        collectionView = StageCollectionView(frame: bounds)
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        
        // Register list item class only
        collectionView.register(StageListItem.self, forItemWithIdentifier: StageListItem.identifier)
        
        // Set up context menu provider
        collectionView.menuProvider = { [weak self] indexPath in
            self?.buildContextMenu(for: indexPath)
        }
        
        scrollView.documentView = collectionView
        
        // Layout constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    // MARK: - Responsive Layout
    
    override func layout() {
        super.layout()
        updateLayoutForWidth(bounds.width)
    }
    
    private func updateLayoutForWidth(_ width: CGFloat) {
        // Ensure non-zero size (required by flow layout)
        let safeWidth = max(width, 100)
        flowLayout.itemSize = NSSize(width: safeWidth, height: listItemHeight)
        flowLayout.invalidateLayout()
    }
    
    // MARK: - Data Binding
    
    private func setupObservers() {
        IkemenBridge.shared.$stages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stages in
                self?.updateStages(stages)
            }
            .store(in: &cancellables)

        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Update all visible items
            for indexPath in self.collectionView.indexPathsForVisibleItems() {
                if let item = self.collectionView.item(at: indexPath) as? StageListItem {
                    item.applyTheme()
                }
            }
            self.collectionView.reloadData()
        }
    }
    
    /// Set stages directly (used for search filtering)
    func setStages(_ newStages: [StageInfo]) {
        updateStages(newStages)
    }
    
    private func updateStages(_ newStages: [StageInfo]) {
        self.allStages = newStages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        applyFilters()
    }
    
    /// Apply registration filter to stages
    private func applyFilters() {
        switch registrationFilter {
        case .all:
            stages = allStages
        case .registeredOnly:
            stages = allStages.filter { $0.status == .active || $0.status == .disabled }
        case .unregisteredOnly:
            stages = allStages.filter { $0.status == .unregistered }
        }
        collectionView.reloadData()
    }
    
    // MARK: - Public Methods
    
    func refresh() {
        updateStages(IkemenBridge.shared.stages)
    }

    deinit {
        if let themeObserver = themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }
}

// MARK: - NSCollectionViewDataSource

extension StageBrowserView: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return stages.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let stage = stages[indexPath.item]
        
        let item = collectionView.makeItem(withIdentifier: StageListItem.identifier, for: indexPath) as! StageListItem
        item.configure(with: stage)
        
        // Wire up the toggle callback
        item.onStatusToggled = { [weak self] isEnabled in
            // Toggle means we're changing the state
            self?.onStageDisableToggle?(stage)
        }
        
        // Wire up the more button callback
        item.onMoreClicked = { [weak self] stage, sourceView in
            self?.showContextMenuForListItem(stage, sourceView: sourceView)
        }
        
        return item
    }
    
    /// Show context menu from the more button in list view
    private func showContextMenuForListItem(_ stage: StageInfo, sourceView: NSView) {
        guard let index = stages.firstIndex(where: { $0.id == stage.id }) else { return }
        let indexPath = IndexPath(item: index, section: 0)
        
        guard let menu = buildContextMenu(for: indexPath) else { return }
        
        // Position menu below the button
        let buttonBounds = sourceView.bounds
        let menuLocation = NSPoint(x: buttonBounds.midX, y: buttonBounds.minY)
        menu.popUp(positioning: nil, at: menuLocation, in: sourceView)
    }
}

// MARK: - NSCollectionViewDelegate

extension StageBrowserView: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let stage = stages[indexPath.item]
        onStageSelected?(stage)
    }
}

// MARK: - Context Menu

extension StageBrowserView {
    
    /// Build context menu for a stage at the given index path
    func buildContextMenu(for indexPath: IndexPath) -> NSMenu? {
        guard indexPath.item < stages.count else { return nil }
        
        let stage = stages[indexPath.item]
        let menu = NSMenu()
        
        // If unregistered, show "Add to select.def" option first
        if stage.status == .unregistered {
            let addToSelectDefItem = NSMenuItem(
                title: "Add to select.def",
                action: #selector(addStageToSelectDefAction(_:)),
                keyEquivalent: ""
            )
            addToSelectDefItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
            addToSelectDefItem.representedObject = stage
            addToSelectDefItem.target = self
            menu.addItem(addToSelectDefItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Disable/Enable toggle (only for registered stages)
        if stage.status != .unregistered {
            let disableItem = NSMenuItem()
            if stage.isDisabled {
                disableItem.title = "Enable Stage"
                disableItem.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
            } else {
                disableItem.title = "Disable Stage"
                disableItem.image = NSImage(systemSymbolName: "slash.circle", accessibilityDescription: nil)
            }
            disableItem.target = self
            disableItem.action = #selector(toggleDisableStage(_:))
            disableItem.representedObject = stage
            menu.addItem(disableItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Rename Stage
        let renameItem = NSMenuItem()
        renameItem.title = "Rename Stage…"
        renameItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        renameItem.target = self
        renameItem.action = #selector(renameStageAction(_:))
        renameItem.representedObject = stage
        menu.addItem(renameItem)
        
        // Reveal in Finder
        let revealItem = NSMenuItem()
        revealItem.title = "Reveal in Finder"
        revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        revealItem.target = self
        revealItem.action = #selector(revealStageInFinder(_:))
        revealItem.representedObject = stage
        menu.addItem(revealItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Remove
        let removeItem = NSMenuItem()
        removeItem.title = "Remove Stage…"
        removeItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        removeItem.target = self
        removeItem.action = #selector(removeStage(_:))
        removeItem.representedObject = stage
        menu.addItem(removeItem)
        
        return menu
    }
    
    @objc private func toggleDisableStage(_ sender: NSMenuItem) {
        guard let stage = sender.representedObject as? StageInfo else { return }
        onStageDisableToggle?(stage)
    }
    
    @objc private func addStageToSelectDefAction(_ sender: NSMenuItem) {
        guard let stage = sender.representedObject as? StageInfo,
              let workingDir = IkemenBridge.shared.workingDirectory else { return }
        
        do {
            // Get the stage entry name from the defFile
            let stageName = stage.defFile.deletingPathExtension().lastPathComponent
            
            // Add to select.def
            try ContentManager.shared.addStageToSelectDef(stageName, in: workingDir)
            
            // Reload stages to update status
            IkemenBridge.shared.loadContent()
            
            // Show success toast
            ToastManager.shared.showSuccess(
                title: "Added to select.def",
                subtitle: "\(stage.name) will now appear in-game"
            )
        } catch {
            ToastManager.shared.showError(
                title: "Failed to add stage",
                subtitle: error.localizedDescription
            )
        }
    }
    
    @objc private func renameStageAction(_ sender: NSMenuItem) {
        guard let stage = sender.representedObject as? StageInfo else { return }
        showRenameDialog(for: stage)
    }
    
    private func showRenameDialog(for stage: StageInfo) {
        let alert = NSAlert()
        alert.messageText = "Rename Stage"
        alert.informativeText = "Enter a new name for this stage. This will update the DEF file."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        // Create text field with current name
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = stage.name
        textField.placeholderString = "Stage name"
        
        // If current name is suspicious (single letter), suggest a better one
        if ContentManager.shared.stageNeedsBetterName(stage) {
            textField.stringValue = ContentManager.shared.suggestStageName(stage)
        }
        
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !newName.isEmpty else {
                ToastManager.shared.showError(title: "Name cannot be empty")
                return
            }
            
            do {
                try ContentManager.shared.renameStage(stage, to: newName)
                IkemenBridge.shared.loadContent()
                ToastManager.shared.showSuccess(title: "Renamed to \"\(newName)\"")
            } catch {
                ToastManager.shared.showError(
                    title: "Failed to rename stage",
                    subtitle: error.localizedDescription
                )
            }
        }
    }
    
    @objc private func revealStageInFinder(_ sender: NSMenuItem) {
        guard let stage = sender.representedObject as? StageInfo else { return }
        onStageRevealInFinder?(stage)
    }
    
    @objc private func removeStage(_ sender: NSMenuItem) {
        guard let stage = sender.representedObject as? StageInfo else { return }
        onStageRemove?(stage)
    }
}

// MARK: - Stage List Item (Row View)

class StageListItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("StageListItem")
    
    private var containerView: NSView!
    private var borderLine: NSView!
    private var previewContainer: NSView!
    private var previewImageView: NSImageView!
    private var disabledOverlay: NSView!
    private var disabledIcon: NSImageView!
    private var nameStack: NSStackView!
    private var nameLabel: NSTextField!
    private var pathLabel: NSTextField!
    private var audioBadge: NSView!
    private var audioBadgeIcon: NSImageView!
    private var audioBadgeLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var statusToggle: NSSwitch!
    private var moreButton: NSButton!
    
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    
    private let animationDuration: CGFloat = 0.2
    
    // Column widths (matching HTML design)
    private let previewWidth: CGFloat = 180
    private let previewHeight: CGFloat = 80
    private let toggleColumnWidth: CGFloat = 52
    private let moreColumnWidth: CGFloat = 44
    private let rightPadding: CGFloat = 24
    
    // Minimum widths for flexible columns
    private let nameMinWidth: CGFloat = 160
    private let audioMinWidth: CGFloat = 70
    private let dateMinWidth: CGFloat = 80
    
    // Column width constraints
    private var nameWidthConstraint: NSLayoutConstraint?
    private var dateWidthConstraint: NSLayoutConstraint?
    
    // Callbacks
    var onStatusToggled: ((Bool) -> Void)?
    var onMoreClicked: ((StageInfo, NSView) -> Void)?
    private var currentStage: StageInfo?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 98))
        view.wantsLayer = true
        setupViews()
    }
    
    private func setupViews() {
        // Container - row with bottom border
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        view.addSubview(containerView)
        
        // Bottom border line
        borderLine = NSView()
        borderLine.translatesAutoresizingMaskIntoConstraints = false
        borderLine.wantsLayer = true
        borderLine.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        containerView.addSubview(borderLine)
        
        // Preview container with rounded corners and border
        previewContainer = NSView()
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.wantsLayer = true
        previewContainer.layer?.cornerRadius = 6
        previewContainer.layer?.borderWidth = 1
        previewContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        previewContainer.layer?.masksToBounds = true
        previewContainer.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        containerView.addSubview(previewContainer)
        
        // Preview image
        previewImageView = NSImageView()
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.alphaValue = 0.6  // Default dimmed
        previewContainer.addSubview(previewImageView)
        
        // Disabled overlay
        disabledOverlay = NSView()
        disabledOverlay.translatesAutoresizingMaskIntoConstraints = false
        disabledOverlay.wantsLayer = true
        disabledOverlay.layer?.backgroundColor = DesignColors.overlayDim.withAlphaComponent(0.2).cgColor
        disabledOverlay.isHidden = true
        previewContainer.addSubview(disabledOverlay)
        
        // Disabled icon (eye-off)
        disabledIcon = NSImageView()
        disabledIcon.translatesAutoresizingMaskIntoConstraints = false
        disabledIcon.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
        disabledIcon.contentTintColor = DesignColors.textDisabled
        disabledIcon.isHidden = true
        previewContainer.addSubview(disabledIcon)
        
        // Name + path stack
        nameStack = NSStackView()
        nameStack.translatesAutoresizingMaskIntoConstraints = false
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = 2
        containerView.addSubview(nameStack)
        
        // Name label
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.textColor = DesignColors.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        nameStack.addArrangedSubview(nameLabel)
        
        // Path label (mono font)
        pathLabel = NSTextField(labelWithString: "")
        pathLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        pathLabel.textColor = DesignColors.textTertiary
        pathLabel.lineBreakMode = .byTruncatingTail
        nameStack.addArrangedSubview(pathLabel)
        
        // Audio badge
        audioBadge = NSView()
        audioBadge.translatesAutoresizingMaskIntoConstraints = false
        audioBadge.wantsLayer = true
        audioBadge.layer?.cornerRadius = 4
        containerView.addSubview(audioBadge)
        
        // Audio badge icon
        audioBadgeIcon = NSImageView()
        audioBadgeIcon.translatesAutoresizingMaskIntoConstraints = false
        audioBadgeIcon.imageScaling = .scaleProportionallyDown
        audioBadge.addSubview(audioBadgeIcon)
        
        // Audio badge label
        audioBadgeLabel = NSTextField(labelWithString: "")
        audioBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        audioBadgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        audioBadge.addSubview(audioBadgeLabel)
        
        // Date label
        dateLabel = NSTextField(labelWithString: "")
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = DesignColors.textTertiary
        dateLabel.alignment = .right
        containerView.addSubview(dateLabel)
        
        // Status toggle (enabled/disabled)
        statusToggle = NSSwitch()
        statusToggle.translatesAutoresizingMaskIntoConstraints = false
        statusToggle.controlSize = .small
        statusToggle.target = self
        statusToggle.action = #selector(statusToggleChanged(_:))
        containerView.addSubview(statusToggle)
        
        // More button (ellipsis)
        moreButton = NSButton(title: "•••", target: self, action: #selector(moreButtonClicked(_:)))
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.bezelStyle = .inline
        moreButton.isBordered = false
        moreButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        moreButton.contentTintColor = DesignColors.textSecondary
        moreButton.alphaValue = 0 // Hidden by default, shown on hover
        containerView.addSubview(moreButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            borderLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            borderLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            borderLine.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            borderLine.heightAnchor.constraint(equalToConstant: 1),
            
            // Preview container: 16px from left, centered vertically
            previewContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            previewContainer.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            previewContainer.widthAnchor.constraint(equalToConstant: previewWidth),
            previewContainer.heightAnchor.constraint(equalToConstant: previewHeight),
            
            // Preview image fills container
            previewImageView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            
            // Disabled overlay fills preview
            disabledOverlay.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            disabledOverlay.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            disabledOverlay.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            disabledOverlay.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            
            // Disabled icon centered in preview
            disabledIcon.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            disabledIcon.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            disabledIcon.widthAnchor.constraint(equalToConstant: 16),
            disabledIcon.heightAnchor.constraint(equalToConstant: 16),
            
            // More button (fixed right)
            moreButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -rightPadding),
            moreButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: moreColumnWidth),
            
            // Status toggle (fixed right, with gap from more button)
            statusToggle.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -12),
            statusToggle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Audio badge constraints (internal)
            audioBadgeIcon.leadingAnchor.constraint(equalTo: audioBadge.leadingAnchor, constant: 8),
            audioBadgeIcon.centerYAnchor.constraint(equalTo: audioBadge.centerYAnchor),
            audioBadgeIcon.widthAnchor.constraint(equalToConstant: 12),
            audioBadgeIcon.heightAnchor.constraint(equalToConstant: 12),
            
            audioBadgeLabel.leadingAnchor.constraint(equalTo: audioBadgeIcon.trailingAnchor, constant: 4),
            audioBadgeLabel.trailingAnchor.constraint(equalTo: audioBadge.trailingAnchor, constant: -8),
            audioBadgeLabel.centerYAnchor.constraint(equalTo: audioBadge.centerYAnchor),
            
            audioBadge.heightAnchor.constraint(equalToConstant: 24),
        ])
        
        // Name stack (flexible width)
        nameStack.leadingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: 16).isActive = true
        nameStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        nameWidthConstraint = nameStack.widthAnchor.constraint(equalToConstant: nameMinWidth)
        nameWidthConstraint?.isActive = true
        
        // Audio badge follows name
        audioBadge.leadingAnchor.constraint(equalTo: nameStack.trailingAnchor, constant: 16).isActive = true
        audioBadge.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        
        // Date (flexible width, anchored to right side)
        dateLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        dateLabel.trailingAnchor.constraint(equalTo: statusToggle.leadingAnchor, constant: -24).isActive = true
        dateWidthConstraint = dateLabel.widthAnchor.constraint(equalToConstant: dateMinWidth)
        dateWidthConstraint?.isActive = true
    }
    
    /// Update column widths based on available space
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Calculate available width for flexible columns
        let totalWidth = view.bounds.width
        
        // Fixed widths: leftPad(16) + preview(180) + gap(16) + ... + gap(24) + toggle(52) + gap(12) + more(44) + rightPad(24)
        let leftFixedWidth: CGFloat = 16 + previewWidth + 16  // left padding + preview + gap to name
        let rightFixedWidth: CGFloat = 24 + toggleColumnWidth + 12 + moreColumnWidth + rightPadding
        let fixedWidth = leftFixedWidth + rightFixedWidth
        
        // Audio badge hugs content - estimate width
        let audioWidth: CGFloat = audioMinWidth
        
        // Gaps between columns: name-audio(16), audio-date(16)
        let gapsWidth: CGFloat = 16 + 16
        
        let flexWidth = totalWidth - fixedWidth - audioWidth - gapsWidth
        
        // Distribute space proportionally
        let nameWidth = max(nameMinWidth, flexWidth * 0.65)
        let dateWidth = max(dateMinWidth, flexWidth * 0.35)
        
        nameWidthConstraint?.constant = nameWidth
        dateWidthConstraint?.constant = dateWidth
        
        setupTrackingArea()
    }
    
    // MARK: - Tracking Area & Hover
    
    private func setupTrackingArea() {
        if let existingArea = trackingArea {
            view.removeTrackingArea(existingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateHoverState()
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateHoverState()
    }
    
    private func updateHoverState() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            
            if isHovered {
                // Show hover state
                containerView.animator().layer?.backgroundColor = DesignColors.hoverBackground.cgColor
                moreButton.animator().alphaValue = 1.0
                
                // If not disabled, brighten image and text
                if currentStage?.isDisabled != true {
                    previewImageView.animator().alphaValue = 1.0
                    nameLabel.animator().textColor = DesignColors.textPrimary
                }
            } else {
                // Return to normal
                containerView.animator().layer?.backgroundColor = NSColor.clear.cgColor
                moreButton.animator().alphaValue = 0
                
                // Return to dimmed state
                if currentStage?.isDisabled != true {
                    previewImageView.animator().alphaValue = 0.6
                    nameLabel.animator().textColor = DesignColors.textPrimary
                }
            }
        }
    }
    
    @objc private func statusToggleChanged(_ sender: NSSwitch) {
        onStatusToggled?(sender.state == .on)
    }
    
    @objc private func moreButtonClicked(_ sender: NSButton) {
        guard let stage = currentStage else { return }
        onMoreClicked?(stage, sender)
    }
    
    func configure(with stage: StageInfo) {
        currentStage = stage
        nameLabel.stringValue = stage.name
        
        // Show path relative to stages folder
        pathLabel.stringValue = "stages/\(stage.defFileName)"
        
        // Configure audio badge based on whether stage has music
        configureAudioBadge(hasMusic: stage.hasBGM)
        
        // Format date
        if let modDate = stage.modificationDate {
            dateLabel.stringValue = formatRelativeDate(modDate)
        } else {
            dateLabel.stringValue = "—"
        }
        
        // Toggle state - hide for unregistered stages
        if stage.status == .unregistered {
            statusToggle.isHidden = true
        } else {
            statusToggle.isHidden = false
            statusToggle.state = stage.isDisabled ? .off : .on
        }
        
        // Show visual state based on status
        if stage.status == .unregistered {
            // Unregistered: dimmed
            previewImageView.alphaValue = 0.3
            disabledOverlay.isHidden = false
            disabledIcon.isHidden = false
            nameLabel.textColor = DesignColors.textSecondary
            nameLabel.stringValue = stage.name
            pathLabel.textColor = DesignColors.textDisabled
            view.toolTip = "Not in select.def - won't appear in game"
        } else if stage.isDisabled {
            // Disabled: strikethrough and dimmed
            previewImageView.alphaValue = 0.4
            disabledOverlay.isHidden = false
            disabledIcon.isHidden = false
            nameLabel.textColor = DesignColors.textTertiary
            // Strikethrough effect using attributed string
            let attributes: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: DesignColors.textDisabled
            ]
            nameLabel.attributedStringValue = NSAttributedString(string: stage.name, attributes: attributes)
            pathLabel.textColor = DesignColors.textDisabled
            view.toolTip = nil
        } else {
            // Active: normal
            previewImageView.alphaValue = 0.6
            disabledOverlay.isHidden = true
            disabledIcon.isHidden = true
            nameLabel.textColor = DesignColors.textPrimary
            nameLabel.stringValue = stage.name  // Remove strikethrough
            pathLabel.textColor = DesignColors.textTertiary
            view.toolTip = nil
        }
        
        // Load preview image
        loadPreviewImage(for: stage)
        
        // Apply base theme colors (borders, etc.)
        applyTheme()
    }
    
    private func configureAudioBadge(hasMusic: Bool) {
        if hasMusic {
            // BGM badge - emerald/green style
            audioBadge.layer?.backgroundColor = DesignColors.positiveBackground.cgColor
            audioBadge.layer?.borderWidth = 1
            audioBadge.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.3).cgColor
            audioBadgeIcon.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
            audioBadgeIcon.contentTintColor = DesignColors.positive
            audioBadgeLabel.stringValue = "BGM"
            audioBadgeLabel.textColor = DesignColors.positive
        } else {
            // No audio badge - gray style
            audioBadge.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
            audioBadge.layer?.borderWidth = 1
            audioBadge.layer?.borderColor = DesignColors.borderSubtle.cgColor
            audioBadgeIcon.image = NSImage(systemSymbolName: "speaker.slash", accessibilityDescription: nil)
            audioBadgeIcon.contentTintColor = DesignColors.textTertiary
            audioBadgeLabel.stringValue = "None"
            audioBadgeLabel.textColor = DesignColors.textTertiary
        }
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        let minute: TimeInterval = 60
        let hour: TimeInterval = 60 * minute
        let day: TimeInterval = 24 * hour
        let week: TimeInterval = 7 * day
        let month: TimeInterval = 30 * day
        
        if interval < hour {
            return "Just now"
        } else if interval < day {
            let hours = Int(interval / hour)
            return "\(hours)h ago"
        } else if interval < 2 * day {
            return "Yesterday"
        } else if interval < week {
            let days = Int(interval / day)
            return "\(days)d ago"
        } else if interval < month {
            let weeks = Int(interval / week)
            return "\(weeks)w ago"
        } else {
            let months = Int(interval / month)
            return "\(months)mo ago"
        }
    }
    
    private func loadPreviewImage(for stage: StageInfo) {
        // Check cache first
        let cacheKey = ImageCache.stagePreviewKey(for: stage.id)
        if let cached = ImageCache.shared.get(cacheKey) {
            previewImageView.image = cached
            return
        }
        
        // Load preview image asynchronously
        previewImageView.image = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let image = stage.loadPreviewImage() {
                // Store in cache
                ImageCache.shared.set(image, for: cacheKey)
                DispatchQueue.main.async { [weak self] in
                    self?.previewImageView.image = image
                }
            }
        }
    }
    
    /// Update all theme-dependent colors
    func applyTheme() {
        // Border line
        borderLine.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        
        // Preview container
        previewContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        previewContainer.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        
        // Disabled overlay
        disabledOverlay.layer?.backgroundColor = DesignColors.overlayDim.withAlphaComponent(0.2).cgColor
        disabledIcon.contentTintColor = DesignColors.textDisabled
        
        // Text colors
        nameLabel.textColor = DesignColors.textPrimary
        pathLabel.textColor = DesignColors.textTertiary
        dateLabel.textColor = DesignColors.textTertiary
        
        // More button
        moreButton.contentTintColor = DesignColors.textSecondary
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        previewImageView.alphaValue = 0.6
        nameLabel.stringValue = ""
        pathLabel.stringValue = ""
        dateLabel.stringValue = ""
        disabledOverlay.isHidden = true
        disabledIcon.isHidden = true
        statusToggle.state = .on
        moreButton.alphaValue = 0
        currentStage = nil
        onStatusToggled = nil
        onMoreClicked = nil
        isHovered = false
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Apply current theme colors
        applyTheme()
    }
}
