import Cocoa
import Combine

// MARK: - Section Header View

/// Section header for list view matching add-ons.html design
/// text-xs font-semibold text-zinc-500 uppercase tracking-widest
class ScreenpackSectionHeader: NSView, NSCollectionViewElement {
    
    static let identifier = NSUserInterfaceItemIdentifier("ScreenpackSectionHeader")
    
    private var titleLabel: NSTextField!
    
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
        
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = DesignColors.textTertiary
        titleLabel.isSelectable = false
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            // 8px to align with thumbnail left edge inside list items
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }
    
    func configure(title: String) {
        // Apply uppercase with wide letter spacing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: DesignColors.textTertiary,
            .kern: 2.0  // tracking-widest equivalent
        ]
        titleLabel.attributedStringValue = NSAttributedString(string: title.uppercased(), attributes: attributes)
    }
}

/// A visual browser for viewing installed screenpacks with thumbnails
/// Shows active screenpack with visual indicator
class ScreenpackBrowserView: NSView {
    
    // MARK: - Properties
    
    private var scrollView: NSScrollView!
    private var collectionView: NSCollectionView!
    private var flowLayout: NSCollectionViewFlowLayout!
    private var screenpacks: [ScreenpackInfo] = []
    private var activeScreenpacks: [ScreenpackInfo] = []
    private var inactiveScreenpacks: [ScreenpackInfo] = []
    private var cancellables = Set<AnyCancellable>()
    private var themeObserver: NSObjectProtocol?
    
    // View mode
    var viewMode: BrowserViewMode = .grid {
        didSet {
            updateLayoutForViewMode()
        }
    }
    
    // Layout constants from shared design system
    private let gridItemWidth = BrowserLayout.stageGridItemWidth   // Same as stages - wide cards
    private let gridItemHeight = BrowserLayout.stageGridItemHeight
    private let listItemHeight = BrowserLayout.screenpackListItemHeight
    private let cardSpacing = BrowserLayout.cardSpacing
    private let sectionInset = BrowserLayout.sectionInset
    private let sectionHeaderHeight: CGFloat = 40
    
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
        
        // Register section header using standard flow layout header kind
        collectionView.register(ScreenpackSectionHeader.self, forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader, withIdentifier: ScreenpackSectionHeader.identifier)
        
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
            flowLayout.sectionInset = NSEdgeInsets(top: sectionInset, left: sectionInset, bottom: sectionInset, right: sectionInset)
        } else {
            // List view: minimal horizontal padding, items should be nearly full width
            let horizontalPadding: CGFloat = 4
            flowLayout.minimumInteritemSpacing = 4
            flowLayout.minimumLineSpacing = 4
            flowLayout.itemSize = NSSize(width: max(width - (horizontalPadding * 2), 100), height: max(itemHeight, 50))
            // Smaller top inset since headers provide spacing, bottom inset for section gap
            flowLayout.sectionInset = NSEdgeInsets(top: 8, left: horizontalPadding, bottom: 24, right: horizontalPadding)
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
        
        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Update all visible items
            for indexPath in self.collectionView.indexPathsForVisibleItems() {
                if let item = self.collectionView.item(at: indexPath) as? ScreenpackGridItem {
                    item.applyTheme()
                } else if let item = self.collectionView.item(at: indexPath) as? ScreenpackListItem {
                    item.applyTheme()
                }
            }
            self.collectionView.reloadData()
        }
    }
    
    /// Set screenpacks directly (used for search filtering)
    func setScreenpacks(_ newScreenpacks: [ScreenpackInfo]) {
        updateScreenpacks(newScreenpacks)
    }
    
    private func updateScreenpacks(_ newScreenpacks: [ScreenpackInfo]) {
        // Split into active and inactive sections
        self.activeScreenpacks = newScreenpacks.filter { $0.isActive }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        self.inactiveScreenpacks = newScreenpacks.filter { !$0.isActive }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        
        // Keep flat list for grid view
        self.screenpacks = newScreenpacks.sorted { 
            if $0.isActive != $1.isActive {
                return $0.isActive
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending 
        }
        collectionView.reloadData()
    }
    
    /// Get screenpack for a given index path (handles sections in list mode)
    private func screenpack(at indexPath: IndexPath) -> ScreenpackInfo {
        if viewMode == .list {
            // Handle case where active section is empty
            if activeScreenpacks.isEmpty {
                return inactiveScreenpacks[indexPath.item]
            } else if indexPath.section == 0 {
                return activeScreenpacks[indexPath.item]
            } else {
                return inactiveScreenpacks[indexPath.item]
            }
        } else {
            return screenpacks[indexPath.item]
        }
    }
    
    // MARK: - Public Methods
    
    func refresh() {
        updateScreenpacks(IkemenBridge.shared.screenpacks)
    }

    deinit {
        if let themeObserver = themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }
}

