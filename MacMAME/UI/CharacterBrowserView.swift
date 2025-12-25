import Cocoa
import Combine

/// A visual browser for viewing installed characters with thumbnails
/// Uses shared design system from UIHelpers.swift
class CharacterBrowserView: NSView {
    
    // MARK: - Properties
    
    private var scrollView: NSScrollView!
    private var collectionView: NSCollectionView!
    private var flowLayout: NSCollectionViewFlowLayout!
    private var characters: [CharacterInfo] = []
    private var portraitCache: [String: NSImage] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // View mode
    var viewMode: BrowserViewMode = .grid {
        didSet {
            updateLayoutForViewMode()
        }
    }
    
    // Layout constants from shared design system
    private let gridItemWidth = BrowserLayout.gridItemWidth
    private let gridItemHeight = BrowserLayout.gridItemHeight
    private let listItemHeight = BrowserLayout.listItemHeight
    private let cardSpacing = BrowserLayout.cardSpacing
    private let sectionInset = BrowserLayout.sectionInset
    
    var onCharacterSelected: ((CharacterInfo) -> Void)?
    var onCharacterDoubleClicked: ((CharacterInfo) -> Void)?
    
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
        collectionView.register(CharacterCollectionViewItem.self, forItemWithIdentifier: CharacterCollectionViewItem.identifier)
        collectionView.register(CharacterListItem.self, forItemWithIdentifier: CharacterListItem.identifier)
        
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
            
            // Update layout
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
        IkemenBridge.shared.$characters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] characters in
                self?.updateCharacters(characters)
            }
            .store(in: &cancellables)
    }
    
    private func updateCharacters(_ newCharacters: [CharacterInfo]) {
        self.characters = newCharacters.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        collectionView.reloadData()
        
        // Load portraits in background
        loadPortraitsAsync()
    }
    
    // MARK: - Portrait Loading
    
    private func loadPortraitsAsync() {
        for character in characters {
            if portraitCache[character.id] != nil { continue }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let portrait = character.getPortraitImage()
                
                DispatchQueue.main.async {
                    self?.portraitCache[character.id] = portrait ?? self?.createPlaceholderImage(for: character)
                    
                    // Find and update the item
                    if let index = self?.characters.firstIndex(where: { $0.id == character.id }) {
                        let indexPath = IndexPath(item: index, section: 0)
                        if let item = self?.collectionView.item(at: indexPath) as? CharacterCollectionViewItem {
                            item.setPortrait(self?.portraitCache[character.id])
                        }
                    }
                }
            }
        }
    }
    
    private func createPlaceholderImage(for character: CharacterInfo) -> NSImage {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Placeholder background from Figma (#d9d9d9)
        DesignColors.placeholderBackground.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw initial in darker gray
        let initial = String(character.displayName.prefix(1)).uppercased()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: DesignFonts.jersey(size: 40),
            .foregroundColor: NSColor(white: 0.5, alpha: 1.0)
        ]
        let attrString = NSAttributedString(string: initial, attributes: attrs)
        let stringSize = attrString.size()
        let point = NSPoint(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2
        )
        attrString.draw(at: point)
        
        image.unlockFocus()
        
        return image
    }
    
    // MARK: - Public Methods
    
    func refresh() {
        portraitCache.removeAll()
        updateCharacters(IkemenBridge.shared.characters)
    }
}

// MARK: - NSCollectionViewDataSource

extension CharacterBrowserView: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return characters.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let character = characters[indexPath.item]
        
        if viewMode == .grid {
            let item = collectionView.makeItem(withIdentifier: CharacterCollectionViewItem.identifier, for: indexPath) as! CharacterCollectionViewItem
            item.configure(with: character)
            
            if let cachedPortrait = portraitCache[character.id] {
                item.setPortrait(cachedPortrait)
            }
            
            return item
        } else {
            let item = collectionView.makeItem(withIdentifier: CharacterListItem.identifier, for: indexPath) as! CharacterListItem
            item.configure(with: character)
            
            if let cachedPortrait = portraitCache[character.id] {
                item.setPortrait(cachedPortrait)
            }
            
            return item
        }
    }
}

// MARK: - NSCollectionViewDelegate

