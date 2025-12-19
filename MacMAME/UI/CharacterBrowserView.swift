import Cocoa
import Combine

/// A visual browser for viewing installed characters with thumbnails
class CharacterBrowserView: NSView {
    
    // MARK: - Properties
    
    private var scrollView: NSScrollView!
    private var collectionView: NSCollectionView!
    private var flowLayout: NSCollectionViewFlowLayout!
    private var characters: [CharacterInfo] = []
    private var portraitCache: [String: NSImage] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Item sizing constants
    private let itemWidth: CGFloat = 120
    private let itemHeight: CGFloat = 150
    private let minSpacing: CGFloat = 12
    private let sectionInset: CGFloat = 16
    
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
        layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor
        
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
        flowLayout.itemSize = NSSize(width: itemWidth, height: itemHeight)
        flowLayout.minimumInteritemSpacing = minSpacing
        flowLayout.minimumLineSpacing = minSpacing
        flowLayout.sectionInset = NSEdgeInsets(top: sectionInset, left: sectionInset, bottom: sectionInset, right: sectionInset)
        
        // Create collection view
        collectionView = NSCollectionView(frame: bounds)
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        
        // Register item class
        collectionView.register(CharacterCollectionViewItem.self, forItemWithIdentifier: CharacterCollectionViewItem.identifier)
        
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
        // Calculate how many items can fit
        let availableWidth = width - (sectionInset * 2)
        let itemsPerRow = max(1, floor((availableWidth + minSpacing) / (itemWidth + minSpacing)))
        
        // Calculate spacing to distribute items evenly
        let totalItemWidth = itemsPerRow * itemWidth
        let totalSpacing = availableWidth - totalItemWidth
        let spacing = max(minSpacing, totalSpacing / max(1, itemsPerRow - 1))
        
        // Update layout
        flowLayout.minimumInteritemSpacing = spacing
        flowLayout.invalidateLayout()
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
        
        // Background
        NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.25, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw initial
        let initial = String(character.displayName.prefix(1)).uppercased()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 40, weight: .bold),
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
        let item = collectionView.makeItem(withIdentifier: CharacterCollectionViewItem.identifier, for: indexPath) as! CharacterCollectionViewItem
        
        let character = characters[indexPath.item]
        item.configure(with: character)
        
        if let cachedPortrait = portraitCache[character.id] {
            item.setPortrait(cachedPortrait)
        }
        
        return item
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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 150))
        view.wantsLayer = true
        
        setupViews()
    }
    
    private func setupViews() {
        // Container with rounded corners
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.2, alpha: 1.0).cgColor
        containerView.layer?.borderWidth = 2
        containerView.layer?.borderColor = NSColor.clear.cgColor
        view.addSubview(containerView)
        
        // Portrait image
        portraitImageView = NSImageView(frame: .zero)
        portraitImageView.translatesAutoresizingMaskIntoConstraints = false
        portraitImageView.imageScaling = .scaleProportionallyUpOrDown
        portraitImageView.wantsLayer = true
        portraitImageView.layer?.cornerRadius = 4
        portraitImageView.layer?.masksToBounds = true
        portraitImageView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 1.0).cgColor
        containerView.addSubview(portraitImageView)
        
        // Name label
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        containerView.addSubview(nameLabel)
        
        // Author label
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        authorLabel.textColor = NSColor(white: 0.5, alpha: 1.0)
        authorLabel.alignment = .center
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.maximumNumberOfLines = 1
        containerView.addSubview(authorLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            portraitImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            portraitImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            portraitImageView.widthAnchor.constraint(equalToConstant: 100),
            portraitImageView.heightAnchor.constraint(equalToConstant: 100),
            
            nameLabel.topAnchor.constraint(equalTo: portraitImageView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
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
            containerView.layer?.borderColor = NSColor(calibratedRed: 0.4, green: 0.6, blue: 1.0, alpha: 1.0).cgColor
            containerView.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.25, blue: 0.35, alpha: 1.0).cgColor
        } else {
            containerView.layer?.borderColor = NSColor.clear.cgColor
            containerView.layer?.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.2, alpha: 1.0).cgColor
        }
    }
    
    func configure(with character: CharacterInfo) {
        nameLabel.stringValue = character.displayName
        authorLabel.stringValue = "by \(character.author)"
        portraitImageView.image = nil
    }
    
    func setPortrait(_ image: NSImage?) {
        portraitImageView.image = image
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        portraitImageView.image = nil
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        isSelected = false
    }
}
