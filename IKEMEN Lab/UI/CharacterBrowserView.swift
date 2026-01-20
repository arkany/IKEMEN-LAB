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
    private var allCharacters: [CharacterInfo] = []  // All characters from data source
    private var characters: [CharacterInfo] = []     // Filtered characters for display
    private var portraitCache: [String: NSImage] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var activeScreenpackSlotLimit: Int = 0
    private var duplicateIds: Set<String> = []       // IDs of characters that have duplicates
    private var themeObserver: NSObjectProtocol?
    
    // View mode
    var viewMode: BrowserViewMode = .grid {
        didSet {
            updateLayoutForViewMode()
        }
    }
    
    // Registration status filter
    var registrationFilter: RegistrationFilter = .all {
        didSet {
            applyFilters()
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
    var onCharacterDisableToggle: ((CharacterInfo) -> Void)?
    
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
        // Use max to ensure non-zero size (required by flow layout)
        flowLayout.itemSize = NSSize(width: max(gridItemWidth, 100), height: max(gridItemHeight, 100))
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
        
        // Register supplementary view for cutoff divider
        collectionView.register(
            CutoffDividerView.self,
            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: NSUserInterfaceItemIdentifier("CutoffDivider")
        )
        
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
        IkemenBridge.shared.$characters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] characters in
                self?.updateCharacters(characters)
            }
            .store(in: &cancellables)
        
        IkemenBridge.shared.$screenpacks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] screenpacks in
                self?.activeScreenpackSlotLimit = screenpacks.first(where: { $0.isActive })?.characterSlots ?? 0
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)

        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Update all visible items (both grid and list)
            for indexPath in self.collectionView.indexPathsForVisibleItems() {
                if let item = self.collectionView.item(at: indexPath) as? CharacterCollectionViewItem {
                    item.applyTheme()
                } else if let item = self.collectionView.item(at: indexPath) as? CharacterListItem {
                    item.applyTheme()
                }
            }
            // Also update the list view header and other components
            self.collectionView.reloadData()
        }
    }
    
    /// Set characters directly (used for search filtering)
    func setCharacters(_ newCharacters: [CharacterInfo]) {
        updateCharacters(newCharacters)
    }
    
    private func updateCharacters(_ newCharacters: [CharacterInfo]) {
        // Keep characters in the order received (which comes from select.def via EmulatorBridge)
        self.allCharacters = newCharacters
        
        // Compute duplicate IDs
        computeDuplicates()
        
        applyFilters()
        
        // Load portraits in background
        loadPortraitsAsync()
    }
    
    /// Compute which characters are duplicates and store their IDs
    private func computeDuplicates() {
        let groups = DuplicateDetector.findDuplicateCharacters(allCharacters)
        duplicateIds.removeAll()
        for group in groups {
            for item in group.items {
                duplicateIds.insert(item.id)
            }
        }
    }
    
    /// Apply registration filter to characters
    private func applyFilters() {
        switch registrationFilter {
        case .all:
            characters = allCharacters
        case .registeredOnly:
            characters = allCharacters.filter { $0.status == .active || $0.status == .disabled }
        case .unregisteredOnly:
            characters = allCharacters.filter { $0.status == .unregistered }
        }
        collectionView.reloadData()
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
                    
                    // Find and update the item in the correct section
                    guard let self else { return }
                    if let index = self.characters.firstIndex(where: { $0.id == character.id }) {
                        let indexPath: IndexPath
                        if self.shouldShowCutoffDivider() && index >= self.activeScreenpackSlotLimit {
                            indexPath = IndexPath(item: index - self.activeScreenpackSlotLimit, section: 1)
                        } else {
                            indexPath = IndexPath(item: index, section: 0)
                        }
                        
                        if let item = self.collectionView.item(at: indexPath) as? CharacterCollectionViewItem {
                            item.setPortrait(self.portraitCache[character.id])
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

    deinit {
        if let themeObserver = themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }
    
    // MARK: - Context Menu
    
    private func buildContextMenu(for indexPath: IndexPath) -> NSMenu? {
        // Calculate actual character index based on section
        let characterIndex: Int
        if shouldShowCutoffDivider() {
            if indexPath.section == 0 {
                characterIndex = indexPath.item
            } else {
                characterIndex = activeScreenpackSlotLimit + indexPath.item
            }
        } else {
            characterIndex = indexPath.item
        }
        
        guard characterIndex < characters.count else { return nil }
        let character = characters[characterIndex]
        
        let menu = NSMenu()
        
        // If unregistered, show "Add to select.def" option first
        if character.status == .unregistered {
            let addToSelectDefItem = NSMenuItem(
                title: "Add to select.def",
                action: #selector(addToSelectDefAction(_:)),
                keyEquivalent: ""
            )
            addToSelectDefItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
            addToSelectDefItem.representedObject = character
            addToSelectDefItem.target = self
            menu.addItem(addToSelectDefItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Add to Collection submenu
        let addToCollectionItem = NSMenuItem(title: "Add to Collection", action: nil, keyEquivalent: "")
        addToCollectionItem.submenu = buildCollectionsSubmenu(for: character)
        menu.addItem(addToCollectionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Enable/Disable toggle (only for registered characters)
        if character.status != .unregistered {
            let disableItem = NSMenuItem()
            if character.isDisabled {
                disableItem.title = "Enable Character"
                disableItem.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
            } else {
                disableItem.title = "Disable Character"
                disableItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
            }
            disableItem.target = self
            disableItem.action = #selector(toggleDisableCharacter(_:))
            disableItem.representedObject = character
            menu.addItem(disableItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Check if folder name is mismatched with character name
        if let suggestedName = ContentManager.shared.detectMismatchedCharacterFolder(character.directory) {
            let renameItem = NSMenuItem(
                title: "Rename Folder to \"\(suggestedName)\"",
                action: #selector(renameCharacterFolder(_:)),
                keyEquivalent: ""
            )
            renameItem.image = NSImage(systemSymbolName: "folder.badge.questionmark", accessibilityDescription: nil)
            renameItem.representedObject = (character, suggestedName)
            renameItem.target = self
            menu.addItem(renameItem)
            menu.addItem(NSMenuItem.separator())
        }
        
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
    
    private func buildCollectionsSubmenu(for character: CharacterInfo) -> NSMenu {
        let submenu = NSMenu()
        
        let collections = CollectionStore.shared.collections.filter { !$0.isDefault }
        
        if collections.isEmpty {
            let emptyItem = NSMenuItem(title: "No collections", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for collection in collections {
                let item = NSMenuItem(title: collection.name, action: #selector(addToCollectionAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = (character, collection)
                
                // Show checkmark if character is already in this collection
                let isInCollection = collection.characters.contains { $0.characterFolder == character.directory.lastPathComponent }
                if isInCollection {
                    item.state = .on
                }
                
                submenu.addItem(item)
            }
        }
        
        submenu.addItem(NSMenuItem.separator())
        
        // New Collection option
        let newCollectionItem = NSMenuItem(title: "New Collection…", action: #selector(addToNewCollectionAction(_:)), keyEquivalent: "")
        newCollectionItem.target = self
        newCollectionItem.representedObject = character
        submenu.addItem(newCollectionItem)
        
        return submenu
    }
    
    @objc private func addToCollectionAction(_ sender: NSMenuItem) {
        guard let (character, collection) = sender.representedObject as? (CharacterInfo, Collection) else { return }
        
        let folder = character.directory.lastPathComponent
        let def = character.defFile.lastPathComponent
        
        // Check if already in collection
        let isInCollection = collection.characters.contains { $0.characterFolder == folder }
        
        if isInCollection {
            // Remove from collection
            if let entry = collection.characters.first(where: { $0.characterFolder == folder }) {
                CollectionStore.shared.removeCharacter(entryId: entry.id, from: collection.id)
                ToastManager.shared.showInfo(title: "Removed from \(collection.name)")
            }
        } else {
            // Add to collection
            CollectionStore.shared.addCharacter(folder: folder, def: def, to: collection.id)
            ToastManager.shared.showSuccess(title: "Added to \(collection.name)")
        }
    }
    
    @objc private func addToNewCollectionAction(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? CharacterInfo else { return }
        
        let alert = NSAlert()
        alert.messageText = "New Collection"
        alert.informativeText = "Enter a name for the new collection:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        input.placeholderString = "Collection Name"
        alert.accessoryView = input
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let name = input.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        // Create collection and add character
        let collection = CollectionStore.shared.createCollection(name: name)
        let folder = character.directory.lastPathComponent
        let def = character.defFile.lastPathComponent
        CollectionStore.shared.addCharacter(folder: folder, def: def, to: collection.id)
        
        ToastManager.shared.showSuccess(title: "Created \(name) with \(character.displayName)")
    }
    
    @objc private func toggleDisableCharacter(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? CharacterInfo else { return }
        onCharacterDisableToggle?(character)
    }
    
    @objc private func addToSelectDefAction(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? CharacterInfo,
              let workingDir = IkemenBridge.shared.workingDirectory else { return }
        
        do {
            // Find the correct select.def entry for this character
            let charEntry = ContentManager.shared.findCharacterDefEntry(charName: character.directory.lastPathComponent, in: character.directory)
            
            // Add to select.def
            try ContentManager.shared.addCharacterToSelectDef(charEntry, in: workingDir)
            
            // Reload characters to update status
            IkemenBridge.shared.loadContent()
            
            // Show success toast
            ToastManager.shared.showSuccess(
                title: "Added to select.def",
                subtitle: "\(character.displayName) will now appear in-game"
            )
        } catch {
            ToastManager.shared.showError(
                title: "Failed to add character",
                subtitle: error.localizedDescription
            )
        }
    }
    
    @objc private func renameCharacterFolder(_ sender: NSMenuItem) {
        guard let (character, suggestedName) = sender.representedObject as? (CharacterInfo, String),
              let workingDir = IkemenBridge.shared.workingDirectory else { return }
        
        do {
            try ContentManager.shared.fixMisnamedCharacterFolder(
                character.directory,
                suggestedName: suggestedName,
                workingDir: workingDir
            )
            
            // Refresh the character list
            IkemenBridge.shared.loadContent()
            
            // Show success toast
            ToastManager.shared.showSuccess(title: "Renamed to \(suggestedName)")
        } catch {
            ToastManager.shared.showError(
                title: "Failed to rename folder",
                subtitle: error.localizedDescription
            )
        }
    }
    
    @objc private func revealInFinderAction(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? CharacterInfo else { return }
        onCharacterRevealInFinder?(character)
    }
    
    @objc private func removeCharacterAction(_ sender: NSMenuItem) {
        guard let character = sender.representedObject as? CharacterInfo else { return }
        onCharacterRemove?(character)
    }
    
    /// Show context menu from the more button in list view
    private func showContextMenuForListItem(_ character: CharacterInfo, sourceView: NSView) {
        guard let index = characters.firstIndex(where: { $0.id == character.id }) else { return }
        
        // Determine the correct section and item index
        let indexPath: IndexPath
        if shouldShowCutoffDivider() {
            if index < activeScreenpackSlotLimit {
                indexPath = IndexPath(item: index, section: 0)
            } else {
                indexPath = IndexPath(item: index - activeScreenpackSlotLimit, section: 1)
            }
        } else {
            indexPath = IndexPath(item: index, section: 0)
        }
        
        guard let menu = buildContextMenu(for: indexPath) else { return }
        
        // Position menu below the button
        let buttonBounds = sourceView.bounds
        let menuLocation = NSPoint(x: buttonBounds.midX, y: buttonBounds.minY)
        menu.popUp(positioning: nil, at: menuLocation, in: sourceView)
    }
}

// MARK: - NSCollectionViewDataSource

extension CharacterBrowserView: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        // Use 2 sections if there's a cutoff, otherwise 1
        if shouldShowCutoffDivider() {
            return 2  // Section 0: visible characters, Section 1: hidden characters
        }
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if shouldShowCutoffDivider() {
            // Section 0: visible characters (up to slot limit)
            // Section 1: hidden characters (beyond slot limit)
            if section == 0 {
                return min(characters.count, activeScreenpackSlotLimit)
            } else {
                return max(0, characters.count - activeScreenpackSlotLimit)
            }
        }
        return characters.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        // Calculate actual character index based on section
        let characterIndex: Int
        if shouldShowCutoffDivider() {
            if indexPath.section == 0 {
                characterIndex = indexPath.item
            } else {
                characterIndex = activeScreenpackSlotLimit + indexPath.item
            }
        } else {
            characterIndex = indexPath.item
        }
        
        let character = characters[characterIndex]
        let isDuplicate = duplicateIds.contains(character.id)
        
        if viewMode == .grid {
            let item = collectionView.makeItem(withIdentifier: CharacterCollectionViewItem.identifier, for: indexPath) as! CharacterCollectionViewItem
            item.configure(with: character, isDuplicate: isDuplicate)
            
            if let cachedPortrait = portraitCache[character.id] {
                item.setPortrait(cachedPortrait)
            }
            
            // Dim characters in section 1 (hidden) but keep interactions intact
            item.view.alphaValue = shouldShowCutoffDivider() && indexPath.section == 1 ? 0.5 : 1.0
            
            return item
        } else {
            let item = collectionView.makeItem(withIdentifier: CharacterListItem.identifier, for: indexPath) as! CharacterListItem
            item.configure(with: character, isDuplicate: isDuplicate)
            
            // Wire up the toggle callback
            item.onStatusToggled = { [weak self] isEnabled in
                // Toggle means we're changing the state - if toggled ON, we want to enable
                self?.onCharacterDisableToggle?(character)
            }
            
            // Wire up the more button callback
            item.onMoreClicked = { [weak self] char, sourceView in
                self?.showContextMenuForListItem(char, sourceView: sourceView)
            }
            
            if let cachedPortrait = portraitCache[character.id] {
                item.setPortrait(cachedPortrait)
            }
            
            // Dim list rows in the hidden section while leaving them fully interactive
            item.view.alphaValue = shouldShowCutoffDivider() && indexPath.section == 1 ? 0.5 : 1.0
            
            return item
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        // Only show header for section 1 (hidden characters)
        if kind == NSCollectionView.elementKindSectionHeader && indexPath.section == 1 {
            let view = collectionView.makeSupplementaryView(
                ofKind: kind,
                withIdentifier: NSUserInterfaceItemIdentifier("CutoffDivider"),
                for: indexPath
            ) as! CutoffDividerView
            
            let visibleCount = min(characters.count, activeScreenpackSlotLimit)
            let hiddenCount = max(0, characters.count - activeScreenpackSlotLimit)
            view.configure(visibleCount: visibleCount, hiddenCount: hiddenCount)
            
            return view
        }
        
        return NSView()
    }
    
    // MARK: - Helper Methods
    
    private func shouldShowCutoffDivider() -> Bool {
        // Only show divider if:
        // 1. There's an active screenpack with a known slot limit
        // 2. The number of characters exceeds the slot limit
        return activeScreenpackSlotLimit > 0 && characters.count > activeScreenpackSlotLimit
    }
}

// MARK: - NSCollectionViewDelegate

extension CharacterBrowserView: NSCollectionViewDelegate {
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        
        // Calculate actual character index based on section
        let characterIndex: Int
        if shouldShowCutoffDivider() {
            if indexPath.section == 0 {
                characterIndex = indexPath.item
            } else {
                characterIndex = activeScreenpackSlotLimit + indexPath.item
            }
        } else {
            characterIndex = indexPath.item
        }
        
        let character = characters[characterIndex]
        onCharacterSelected?(character)
    }
    
    // MARK: - Drag and Drop
    
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        // Calculate actual character index based on section
        let characterIndex: Int
        if shouldShowCutoffDivider() {
            if indexPath.section == 0 {
                characterIndex = indexPath.item
            } else {
                characterIndex = activeScreenpackSlotLimit + indexPath.item
            }
        } else {
            characterIndex = indexPath.item
        }
        
        let item = NSPasteboardItem()
        // Store the actual character index as string data
        item.setString(String(characterIndex), forType: .characterDrag)
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
        
        // Get the source index from the pasteboard (this is the actual character index)
        guard let pasteboardItem = draggingInfo.draggingPasteboard.pasteboardItems?.first,
              let sourceIndexString = pasteboardItem.string(forType: .characterDrag),
              let sourceIndex = Int(sourceIndexString) else {
            return false
        }
        
        // Calculate destination index based on section
        var destinationIndex: Int
        if shouldShowCutoffDivider() {
            if indexPath.section == 0 {
                destinationIndex = indexPath.item
            } else {
                destinationIndex = activeScreenpackSlotLimit + indexPath.item
            }
        } else {
            destinationIndex = indexPath.item
        }
        
        // Adjust destination if moving down
        if sourceIndex < destinationIndex {
            destinationIndex -= 1
        }
        
        // Don't do anything if not actually moving
        guard sourceIndex != destinationIndex else { return false }
        
        // Perform the move in our data model
        let movedCharacter = characters.remove(at: sourceIndex)
        characters.insert(movedCharacter, at: destinationIndex)
        
        // Calculate source and destination IndexPaths for animation
        let sourceIndexPath: IndexPath
        let destIndexPath: IndexPath
        
        if shouldShowCutoffDivider() {
            // Calculate section-based index paths
            if sourceIndex < activeScreenpackSlotLimit {
                sourceIndexPath = IndexPath(item: sourceIndex, section: 0)
            } else {
                sourceIndexPath = IndexPath(item: sourceIndex - activeScreenpackSlotLimit, section: 1)
            }
            
            if destinationIndex < activeScreenpackSlotLimit {
                destIndexPath = IndexPath(item: destinationIndex, section: 0)
            } else {
                destIndexPath = IndexPath(item: destinationIndex - activeScreenpackSlotLimit, section: 1)
            }
        } else {
            sourceIndexPath = IndexPath(item: sourceIndex, section: 0)
            destIndexPath = IndexPath(item: destinationIndex, section: 0)
        }
        
        // Reload data instead of animating move (safer with sections)
        collectionView.reloadData()
        
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

// MARK: - NSCollectionViewDelegateFlowLayout

extension CharacterBrowserView: NSCollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> NSSize {
        // Only show header for section 1 (hidden characters section)
        if section == 1 && shouldShowCutoffDivider() {
            return NSSize(width: collectionView.bounds.width, height: 40)
        }
        return .zero
    }
}

// MARK: - Gradient Overlay View
/// A view that displays a gradient from bottom (dark) to top (transparent)
/// Properly manages its own CAGradientLayer
class GradientOverlayView: NSView {
    
    private let gradientLayer = CAGradientLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        wantsLayer = true
        layer?.addSublayer(gradientLayer)
        
        // Gradient from bottom (dark) to top (transparent)
        // Matches HTML: bg-gradient-to-t from-zinc-950 via-zinc-950/20 to-transparent
        gradientLayer.colors = [
            DesignColors.panelBackground.cgColor,                              // bottom: panel background (full)
            DesignColors.panelBackground.withAlphaComponent(0.2).cgColor,      // via: panel/20
            NSColor.clear.cgColor                                      // top: transparent
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)  // bottom
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)    // top
    }
    
    func applyTheme() {
        gradientLayer.colors = [
            DesignColors.panelBackground.cgColor,
            DesignColors.panelBackground.withAlphaComponent(0.2).cgColor,
            NSColor.clear.cgColor
        ]
    }
    
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        CATransaction.commit()
    }
    
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    override func updateLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        CATransaction.commit()
    }
}

// MARK: - Character Collection View Item (Grid Card)
/// Matches HTML design: aspect-square card with gradient overlay, name/author at bottom-left
/// States: default, hover, selected (active)
class CharacterCollectionViewItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("CharacterCollectionViewItem")
    
    private var containerView: NSView!
    private var portraitImageView: NSImageView!
    private var gradientOverlay: GradientOverlayView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var statusDot: NSView!
    private var placeholderLabel: NSTextField!
    private var tagsStackView: NSStackView!
    private var unregisteredOverlay: NSView!
    private var unregisteredBadge: NSView!
    private var unregisteredLabel: NSTextField!
    private var duplicateBadge: NSView!
    private var duplicateLabel: NSTextField!
    
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    
    // Animation duration (200ms as requested)
    private let animationDuration: CGFloat = 0.2
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 180))
        view.wantsLayer = true
        setupViews()
    }
    
    private func setupViews() {
        // Container - rounded-xl (12px), with border
        containerView = NSView(frame: view.bounds)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true
        containerView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.1).cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        view.addSubview(containerView)
        
        // Portrait image - fills container
        portraitImageView = NSImageView(frame: .zero)
        portraitImageView.translatesAutoresizingMaskIntoConstraints = false
        portraitImageView.imageScaling = .scaleProportionallyUpOrDown
        portraitImageView.wantsLayer = true
        portraitImageView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
        containerView.addSubview(portraitImageView)
        
        // Placeholder initial (shows when no portrait)
        placeholderLabel = NSTextField(labelWithString: "")
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = DesignFonts.header(size: 48)
        placeholderLabel.textColor = DesignColors.textPrimary.withAlphaComponent(0.05)
        placeholderLabel.alignment = .center
        containerView.addSubview(placeholderLabel)
        
        // Gradient overlay view - sits on top of image
        // Uses dedicated GradientOverlayView that properly manages its CAGradientLayer
        gradientOverlay = GradientOverlayView()
        gradientOverlay.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(gradientOverlay)
        
        // Status dot (top-right) - emerald-500 for active
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
        
        // Name label - bottom-left, primary color, semibold
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.textColor = DesignColors.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        containerView.addSubview(nameLabel)
        
        // Author label - below name, zinc-400/500, smaller
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.caption(size: 10)
        authorLabel.textColor = DesignColors.textTertiary
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.maximumNumberOfLines = 1
        containerView.addSubview(authorLabel)
        
        // Tags stack view - horizontal, above the name label
        tagsStackView = NSStackView()
        tagsStackView.translatesAutoresizingMaskIntoConstraints = false
        tagsStackView.orientation = .horizontal
        tagsStackView.spacing = 4
        tagsStackView.alignment = .leading
        tagsStackView.distribution = .fill
        containerView.addSubview(tagsStackView)
        
        // Unregistered overlay - semi-transparent overlay for unregistered characters
        unregisteredOverlay = NSView()
        unregisteredOverlay.translatesAutoresizingMaskIntoConstraints = false
        unregisteredOverlay.wantsLayer = true
        unregisteredOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        unregisteredOverlay.isHidden = true
        containerView.addSubview(unregisteredOverlay)
        
        // Unregistered badge - top-right corner
        unregisteredBadge = NSView()
        unregisteredBadge.translatesAutoresizingMaskIntoConstraints = false
        unregisteredBadge.wantsLayer = true
        unregisteredBadge.layer?.cornerRadius = 4
        unregisteredBadge.layer?.backgroundColor = DesignColors.red900.cgColor
        unregisteredBadge.layer?.borderWidth = 1
        unregisteredBadge.layer?.borderColor = DesignColors.negative.withAlphaComponent(0.3).cgColor
        unregisteredBadge.isHidden = true
        containerView.addSubview(unregisteredBadge)
        
        unregisteredLabel = NSTextField(labelWithString: "UNREGISTERED")
        unregisteredLabel.translatesAutoresizingMaskIntoConstraints = false
        unregisteredLabel.font = DesignFonts.caption(size: 8)
        unregisteredLabel.textColor = DesignColors.red200
        unregisteredLabel.isBordered = false
        unregisteredLabel.drawsBackground = false
        unregisteredLabel.isEditable = false
        unregisteredLabel.isSelectable = false
        unregisteredBadge.addSubview(unregisteredLabel)
        
        // Duplicate badge - top-left corner (opposite unregistered which is top-right)
        duplicateBadge = NSView()
        duplicateBadge.translatesAutoresizingMaskIntoConstraints = false
        duplicateBadge.wantsLayer = true
        duplicateBadge.layer?.cornerRadius = 4
        duplicateBadge.layer?.backgroundColor = DesignColors.amber900.cgColor
        duplicateBadge.layer?.borderWidth = 1
        duplicateBadge.layer?.borderColor = DesignColors.warning.withAlphaComponent(0.3).cgColor
        duplicateBadge.isHidden = true
        containerView.addSubview(duplicateBadge)
        
        duplicateLabel = NSTextField(labelWithString: "DUPLICATE")
        duplicateLabel.translatesAutoresizingMaskIntoConstraints = false
        duplicateLabel.font = DesignFonts.caption(size: 8)
        duplicateLabel.textColor = DesignColors.amber200
        duplicateLabel.isBordered = false
        duplicateLabel.drawsBackground = false
        duplicateLabel.isEditable = false
        duplicateLabel.isSelectable = false
        duplicateBadge.addSubview(duplicateLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            portraitImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            portraitImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            portraitImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            portraitImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Gradient overlay fills container
            gradientOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            gradientOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gradientOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            gradientOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            statusDot.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            statusDot.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
            
            // Tags above name
            tagsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            tagsStackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -8),
            tagsStackView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -6),
            
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            nameLabel.bottomAnchor.constraint(equalTo: authorLabel.topAnchor, constant: -2),
            
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            authorLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            // Unregistered overlay fills container
            unregisteredOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            unregisteredOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            unregisteredOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            unregisteredOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Unregistered badge in top-right
            unregisteredBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            unregisteredBadge.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            unregisteredBadge.heightAnchor.constraint(equalToConstant: 18),
            
            unregisteredLabel.centerYAnchor.constraint(equalTo: unregisteredBadge.centerYAnchor),
            unregisteredLabel.leadingAnchor.constraint(equalTo: unregisteredBadge.leadingAnchor, constant: 6),
            unregisteredLabel.trailingAnchor.constraint(equalTo: unregisteredBadge.trailingAnchor, constant: -6),
            
            // Duplicate badge in top-left
            duplicateBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            duplicateBadge.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            duplicateBadge.heightAnchor.constraint(equalToConstant: 18),
            
            duplicateLabel.centerYAnchor.constraint(equalTo: duplicateBadge.centerYAnchor),
            duplicateLabel.leadingAnchor.constraint(equalTo: duplicateBadge.leadingAnchor, constant: 6),
            duplicateLabel.trailingAnchor.constraint(equalTo: duplicateBadge.trailingAnchor, constant: -6),
        ])
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
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
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if isSelected {
                // Active state: strong border, elevated bg
                containerView.animator().layer?.borderColor = DesignColors.borderStrong.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.4).cgColor
                // Add subtle glow
                containerView.layer?.shadowColor = DesignColors.textPrimary.cgColor
                containerView.layer?.shadowOffset = .zero
                containerView.layer?.shadowRadius = 8
                containerView.layer?.shadowOpacity = 0.1
            } else if isHovered {
                // Hover state: hover border, medium bg
                containerView.animator().layer?.borderColor = DesignColors.borderHover.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.3).cgColor
                containerView.layer?.shadowOpacity = 0
            } else {
                // Default state: subtle border, light bg
                containerView.animator().layer?.borderColor = DesignColors.borderSubtle.cgColor
                containerView.animator().layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.1).cgColor
                containerView.layer?.shadowOpacity = 0
            }
        }
        
        // Placeholder text color change on hover
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        placeholderLabel.textColor = isHovered ? DesignColors.textPrimary.withAlphaComponent(0.1) : DesignColors.textPrimary.withAlphaComponent(0.05)
        
        // Name color change: primary when selected/hovered
        if isSelected {
            nameLabel.textColor = DesignColors.textPrimary
        } else if isHovered {
            nameLabel.textColor = DesignColors.textPrimary
        } else {
            nameLabel.textColor = DesignColors.textPrimary
        }
        CATransaction.commit()
    }
    
    func configure(with character: CharacterInfo, isDuplicate: Bool = false) {
        nameLabel.stringValue = character.displayName
        let formattedDate = VersionDateFormatter.formatToStandard(character.versionDate)
        authorLabel.stringValue = "\(character.author) • \(formattedDate.isEmpty ? "v1.0" : formattedDate)"
        placeholderLabel.stringValue = String(character.displayName.prefix(1)).uppercased()
        portraitImageView.image = nil
        placeholderLabel.isHidden = false
        
        // Show status dot if this is the first character (placeholder logic - could be enhanced)
        statusDot.isHidden = true
        
        // Show unregistered overlay and badge for unregistered characters
        let isUnregistered = (character.status == .unregistered)
        unregisteredOverlay.isHidden = !isUnregistered
        unregisteredBadge.isHidden = !isUnregistered
        
        // Show duplicate badge
        duplicateBadge.isHidden = !isDuplicate
        
        // Add tooltip for unregistered or duplicate characters
        if isUnregistered && isDuplicate {
            view.toolTip = "Not in select.def • Duplicate detected in library"
        } else if isUnregistered {
            view.toolTip = "Not in select.def - won't appear in game"
        } else if isDuplicate {
            view.toolTip = "Duplicate detected in library"
        } else {
            view.toolTip = nil
        }
        
        // Update tags (show up to 3)
        updateTags(character.inferredTags)
        
        // Apply current theme colors
        applyTheme()
    }
    
    private func updateTags(_ tags: [String]) {
        // Clear existing tags
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add up to 3 tags
        let displayTags = Array(tags.prefix(3))
        for tag in displayTags {
            let badge = createSmallTagBadge(tag)
            tagsStackView.addArrangedSubview(badge)
        }
        
        // Hide if no tags
        tagsStackView.isHidden = displayTags.isEmpty
    }
    
    private func createSmallTagBadge(_ text: String) -> NSView {
        let badge = NSView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        badge.layer?.cornerRadius = 4
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.caption(size: 9)
        label.textColor = NSColor.white.withAlphaComponent(0.9)
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        badge.addSubview(label)
        
        NSLayoutConstraint.activate([
            badge.heightAnchor.constraint(equalToConstant: 16),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -5),
        ])
        
        return badge
    }
    
    func setPortrait(_ image: NSImage?) {
        portraitImageView.image = image
        placeholderLabel.isHidden = (image != nil)
        if image != nil {
            portraitImageView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    /// Show/hide status indicator (e.g., for warnings)
    func setStatus(_ status: CharacterStatus) {
        switch status {
        case .active:
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = DesignColors.positive.cgColor
            statusDot.layer?.shadowColor = DesignColors.positive.cgColor
        case .warning:
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = DesignColors.warning.cgColor
            statusDot.layer?.shadowColor = DesignColors.warning.cgColor
        case .none:
            statusDot.isHidden = true
        }
    }
    
    /// Update all theme-dependent colors and gradients
    func applyTheme() {
        // Update gradient overlay
        gradientOverlay.applyTheme()
        
        // Update container background and border
        containerView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.1).cgColor
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Update portrait placeholder background
        portraitImageView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
        
        // Update text colors
        placeholderLabel.textColor = DesignColors.textPrimary.withAlphaComponent(0.05)
        nameLabel.textColor = DesignColors.textPrimary
        authorLabel.textColor = DesignColors.textTertiary
        
        // Update status dot color
        statusDot.layer?.backgroundColor = DesignColors.positive.cgColor
        statusDot.layer?.shadowColor = DesignColors.positive.cgColor
        
        // Update unregistered badge
        unregisteredBadge.layer?.backgroundColor = DesignColors.red900.cgColor
        unregisteredBadge.layer?.borderColor = DesignColors.red400.withAlphaComponent(0.3).cgColor
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        portraitImageView.image = nil
        portraitImageView.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
        placeholderLabel.isHidden = false
        nameLabel.stringValue = ""
        authorLabel.stringValue = ""
        statusDot.isHidden = true
        isSelected = false
        isHovered = false
        updateAppearance(animated: false)
        
        // Clear tags
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tagsStackView.isHidden = true
        
        // Reset unregistered overlay and badge
        unregisteredOverlay.isHidden = true
        unregisteredBadge.isHidden = true
        
        // Reset duplicate badge
        duplicateBadge.isHidden = true
        
        view.toolTip = nil
        
        // Apply current theme colors
        applyTheme()
    }
}