// MARK: - NSCollectionViewDataSource

extension ScreenpackBrowserView: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        // List view: 2 sections (Active, All Add-ons)
        // Grid view: 1 section (flat list)
        if viewMode == .list {
            // Only show sections that have items
            var count = 0
            if !activeScreenpacks.isEmpty { count += 1 }
            if !inactiveScreenpacks.isEmpty { count += 1 }
            return max(1, count)  // At least 1 to avoid issues
        }
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if viewMode == .list {
            // Determine which section this is based on available data
            if activeScreenpacks.isEmpty {
                return inactiveScreenpacks.count
            } else if section == 0 {
                return activeScreenpacks.count
            } else {
                return inactiveScreenpacks.count
            }
        }
        return screenpacks.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let screenpack = self.screenpack(at: indexPath)
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
    
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView {
        guard kind == NSCollectionView.elementKindSectionHeader else {
            return NSView()
        }
        
        let header = collectionView.makeSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader, withIdentifier: ScreenpackSectionHeader.identifier, for: indexPath) as! ScreenpackSectionHeader
        
        // Determine section title
        let title: String
        if activeScreenpacks.isEmpty {
            title = "All Add-ons"
        } else if indexPath.section == 0 {
            title = "Active"
        } else {
            title = "All Add-ons"
        }
        
        header.configure(title: title)
        return header
    }
}

// MARK: - NSCollectionViewDelegate

extension ScreenpackBrowserView: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let screenpack = self.screenpack(at: indexPath)
        onScreenpackSelected?(screenpack)
    }
}

// MARK: - NSCollectionViewDelegateFlowLayout

