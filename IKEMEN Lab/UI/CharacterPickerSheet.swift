import Cocoa
import Combine

// MARK: - CharacterPickerSheet

/// Sheet for selecting characters to add to a collection
class CharacterPickerSheet: NSViewController {
    
    // MARK: - Properties
    
    private var collection: Collection
    private var allCharacters: [CharacterInfo] = []
    private var filteredCharacters: [CharacterInfo] = []
    private var selectedCharacterFolders: Set<String> = []
    private var cancellables = Set<AnyCancellable>()
    
    var onDismiss: (() -> Void)?
    
    // UI Components
    private var titleLabel: NSTextField!
    private var searchField: NSSearchField!
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var selectionCountLabel: NSTextField!
    private var addAllButton: NSButton!
    private var doneButton: NSButton!
    
    // MARK: - Initialization
    
    init(collection: Collection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
        
        // Initialize selected folders from existing collection
        selectedCharacterFolders = Set(collection.characters.compactMap { $0.characterFolder })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
        view.wantsLayer = true
        view.layer?.backgroundColor = DesignColors.zinc900.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCharacters()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Header
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        titleLabel = NSTextField(labelWithString: "Add Characters to Collection")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.header(size: 18)
        titleLabel.textColor = DesignColors.textPrimary
        headerView.addSubview(titleLabel)
        
        doneButton = NSButton(title: "Done", target: self, action: #selector(doneClicked))
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        headerView.addSubview(doneButton)
        
        // Search field
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search characters..."
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.sendsSearchStringImmediately = true
        view.addSubview(searchField)
        
        // Collection view
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 120, height: 40)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.register(CharacterPickerItem.self, forItemWithIdentifier: CharacterPickerItem.identifier)
        
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = DesignColors.zinc800.cgColor
        scrollView.layer?.cornerRadius = 8
        view.addSubview(scrollView)
        
        // Footer
        let footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerView)
        
        selectionCountLabel = NSTextField(labelWithString: "Selected: 0 characters")
        selectionCountLabel.translatesAutoresizingMaskIntoConstraints = false
        selectionCountLabel.font = DesignFonts.body(size: 13)
        selectionCountLabel.textColor = DesignColors.textSecondary
        footerView.addSubview(selectionCountLabel)
        
        addAllButton = NSButton(title: "Add All Visible", target: self, action: #selector(addAllClicked))
        addAllButton.translatesAutoresizingMaskIntoConstraints = false
        addAllButton.bezelStyle = .inline
        addAllButton.isBordered = false
        addAllButton.font = DesignFonts.body(size: 13)
        addAllButton.contentTintColor = DesignColors.badgeCharacter
        footerView.addSubview(addAllButton)
        
        // Layout
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            doneButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            searchField.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 28),
            
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: footerView.topAnchor, constant: -16),
            
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            footerView.heightAnchor.constraint(equalToConstant: 32),
            
            selectionCountLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            selectionCountLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            
            addAllButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            addAllButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
        ])
    }
    
    private func loadCharacters() {
        // Use IkemenBridge to get cached characters
        allCharacters = IkemenBridge.shared.characters.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        filteredCharacters = allCharacters
        
        collectionView.reloadData()
        updateSelectionCount()
    }
    
    private func updateSelectionCount() {
        selectionCountLabel.stringValue = "Selected: \(selectedCharacterFolders.count) characters"
    }
    
    // MARK: - Actions
    
    @objc private func searchChanged() {
        let query = searchField.stringValue.lowercased().trimmingCharacters(in: .whitespaces)
        
        if query.isEmpty {
            filteredCharacters = allCharacters
        } else {
            filteredCharacters = allCharacters.filter { character in
                character.displayName.lowercased().contains(query) ||
                character.directory.lastPathComponent.lowercased().contains(query) ||
                character.author.lowercased().contains(query)
            }
        }
        
        collectionView.reloadData()
    }
    
    @objc private func addAllClicked() {
        for character in filteredCharacters {
            let folder = character.directory.lastPathComponent
            selectedCharacterFolders.insert(folder)
        }
        
        syncToCollection()
        collectionView.reloadData()
        updateSelectionCount()
    }
    
    @objc private func doneClicked() {
        syncToCollection()
        onDismiss?()
        dismiss(nil)
    }
    
    private func syncToCollection() {
        // Get current collection
        guard var updatedCollection = CollectionStore.shared.collection(withId: collection.id) else { return }
        
        // Build new character list
        var newCharacters: [RosterEntry] = []
        
        // Keep existing non-character entries (randomselect, empty slots)
        for entry in updatedCollection.characters {
            if entry.entryType != .character {
                newCharacters.append(entry)
            }
        }
        
        // Add selected characters
        for folder in selectedCharacterFolders {
            // Find the character info to get the def file
            if let charInfo = allCharacters.first(where: { $0.directory.lastPathComponent == folder }) {
                let def = charInfo.defFile.lastPathComponent
                newCharacters.append(.character(folder: folder, def: def))
            } else {
                newCharacters.append(.character(folder: folder))
            }
        }
        
        updatedCollection.characters = newCharacters
        CollectionStore.shared.update(updatedCollection)
        
        // Update local reference
        collection = updatedCollection
    }
    
    func toggleCharacter(_ folder: String) {
        if selectedCharacterFolders.contains(folder) {
            selectedCharacterFolders.remove(folder)
        } else {
            selectedCharacterFolders.insert(folder)
        }
        updateSelectionCount()
    }
    
    func isCharacterSelected(_ folder: String) -> Bool {
        return selectedCharacterFolders.contains(folder)
    }
}

