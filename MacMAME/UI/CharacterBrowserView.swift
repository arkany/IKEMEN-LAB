import Cocoa
import Combine

// MARK: - Pasteboard Type for Character Drag

extension NSPasteboard.PasteboardType {
    static let characterDrag = NSPasteboard.PasteboardType("com.macmame.character-drag")
}

// MARK: - Custom Collection View for Context Menu Support

/// NSCollectionView subclass that properly handles right-click/control-click context menus
class CharacterCollectionView: NSCollectionView {
    
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
class CharacterClipView: NSClipView {
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

/// A visual browser for viewing installed characters with thumbnails
/// Uses shared design system from UIHelpers.swift
class CharacterBrowserView: NSView {
    
    // MARK: - Properties
    
    private var scrollView: NSScrollView!
    private var collectionView: CharacterCollectionView!
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
    var onCharacterRevealInFinder: ((CharacterInfo) -> Void)?
    var onCharacterRemove: ((CharacterInfo) -> Void)?
    
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
        scrollView.contentView = CharacterClipView()  // Use custom clip view
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
        collectionView = CharacterCollectionView(frame: bounds)
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        
        // Enable drag-and-drop reordering
        collectionView.registerForDraggedTypes([.characterDrag])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        // Register item classes
        collectionView.register(CharacterCollectionViewItem.self, forItemWithIdentifier: CharacterCollectionViewItem.identifier)
        collectionView.register(CharacterListItem.self, forItemWithIdentifier: CharacterListItem.identifier)
        
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
        // Keep characters in the order received (which comes from select.def via EmulatorBridge)
        self.characters = newCharacters
        collectionView.reloadData()
        
        // Load portraits in background
        loadPortraitsAsync()
    }
    
    // MARK: - Portrait Loading
    
    private func loadPortraitsAsync() {
        for character in characters {
            // Check local cache first (for current session quick access)
            if portraitCache[character.id] != nil { continue }
            
            // Check shared ImageCache
            let cacheKey = ImageCache.portraitKey(for: character.id)
            if let cached = ImageCache.shared.get(cacheKey) {
                portraitCache[character.id] = cached
                continue
            }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let portrait = character.getPortraitImage()
                
                DispatchQueue.main.async {
                    let finalImage = portrait ?? self?.createPlaceholderImage(for: character)
                    self?.portraitCache[character.id] = finalImage
                    
                    // Store in shared cache (only real portraits, not placeholders)
                    if let realPortrait = portrait {
                        ImageCache.shared.set(realPortrait, for: cacheKey)
                    }
                    
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
            .font: DesignFonts.header(size: 32),
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
    
    // MARK: - Context Menu
    
    private func buildContextMenu(for indexPath: IndexPath) -> NSMenu? {
        guard indexPath.item < characters.count else { return nil }
        let character = characters[indexPath.item]
        
        let menu = NSMenu()
        
        // Reveal in Finder
        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(revealInFinderAction(_:)), keyEquivalent: "")
        revealItem.representedObject = character
        revealItem.target = self
        menu.addItem(revealItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Remove Character
        let removeItem = NSMenuItem(title: "Remove Character…", action: #selector(removeCharacterAction(_:)), keyEquivalent: "")
        removeItem.representedObject = character
        removeItem.target = self
        menu.addItem(removeItem)
        
        return menu
    }
    
    @objc private func revealInFinderAction(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? CharacterInfo else { return }
        onCharacterRevealInFinder?(character)
    }
    
    @objc private func removeCharacterAction(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? CharacterInfo else { return }
        onCharacterRemove?(character)
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
    
    // MARK: - Drag and Drop
    
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        // Store the index as string data
        item.setString(String(indexPath.item), forType: .characterDrag)
        return item
    }
    
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexPaths: Set<IndexPath>) {
        // Optional: could add visual feedback here
    }
    
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        
        // Only accept drops between items (not on items)
        if proposedDropOperation.pointee == .on {
            proposedDropOperation.pointee = .before
        }
        
        return .move
    }
    
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        
        // Get the source index from the pasteboard
        guard let pasteboardItem = draggingInfo.draggingPasteboard.pasteboardItems?.first,
              let sourceIndexString = pasteboardItem.string(forType: .characterDrag),
              let sourceIndex = Int(sourceIndexString) else {
            return false
        }
        
        var destinationIndex = indexPath.item
        
        // Adjust destination if moving down
        if sourceIndex < destinationIndex {
            destinationIndex -= 1
        }
        
        // Don't do anything if not actually moving
        guard sourceIndex != destinationIndex else { return false }
        
        // Perform the move in our data model
        let movedCharacter = characters.remove(at: sourceIndex)
        characters.insert(movedCharacter, at: destinationIndex)
        
        // Animate the move in the collection view
        collectionView.animator().moveItem(at: IndexPath(item: sourceIndex, section: 0),
                                           to: IndexPath(item: destinationIndex, section: 0))
        
        // Save the new order to select.def
        saveCharacterOrder()
        
        return true
    }
    
    /// Save the current character order to select.def
    private func saveCharacterOrder() {
        guard let workingDir = IkemenBridge.shared.workingDirectory else { return }
        
        let characterNames = characters.map { $0.directory.lastPathComponent }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try ContentManager.shared.reorderCharacters(characterNames, in: workingDir)
                print("Saved character order: \(characterNames)")
            } catch {
                print("Failed to save character order: \(error)")
            }
        }
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
        
        // Name label - header style, centered
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.header(size: 16)
        nameLabel.textColor = DesignColors.grayText
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        containerView.addSubview(nameLabel)
        
        // Author label - body style, centered
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.body(size: 12)
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
        nameLabel.font = DesignFonts.header(size: 16)
        nameLabel.textColor = DesignColors.creamText
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)
        
        // Author
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.body(size: 12)
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