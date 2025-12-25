import Cocoa
import Combine

/// A visual browser for viewing installed screenpacks with thumbnails
/// Shows active screenpack with visual indicator
class ScreenpackBrowserView: NSView {
    
    // MARK: - Properties
    
    private var scrollView: NSScrollView!
    private var collectionView: NSCollectionView!
    private var flowLayout: NSCollectionViewFlowLayout!
    private var screenpacks: [ScreenpackInfo] = []
    private var cancellables = Set<AnyCancellable>()
    
    // View mode
    var viewMode: BrowserViewMode = .grid {
        didSet {
            updateLayoutForViewMode()
        }
    }
    
    // Layout constants from shared design system
    private let gridItemWidth = BrowserLayout.stageGridItemWidth   // Same as stages - wide cards
    private let gridItemHeight = BrowserLayout.stageGridItemHeight
    private let listItemHeight = BrowserLayout.listItemHeight
    private let cardSpacing = BrowserLayout.cardSpacing
    private let sectionInset = BrowserLayout.sectionInset
    
    var onScreenpackSelected: ((ScreenpackInfo) -> Void)?
    var onScreenpackActivate: ((ScreenpackInfo) -> Void)?
    
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
        collectionView.register(ScreenpackGridItem.self, forItemWithIdentifier: ScreenpackGridItem.identifier)
        collectionView.register(ScreenpackListItem.self, forItemWithIdentifier: ScreenpackListItem.identifier)
        
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
        IkemenBridge.shared.$screenpacks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] screenpacks in
                self?.updateScreenpacks(screenpacks)
            }
            .store(in: &cancellables)
    }
    
    private func updateScreenpacks(_ newScreenpacks: [ScreenpackInfo]) {
        // Sort: active first, then alphabetical
        self.screenpacks = newScreenpacks.sorted { 
            if $0.isActive != $1.isActive {
                return $0.isActive
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending 
        }
        collectionView.reloadData()
    }
    
    // MARK: - Public Methods
    
    func refresh() {
        updateScreenpacks(IkemenBridge.shared.screenpacks)
    }
}

// MARK: - NSCollectionViewDataSource

extension ScreenpackBrowserView: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return screenpacks.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let screenpack = screenpacks[indexPath.item]
        
        if viewMode == .grid {
            let item = collectionView.makeItem(withIdentifier: ScreenpackGridItem.identifier, for: indexPath) as! ScreenpackGridItem
            item.configure(with: screenpack)
            item.onActivate = { [weak self] in
                self?.onScreenpackActivate?(screenpack)
            }
            return item
        } else {
            let item = collectionView.makeItem(withIdentifier: ScreenpackListItem.identifier, for: indexPath) as! ScreenpackListItem
            item.configure(with: screenpack)
            item.onActivate = { [weak self] in
                self?.onScreenpackActivate?(screenpack)
            }
            return item
        }
    }
}

// MARK: - NSCollectionViewDelegate

extension ScreenpackBrowserView: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let screenpack = screenpacks[indexPath.item]
        onScreenpackSelected?(screenpack)
    }
}

// MARK: - Screenpack Grid Item (Card View)

class ScreenpackGridItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("ScreenpackGridItem")
    
    private var containerView: NSView!
    private var previewImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var activeBadge: NSView!
    private var activeBadgeLabel: NSTextField!
    private var resolutionLabel: NSTextField!
    private var activateButton: NSButton!
    
    var onActivate: (() -> Void)?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
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
        
        // Preview image - wider aspect ratio for screenpacks
        previewImageView = NSImageView(frame: .zero)
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.backgroundColor = DesignColors.placeholderBackground.cgColor
        containerView.addSubview(previewImageView)
        
        // Active badge
        activeBadge = NSView()
        activeBadge.translatesAutoresizingMaskIntoConstraints = false
        activeBadge.wantsLayer = true
        activeBadge.layer?.backgroundColor = DesignColors.greenAccent.withAlphaComponent(0.2).cgColor
        activeBadge.layer?.cornerRadius = 4
        activeBadge.layer?.borderWidth = 1
        activeBadge.layer?.borderColor = DesignColors.greenAccent.cgColor
        activeBadge.isHidden = true
        containerView.addSubview(activeBadge)
        
        activeBadgeLabel = NSTextField(labelWithString: "Active")
        activeBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        activeBadgeLabel.font = DesignFonts.jersey(size: 12)
        activeBadgeLabel.textColor = DesignColors.greenAccent
        activeBadge.addSubview(activeBadgeLabel)
        
        // Resolution label (top-left)
        resolutionLabel = NSTextField(labelWithString: "")
        resolutionLabel.translatesAutoresizingMaskIntoConstraints = false
        resolutionLabel.font = DesignFonts.jersey(size: 12)
        resolutionLabel.textColor = DesignColors.grayText
        resolutionLabel.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.8)
        resolutionLabel.wantsLayer = true
        resolutionLabel.layer?.cornerRadius = 3
        resolutionLabel.isBordered = false
        resolutionLabel.isEditable = false
        containerView.addSubview(resolutionLabel)
        
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
        
        // Activate button
        activateButton = NSButton(title: "Activate", target: self, action: #selector(activateClicked))
        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.bezelStyle = .rounded
        activateButton.font = DesignFonts.jersey(size: 14)
        activateButton.isHidden = true
        containerView.addSubview(activateButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Preview: 12px from top, 12px sides, 90px tall
            previewImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            previewImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            previewImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            previewImageView.heightAnchor.constraint(equalToConstant: 90),
            
            // Active badge in top-right of preview
            activeBadge.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 4),
            activeBadge.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: -4),
            
            activeBadgeLabel.topAnchor.constraint(equalTo: activeBadge.topAnchor, constant: 2),
            activeBadgeLabel.bottomAnchor.constraint(equalTo: activeBadge.bottomAnchor, constant: -2),
            activeBadgeLabel.leadingAnchor.constraint(equalTo: activeBadge.leadingAnchor, constant: 6),
            activeBadgeLabel.trailingAnchor.constraint(equalTo: activeBadge.trailingAnchor, constant: -6),
            
            // Resolution in top-left
            resolutionLabel.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 4),
            resolutionLabel.leadingAnchor.constraint(equalTo: previewImageView.leadingAnchor, constant: 4),
            
            // Name: 4px below preview
            nameLabel.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            // Author: 2px below name
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            // Activate button: bottom right
            activateButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            activateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
        ])
    }
    
    @objc private func activateClicked() {
        onActivate?()
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
            // Show activate button when selected (if not already active)
            activateButton.isHidden = false
        } else {
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 1
            containerView.layer?.shadowOpacity = 0
            activateButton.isHidden = true
        }
    }
    
    func configure(with screenpack: ScreenpackInfo) {
        nameLabel.stringValue = screenpack.name
        authorLabel.stringValue = "by \(screenpack.author)"
        
        // Show resolution and component count
        let componentCount = screenpack.components.componentNames.count
        if componentCount > 0 {
            resolutionLabel.stringValue = " \(screenpack.resolutionString) • \(componentCount) components "
        } else {
            resolutionLabel.stringValue = " \(screenpack.resolutionString) "
        }
        
        // Show active badge
        if screenpack.isActive {
            activeBadge.isHidden = false
            containerView.layer?.borderColor = DesignColors.greenAccent.withAlphaComponent(0.5).cgColor
            containerView.layer?.borderWidth = 2
            activateButton.isHidden = true // Can't activate already active
        } else {
            activeBadge.isHidden = true
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 1
        }
        
        // Check cache first
        let cacheKey = "screenpack:\(screenpack.id)"
        if let cached = ImageCache.shared.get(cacheKey) {
            previewImageView.image = cached
            return
        }
        
        // Load preview image asynchronously
        previewImageView.image = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let image = screenpack.loadPreviewImage() {
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
        resolutionLabel.stringValue = ""
        activeBadge.isHidden = true
        activateButton.isHidden = true
        isSelected = false
        onActivate = nil
    }
}

// MARK: - Screenpack List Item (Row View)

class ScreenpackListItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("ScreenpackListItem")
    
    private var containerView: NSView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var resolutionLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var activateButton: NSButton!
    
    var onActivate: (() -> Void)?
    
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
        
        // Resolution
        resolutionLabel = NSTextField(labelWithString: "")
        resolutionLabel.translatesAutoresizingMaskIntoConstraints = false
        resolutionLabel.font = DesignFonts.jersey(size: 18)
        resolutionLabel.textColor = DesignColors.grayText
        containerView.addSubview(resolutionLabel)
        
        // Status (Active indicator)
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = DesignFonts.jersey(size: 18)
        statusLabel.textColor = DesignColors.greenAccent
        containerView.addSubview(statusLabel)
        
        // Activate button
        activateButton = NSButton(title: "Activate", target: self, action: #selector(activateClicked))
        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.bezelStyle = .rounded
        activateButton.font = DesignFonts.jersey(size: 14)
        activateButton.isHidden = true
        containerView.addSubview(activateButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            
            authorLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            
            resolutionLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            resolutionLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -20),
            
            statusLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: activateButton.leadingAnchor, constant: -12),
            
            activateButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            activateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
        ])
    }
    
    @objc private func activateClicked() {
        onActivate?()
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
            activateButton.isHidden = false
        } else {
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.borderWidth = 1
            containerView.layer?.shadowOpacity = 0
            activateButton.isHidden = true
        }
    }
    
    func configure(with screenpack: ScreenpackInfo) {
        nameLabel.stringValue = screenpack.name
        
        // Show author and component summary
        let componentSummary = screenpack.componentSummary
        if componentSummary != "Standard Screenpack" {
            authorLabel.stringValue = "by \(screenpack.author) • \(componentSummary)"
        } else {
            authorLabel.stringValue = "by \(screenpack.author)"
        }
        
        resolutionLabel.stringValue = screenpack.resolutionString
        
        if screenpack.isActive {
            statusLabel.stringValue = "● Active"
            statusLabel.textColor = DesignColors.greenAccent
            containerView.layer?.borderColor = DesignColors.greenAccent.withAlphaComponent(0.3).cgColor
            containerView.layer?.borderWidth = 1
            activateButton.isHidden = true
        } else {
            statusLabel.stringValue = ""
            containerView.layer?.borderColor = NSColor.clear.cgColor
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        resolutionLabel.stringValue = ""
        statusLabel.stringValue = ""
        activateButton.isHidden = true
        isSelected = false
        onActivate = nil
    }
}