/// Status for character cards
enum CharacterStatus {
    case none
    case active
    case warning
}

// MARK: - Character List Item (Table Row)
/// Matches HTML design: table row with columns for icon, name+path, author, series badge, version, date
/// Uses hover states with 200ms transitions

class CharacterListItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("CharacterListItem")
    
    private var containerView: NSView!
    private var iconView: NSView!
    private var iconImageView: NSImageView!
    private var iconInitialLabel: NSTextField!
    private var nameStack: NSStackView!
    private var nameLabel: NSTextField!
    private var pathLabel: NSTextField!
    private var statusDot: NSView!
    private var authorLabel: NSTextField!
    private var seriesBadge: NSView!
    private var seriesLabel: NSTextField!
    private var versionLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var statusToggle: NSSwitch!
    private var moreButton: NSButton!
    
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    
    private let animationDuration: CGFloat = 0.2
    
    // Fixed column widths (these don't resize)
    private let iconColumnWidth: CGFloat = 48  // Padding + 32px icon
    private let toggleColumnWidth: CGFloat = 52  // Toggle switch needs ~50px
    private let moreColumnWidth: CGFloat = 44   // More button with extra padding
    private let rightPadding: CGFloat = 24      // Extra right margin
    
    // Minimum widths for flexible columns
    private let nameMinWidth: CGFloat = 160
    private let authorMinWidth: CGFloat = 80
    private let seriesMinWidth: CGFloat = 60
    private let versionMinWidth: CGFloat = 50
    private let dateMinWidth: CGFloat = 70
    
    // Column width constraints (for responsive resizing)
    private var nameWidthConstraint: NSLayoutConstraint?
    private var authorWidthConstraint: NSLayoutConstraint?
    private var versionWidthConstraint: NSLayoutConstraint?
    private var dateWidthConstraint: NSLayoutConstraint?
    
    // Callbacks
    var onStatusToggled: ((Bool) -> Void)?
    var onMoreClicked: ((CharacterInfo, NSView) -> Void)?
    private var currentCharacter: CharacterInfo?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 52))
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
        borderLine.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        borderLine.identifier = NSUserInterfaceItemIdentifier("listBorderLine")
        containerView.addSubview(borderLine)
        
        // Icon container with gradient background
        iconView = NSView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 4
        iconView.layer?.borderWidth = 1
        iconView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Create gradient layer for icon bg
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            DesignColors.cardBackground.cgColor,
            DesignColors.panelBackground.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 4
        iconView.layer?.addSublayer(gradientLayer)
        containerView.addSubview(iconView)
        
        // Icon image
        iconImageView = NSImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.wantsLayer = true
        iconView.addSubview(iconImageView)
        
        // Icon initial placeholder
        iconInitialLabel = NSTextField(labelWithString: "")
        iconInitialLabel.translatesAutoresizingMaskIntoConstraints = false
        iconInitialLabel.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        iconInitialLabel.textColor = DesignColors.textTertiary
        iconInitialLabel.alignment = .center
        iconView.addSubview(iconInitialLabel)
        
        // Name + path stack
        nameStack = NSStackView()
        nameStack.translatesAutoresizingMaskIntoConstraints = false
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = 2
        containerView.addSubview(nameStack)
        
        // Name row with status dot
        let nameRow = NSStackView()
        nameRow.orientation = .horizontal
        nameRow.alignment = .centerY
        nameRow.spacing = 6
        
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.textColor = DesignColors.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        nameRow.addArrangedSubview(nameLabel)
        
        statusDot = NSView()
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 3
        statusDot.layer?.backgroundColor = DesignColors.positive.cgColor
        statusDot.isHidden = true
        nameRow.addArrangedSubview(statusDot)
        nameStack.addArrangedSubview(nameRow)
        
        // Path label (mono font)
        pathLabel = NSTextField(labelWithString: "")
        pathLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        pathLabel.textColor = DesignColors.textTertiary
        pathLabel.lineBreakMode = .byTruncatingTail
        nameStack.addArrangedSubview(pathLabel)
        
        // Author
        authorLabel = NSTextField(labelWithString: "")
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = DesignFonts.body(size: 13)
        authorLabel.textColor = DesignColors.textSecondary
        authorLabel.lineBreakMode = .byTruncatingTail
        authorLabel.alignment = .left
        containerView.addSubview(authorLabel)
        
        // Series badge
        seriesBadge = NSView()
        seriesBadge.translatesAutoresizingMaskIntoConstraints = false
        seriesBadge.wantsLayer = true
        seriesBadge.layer?.cornerRadius = 4
        seriesBadge.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        seriesBadge.layer?.borderWidth = 1
        seriesBadge.layer?.borderColor = DesignColors.borderSubtle.cgColor
        containerView.addSubview(seriesBadge)
        
        seriesLabel = NSTextField(labelWithString: "")
        seriesLabel.translatesAutoresizingMaskIntoConstraints = false
        seriesLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        seriesLabel.textColor = DesignColors.textSecondary
        seriesBadge.addSubview(seriesLabel)
        
        // Version
        versionLabel = NSTextField(labelWithString: "")
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        versionLabel.textColor = DesignColors.textSecondary
        versionLabel.alignment = .left
        containerView.addSubview(versionLabel)
        
        // Date
        dateLabel = NSTextField(labelWithString: "")
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        dateLabel.textColor = DesignColors.textTertiary
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
        moreButton.contentTintColor = DesignColors.textSecondary
        moreButton.alphaValue = 0 // Hidden by default, shown on hover
        containerView.addSubview(moreButton)
        
        // Layout constraints - using continuous left-to-right flow
        // Fixed elements: icon (left), toggle + more (right)
        // Flexible columns: name, author, series, version, date (fill remaining space proportionally)
        
        // First, set up fixed constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            borderLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            borderLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            borderLine.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            borderLine.heightAnchor.constraint(equalToConstant: 1),
            
            // Icon: 32x32 with padding (fixed)
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 28),
            iconImageView.heightAnchor.constraint(equalToConstant: 28),
            
            iconInitialLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconInitialLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),
            
            // More button (fixed right)
            moreButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -rightPadding),
            moreButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: moreColumnWidth),
            
            // Status toggle (fixed right, with gap from more button)
            statusToggle.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -12),
            statusToggle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Series badge label internal constraints
            seriesLabel.topAnchor.constraint(equalTo: seriesBadge.topAnchor, constant: 2),
            seriesLabel.bottomAnchor.constraint(equalTo: seriesBadge.bottomAnchor, constant: -2),
            seriesLabel.leadingAnchor.constraint(equalTo: seriesBadge.leadingAnchor, constant: 8),
            seriesLabel.trailingAnchor.constraint(equalTo: seriesBadge.trailingAnchor, constant: -8),
        ])
        
        // Name stack (flexible width)
        nameStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12).isActive = true
        nameStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        nameWidthConstraint = nameStack.widthAnchor.constraint(equalToConstant: nameMinWidth)
        nameWidthConstraint?.isActive = true
        
        // Author (flexible width)
        authorLabel.leadingAnchor.constraint(equalTo: nameStack.trailingAnchor, constant: 16).isActive = true
        authorLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        authorWidthConstraint = authorLabel.widthAnchor.constraint(equalToConstant: authorMinWidth)
        authorWidthConstraint?.isActive = true
        
        // Series badge - hugs content naturally
        seriesBadge.leadingAnchor.constraint(equalTo: authorLabel.trailingAnchor, constant: 16).isActive = true
        seriesBadge.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        
        // Version (flexible width)
        versionLabel.leadingAnchor.constraint(equalTo: seriesBadge.trailingAnchor, constant: 16).isActive = true
        versionLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        versionWidthConstraint = versionLabel.widthAnchor.constraint(equalToConstant: versionMinWidth)
        versionWidthConstraint?.isActive = true
        
        // Date (flexible width, anchored to right side)
        dateLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor).isActive = true
        dateLabel.trailingAnchor.constraint(equalTo: statusToggle.leadingAnchor, constant: -24).isActive = true
        dateWidthConstraint = dateLabel.widthAnchor.constraint(equalToConstant: dateMinWidth)
        dateWidthConstraint?.isActive = true
    }
    
    /// Update column widths based on available space
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Update gradient layer frame
        if let gradientLayer = iconView.layer?.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = iconView.bounds
        }
        
        // Calculate available width for flexible columns
        let totalWidth = view.bounds.width
        
        // Fixed widths: leftPad(16) + icon(32) + gap(12) + ... + gap(24) + toggle(52) + gap(12) + more(44) + rightPad(24)
        let leftFixedWidth: CGFloat = 16 + 32 + 12  // left padding + icon + gap to name
        let rightFixedWidth: CGFloat = 24 + toggleColumnWidth + 12 + moreColumnWidth + rightPadding
        let fixedWidth = leftFixedWidth + rightFixedWidth
        
        // Series badge hugs content - estimate width based on label
        let seriesWidth = seriesBadge.isHidden ? 0 : max(seriesMinWidth, seriesLabel.intrinsicContentSize.width + 16)
        
        // Gaps between columns: name-author(16), author-series(16), series-version(16), version-date(16)
        // When columns are hidden, we have fewer gaps
        let availableForFlexColumns = totalWidth - fixedWidth - seriesWidth
        
        // Check if we need to hide columns
        let allColumnsMinWidth = nameMinWidth + 16 + authorMinWidth + 16 + 16 + versionMinWidth + 16 + dateMinWidth
        let noVersionMinWidth = nameMinWidth + 16 + authorMinWidth + 16 + 16 + dateMinWidth
        
        let shouldHideVersion = availableForFlexColumns < allColumnsMinWidth
        let shouldHideDate = availableForFlexColumns < noVersionMinWidth
        
        versionLabel.isHidden = shouldHideVersion
        dateLabel.isHidden = shouldHideDate
        
        // Calculate actual available width based on visible columns
        var gapsWidth: CGFloat = 16 + 16  // name-author, author-series (always present)
        if !shouldHideVersion { gapsWidth += 16 }  // series-version
        if !shouldHideDate { gapsWidth += 16 }     // version-date or series-date
        
        let flexWidth = availableForFlexColumns - gapsWidth
        
        // Distribute space proportionally to visible columns
        if shouldHideDate && shouldHideVersion {
            // Only name and author visible
            let nameWidth = max(nameMinWidth, flexWidth * 0.60)
            let authorWidth = max(authorMinWidth, flexWidth * 0.40)
            nameWidthConstraint?.constant = nameWidth
            authorWidthConstraint?.constant = authorWidth
        } else if shouldHideVersion {
            // Name, author, date visible
            let nameWidth = max(nameMinWidth, flexWidth * 0.45)
            let authorWidth = max(authorMinWidth, flexWidth * 0.28)
            let dateWidth = max(dateMinWidth, flexWidth * 0.27)
            nameWidthConstraint?.constant = nameWidth
            authorWidthConstraint?.constant = authorWidth
            dateWidthConstraint?.constant = dateWidth
        } else {
            // All columns visible
            let nameWidth = max(nameMinWidth, flexWidth * 0.38)
            let authorWidth = max(authorMinWidth, flexWidth * 0.24)
            let versionWidth = max(versionMinWidth, flexWidth * 0.16)
            let dateWidth = max(dateMinWidth, flexWidth * 0.22)
            nameWidthConstraint?.constant = nameWidth
            authorWidthConstraint?.constant = authorWidth
            versionWidthConstraint?.constant = versionWidth
            dateWidthConstraint?.constant = dateWidth
        }
        
        setupTrackingArea()
    }
    
    @objc private func statusToggleChanged(_ sender: NSSwitch) {
        onStatusToggled?(sender.state == .on)
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
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            if isSelected {
                // Selected row: subtle bg highlight
                containerView.animator().layer?.backgroundColor = DesignColors.selectedBackground.withAlphaComponent(0.1).cgColor
                nameLabel.animator().textColor = DesignColors.textPrimary
            } else if isHovered {
                // Hover: subtle bg
                containerView.animator().layer?.backgroundColor = DesignColors.hoverBackground.cgColor
                nameLabel.animator().textColor = DesignColors.textPrimary
                moreButton.animator().alphaValue = 1.0
            } else {
                // Default
                containerView.animator().layer?.backgroundColor = NSColor.clear.cgColor
                nameLabel.animator().textColor = DesignColors.textPrimary
                moreButton.animator().alphaValue = 0
            }
        }
    }
    
    func configure(with character: CharacterInfo, isDuplicate: Bool = false) {
        currentCharacter = character
        nameLabel.stringValue = character.displayName
        
        // Path: directory relative to chars folder
        let pathString = character.directory.lastPathComponent + "/" + character.defFile.lastPathComponent
        pathLabel.stringValue = pathString
        
        // Author
        authorLabel.stringValue = character.author
        
        // Feature tags based on character content
        var tags = getFeatureTags(for: character)
        
        // Add DUPLICATE indicator if applicable
        if isDuplicate {
            tags = tags.isEmpty ? "DUPLICATE" : "\(tags) • DUPLICATE"
        }
        
        seriesLabel.stringValue = tags
        seriesBadge.isHidden = seriesLabel.stringValue.isEmpty
        
        // Style the badge differently if showing duplicate
        if isDuplicate {
            seriesBadge.layer?.backgroundColor = DesignColors.amber900.cgColor
            seriesBadge.layer?.borderColor = DesignColors.warning.withAlphaComponent(0.3).cgColor
            seriesLabel.textColor = DesignColors.amber200
        } else {
            seriesBadge.layer?.backgroundColor = DesignColors.cardBackground.cgColor
            seriesBadge.layer?.borderColor = DesignColors.borderSubtle.cgColor
            seriesLabel.textColor = DesignColors.textSecondary
        }
        
        // Version
        versionLabel.stringValue = "v1.0"
        
        // Date - formatted consistently
        let formattedDate = VersionDateFormatter.formatToStandard(character.versionDate)
        dateLabel.stringValue = formattedDate.isEmpty ? "—" : formattedDate
        
        // Placeholder initial
        iconInitialLabel.stringValue = String(character.displayName.prefix(1)).uppercased()
        iconImageView.image = nil
        iconInitialLabel.isHidden = false
        
        // Status dot hidden by default
        statusDot.isHidden = true
        
        // Toggle state - ON means enabled, OFF means disabled
        // Hide toggle for unregistered characters
        if character.status == .unregistered {
            statusToggle.isHidden = true
        } else {
            statusToggle.isHidden = false
            statusToggle.state = character.isDisabled ? .off : .on
        }
        
        // Build tooltip
        var tooltipParts: [String] = []
        if character.status == .unregistered {
            tooltipParts.append("Not in select.def - won't appear in game")
        }
        if isDuplicate {
            tooltipParts.append("Duplicate detected in library")
        }
        view.toolTip = tooltipParts.isEmpty ? nil : tooltipParts.joined(separator: " • ")
        
        // Visual feedback for unregistered/disabled state
        if character.status == .unregistered {
            // Unregistered: dimmed text with secondary color
            nameLabel.textColor = DesignColors.textSecondary
            pathLabel.textColor = DesignColors.textDisabled
            authorLabel.textColor = DesignColors.textTertiary
            containerView.layer?.opacity = 0.6
        } else if character.isDisabled {
            // Disabled: dimmed text
            nameLabel.textColor = DesignColors.textSecondary
            pathLabel.textColor = DesignColors.textDisabled
            authorLabel.textColor = DesignColors.textTertiary
            containerView.layer?.opacity = 0.7
            view.toolTip = nil
        } else {
            // Active: normal text
            nameLabel.textColor = DesignColors.textPrimary
            pathLabel.textColor = DesignColors.textTertiary
            authorLabel.textColor = DesignColors.textSecondary
            containerView.layer?.opacity = 1.0
            view.toolTip = nil
        }
        
        // Apply base theme colors (borders, etc.)
        applyTheme()
    }
    
    func setPortrait(_ image: NSImage?) {
        iconImageView.image = image
        iconInitialLabel.isHidden = (image != nil)
    }
    
    /// Show status indicator
    func setStatus(_ status: CharacterStatus) {
        switch status {
        case .active:
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = DesignColors.positive.cgColor
        case .warning:
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = DesignColors.warning.cgColor
        case .none:
            statusDot.isHidden = true
        }
    }
    
    /// Update all theme-dependent colors
    func applyTheme() {
        // Update border line
        if let borderLine = containerView.subviews.first(where: { $0.identifier?.rawValue == "listBorderLine" }) {
            borderLine.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        }
        
        // Update icon view
        iconView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Update text colors
        nameLabel.textColor = DesignColors.textPrimary
        pathLabel.textColor = DesignColors.textTertiary
        authorLabel.textColor = DesignColors.textSecondary
        versionLabel.textColor = DesignColors.textSecondary
        dateLabel.textColor = DesignColors.textTertiary
        iconInitialLabel.textColor = DesignColors.textTertiary
        
        // Update series badge
        seriesBadge.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        seriesBadge.layer?.borderColor = DesignColors.borderSubtle.cgColor
        seriesLabel.textColor = DesignColors.textSecondary
        
        // Update status dot
        statusDot.layer?.backgroundColor = DesignColors.positive.cgColor
        
        // Update more button
        moreButton.contentTintColor = DesignColors.textTertiary
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        iconInitialLabel.isHidden = false
        nameLabel.stringValue = ""
        pathLabel.stringValue = ""
        authorLabel.stringValue = ""
        seriesLabel.stringValue = ""
        versionLabel.stringValue = ""
        dateLabel.stringValue = ""
        statusDot.isHidden = true
        statusToggle.state = .on
        currentCharacter = nil
        onStatusToggled = nil
        onMoreClicked = nil
        containerView.layer?.opacity = 1.0
        isSelected = false
        isHovered = false
        updateAppearance(animated: false)
        
        // Apply current theme colors
        applyTheme()
        
        view.toolTip = nil
    }
    
    @objc private func moreButtonClicked(_ sender: NSButton) {
        guard let character = currentCharacter else { return }
        onMoreClicked?(character, sender)
    }
    
    /// Detect character features and return appropriate tag
    private func getFeatureTags(for character: CharacterInfo) -> String {
        let directory = character.directory
        let fm = FileManager.default
        
        var tags: [String] = []
        
        // Check for intro
        if fm.fileExists(atPath: directory.appendingPathComponent("intro.def").path) {
            tags.append("INTRO")
        }
        
        // Check for sounds (.snd file)
        if let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            if contents.contains(where: { $0.pathExtension.lowercased() == "snd" }) {
                tags.append("SFX")
            }
        }
        
        // Check for AI in CMD file
        if let cmdFile = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension.lowercased() == "cmd" }),
           let cmdContent = try? String(contentsOf: cmdFile, encoding: .utf8) {
            if cmdContent.lowercased().contains("[state -1") || cmdContent.lowercased().contains("ai.") {
                tags.append("AI")
            }
        }
        
        // Return all tags joined, or empty string
        return tags.joined(separator: " • ")
    }
}

