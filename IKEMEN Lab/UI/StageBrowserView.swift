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
    private var stages: [StageInfo] = []
    private var cancellables = Set<AnyCancellable>()
    
    // View mode
    var viewMode: BrowserViewMode = .grid {
        didSet {
            updateLayoutForViewMode()
        }
    }
    
    // Layout constants from shared design system
    private let gridItemWidth = BrowserLayout.stageGridItemWidth
    private let gridItemHeight = BrowserLayout.stageGridItemHeight
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
        
        // Create flow layout
        flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: gridItemWidth, height: gridItemHeight)
        flowLayout.minimumInteritemSpacing = cardSpacing
        flowLayout.minimumLineSpacing = cardSpacing
        flowLayout.sectionInset = NSEdgeInsets(top: sectionInset, left: sectionInset, bottom: sectionInset, right: sectionInset)
        
        // Create collection view (using custom subclass)
        collectionView = StageCollectionView(frame: bounds)
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        
        // Register item classes
        collectionView.register(StageGridItem.self, forItemWithIdentifier: StageGridItem.identifier)
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
        let itemWidth = viewMode == .grid ? gridItemWidth : width
        let itemHeight = viewMode == .grid ? gridItemHeight : listItemHeight
        
        if viewMode == .grid {
            // Calculate how many items can fit
            let availableWidth = width - (sectionInset * 2)
            let itemsPerRow = max(1, floor((availableWidth + cardSpacing) / (itemWidth + cardSpacing)))
            
            // Calculate spacing to distribute items evenly
            let totalItemWidth = itemsPerRow * itemWidth
            let totalSpacing = availableWidth - totalItemWidth
            let spacing = max(cardSpacing, totalSpacing / max(1, itemsPerRow - 1))
            
            flowLayout.minimumInteritemSpacing = spacing
            flowLayout.itemSize = NSSize(width: itemWidth, height: itemHeight)
        } else {
            flowLayout.minimumInteritemSpacing = 8
            flowLayout.itemSize = NSSize(width: width, height: itemHeight)
        }
        
        flowLayout.invalidateLayout()
    }
    
    private func updateLayoutForViewMode() {
        collectionView.reloadData()
        updateLayoutForWidth(bounds.width)
    }
    
    // MARK: - Data Binding
    
    private func setupObservers() {
        IkemenBridge.shared.$stages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stages in
                self?.updateStages(stages)
            }
            .store(in: &cancellables)
    }
    
    /// Set stages directly (used for search filtering)
    func setStages(_ newStages: [StageInfo]) {
        updateStages(newStages)
    }
    
    private func updateStages(_ newStages: [StageInfo]) {
        self.stages = newStages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        collectionView.reloadData()
    }
    
    // MARK: - Public Methods
    
    func refresh() {
        updateStages(IkemenBridge.shared.stages)
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
        
        if viewMode == .grid {
            let item = collectionView.makeItem(withIdentifier: StageGridItem.identifier, for: indexPath) as! StageGridItem
            item.configure(with: stage)
            return item
        } else {
            let item = collectionView.makeItem(withIdentifier: StageListItem.identifier, for: indexPath) as! StageListItem
            item.configure(with: stage)
            
            // Wire up the toggle callback
            item.onStatusToggled = { [weak self] isEnabled in
                // Toggle means we're changing the state
                self?.onStageDisableToggle?(stage)
            }
            
            return item
        }
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
        
        // Disable/Enable toggle
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
    
    @objc private func revealStageInFinder(_ sender: NSMenuItem) {
        guard let stage = sender.representedObject as? StageInfo else { return }
        onStageRevealInFinder?(stage)
    }
    
    @objc private func removeStage(_ sender: NSMenuItem) {
        guard let stage = sender.representedObject as? StageInfo else { return }
        onStageRemove?(stage)
    }
}

// MARK: - Stage Grid Item (Card View)

class StageGridItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("StageGridItem")
    
    private var containerView: NSView!
    private var previewImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var sizeBadge: NSView!
    private var sizeBadgeLabel: NSTextField!
    private var disabledBadge: NSView!
    private var disabledBadgeLabel: NSTextField!
    private var disabledOverlay: NSView!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 160))
        view.wantsLayer = true
        
        setupViews()
    }
    
    private func setupViews() {
        // Container
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.clear.cgColor
        view.addSubview(containerView)
        
        // Preview image - wider aspect ratio for stages
        previewImageView = NSImageView(frame: .zero)
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.backgroundColor = DesignColors.placeholderBackground.cgColor
        containerView.addSubview(previewImageView)
        
        // Disabled overlay (semi-transparent dark layer)
        disabledOverlay = NSView()
        disabledOverlay.translatesAutoresizingMaskIntoConstraints = false
        disabledOverlay.wantsLayer = true
        disabledOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        disabledOverlay.isHidden = true
        containerView.addSubview(disabledOverlay)
        
        // Size badge (for wide stages)
        sizeBadge = NSView()
        sizeBadge.translatesAutoresizingMaskIntoConstraints = false
        sizeBadge.wantsLayer = true
        sizeBadge.layer?.backgroundColor = DesignColors.greenAccent.withAlphaComponent(0.2).cgColor
        sizeBadge.layer?.cornerRadius = 4
        sizeBadge.layer?.borderWidth = 1
        sizeBadge.layer?.borderColor = DesignColors.greenAccent.cgColor
        sizeBadge.isHidden = true
        containerView.addSubview(sizeBadge)
        
        sizeBadgeLabel = NSTextField(labelWithString: "Wide")
        sizeBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeBadgeLabel.font = DesignFonts.caption(size: 11)
        sizeBadgeLabel.textColor = DesignColors.greenAccent
        sizeBadge.addSubview(sizeBadgeLabel)
        
        // Disabled badge
        disabledBadge = NSView()
        disabledBadge.translatesAutoresizingMaskIntoConstraints = false
        disabledBadge.wantsLayer = true
        disabledBadge.layer?.backgroundColor = DesignColors.redAccent.withAlphaComponent(0.2).cgColor
        disabledBadge.layer?.cornerRadius = 4
        disabledBadge.layer?.borderWidth = 1
        disabledBadge.layer?.borderColor = DesignColors.redAccent.cgColor
        disabledBadge.isHidden = true
        containerView.addSubview(disabledBadge)
        
        disabledBadgeLabel = NSTextField(labelWithString: "Disabled")
        disabledBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        disabledBadgeLabel.font = DesignFonts.caption(size: 11)
        disabledBadgeLabel.textColor = DesignColors.redAccent
        disabledBadge.addSubview(disabledBadgeLabel)
        
        // Name label
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.header(size: 16)
        nameLabel.textColor = DesignColors.grayText
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        containerView.addSubview(nameLabel)
        
        // Author label
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.body(size: 12)
        authorLabel.textColor = DesignColors.grayText
        authorLabel.alignment = .center
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.maximumNumberOfLines = 1
        containerView.addSubview(authorLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Preview: 12px from top, 12px sides, 80px tall (16:9 aspect for 256px width)
            previewImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            previewImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            previewImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            previewImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Disabled overlay covers the preview image
            disabledOverlay.topAnchor.constraint(equalTo: previewImageView.topAnchor),
            disabledOverlay.leadingAnchor.constraint(equalTo: previewImageView.leadingAnchor),
            disabledOverlay.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor),
            disabledOverlay.bottomAnchor.constraint(equalTo: previewImageView.bottomAnchor),
            
            // Size badge in top-right of preview
            sizeBadge.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 4),
            sizeBadge.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: -4),
            
            sizeBadgeLabel.topAnchor.constraint(equalTo: sizeBadge.topAnchor, constant: 2),
            sizeBadgeLabel.bottomAnchor.constraint(equalTo: sizeBadge.bottomAnchor, constant: -2),
            sizeBadgeLabel.leadingAnchor.constraint(equalTo: sizeBadge.leadingAnchor, constant: 6),
            sizeBadgeLabel.trailingAnchor.constraint(equalTo: sizeBadge.trailingAnchor, constant: -6),
            
            // Disabled badge in top-left of preview
            disabledBadge.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 4),
            disabledBadge.leadingAnchor.constraint(equalTo: previewImageView.leadingAnchor, constant: 4),
            
            disabledBadgeLabel.topAnchor.constraint(equalTo: disabledBadge.topAnchor, constant: 2),
            disabledBadgeLabel.bottomAnchor.constraint(equalTo: disabledBadge.bottomAnchor, constant: -2),
            disabledBadgeLabel.leadingAnchor.constraint(equalTo: disabledBadge.leadingAnchor, constant: 6),
            disabledBadgeLabel.trailingAnchor.constraint(equalTo: disabledBadge.trailingAnchor, constant: -6),
            
            // Name: 4px below preview
            nameLabel.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            // Author: 4px below name
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
        ])
    }
    
    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }
    
    private func updateSelectionAppearance() {
        if isSelected {
            containerView.layer?.borderColor = DesignColors.selectedBorder.cgColor
            containerView.layer?.borderWidth = 1
            containerView.layer?.shadowColor = DesignColors.selectedBorder.cgColor
            containerView.layer?.shadowOffset = CGSize.zero
            containerView.layer?.shadowRadius = 18
            containerView.layer?.shadowOpacity = 0.4
        } else {
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 1
            containerView.layer?.shadowOpacity = 0
        }
    }
    
    func configure(with stage: StageInfo) {
        nameLabel.stringValue = stage.name
        authorLabel.stringValue = "by \(stage.author)"
        
        // Show size badge for wide stages
        if stage.isWideStage {
            sizeBadge.isHidden = false
            sizeBadgeLabel.stringValue = stage.sizeCategory
        } else {
            sizeBadge.isHidden = true
        }
        
        // Show disabled state
        if stage.isDisabled {
            disabledBadge.isHidden = false
            disabledOverlay.isHidden = false
            nameLabel.textColor = DesignColors.grayText.withAlphaComponent(0.5)
            authorLabel.textColor = DesignColors.grayText.withAlphaComponent(0.5)
        } else {
            disabledBadge.isHidden = true
            disabledOverlay.isHidden = true
            nameLabel.textColor = DesignColors.grayText
            authorLabel.textColor = DesignColors.grayText
        }
        
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
                DispatchQueue.main.async {
                    self?.previewImageView.image = image
                }
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        sizeBadge.isHidden = true
        disabledBadge.isHidden = true
        disabledOverlay.isHidden = true
        nameLabel.textColor = DesignColors.grayText
        authorLabel.textColor = DesignColors.grayText
        isSelected = false
    }
}

