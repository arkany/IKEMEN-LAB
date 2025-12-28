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
    private let listItemHeight = BrowserLayout.listItemHeight
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
        sizeBadgeLabel.font = DesignFonts.jersey(size: 12)
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
        disabledBadgeLabel.font = DesignFonts.jersey(size: 12)
        disabledBadgeLabel.textColor = DesignColors.redAccent
        disabledBadge.addSubview(disabledBadgeLabel)
        
        // Name label
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.jersey(size: 24)
        nameLabel.textColor = DesignColors.grayText
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        containerView.addSubview(nameLabel)
        
        // Author label
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.jersey(size: 16)
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
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var sizeLabel: NSTextField!
    private var widthLabel: NSTextField!
    private var disabledLabel: NSTextField!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 60))
        view.wantsLayer = true
        
        setupViews()
    }
    
    private func setupViews() {
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.clear.cgColor
        view.addSubview(containerView)
        
        // Disabled label (shown before name)
        disabledLabel = NSTextField(labelWithString: "[Disabled]")
        disabledLabel.translatesAutoresizingMaskIntoConstraints = false
        disabledLabel.font = DesignFonts.jersey(size: 14)
        disabledLabel.textColor = DesignColors.redAccent
        disabledLabel.isHidden = true
        containerView.addSubview(disabledLabel)
        
        // Name
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.jersey(size: 24)
        nameLabel.textColor = DesignColors.creamText
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)
        
        // Author
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.jersey(size: 16)
        authorLabel.textColor = DesignColors.grayText
        authorLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(authorLabel)
        
        // Size category
        sizeLabel = NSTextField(labelWithString: "")
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.font = DesignFonts.jersey(size: 18)
        sizeLabel.textColor = DesignColors.greenAccent
        sizeLabel.alignment = .right
        containerView.addSubview(sizeLabel)
        
        // Width value
        widthLabel = NSTextField(labelWithString: "")
        widthLabel.translatesAutoresizingMaskIntoConstraints = false
        widthLabel.font = DesignFonts.jersey(size: 14)
        widthLabel.textColor = DesignColors.grayText
        widthLabel.alignment = .right
        containerView.addSubview(widthLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            disabledLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            disabledLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: sizeLabel.leadingAnchor, constant: -16),
            
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            
            sizeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            sizeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            
            widthLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            widthLabel.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 2),
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
            containerView.layer?.shadowRadius = 10
            containerView.layer?.shadowOpacity = 0.3
        } else {
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 1
            containerView.layer?.shadowOpacity = 0
        }
    }
    
    func configure(with stage: StageInfo) {
        nameLabel.stringValue = stage.name
        authorLabel.stringValue = "by \(stage.author)"
        sizeLabel.stringValue = stage.sizeCategory
        widthLabel.stringValue = "Width: \(stage.totalWidth)px"
        
        // Show disabled state
        if stage.isDisabled {
            disabledLabel.isHidden = false
            nameLabel.textColor = DesignColors.creamText.withAlphaComponent(0.5)
            authorLabel.textColor = DesignColors.grayText.withAlphaComponent(0.5)
            sizeLabel.textColor = DesignColors.grayText.withAlphaComponent(0.5)
            widthLabel.textColor = DesignColors.grayText.withAlphaComponent(0.5)
        } else {
            disabledLabel.isHidden = true
            nameLabel.textColor = DesignColors.creamText
            authorLabel.textColor = DesignColors.grayText
            // Color code the size
            if stage.isWideStage {
                sizeLabel.textColor = DesignColors.greenAccent
            } else {
                sizeLabel.textColor = DesignColors.grayText
            }
            widthLabel.textColor = DesignColors.grayText
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        sizeLabel.stringValue = ""
        widthLabel.stringValue = ""
        disabledLabel.isHidden = true
        nameLabel.textColor = DesignColors.creamText
        authorLabel.textColor = DesignColors.grayText
        isSelected = false
    }
}