extension ScreenpackBrowserView: NSCollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> NSSize {
        // Only show headers in list mode
        if viewMode == .list {
            return NSSize(width: collectionView.bounds.width, height: sectionHeaderHeight)
        }
        return .zero
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
        containerView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.2).cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        view.addSubview(containerView)
        
        // Preview image - fills container
        previewImageView = NSImageView(frame: .zero)
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
        containerView.addSubview(previewImageView)
        
        // Placeholder text (shows when no preview)
        placeholderLabel = NSTextField(labelWithString: "")
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = DesignFonts.header(size: 32)
        placeholderLabel.textColor = DesignColors.textDisabled.withAlphaComponent(0.3)
        placeholderLabel.alignment = .center
        containerView.addSubview(placeholderLabel)
        
        // Gradient overlay - from top transparent to bottom dark
        gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            NSColor.clear.cgColor,
            NSColor.clear.cgColor,
            DesignColors.imageOverlay.cgColor
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
        resolutionBadge.layer?.backgroundColor = DesignColors.imageLabelBackground.cgColor
        resolutionBadge.layer?.cornerRadius = 4
        containerView.addSubview(resolutionBadge)
        
        resolutionLabel = NSTextField(labelWithString: "")
        resolutionLabel.translatesAutoresizingMaskIntoConstraints = false
        resolutionLabel.font = DesignFonts.caption(size: 10)
        resolutionLabel.textColor = DesignColors.textOnImageOverlay
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
        
        // Name label - bottom-left, uses textOnImageOverlay for proper contrast
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.textColor = DesignColors.textOnImageOverlay
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        containerView.addSubview(nameLabel)
        
        // Author label - below name
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.caption(size: 11)
        authorLabel.textColor = DesignColors.textOnImageOverlay.withAlphaComponent(0.7)
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
        // Disable implicit animations for frame changes during resize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = containerView.bounds
        CATransaction.commit()
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
                containerView.animator().layer?.borderColor = DesignColors.borderStrong.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.4).cgColor
                containerView.layer?.shadowColor = DesignColors.textPrimary.cgColor
                containerView.layer?.shadowOffset = .zero
                containerView.layer?.shadowRadius = 8
                containerView.layer?.shadowOpacity = 0.15
            } else if isHovered {
                // Hovered: medium border
                containerView.animator().layer?.borderColor = DesignColors.borderHover.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.3).cgColor
                containerView.layer?.shadowOpacity = 0
            } else if isActive {
                // Active (not hovered/selected): emerald tint
                containerView.animator().layer?.borderColor = DesignColors.positive.withAlphaComponent(0.3).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.1).cgColor
                containerView.layer?.shadowColor = DesignColors.positive.cgColor
                containerView.layer?.shadowOpacity = 0.1
            } else {
                // Default: subtle border
                containerView.animator().layer?.borderColor = DesignColors.borderSubtle.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.1).cgColor
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
        
        // Apply current theme colors
        applyTheme()
        
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
                DispatchQueue.main.async { [weak self] in
                    self?.previewImageView.image = image
                    self?.placeholderLabel.isHidden = true
                }
            }
        }
    }
    
    /// Update all theme-dependent colors
    func applyTheme() {
        // Container
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        containerView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.1).cgColor
        
        // Preview background
        previewImageView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
        
        // Placeholder text
        placeholderLabel.textColor = DesignColors.textDisabled.withAlphaComponent(0.3)
        
        // Gradient overlay
        gradientLayer.colors = [
            NSColor.clear.cgColor,
            NSColor.clear.cgColor,
            DesignColors.imageOverlay.cgColor
        ]
        
        // Status dot
        statusDot.layer?.backgroundColor = DesignColors.positive.cgColor
        statusDot.layer?.shadowColor = DesignColors.positive.cgColor
        
        // Resolution badge - use imageLabelBackground for proper contrast
        resolutionBadge.layer?.backgroundColor = DesignColors.imageLabelBackground.cgColor
        resolutionLabel.textColor = DesignColors.textOnImageOverlay
        
        // Warning badge
        warningBadge.layer?.backgroundColor = DesignColors.warningBackground.cgColor
        warningLabel.textColor = DesignColors.warning
        
        // Text labels - use textOnImageOverlay for proper contrast over gradient
        nameLabel.textColor = DesignColors.textOnImageOverlay
        authorLabel.textColor = DesignColors.textOnImageOverlay.withAlphaComponent(0.7)
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
        containerView.layer?.shadowOpacity = 0
        
        // Apply current theme colors
        applyTheme()
    }
}

// MARK: - Screenpack List Item (Row View)

class ScreenpackListItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("ScreenpackListItem")
    
    private var containerView: NSView!
    private var thumbnailView: NSImageView!
    private var thumbnailOverlay: NSView!  // Emerald tint for active items
    private var placeholderLabel: NSTextField!
    private var nameLabel: NSTextField!
    private var activeBadge: NSView!
    private var activeBadgeLabel: NSTextField!
    private var typeLabel: NSTextField!
    private var dotLabel: NSTextField!
    private var descriptionLabel: NSTextField!
    private var versionLabel: NSTextField!
    private var resolutionLabel: NSTextField!
    private var actionButton: NSButton!
    private var warningBadge: NSView!
    private var warningLabel: NSTextField!
    
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var currentScreenpack: ScreenpackInfo?
    
    private let animationDuration: CGFloat = 0.2
    
    var onActivate: (() -> Void)?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 60))
        view.wantsLayer = true
        setupViews()
    }
    
    private func setupViews() {
        // Container with padding
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.2).cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        view.addSubview(containerView)
        
        // Thumbnail (80x48 - matches HTML w-20 h-12)
        thumbnailView = NSImageView(frame: .zero)
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 6
        thumbnailView.layer?.masksToBounds = true
        thumbnailView.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        thumbnailView.layer?.borderWidth = 1
        thumbnailView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        containerView.addSubview(thumbnailView)
        
        // Thumbnail overlay for active items (emerald tint)
        thumbnailOverlay = NSView()
        thumbnailOverlay.translatesAutoresizingMaskIntoConstraints = false
        thumbnailOverlay.wantsLayer = true
        thumbnailOverlay.layer?.cornerRadius = 6
        thumbnailOverlay.layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.1).cgColor
        thumbnailOverlay.isHidden = true
        containerView.addSubview(thumbnailOverlay)
        
        // Placeholder initial
        placeholderLabel = NSTextField(labelWithString: "")
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = DesignFonts.header(size: 18)
        placeholderLabel.textColor = DesignColors.textDisabled.withAlphaComponent(0.4)
        placeholderLabel.alignment = .center
        containerView.addSubview(placeholderLabel)
        
        // Name label
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.textColor = DesignColors.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)
        
        // Active badge (shows "Active" for current screenpack)
        activeBadge = NSView()
        activeBadge.translatesAutoresizingMaskIntoConstraints = false
        activeBadge.wantsLayer = true
        activeBadge.layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.1).cgColor
        activeBadge.layer?.borderWidth = 1
        activeBadge.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.2).cgColor
        activeBadge.layer?.cornerRadius = 3
        activeBadge.isHidden = true
        containerView.addSubview(activeBadge)
        
        activeBadgeLabel = NSTextField(labelWithString: "Active")
        activeBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        activeBadgeLabel.font = DesignFonts.caption(size: 10)
        activeBadgeLabel.textColor = DesignColors.positive
        activeBadgeLabel.isBordered = false
        activeBadgeLabel.isEditable = false
        activeBadgeLabel.drawsBackground = false
        activeBadge.addSubview(activeBadgeLabel)
        
        // Type label (e.g., "Screenpack", "Lifebar")
        typeLabel = NSTextField(labelWithString: "")
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.font = DesignFonts.caption(size: 12)
        typeLabel.textColor = DesignColors.textSecondary
        containerView.addSubview(typeLabel)
        
        // Dot separator
        dotLabel = NSTextField(labelWithString: "•")
        dotLabel.translatesAutoresizingMaskIntoConstraints = false
        dotLabel.font = DesignFonts.caption(size: 10)
        dotLabel.textColor = DesignColors.textTertiary
        containerView.addSubview(dotLabel)
        
        // Description label
        descriptionLabel = NSTextField(labelWithString: "")
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = DesignFonts.caption(size: 12)
        descriptionLabel.textColor = DesignColors.textTertiary
        descriptionLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(descriptionLabel)
        
        // Warning badge (between description and meta)
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
        
        // Version label (e.g., "v1.1", "Local")
        versionLabel = NSTextField(labelWithString: "")
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        versionLabel.textColor = DesignColors.textTertiary
        versionLabel.alignment = .right
        containerView.addSubview(versionLabel)
        
        // Resolution label (e.g., "1280x720")
        resolutionLabel = NSTextField(labelWithString: "")
        resolutionLabel.translatesAutoresizingMaskIntoConstraints = false
        resolutionLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        resolutionLabel.textColor = DesignColors.textTertiary
        resolutionLabel.alignment = .right
        containerView.addSubview(resolutionLabel)
        
        // Action button (Load/Settings)
        actionButton = NSButton(title: "Load", target: self, action: #selector(actionButtonClicked))
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.bezelStyle = .inline
        actionButton.isBordered = false
        actionButton.wantsLayer = true
        actionButton.font = DesignFonts.caption(size: 10)
        (actionButton.cell as? NSButtonCell)?.backgroundColor = .clear
        actionButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
        actionButton.layer?.cornerRadius = 4
        actionButton.layer?.borderWidth = 1
        actionButton.layer?.borderColor = DesignColors.borderSubtle.cgColor
        actionButton.contentTintColor = DesignColors.textSecondary
        containerView.addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -1),
            
            // Thumbnail on left (80x48)
            thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            thumbnailView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 80),
            thumbnailView.heightAnchor.constraint(equalToConstant: 48),
            
            thumbnailOverlay.topAnchor.constraint(equalTo: thumbnailView.topAnchor),
            thumbnailOverlay.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor),
            thumbnailOverlay.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor),
            thumbnailOverlay.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: thumbnailView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor),
            
            // Name row (with optional active badge)
            nameLabel.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            
            activeBadge.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            activeBadge.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            
            activeBadgeLabel.topAnchor.constraint(equalTo: activeBadge.topAnchor, constant: 2),
            activeBadgeLabel.bottomAnchor.constraint(equalTo: activeBadge.bottomAnchor, constant: -2),
            activeBadgeLabel.leadingAnchor.constraint(equalTo: activeBadge.leadingAnchor, constant: 6),
            activeBadgeLabel.trailingAnchor.constraint(equalTo: activeBadge.trailingAnchor, constant: -6),
            
            // Type/Description row
            typeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            
            dotLabel.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 6),
            dotLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: dotLabel.trailingAnchor, constant: 6),
            descriptionLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            descriptionLabel.trailingAnchor.constraint(lessThanOrEqualTo: warningBadge.leadingAnchor, constant: -12),
            
            // Warning badge
            warningBadge.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            warningBadge.trailingAnchor.constraint(equalTo: versionLabel.leadingAnchor, constant: -16),
            
            warningLabel.topAnchor.constraint(equalTo: warningBadge.topAnchor, constant: 3),
            warningLabel.bottomAnchor.constraint(equalTo: warningBadge.bottomAnchor, constant: -3),
            warningLabel.leadingAnchor.constraint(equalTo: warningBadge.leadingAnchor, constant: 6),
            warningLabel.trailingAnchor.constraint(equalTo: warningBadge.trailingAnchor, constant: -6),
            
            // Meta info on right (version/resolution stacked)
            versionLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -24),
            versionLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            versionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            resolutionLabel.trailingAnchor.constraint(equalTo: versionLabel.trailingAnchor),
            resolutionLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 2),
            
            // Action button on far right
            actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            actionButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            actionButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    @objc private func actionButtonClicked() {
        if !(currentScreenpack?.isActive ?? false) {
            onActivate?()
        }
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
                containerView.animator().layer?.borderColor = DesignColors.borderStrong.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
                containerView.layer?.shadowColor = DesignColors.textPrimary.cgColor
                containerView.layer?.shadowOffset = .zero
                containerView.layer?.shadowRadius = 6
                containerView.layer?.shadowOpacity = 0.1
            } else if isHovered {
                containerView.animator().layer?.borderColor = DesignColors.borderHover.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.6).cgColor
                containerView.layer?.shadowOpacity = 0
                
                // Hover button effect
                actionButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackgroundHover.cgColor
                actionButton.contentTintColor = DesignColors.textPrimary
            } else if isActive {
                // Active item: emerald border with subtle ring
                containerView.animator().layer?.borderColor = DesignColors.positive.withAlphaComponent(0.2).cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.4).cgColor
                containerView.layer?.shadowColor = DesignColors.positive.cgColor
                containerView.layer?.shadowOpacity = 0.05
                containerView.layer?.shadowRadius = 4
                
                actionButton.layer?.backgroundColor = NSColor.clear.cgColor
                actionButton.contentTintColor = DesignColors.textSecondary
            } else {
                containerView.animator().layer?.borderColor = DesignColors.borderSubtle.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.2).cgColor
                containerView.layer?.shadowOpacity = 0
                
                actionButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
                actionButton.contentTintColor = DesignColors.textSecondary
            }
        }
        
        // Update name color on hover
        nameLabel.textColor = isHovered && isActive
            ? DesignColors.positive
            : (isHovered ? DesignColors.textPrimary : (isActive ? DesignColors.positive : DesignColors.textPrimary))
        descriptionLabel.textColor = isHovered ? DesignColors.textSecondary : DesignColors.textTertiary
        
        // Update image opacity/saturation on hover for inactive items
        if !isActive {
            thumbnailView.alphaValue = isHovered ? 0.7 : 0.4
            if #available(macOS 10.15, *) {
                // Apply desaturation effect
                if !isHovered {
                    thumbnailView.contentFilters = [CIFilter(name: "CIColorControls", parameters: ["inputSaturation": 0])].compactMap { $0 }
                } else {
                    thumbnailView.contentFilters = []
                }
            }
        }
    }
    
    func configure(with screenpack: ScreenpackInfo, currentRosterSize: Int = 0) {
        currentScreenpack = screenpack
        
        // Name
        nameLabel.stringValue = screenpack.name
        
        // Placeholder initial
        if let firstChar = screenpack.name.first?.uppercased() {
            placeholderLabel.stringValue = firstChar
        }
        
        // Active badge and overlay
        let isActive = screenpack.isActive
        activeBadge.isHidden = !isActive
        thumbnailOverlay.isHidden = !isActive
        
        // Type and description
        typeLabel.stringValue = screenpack.primaryType
        descriptionLabel.stringValue = screenpack.shortDescription
        
        // Action button
        if isActive {
            actionButton.title = "⚙︎"  // Settings gear
            actionButton.toolTip = "Configure active screenpack"
        } else {
            actionButton.title = "Load"
            actionButton.toolTip = "Set as active screenpack"
        }
        
        // Version (show "Local" for local files, or version if available)
        versionLabel.stringValue = "Local"
        
        // Resolution
        resolutionLabel.stringValue = screenpack.resolutionString
        
        // Show warning if roster exceeds slots
        if screenpack.characterSlots > 0 && currentRosterSize > screenpack.characterSlots {
            let overflow = currentRosterSize - screenpack.characterSlots
            warningLabel.stringValue = "⚠️ \(overflow) hidden"
            warningBadge.isHidden = false
        } else {
            warningBadge.isHidden = true
        }
        
        // Update initial appearance
        updateAppearance(animated: false)
        
        // Apply current theme colors
        applyTheme()
        
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
                    DispatchQueue.main.async { [weak self] in
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
        thumbnailView.alphaValue = 1.0
        thumbnailView.contentFilters = []
        thumbnailOverlay.isHidden = true
        placeholderLabel.stringValue = ""
        placeholderLabel.isHidden = false
        nameLabel.stringValue = ""
        typeLabel.stringValue = ""
        descriptionLabel.stringValue = ""
        versionLabel.stringValue = ""
        resolutionLabel.stringValue = ""
        activeBadge.isHidden = true
        warningLabel.stringValue = ""
        warningBadge.isHidden = true
        actionButton.title = "Load"
        currentScreenpack = nil
        isHovered = false
        isSelected = false
        onActivate = nil
        containerView.layer?.shadowOpacity = 0
        
        // Apply current theme colors
        applyTheme()
    }
    
    /// Update all theme-dependent colors
    func applyTheme() {
        // Container
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        containerView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.2).cgColor
        
        // Text colors
        nameLabel.textColor = DesignColors.textPrimary
        typeLabel.textColor = DesignColors.textTertiary
        descriptionLabel.textColor = DesignColors.textTertiary
        versionLabel.textColor = DesignColors.textTertiary
        resolutionLabel.textColor = DesignColors.textTertiary
        
        // Active badge
        activeBadge.layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.1).cgColor
        activeBadge.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.3).cgColor
        activeBadgeLabel.textColor = DesignColors.positive
        
        // Warning badge
        warningBadge.layer?.backgroundColor = DesignColors.warningBackground.cgColor
        warningLabel.textColor = DesignColors.warning
        
        // Action button
        actionButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
        actionButton.contentTintColor = DesignColors.textSecondary
    }
}
