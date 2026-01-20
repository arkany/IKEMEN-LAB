import Cocoa
import Combine

// MARK: - ScreenpackPickerSheet

/// Sheet for selecting a screenpack for a collection
/// Unlike character/stage pickers, this is single-selection
class ScreenpackPickerSheet: NSViewController {
    
    // MARK: - Properties
    
    private var collection: Collection
    private var allScreenpacks: [ScreenpackInfo] = []
    private var filteredScreenpacks: [ScreenpackInfo] = []
    private var selectedScreenpackPath: String?
    private var cancellables = Set<AnyCancellable>()
    
    var onDismiss: (() -> Void)?
    
    // UI Components
    private var titleLabel: NSTextField!
    private var searchField: NSSearchField!
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var selectionLabel: NSTextField!
    private var clearButton: NSButton!
    private var doneButton: NSButton!
    
    // MARK: - Initialization
    
    init(collection: Collection) {
        self.collection = collection
        super.init(nibName: nil, bundle: nil)
        
        // Initialize with current selection
        selectedScreenpackPath = collection.screenpackPath
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
        view.wantsLayer = true
        view.layer?.backgroundColor = DesignColors.pickerBackground.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadScreenpacks()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Header
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        titleLabel = NSTextField(labelWithString: "Select Screenpack")
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
        searchField.placeholderString = "Search screenpacks..."
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.sendsSearchStringImmediately = true
        view.addSubview(searchField)
        
        // Collection view
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 180, height: 60)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.register(ScreenpackPickerItem.self, forItemWithIdentifier: ScreenpackPickerItem.identifier)
        
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = DesignColors.pickerScrollBackground.cgColor
        scrollView.layer?.cornerRadius = 8
        view.addSubview(scrollView)
        
        // Footer
        let footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footerView)
        
        selectionLabel = NSTextField(labelWithString: "No screenpack selected (using default)")
        selectionLabel.translatesAutoresizingMaskIntoConstraints = false
        selectionLabel.font = DesignFonts.body(size: 13)
        selectionLabel.textColor = DesignColors.textSecondary
        footerView.addSubview(selectionLabel)
        
        clearButton = NSButton(title: "Use Default", target: self, action: #selector(clearClicked))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.font = DesignFonts.body(size: 13)
        clearButton.contentTintColor = DesignColors.textSecondary
        footerView.addSubview(clearButton)
        
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
            
            selectionLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            selectionLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            
            clearButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
        ])
    }
    
    private func loadScreenpacks() {
        // Use IkemenBridge to get cached screenpacks
        allScreenpacks = IkemenBridge.shared.screenpacks.sorted { $0.name.lowercased() < $1.name.lowercased() }
        filteredScreenpacks = allScreenpacks
        
        collectionView.reloadData()
        updateSelectionLabel()
    }
    
    private func updateSelectionLabel() {
        if let path = selectedScreenpackPath,
           let screenpack = allScreenpacks.first(where: { screenpackPath(for: $0) == path }) {
            selectionLabel.stringValue = "Selected: \(screenpack.name)"
        } else {
            selectionLabel.stringValue = "No screenpack selected (using default)"
        }
    }
    
    // MARK: - Actions
    
    @objc private func searchChanged() {
        let query = searchField.stringValue.lowercased().trimmingCharacters(in: .whitespaces)
        
        if query.isEmpty {
            filteredScreenpacks = allScreenpacks
        } else {
            filteredScreenpacks = allScreenpacks.filter { screenpack in
                screenpack.name.lowercased().contains(query) ||
                screenpack.author.lowercased().contains(query)
            }
        }
        
        collectionView.reloadData()
    }
    
    @objc private func clearClicked() {
        selectedScreenpackPath = nil
        collectionView.reloadData()
        updateSelectionLabel()
    }
    
    @objc private func doneClicked() {
        syncToCollection()
        onDismiss?()
        // Dismiss the sheet window properly
        if let sheetWindow = view.window, let parentWindow = sheetWindow.sheetParent {
            parentWindow.endSheet(sheetWindow)
        } else {
            dismiss(nil)
        }
    }
    
    private func screenpackPath(for screenpack: ScreenpackInfo) -> String {
        // Return relative path from Ikemen GO root (e.g., "data/MvC2")
        guard let workingDir = IkemenBridge.shared.workingDirectory else {
            return screenpack.defFile.deletingLastPathComponent().lastPathComponent
        }
        
        let screenpackDir = screenpack.defFile.deletingLastPathComponent()
        if let relativePath = screenpackDir.path.replacingOccurrences(of: workingDir.path + "/", with: "").nilIfEmpty {
            return relativePath
        }
        return screenpackDir.lastPathComponent
    }
    
    private func syncToCollection() {
        // Get current collection
        guard var updatedCollection = CollectionStore.shared.collection(withId: collection.id) else { return }
        
        // Update screenpack
        updatedCollection.screenpackPath = selectedScreenpackPath
        CollectionStore.shared.update(updatedCollection)
        
        // Update local reference
        collection = updatedCollection
    }
    
    func selectScreenpack(_ path: String?) {
        selectedScreenpackPath = path
        collectionView.reloadData()
        updateSelectionLabel()
    }
    
    func isScreenpackSelected(_ path: String) -> Bool {
        return selectedScreenpackPath == path
    }
}

