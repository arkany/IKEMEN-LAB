import Cocoa
import Combine

/// A visual browser for viewing installed stages with thumbnails
/// Uses shared design system from UIHelpers.swift
class StageBrowserView: NSView {
    
    // MARK: - Properties
    
    private var scrollView: NSScrollView!
    private var collectionView: NSCollectionView!
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
        // Create scroll view
        scrollView = NSScrollView(frame: bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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
        
        // Create collection view
        collectionView = NSCollectionView(frame: bounds)
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        
        // Register item classes
        collectionView.register(StageGridItem.self, forItemWithIdentifier: StageGridItem.identifier)
        collectionView.register(StageListItem.self, forItemWithIdentifier: StageListItem.identifier)
        
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

// MARK: - Stage Grid Item (Card View)

class StageGridItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("StageGridItem")
    
    private var containerView: NSView!
    private var previewImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var sizeBadge: NSView!
    private var sizeBadgeLabel: NSTextField!
    
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
            
            // Size badge in top-right of preview
            sizeBadge.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 4),
            sizeBadge.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: -4),
            
            sizeBadgeLabel.topAnchor.constraint(equalTo: sizeBadge.topAnchor, constant: 2),
            sizeBadgeLabel.bottomAnchor.constraint(equalTo: sizeBadge.bottomAnchor, constant: -2),
            sizeBadgeLabel.leadingAnchor.constraint(equalTo: sizeBadge.leadingAnchor, constant: 6),
            sizeBadgeLabel.trailingAnchor.constraint(equalTo: sizeBadge.trailingAnchor, constant: -6),
            
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
        
        // Color code the size
        if stage.isWideStage {
            sizeLabel.textColor = DesignColors.greenAccent
        } else {
            sizeLabel.textColor = DesignColors.grayText
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        sizeLabel.stringValue = ""
        widthLabel.stringValue = ""
        isSelected = false
    }
}
