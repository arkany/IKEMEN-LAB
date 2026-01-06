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
        // Use max to ensure non-zero size (required by flow layout)
        flowLayout.itemSize = NSSize(width: max(gridItemWidth, 100), height: max(gridItemHeight, 100))
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
            flowLayout.itemSize = NSSize(width: max(itemWidth, 100), height: max(itemHeight, 50))
        } else {
            flowLayout.minimumInteritemSpacing = 8
            flowLayout.itemSize = NSSize(width: max(width, 100), height: max(itemHeight, 50))
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
    
    /// Set screenpacks directly (used for search filtering)
    func setScreenpacks(_ newScreenpacks: [ScreenpackInfo]) {
        updateScreenpacks(newScreenpacks)
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
        let rosterSize = IkemenBridge.shared.characters.count
        
        if viewMode == .grid {
            let item = collectionView.makeItem(withIdentifier: ScreenpackGridItem.identifier, for: indexPath) as! ScreenpackGridItem
            item.configure(with: screenpack, currentRosterSize: rosterSize)
            item.onActivate = { [weak self] in
                self?.onScreenpackActivate?(screenpack)
            }
            return item
        } else {
            let item = collectionView.makeItem(withIdentifier: ScreenpackListItem.identifier, for: indexPath) as! ScreenpackListItem
            item.configure(with: screenpack, currentRosterSize: rosterSize)
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
    private var gradientLayer: CAGradientLayer!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var statusDot: NSView!
    private var resolutionBadge: NSView!
    private var resolutionLabel: NSTextField!
    private var warningBadge: NSView!
    private var warningLabel: NSTextField!
    private var placeholderLabel: NSTextField!
    
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var currentScreenpack: ScreenpackInfo?
    
    // Animation duration (200ms to match character browser)
    private let animationDuration: CGFloat = 0.2
    
    var onActivate: (() -> Void)?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        view.wantsLayer = true
        setupViews()
    }
    
    private func setupViews() {
        // Container - rounded-xl (12px), with subtle border
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true
        containerView.layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.1).cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        view.addSubview(containerView)
        
        // Preview image - fills container
        previewImageView = NSImageView(frame: .zero)
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.5).cgColor
        containerView.addSubview(previewImageView)
        
        // Placeholder text (shows when no preview)
        placeholderLabel = NSTextField(labelWithString: "")
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = DesignFonts.header(size: 32)
        placeholderLabel.textColor = NSColor.white.withAlphaComponent(0.05)
        placeholderLabel.alignment = .center
        containerView.addSubview(placeholderLabel)
        
        // Gradient overlay - from top transparent to bottom dark
        gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            NSColor.clear.cgColor,
            NSColor.clear.cgColor,
            DesignColors.zinc900.withAlphaComponent(0.9).cgColor
        ]
        gradientLayer.locations = [0.0, 0.4, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        containerView.layer?.addSublayer(gradientLayer)
        
        // Status dot (top-right) - emerald for active
        statusDot = NSView()
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 5
        statusDot.layer?.backgroundColor = DesignColors.positive.cgColor
        statusDot.layer?.shadowColor = DesignColors.positive.cgColor
        statusDot.layer?.shadowOffset = .zero
        statusDot.layer?.shadowRadius = 6
        statusDot.layer?.shadowOpacity = 0.6
        statusDot.isHidden = true
        containerView.addSubview(statusDot)
        
        // Resolution badge (top-left)
        resolutionBadge = NSView()
        resolutionBadge.translatesAutoresizingMaskIntoConstraints = false
        resolutionBadge.wantsLayer = true
        resolutionBadge.layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.7).cgColor
        resolutionBadge.layer?.cornerRadius = 4
        containerView.addSubview(resolutionBadge)
        
        resolutionLabel = NSTextField(labelWithString: "")
        resolutionLabel.translatesAutoresizingMaskIntoConstraints = false
        resolutionLabel.font = DesignFonts.caption(size: 10)
        resolutionLabel.textColor = DesignColors.textSecondary
        resolutionLabel.isBordered = false
        resolutionLabel.isEditable = false
        resolutionLabel.drawsBackground = false
        resolutionBadge.addSubview(resolutionLabel)
        
        // Warning badge (below resolution)
        warningBadge = NSView()
        warningBadge.translatesAutoresizingMaskIntoConstraints = false
        warningBadge.wantsLayer = true
        warningBadge.layer?.backgroundColor = DesignColors.warningBackground.cgColor
        warningBadge.layer?.cornerRadius = 4
        warningBadge.isHidden = true
        containerView.addSubview(warningBadge)
        
        warningLabel = NSTextField(labelWithString: "")
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.font = DesignFonts.caption(size: 10)
        warningLabel.textColor = DesignColors.warning
        warningLabel.isBordered = false
        warningLabel.isEditable = false
        warningLabel.drawsBackground = false
        warningBadge.addSubview(warningLabel)
        
        // Name label - bottom-left, white, semibold
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        containerView.addSubview(nameLabel)
        
        // Author label - below name, zinc-400
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.caption(size: 11)
        authorLabel.textColor = DesignColors.textTertiary
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.maximumNumberOfLines = 1
        containerView.addSubview(authorLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            previewImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -20),
            
            statusDot.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            statusDot.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),
            
            resolutionBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            resolutionBadge.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            
            resolutionLabel.topAnchor.constraint(equalTo: resolutionBadge.topAnchor, constant: 3),
            resolutionLabel.bottomAnchor.constraint(equalTo: resolutionBadge.bottomAnchor, constant: -3),
            resolutionLabel.leadingAnchor.constraint(equalTo: resolutionBadge.leadingAnchor, constant: 6),
            resolutionLabel.trailingAnchor.constraint(equalTo: resolutionBadge.trailingAnchor, constant: -6),
            
            warningBadge.topAnchor.constraint(equalTo: resolutionBadge.bottomAnchor, constant: 4),
            warningBadge.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            
            warningLabel.topAnchor.constraint(equalTo: warningBadge.topAnchor, constant: 3),
            warningLabel.bottomAnchor.constraint(equalTo: warningBadge.bottomAnchor, constant: -3),
            warningLabel.leadingAnchor.constraint(equalTo: warningBadge.leadingAnchor, constant: 6),
            warningLabel.trailingAnchor.constraint(equalTo: warningBadge.trailingAnchor, constant: -6),
            
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            nameLabel.bottomAnchor.constraint(equalTo: authorLabel.topAnchor, constant: -2),
            
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            authorLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
        ])
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        gradientLayer.frame = containerView.bounds
        setupTrackingArea()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        if let existing = trackingArea {
            view.removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance(animated: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance(animated: true)
    }
    
    override var isSelected: Bool {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? animationDuration : 0
        let isActive = currentScreenpack?.isActive ?? false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if isSelected {
                // Selected: bright border, subtle glow
                containerView.animator().layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.4).cgColor
                containerView.layer?.shadowColor = NSColor.white.cgColor
                containerView.layer?.shadowOffset = .zero
                containerView.layer?.shadowRadius = 8
                containerView.layer?.shadowOpacity = 0.15
            } else if isHovered {
                // Hovered: medium border
                containerView.animator().layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.3).cgColor
                containerView.layer?.shadowOpacity = 0
            } else if isActive {
                // Active (not hovered/selected): emerald tint
                containerView.animator().layer?.borderColor = DesignColors.positive.withAlphaComponent(0.3).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.1).cgColor
                containerView.layer?.shadowColor = DesignColors.positive.cgColor
                containerView.layer?.shadowOpacity = 0.1
            } else {
                // Default: subtle border
                containerView.animator().layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.1).cgColor
                containerView.layer?.shadowOpacity = 0
            }
        }
    }
    
    func configure(with screenpack: ScreenpackInfo, currentRosterSize: Int = 0) {
        currentScreenpack = screenpack
        nameLabel.stringValue = screenpack.name
        authorLabel.stringValue = screenpack.author
        
        // Placeholder initial
        if let firstChar = screenpack.name.first?.uppercased() {
            placeholderLabel.stringValue = firstChar
        }
        
        // Show resolution and character limit
        var info = screenpack.resolutionString
        if screenpack.characterSlots > 0 {
            info += " • \(screenpack.characterSlots) slots"
        }
        resolutionLabel.stringValue = info
        
        // Show warning if roster exceeds slots
        if screenpack.characterSlots > 0 && currentRosterSize > screenpack.characterSlots {
            let overflow = currentRosterSize - screenpack.characterSlots
            warningLabel.stringValue = "⚠️ \(overflow) hidden"
            warningBadge.isHidden = false
        } else {
            warningBadge.isHidden = true
        }
        
        // Show status dot for active screenpack
        statusDot.isHidden = !screenpack.isActive
        
        // Update appearance for active state
        updateAppearance(animated: false)
        
        // Check cache first
        let cacheKey = "screenpack:\(screenpack.id)"
        if let cached = ImageCache.shared.get(cacheKey) {
            previewImageView.image = cached
            placeholderLabel.isHidden = true
            return
        }
        
        // Load preview image asynchronously
        previewImageView.image = nil
        placeholderLabel.isHidden = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let image = screenpack.loadPreviewImage() {
                ImageCache.shared.set(image, for: cacheKey)
                DispatchQueue.main.async {
                    self?.previewImageView.image = image
                    self?.placeholderLabel.isHidden = true
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
        warningLabel.stringValue = ""
        warningBadge.isHidden = true
        statusDot.isHidden = true
        placeholderLabel.stringValue = ""
        placeholderLabel.isHidden = false
        currentScreenpack = nil
        isHovered = false
        isSelected = false
        onActivate = nil
        
        // Reset appearance
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        containerView.layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.1).cgColor
        containerView.layer?.shadowOpacity = 0
    }
}

