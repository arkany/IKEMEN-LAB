import Cocoa

/// Browser view for managing collections
class CollectionsBrowserView: NSView {
    
    // MARK: - Callbacks
    var onCollectionSelected: ((CollectionInfo) -> Void)?
    var onCreateCollection: (() -> Void)?
    
    // MARK: - Properties
    private var collections: [CollectionInfo] = []
    private var scrollView: NSScrollView!
    private var contentStack: NSStackView!
    private var emptyStateLabel: NSTextField!
    
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
        
        // Toolbar with New Collection button
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(toolbar)
        
        let newButton = NSButton(title: "New Collection", target: self, action: #selector(newCollectionClicked))
        newButton.translatesAutoresizingMaskIntoConstraints = false
        newButton.bezelStyle = .rounded
        toolbar.addSubview(newButton)
        
        // Scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        addSubview(scrollView)
        
        // Document view
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        
        // Content stack
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .leading
        documentView.addSubview(contentStack)
        
        // Empty state
        emptyStateLabel = NSTextField(labelWithString: "No collections yet\nCreate one to organize your content")
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.font = DesignFonts.body(size: 14)
        emptyStateLabel.textColor = DesignColors.textTertiary
        emptyStateLabel.alignment = .center
        emptyStateLabel.maximumNumberOfLines = 2
        emptyStateLabel.isHidden = true
        addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 50),
            
            newButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            newButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
            
            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        
        loadCollections()
    }
    
    @objc private func newCollectionClicked() {
        onCreateCollection?()
    }
    
    // MARK: - Data Loading
    
    func loadCollections() {
        do {
            collections = try MetadataStore.shared.allCollections()
            updateUI()
        } catch {
            print("Failed to load collections: \(error)")
            collections = []
            updateUI()
        }
    }
    
    func setCollections(_ collections: [CollectionInfo]) {
        self.collections = collections
        updateUI()
    }
    
    func refresh() {
        loadCollections()
    }
    
    private func updateUI() {
        // Clear existing views
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if collections.isEmpty {
            emptyStateLabel.isHidden = false
            return
        }
        
        emptyStateLabel.isHidden = true
        
        // Add collection cards
        for collection in collections {
            let card = createCollectionCard(for: collection)
            contentStack.addArrangedSubview(card)
            
            // Make card fill width
            card.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
            card.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
        }
    }
    
    // MARK: - Card Creation
    
    private func createCollectionCard(for collection: CollectionInfo) -> NSView {
        let card = HoverableCollectionCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(container)
        
        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textSecondary
        iconView.symbolConfiguration = .init(pointSize: 24, weight: .medium)
        container.addSubview(iconView)
        
        // Text stack
        let textStack = NSStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        container.addSubview(textStack)
        
        // Name
        let nameLabel = NSTextField(labelWithString: collection.name)
        nameLabel.font = DesignFonts.body(size: 16)
        nameLabel.textColor = DesignColors.textPrimary
        textStack.addArrangedSubview(nameLabel)
        
        // Summary (e.g., "5 characters, 3 stages")
        let summaryLabel = NSTextField(labelWithString: collection.itemSummary)
        summaryLabel.font = DesignFonts.caption(size: 13)
        summaryLabel.textColor = DesignColors.textSecondary
        textStack.addArrangedSubview(summaryLabel)
        
        // Description (if not empty)
        if !collection.description.isEmpty {
            let descLabel = NSTextField(labelWithString: collection.description)
            descLabel.font = DesignFonts.caption(size: 12)
            descLabel.textColor = DesignColors.textTertiary
            descLabel.lineBreakMode = .byTruncatingTail
            textStack.addArrangedSubview(descLabel)
        }
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.topAnchor.constraint(equalTo: container.topAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textStack.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])
        
        // Click handler
        card.onClick = { [weak self] in
            self?.onCollectionSelected?(collection)
        }
        
        return card
    }
}

// MARK: - Hoverable Collection Card

class HoverableCollectionCard: NSView {
    
    var onClick: (() -> Void)?
    
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
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Glass panel gradient
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor.white.withAlphaComponent(0.03).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.cornerRadius = 8
        layer?.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }
    
    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        } else {
            layer?.borderColor = DesignColors.borderSubtle.cgColor
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
        guard onClick != nil else { return }
        alphaValue = 0.8
    }
    
    override func mouseUp(with event: NSEvent) {
        guard onClick != nil else { return }
        alphaValue = 1.0
        
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