extension CharacterBrowserView: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let character = characters[indexPath.item]
        onCharacterSelected?(character)
    }
}

// MARK: - Character Collection View Item

class CharacterCollectionViewItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("CharacterCollectionViewItem")
    
    private var portraitImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var containerView: NSView!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 160))
        view.wantsLayer = true
        
        setupViews()
    }
    
    private func setupViews() {
        // Container - matches Figma card design
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.clear.cgColor
        view.addSubview(containerView)
        
        // Portrait image - 100x100 from Figma
        portraitImageView = NSImageView(frame: .zero)
        portraitImageView.translatesAutoresizingMaskIntoConstraints = false
        portraitImageView.imageScaling = .scaleProportionallyUpOrDown
        portraitImageView.wantsLayer = true
        portraitImageView.layer?.backgroundColor = DesignColors.defaultPlaceholder.cgColor
        containerView.addSubview(portraitImageView)
        
        // Name label - Jersey 10, 24px, gray, centered
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.jersey(size: 24)
        nameLabel.textColor = DesignColors.grayText
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        containerView.addSubview(nameLabel)
        
        // Author label - Jersey 10, 16px, gray, centered
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.jersey(size: 16)
        authorLabel.textColor = DesignColors.grayText
        authorLabel.alignment = .center
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.maximumNumberOfLines = 1
        containerView.addSubview(authorLabel)
        
        // Layout per Figma: 12px padding, 4px gaps
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Portrait: 12px from top, centered, 100x100
            portraitImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            portraitImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            portraitImageView.widthAnchor.constraint(equalToConstant: 100),
            portraitImageView.heightAnchor.constraint(equalToConstant: 100),
            
            // Name: 4px below portrait
            nameLabel.topAnchor.constraint(equalTo: portraitImageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            
            // Author: 4px below name
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
        ])
    }
    
    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }
    
    private func updateSelectionAppearance() {
        if isSelected {
            // Figma: border-[#fd4e5b], shadow 0px 0px 18px rgba(253,78,91,0.4)
            containerView.layer?.borderColor = DesignColors.selectedBorder.cgColor
            containerView.layer?.borderWidth = 1
            
            // Add glow shadow
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
    
    func configure(with character: CharacterInfo) {
        nameLabel.stringValue = character.displayName
        authorLabel.stringValue = "by \(character.author)"
        portraitImageView.image = nil
    }
    
    func setPortrait(_ image: NSImage?) {
        portraitImageView.image = image
        if image != nil {
            portraitImageView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        portraitImageView.image = nil
        portraitImageView.layer?.backgroundColor = DesignColors.defaultPlaceholder.cgColor
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        isSelected = false
    }
}

// MARK: - Character List Item (Row View)

class CharacterListItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("CharacterListItem")
    
    private var containerView: NSView!
    private var portraitImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    
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
        
        // Small portrait thumbnail
        portraitImageView = NSImageView(frame: .zero)
        portraitImageView.translatesAutoresizingMaskIntoConstraints = false
        portraitImageView.imageScaling = .scaleProportionallyUpOrDown
        portraitImageView.wantsLayer = true
        portraitImageView.layer?.backgroundColor = DesignColors.defaultPlaceholder.cgColor
        containerView.addSubview(portraitImageView)
        
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
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Portrait: 44x44, centered vertically
            portraitImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            portraitImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            portraitImageView.widthAnchor.constraint(equalToConstant: 44),
            portraitImageView.heightAnchor.constraint(equalToConstant: 44),
            
            // Name
            nameLabel.leadingAnchor.constraint(equalTo: portraitImageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Author
            authorLabel.leadingAnchor.constraint(equalTo: portraitImageView.trailingAnchor, constant: 12),
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
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
    
    func configure(with character: CharacterInfo) {
        nameLabel.stringValue = character.displayName
        authorLabel.stringValue = "by \(character.author)"
        portraitImageView.image = nil
    }
    
    func setPortrait(_ image: NSImage?) {
        portraitImageView.image = image
        if image != nil {
            portraitImageView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        portraitImageView.image = nil
        portraitImageView.layer?.backgroundColor = DesignColors.defaultPlaceholder.cgColor
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        isSelected = false
    }
}