// MARK: - String Extension

fileprivate extension String {
    var nilIfEmpty: String? {
        return isEmpty ? nil : self
    }
}

// MARK: - NSCollectionViewDataSource

extension ScreenpackPickerSheet: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredScreenpacks.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ScreenpackPickerItem.identifier, for: indexPath) as! ScreenpackPickerItem
        let screenpack = filteredScreenpacks[indexPath.item]
        let path = screenpackPath(for: screenpack)
        item.configure(with: screenpack, isSelected: isScreenpackSelected(path))
        item.onSelect = { [weak self] in
            self?.selectScreenpack(path)
        }
        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension ScreenpackPickerSheet: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Selection handled by item click
        collectionView.deselectItems(at: indexPaths)
    }
}

// MARK: - ScreenpackPickerItem

class ScreenpackPickerItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("ScreenpackPickerItem")
    
    private var containerView: NSView!
    private var radioView: NSImageView!
    private var nameLabel: NSTextField!
    private var detailLabel: NSTextField!
    
    var onSelect: (() -> Void)?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 60))
        view.wantsLayer = true
        
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.pickerItemBackground.cgColor
        containerView.layer?.cornerRadius = 6
        view.addSubview(containerView)
        
        // Radio button indicator
        radioView = NSImageView()
        radioView.translatesAutoresizingMaskIntoConstraints = false
        radioView.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)
        radioView.contentTintColor = DesignColors.textTertiary
        containerView.addSubview(radioView)
        
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.body(size: 13)
        nameLabel.textColor = DesignColors.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)
        
        detailLabel = NSTextField(labelWithString: "")
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = DesignFonts.caption(size: 11)
        detailLabel.textColor = DesignColors.textTertiary
        detailLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            radioView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            radioView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            radioView.widthAnchor.constraint(equalToConstant: 18),
            radioView.heightAnchor.constraint(equalToConstant: 18),
            
            nameLabel.leadingAnchor.constraint(equalTo: radioView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            
            detailLabel.leadingAnchor.constraint(equalTo: radioView.trailingAnchor, constant: 8),
            detailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
        ])
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(itemClicked))
        containerView.addGestureRecognizer(clickGesture)
    }
    
    func configure(with screenpack: ScreenpackInfo, isSelected: Bool) {
        nameLabel.stringValue = screenpack.name
        detailLabel.stringValue = "\(screenpack.resolutionString) • \(screenpack.characterLimitString)"
        updateSelection(isSelected)
    }
    
    func updateSelection(_ selected: Bool) {
        if selected {
            radioView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            radioView.contentTintColor = DesignColors.positive
            containerView.layer?.backgroundColor = DesignColors.pickerItemSelectedBackground.cgColor
        } else {
            radioView.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)
            radioView.contentTintColor = DesignColors.textTertiary
            containerView.layer?.backgroundColor = DesignColors.pickerItemBackground.cgColor
        }
    }
    
    @objc private func itemClicked() {
        onSelect?()
    }
}