// MARK: - Cutoff Divider View

/// A supplementary view that displays a divider showing the screenpack cutoff point
class CutoffDividerView: NSView, NSCollectionViewElement {
    
    private var containerView: NSView!
    private var topDividerLine: NSView!
    private var visibleCountLabel: NSTextField!
    private var hiddenCountLabel: NSTextField!
    private var bottomDividerLine: NSView!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        // Outer background stays dark so margins render as solid black behind inset container
        layer?.backgroundColor = DesignColors.panelBackground.cgColor
        // TODO: Refresh divider visuals to match the final design pass.
        
        // Container view with gradient background
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Top divider line
        topDividerLine = NSView()
        topDividerLine.wantsLayer = true
        topDividerLine.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        topDividerLine.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(topDividerLine)
        
        // Visible count label (left side)
        visibleCountLabel = NSTextField(labelWithString: "")
        visibleCountLabel.font = DesignFonts.caption(size: 12)
        visibleCountLabel.textColor = NSColor.systemGreen
        visibleCountLabel.alignment = .left
        visibleCountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(visibleCountLabel)
        
        // Hidden count label (right side)
        hiddenCountLabel = NSTextField(labelWithString: "")
        hiddenCountLabel.font = DesignFonts.caption(size: 12)
        hiddenCountLabel.textColor = NSColor.systemOrange
        hiddenCountLabel.alignment = .right
        hiddenCountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hiddenCountLabel)
        
        // Bottom divider line
        bottomDividerLine = NSView()
        bottomDividerLine.wantsLayer = true
        bottomDividerLine.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        bottomDividerLine.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bottomDividerLine)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Container fills the entire view
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            // Top divider line
            topDividerLine.topAnchor.constraint(equalTo: containerView.topAnchor),
            topDividerLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            topDividerLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            topDividerLine.heightAnchor.constraint(equalToConstant: 1),
            
            // Visible count label (left)
            visibleCountLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            visibleCountLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Hidden count label (right)
            hiddenCountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            hiddenCountLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Bottom divider line
            bottomDividerLine.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bottomDividerLine.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bottomDividerLine.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bottomDividerLine.heightAnchor.constraint(equalToConstant: 1),
        ])
    }
    
    func configure(visibleCount: Int, hiddenCount: Int) {
        visibleCountLabel.stringValue = "✓ \(visibleCount) characters shown"
        hiddenCountLabel.stringValue = "⚠️ \(hiddenCount) characters hidden"
    }
    
    override func prepareForReuse() {
        visibleCountLabel.stringValue = ""
        hiddenCountLabel.stringValue = ""
    }
}