// MARK: - Screenpack List Item (Row View)

class ScreenpackListItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("ScreenpackListItem")
    
    private var containerView: NSView!
    private var thumbnailView: NSImageView!
    private var placeholderLabel: NSTextField!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var resolutionLabel: NSTextField!
    private var statusDot: NSView!
    private var warningBadge: NSView!
    private var warningLabel: NSTextField!
    
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var currentScreenpack: ScreenpackInfo?
    
    private let animationDuration: CGFloat = 0.2
    
    var onActivate: (() -> Void)?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 56))
        view.wantsLayer = true
        setupViews()
    }
    
    private func setupViews() {
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.1).cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        view.addSubview(containerView)
        
        // Thumbnail (small preview)
        thumbnailView = NSImageView(frame: .zero)
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 6
        thumbnailView.layer?.masksToBounds = true
        thumbnailView.layer?.backgroundColor = DesignColors.zinc800.cgColor
        containerView.addSubview(thumbnailView)
        
        // Placeholder initial
        placeholderLabel = NSTextField(labelWithString: "")
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = DesignFonts.header(size: 18)
        placeholderLabel.textColor = NSColor.white.withAlphaComponent(0.1)
        placeholderLabel.alignment = .center
        containerView.addSubview(placeholderLabel)
        
        // Name
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)
        
        // Author
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.caption(size: 12)
        authorLabel.textColor = DesignColors.textTertiary
        authorLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(authorLabel)
        
        // Resolution (right side)
        resolutionLabel = NSTextField(labelWithString: "")
        resolutionLabel.translatesAutoresizingMaskIntoConstraints = false
        resolutionLabel.font = DesignFonts.caption(size: 11)
        resolutionLabel.textColor = DesignColors.textSecondary
        resolutionLabel.alignment = .right
        containerView.addSubview(resolutionLabel)
        
        // Status dot (next to name for active)
        statusDot = NSView()
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.layer?.backgroundColor = DesignColors.positive.cgColor
        statusDot.layer?.shadowColor = DesignColors.positive.cgColor
        statusDot.layer?.shadowOffset = .zero
        statusDot.layer?.shadowRadius = 4
        statusDot.layer?.shadowOpacity = 0.5
        statusDot.isHidden = true
        containerView.addSubview(statusDot)
        
        // Warning badge
        warningBadge = NSView()
        warningBadge.translatesAutoresizingMaskIntoConstraints = false
        warningBadge.wantsLayer = true
        warningBadge.layer?.backgroundColor = DesignColors.warningBackground.cgColor
        warningBadge.layer?.cornerRadius = 4
        warningBadge.isHidden = true
        containerView.addSubview(warningBadge)
        
        warningLabel = NSTextField(labelWithString: "")
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.font = DesignFonts.caption(size: 10)
        warningLabel.textColor = DesignColors.warning
        warningLabel.isBordered = false
        warningLabel.isEditable = false
        warningLabel.drawsBackground = false
        warningBadge.addSubview(warningLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),
            
            // Thumbnail on left (16:9 ratio, ~72x40)
            thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            thumbnailView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 72),
            thumbnailView.heightAnchor.constraint(equalToConstant: 40),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: thumbnailView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor),
            
            // Status dot next to name
            statusDot.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            statusDot.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
            
            // Name (after status dot if visible, otherwise after thumbnail)
            nameLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: warningBadge.leadingAnchor, constant: -12),
            
            // Author below name
            authorLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            authorLabel.trailingAnchor.constraint(lessThanOrEqualTo: resolutionLabel.leadingAnchor, constant: -12),
            
            // Warning badge (before resolution)
            warningBadge.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            warningBadge.trailingAnchor.constraint(equalTo: resolutionLabel.leadingAnchor, constant: -12),
            
            warningLabel.topAnchor.constraint(equalTo: warningBadge.topAnchor, constant: 3),
            warningLabel.bottomAnchor.constraint(equalTo: warningBadge.bottomAnchor, constant: -3),
            warningLabel.leadingAnchor.constraint(equalTo: warningBadge.leadingAnchor, constant: 6),
            warningLabel.trailingAnchor.constraint(equalTo: warningBadge.trailingAnchor, constant: -6),
            
            // Resolution on right
            resolutionLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            resolutionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            resolutionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        if let existing = trackingArea {
            view.removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance(animated: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance(animated: true)
    }
    
    override var isSelected: Bool {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? animationDuration : 0
        let isActive = currentScreenpack?.isActive ?? false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if isSelected {
                containerView.animator().layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.4).cgColor
                containerView.layer?.shadowColor = NSColor.white.cgColor
                containerView.layer?.shadowOffset = .zero
                containerView.layer?.shadowRadius = 6
                containerView.layer?.shadowOpacity = 0.1
            } else if isHovered {
                containerView.animator().layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.3).cgColor
                containerView.layer?.shadowOpacity = 0
            } else if isActive {
                containerView.animator().layer?.borderColor = DesignColors.positive.withAlphaComponent(0.2).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.15).cgColor
                containerView.layer?.shadowOpacity = 0
            } else {
                containerView.animator().layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.1).cgColor
                containerView.layer?.shadowOpacity = 0
            }
        }
    }
    
    func configure(with screenpack: ScreenpackInfo, currentRosterSize: Int = 0) {
        currentScreenpack = screenpack
        nameLabel.stringValue = screenpack.name
        
        // Placeholder initial
        if let firstChar = screenpack.name.first?.uppercased() {
            placeholderLabel.stringValue = firstChar
        }
        
        // Show author and component summary
        let componentSummary = screenpack.componentSummary
        if componentSummary != "Standard Screenpack" {
            authorLabel.stringValue = "\(screenpack.author) • \(componentSummary)"
        } else {
            authorLabel.stringValue = screenpack.author
        }
        
        // Show resolution and character limit
        var info = screenpack.resolutionString
        if screenpack.characterSlots > 0 {
            info += " • \(screenpack.characterSlots) slots"
        }
        resolutionLabel.stringValue = info
        
        // Show warning if roster exceeds slots
        if screenpack.characterSlots > 0 && currentRosterSize > screenpack.characterSlots {
            let overflow = currentRosterSize - screenpack.characterSlots
            warningLabel.stringValue = "⚠️ \(overflow) hidden"
            warningBadge.isHidden = false
        } else {
            warningBadge.isHidden = true
        }
        
        // Show status dot for active
        statusDot.isHidden = !screenpack.isActive
        
        // Update appearance for active state
        updateAppearance(animated: false)
        
        // Load thumbnail
        let cacheKey = "screenpack:\(screenpack.id)"
        if let cached = ImageCache.shared.get(cacheKey) {
            thumbnailView.image = cached
            placeholderLabel.isHidden = true
        } else {
            thumbnailView.image = nil
            placeholderLabel.isHidden = false
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                if let image = screenpack.loadPreviewImage() {
                    ImageCache.shared.set(image, for: cacheKey)
                    DispatchQueue.main.async {
                        self?.thumbnailView.image = image
                        self?.placeholderLabel.isHidden = true
                    }
                }
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.image = nil
        placeholderLabel.stringValue = ""
        placeholderLabel.isHidden = false
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        resolutionLabel.stringValue = ""
        statusDot.isHidden = true
        warningLabel.stringValue = ""
        warningBadge.isHidden = true
        currentScreenpack = nil
        isHovered = false
        isSelected = false
        onActivate = nil
        
        // Reset appearance
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        containerView.layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.1).cgColor
        containerView.layer?.shadowOpacity = 0
    }
}