// MARK: - NSCollectionViewDataSource

extension CharacterPickerSheet: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredCharacters.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: CharacterPickerItem.identifier, for: indexPath) as! CharacterPickerItem
        let character = filteredCharacters[indexPath.item]
        let folder = character.directory.lastPathComponent
        item.configure(with: character, isSelected: isCharacterSelected(folder))
        item.onToggle = { [weak self] in
            self?.toggleCharacter(folder)
            item.updateCheckmark(self?.isCharacterSelected(folder) ?? false)
        }
        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension CharacterPickerSheet: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Selection handled by item click
        collectionView.deselectItems(at: indexPaths)
    }
}

// MARK: - CharacterPickerItem

class CharacterPickerItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("CharacterPickerItem")
    
    private var containerView: NSView!
    private var checkmarkView: NSImageView!
    private var nameLabel: NSTextField!
    
    var onToggle: (() -> Void)?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 40))
        view.wantsLayer = true
        
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.zinc700.cgColor
        containerView.layer?.cornerRadius = 6
        view.addSubview(containerView)
        
        // Checkmark
        checkmarkView = NSImageView()
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        checkmarkView.contentTintColor = DesignColors.positive
        checkmarkView.isHidden = true
        containerView.addSubview(checkmarkView)
        
        // Empty circle (unselected)
        let emptyCircle = NSImageView()
        emptyCircle.translatesAutoresizingMaskIntoConstraints = false
        emptyCircle.identifier = NSUserInterfaceItemIdentifier("emptyCircle")
        emptyCircle.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)
        emptyCircle.contentTintColor = DesignColors.zinc500
        containerView.addSubview(emptyCircle)
        
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.body(size: 12)
        nameLabel.textColor = DesignColors.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            checkmarkView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            checkmarkView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 18),
            checkmarkView.heightAnchor.constraint(equalToConstant: 18),
            
            emptyCircle.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            emptyCircle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            emptyCircle.widthAnchor.constraint(equalToConstant: 18),
            emptyCircle.heightAnchor.constraint(equalToConstant: 18),
            
            nameLabel.leadingAnchor.constraint(equalTo: checkmarkView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(itemClicked))
        containerView.addGestureRecognizer(clickGesture)
    }
    
    func configure(with character: CharacterInfo, isSelected: Bool) {
        nameLabel.stringValue = character.displayName
        updateCheckmark(isSelected)
    }
    
    func updateCheckmark(_ selected: Bool) {
        checkmarkView.isHidden = !selected
        
        // Find and update empty circle
        if let emptyCircle = containerView.subviews.first(where: { $0.identifier?.rawValue == "emptyCircle" }) {
            emptyCircle.isHidden = selected
        }
        
        // Update background
        containerView.layer?.backgroundColor = selected ? DesignColors.zinc600.cgColor : DesignColors.zinc700.cgColor
    }
    
    @objc private func itemClicked() {
        onToggle?()
    }
}