// MARK: - Stage List Item (Row View)

class StageListItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("StageListItem")
    
    private var containerView: NSView!
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
        let borderLine = NSView()
        borderLine.translatesAutoresizingMaskIntoConstraints = false
        borderLine.wantsLayer = true
        borderLine.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        containerView.addSubview(borderLine)
        
        // Preview container with rounded corners and border
        previewContainer = NSView()
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.wantsLayer = true
        previewContainer.layer?.cornerRadius = 6
        previewContainer.layer?.borderWidth = 1
        previewContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        previewContainer.layer?.masksToBounds = true
        previewContainer.layer?.backgroundColor = DesignColors.zinc900.cgColor
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
        disabledOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        disabledOverlay.isHidden = true
        previewContainer.addSubview(disabledOverlay)
        
        // Disabled icon (eye-off)
        disabledIcon = NSImageView()
        disabledIcon.translatesAutoresizingMaskIntoConstraints = false
        disabledIcon.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
        disabledIcon.contentTintColor = NSColor.white.withAlphaComponent(0.5)
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
        nameLabel.textColor = DesignColors.zinc300
        nameLabel.lineBreakMode = .byTruncatingTail
        nameStack.addArrangedSubview(nameLabel)
        
        // Path label (mono font)
        pathLabel = NSTextField(labelWithString: "")
        pathLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        pathLabel.textColor = DesignColors.zinc600
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
        dateLabel.textColor = DesignColors.zinc600
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
        moreButton.contentTintColor = DesignColors.zinc400
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
                containerView.animator().layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
                moreButton.animator().alphaValue = 1.0
                
                // If not disabled, brighten image and text
                if currentStage?.isDisabled != true {
                    previewImageView.animator().alphaValue = 1.0
                    nameLabel.animator().textColor = .white
                }
            } else {
                // Return to normal
                containerView.animator().layer?.backgroundColor = NSColor.clear.cgColor
                moreButton.animator().alphaValue = 0
                
                // Return to dimmed state
                if currentStage?.isDisabled != true {
                    previewImageView.animator().alphaValue = 0.6
                    nameLabel.animator().textColor = DesignColors.zinc300
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
        
        // Toggle state - ON means enabled, OFF means disabled
        statusToggle.state = stage.isDisabled ? .off : .on
        
        // Show disabled state
        if stage.isDisabled {
            previewImageView.alphaValue = 0.4
            disabledOverlay.isHidden = false
            disabledIcon.isHidden = false
            nameLabel.textColor = DesignColors.zinc500
            // Strikethrough effect using attributed string
            let attributes: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: DesignColors.zinc600
            ]
            nameLabel.attributedStringValue = NSAttributedString(string: stage.name, attributes: attributes)
            pathLabel.textColor = DesignColors.zinc700
        } else {
            previewImageView.alphaValue = 0.6
            disabledOverlay.isHidden = true
            disabledIcon.isHidden = true
            nameLabel.textColor = DesignColors.zinc300
            nameLabel.stringValue = stage.name  // Remove strikethrough
            pathLabel.textColor = DesignColors.zinc600
        }
        
        // Load preview image
        loadPreviewImage(for: stage)
    }
    
    private func configureAudioBadge(hasMusic: Bool) {
        if hasMusic {
            // BGM badge - emerald/green style
            audioBadge.layer?.backgroundColor = DesignColors.emerald500.withAlphaComponent(0.1).cgColor
            audioBadge.layer?.borderWidth = 1
            audioBadge.layer?.borderColor = DesignColors.emerald500.withAlphaComponent(0.2).cgColor
            audioBadgeIcon.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
            audioBadgeIcon.contentTintColor = DesignColors.emerald400
            audioBadgeLabel.stringValue = "BGM"
            audioBadgeLabel.textColor = DesignColors.emerald400
        } else {
            // No audio badge - gray style
            audioBadge.layer?.backgroundColor = DesignColors.zinc800.withAlphaComponent(0.5).cgColor
            audioBadge.layer?.borderWidth = 1
            audioBadge.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
            audioBadgeIcon.image = NSImage(systemSymbolName: "speaker.slash", accessibilityDescription: nil)
            audioBadgeIcon.contentTintColor = DesignColors.zinc500
            audioBadgeLabel.stringValue = "None"
            audioBadgeLabel.textColor = DesignColors.zinc500
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
                DispatchQueue.main.async {
                    self?.previewImageView.image = image
                }
            }
        }
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
        nameLabel.textColor = DesignColors.zinc300
        pathLabel.textColor = DesignColors.zinc600
    }
}
