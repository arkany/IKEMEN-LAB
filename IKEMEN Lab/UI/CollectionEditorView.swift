import Cocoa
import Combine

// MARK: - Pasteboard Type for Roster Drag

extension NSPasteboard.PasteboardType {
    static let rosterEntryDrag = NSPasteboard.PasteboardType("com.ikemenlab.roster-entry-drag")
}

// MARK: - CollectionEditorView

/// View for editing a collection's roster, stages, and screenpack
class CollectionEditorView: NSView {
    
    // MARK: - Properties
    
    private var collection: Collection?
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var onBackClicked: (() -> Void)?
    var onActivateClicked: ((Collection) -> Void)?
    var onAddCharactersClicked: ((Collection) -> Void)?
    var onAddStagesClicked: ((Collection) -> Void)?
    var onChangeScreenpackClicked: ((Collection) -> Void)?
    
    // UI Components
    private var scrollView: NSScrollView!
    private var contentStack: NSStackView!
    
    // Header
    private var headerView: NSView!
    private var backButton: NSButton!
    private var titleLabel: NSTextField!
    private var activateButton: NSButton!
    private var menuButton: NSButton!
    private var backButtonTrackingArea: NSTrackingArea?
    
    // Roster Section
    private var rosterHeaderView: NSView!
    private var rosterCountLabel: NSTextField!
    private var addCharactersButton: NSButton!
    private var rosterCollectionView: NSCollectionView!
    private var rosterScrollView: NSScrollView!
    
    // Stages Section
    private var stagesHeaderView: NSView!
    private var stagesCountLabel: NSTextField!
    private var addStagesButton: NSButton!
    private var stagesCollectionView: NSCollectionView!
    private var stagesScrollView: NSScrollView!
    
    // Screenpack Section
    private var screenpackView: NSView!
    private var screenpackLabel: NSTextField!
    private var screenpackWarningLabel: NSTextField!
    private var changeScreenpackButton: NSButton!
    
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
        
        setupScrollView()
        setupHeader()
        setupRosterSection()
        setupStagesSection()
        setupScreenpackSection()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        addSubview(scrollView)
        
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 24
        contentStack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 24, right: 24)
        
        scrollView.documentView = contentStack
        
        // Note: scrollView.topAnchor will be constrained to headerView.bottomAnchor in setupHeader()
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
    
    private func setupHeader() {
        // Header matches ContentHeaderView style: 64px height, bg-zinc-950/50, border-b border-white/5
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.5).cgColor
        
        // Border at bottom
        let borderLayer = CALayer()
        borderLayer.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: 10000, height: 1)
        headerView.layer?.addSublayer(borderLayer)
        
        // Left side: Back button styled as breadcrumb link
        backButton = NSButton(frame: .zero)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.isBordered = false
        backButton.target = self
        backButton.action = #selector(backClicked)
        backButton.setButtonType(.momentaryChange)
        backButton.attributedTitle = NSAttributedString(
            string: "Collections",
            attributes: [
                .font: DesignFonts.body(size: 13),
                .foregroundColor: DesignColors.textSecondary
            ]
        )
        headerView.addSubview(backButton)
        
        // Chevron separator
        let chevronImage = NSImageView()
        chevronImage.translatesAutoresizingMaskIntoConstraints = false
        chevronImage.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevronImage.contentTintColor = DesignColors.textSecondary
        chevronImage.imageScaling = .scaleProportionallyDown
        headerView.addSubview(chevronImage)
        
        // Title label (editable collection name)
        titleLabel = NSTextField(labelWithString: "Collection")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.body(size: 13)
        titleLabel.textColor = DesignColors.textPrimary
        titleLabel.isEditable = true
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.focusRingType = .none
        titleLabel.delegate = self
        headerView.addSubview(titleLabel)
        
        // Right side: Activate button (styled pill button)
        activateButton = NSButton(title: "Activate", target: self, action: #selector(activateClicked))
        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.bezelStyle = .inline
        activateButton.isBordered = false
        activateButton.wantsLayer = true
        activateButton.layer?.backgroundColor = DesignColors.positive.cgColor
        activateButton.layer?.cornerRadius = 6
        activateButton.font = DesignFonts.label(size: 12)
        activateButton.attributedTitle = NSAttributedString(
            string: "Activate",
            attributes: [
                .font: DesignFonts.label(size: 12),
                .foregroundColor: NSColor.white
            ]
        )
        headerView.addSubview(activateButton)
        
        // Menu button (three dots)
        menuButton = NSButton(title: "", target: self, action: #selector(menuClicked))
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.bezelStyle = .inline
        menuButton.isBordered = false
        menuButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "More options")
        menuButton.contentTintColor = DesignColors.textSecondary
        headerView.addSubview(menuButton)
        
        // Add header directly to the view (not to contentStack) so it stays fixed at top
        addSubview(headerView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 64),
            
            // Left side - breadcrumb style: Collections > [Name]
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 32),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            chevronImage.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            chevronImage.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            chevronImage.widthAnchor.constraint(equalToConstant: 12),
            chevronImage.heightAnchor.constraint(equalToConstant: 12),
            
            titleLabel.leadingAnchor.constraint(equalTo: chevronImage.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Right side - activate + menu
            menuButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -32),
            menuButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 28),
            menuButton.heightAnchor.constraint(equalToConstant: 28),
            
            activateButton.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -16),
            activateButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            activateButton.heightAnchor.constraint(equalToConstant: 28),
            activateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Connect scrollView to header
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
        ])
        
        // Add tracking area for back button hover effect
        backButtonTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["view": "backButton"]
        )
        backButton.addTrackingArea(backButtonTrackingArea!)
    }
    
    // MARK: - Mouse Tracking for Header
    
    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           userInfo["view"] == "backButton" {
            backButton.attributedTitle = NSAttributedString(
                string: "Collections",
                attributes: [
                    .font: DesignFonts.body(size: 13),
                    .foregroundColor: DesignColors.textPrimary
                ]
            )
            NSCursor.pointingHand.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           userInfo["view"] == "backButton" {
            backButton.attributedTitle = NSAttributedString(
                string: "Collections",
                attributes: [
                    .font: DesignFonts.body(size: 13),
                    .foregroundColor: DesignColors.textSecondary
                ]
            )
            NSCursor.arrow.set()
        }
    }
    
    private func setupRosterSection() {
        // Section header
        rosterHeaderView = createSectionHeader(
            title: "ROSTER",
            countLabel: &rosterCountLabel,
            buttonTitle: "+ Add Characters",
            buttonAction: #selector(addCharactersClicked)
        )
        addCharactersButton = rosterHeaderView.subviews.compactMap { $0 as? NSButton }.first
        contentStack.addArrangedSubview(rosterHeaderView)
        
        // Roster collection view
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 100, height: 130)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        rosterCollectionView = NSCollectionView()
        rosterCollectionView.collectionViewLayout = layout
        rosterCollectionView.delegate = self
        rosterCollectionView.dataSource = self
        rosterCollectionView.backgroundColors = [.clear]
        rosterCollectionView.isSelectable = true
        rosterCollectionView.allowsMultipleSelection = false
        rosterCollectionView.register(RosterEntryItem.self, forItemWithIdentifier: RosterEntryItem.identifier)
        
        // Enable drag reordering
        rosterCollectionView.registerForDraggedTypes([.rosterEntryDrag])
        rosterCollectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        rosterScrollView = NSScrollView()
        rosterScrollView.translatesAutoresizingMaskIntoConstraints = false
        rosterScrollView.documentView = rosterCollectionView
        rosterScrollView.hasVerticalScroller = true
        rosterScrollView.hasHorizontalScroller = false
        rosterScrollView.backgroundColor = .clear
        rosterScrollView.drawsBackground = false
        rosterScrollView.wantsLayer = true
        rosterScrollView.layer?.backgroundColor = DesignColors.zinc900.cgColor
        rosterScrollView.layer?.cornerRadius = 8
        
        contentStack.addArrangedSubview(rosterScrollView)
        
        NSLayoutConstraint.activate([
            rosterHeaderView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            rosterHeaderView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            
            rosterScrollView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            rosterScrollView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            rosterScrollView.heightAnchor.constraint(equalToConstant: 300),
        ])
    }
    
    private func setupStagesSection() {
        // Section header
        stagesHeaderView = createSectionHeader(
            title: "STAGES",
            countLabel: &stagesCountLabel,
            buttonTitle: "+ Add Stages",
            buttonAction: #selector(addStagesClicked)
        )
        addStagesButton = stagesHeaderView.subviews.compactMap { $0 as? NSButton }.first
        contentStack.addArrangedSubview(stagesHeaderView)
        
        // Stages collection view (horizontal scroll)
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = NSSize(width: 160, height: 90)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        stagesCollectionView = NSCollectionView()
        stagesCollectionView.collectionViewLayout = layout
        stagesCollectionView.delegate = self
        stagesCollectionView.dataSource = self
        stagesCollectionView.backgroundColors = [.clear]
        stagesCollectionView.isSelectable = true
        stagesCollectionView.register(StageEntryItem.self, forItemWithIdentifier: StageEntryItem.identifier)
        
        stagesScrollView = NSScrollView()
        stagesScrollView.translatesAutoresizingMaskIntoConstraints = false
        stagesScrollView.documentView = stagesCollectionView
        stagesScrollView.hasVerticalScroller = false
        stagesScrollView.hasHorizontalScroller = true
        stagesScrollView.backgroundColor = .clear
        stagesScrollView.drawsBackground = false
        stagesScrollView.wantsLayer = true
        stagesScrollView.layer?.backgroundColor = DesignColors.zinc900.cgColor
        stagesScrollView.layer?.cornerRadius = 8
        
        contentStack.addArrangedSubview(stagesScrollView)
        
        NSLayoutConstraint.activate([
            stagesHeaderView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            stagesHeaderView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            
            stagesScrollView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            stagesScrollView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            stagesScrollView.heightAnchor.constraint(equalToConstant: 120),
        ])
    }
    
    private func setupScreenpackSection() {
        // Container
        screenpackView = NSView()
        screenpackView.translatesAutoresizingMaskIntoConstraints = false
        screenpackView.wantsLayer = true
        screenpackView.layer?.backgroundColor = DesignColors.zinc900.cgColor
        screenpackView.layer?.cornerRadius = 8
        
        // Title
        let titleLabel = NSTextField(labelWithString: "SCREENPACK")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.label(size: 12)
        titleLabel.textColor = DesignColors.textTertiary
        screenpackView.addSubview(titleLabel)
        
        // Screenpack name
        screenpackLabel = NSTextField(labelWithString: "Default")
        screenpackLabel.translatesAutoresizingMaskIntoConstraints = false
        screenpackLabel.font = DesignFonts.body(size: 14)
        screenpackLabel.textColor = DesignColors.textPrimary
        screenpackView.addSubview(screenpackLabel)
        
        // Warning label
        screenpackWarningLabel = NSTextField(labelWithString: "")
        screenpackWarningLabel.translatesAutoresizingMaskIntoConstraints = false
        screenpackWarningLabel.font = DesignFonts.caption(size: 12)
        screenpackWarningLabel.textColor = DesignColors.warning
        screenpackWarningLabel.isHidden = true
        screenpackView.addSubview(screenpackWarningLabel)
        
        // Change button
        changeScreenpackButton = NSButton(title: "Change", target: self, action: #selector(changeScreenpackClicked))
        changeScreenpackButton.translatesAutoresizingMaskIntoConstraints = false
        changeScreenpackButton.bezelStyle = .rounded
        screenpackView.addSubview(changeScreenpackButton)
        
        contentStack.addArrangedSubview(screenpackView)
        
        NSLayoutConstraint.activate([
            screenpackView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            screenpackView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            screenpackView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.leadingAnchor.constraint(equalTo: screenpackView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: screenpackView.topAnchor, constant: 12),
            
            screenpackLabel.leadingAnchor.constraint(equalTo: screenpackView.leadingAnchor, constant: 16),
            screenpackLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            screenpackWarningLabel.leadingAnchor.constraint(equalTo: screenpackView.leadingAnchor, constant: 16),
            screenpackWarningLabel.topAnchor.constraint(equalTo: screenpackLabel.bottomAnchor, constant: 4),
            
            changeScreenpackButton.trailingAnchor.constraint(equalTo: screenpackView.trailingAnchor, constant: -16),
            changeScreenpackButton.centerYAnchor.constraint(equalTo: screenpackView.centerYAnchor),
        ])
    }
    
    private func createSectionHeader(title: String, countLabel: inout NSTextField!, buttonTitle: String, buttonAction: Selector) -> NSView {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        
        // Title with count
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.label(size: 12)
        titleLabel.textColor = DesignColors.textTertiary
        header.addSubview(titleLabel)
        
        // Count label
        countLabel = NSTextField(labelWithString: "(0)")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = DesignFonts.label(size: 12)
        countLabel.textColor = DesignColors.textTertiary
        header.addSubview(countLabel)
        
        // Add button
        let button = NSButton(title: buttonTitle, target: self, action: buttonAction)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = DesignFonts.body(size: 13)
        button.contentTintColor = DesignColors.badgeCharacter
        header.addSubview(button)
        
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            countLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            button.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            button.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        
        return header
    }
    
    private func setupObservers() {
        // Observe collection store changes
        CollectionStore.shared.$collections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshIfNeeded()
            }
            .store(in: &cancellables)
        
        CollectionStore.shared.$activeCollectionId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActivateButton()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    func configure(with collection: Collection) {
        self.collection = collection
        updateUI()
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        guard let collection = collection else { return }
        
        titleLabel.stringValue = collection.name
        rosterCountLabel.stringValue = "(\(collection.characters.count))"
        stagesCountLabel.stringValue = "(\(collection.stages.count))"
        
        // Screenpack
        if let screenpackPath = collection.screenpackPath {
            screenpackLabel.stringValue = URL(fileURLWithPath: screenpackPath).lastPathComponent
        } else {
            screenpackLabel.stringValue = "Default"
        }
        
        updateActivateButton()
        
        // Reload collection views
        rosterCollectionView.reloadData()
        stagesCollectionView.reloadData()
    }
    
    private func refreshIfNeeded() {
        guard let currentId = collection?.id,
              let updated = CollectionStore.shared.collection(withId: currentId) else { return }
        collection = updated
        updateUI()
    }
    
    private func updateActivateButton() {
        guard let collection = collection else { return }
        
        let isActive = CollectionStore.shared.activeCollectionId == collection.id
        
        if isActive {
            activateButton.title = "Active"
            activateButton.isEnabled = false
            activateButton.layer?.backgroundColor = DesignColors.zinc700.cgColor
        } else {
            activateButton.title = "Activate"
            activateButton.isEnabled = true
            activateButton.layer?.backgroundColor = DesignColors.positive.cgColor
        }
    }
    
    // MARK: - Actions
    
    @objc private func backClicked() {
        onBackClicked?()
    }
    
    @objc private func activateClicked() {
        guard let collection = collection else { return }
        onActivateClicked?(collection)
    }
    
    @objc private func menuClicked() {
        guard let collection = collection else { return }
        
        let menu = NSMenu()
        
        // Duplicate
        let duplicateItem = NSMenuItem(title: "Duplicate Collection", action: #selector(duplicateCollection), keyEquivalent: "")
        duplicateItem.target = self
        menu.addItem(duplicateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Delete (only if not default)
        if !collection.isDefault {
            let deleteItem = NSMenuItem(title: "Delete Collection…", action: #selector(deleteCollection), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
        }
        
        let location = NSPoint(x: menuButton.frame.midX, y: menuButton.frame.minY)
        menu.popUp(positioning: nil, at: location, in: headerView)
    }
    
    @objc private func duplicateCollection() {
        guard let collection = collection else { return }
        
        var newCollection = CollectionStore.shared.createCollection(name: "\(collection.name) Copy")
        newCollection.characters = collection.characters
        newCollection.stages = collection.stages
        newCollection.screenpackPath = collection.screenpackPath
        CollectionStore.shared.update(newCollection)
        
        ToastManager.shared.showSuccess(title: "Created copy: \(newCollection.name)")
    }
    
    @objc private func deleteCollection() {
        guard let collection = collection else { return }
        guard !collection.isDefault else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Collection?"
        alert.informativeText = "Are you sure you want to delete \"\(collection.name)\"? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            CollectionStore.shared.delete(collection)
            onBackClicked?()
            ToastManager.shared.showInfo(title: "Deleted: \(collection.name)")
        }
    }
    
    @objc private func addCharactersClicked() {
        guard let collection = collection else { return }
        onAddCharactersClicked?(collection)
    }
    
    @objc private func addStagesClicked() {
        guard let collection = collection else { return }
        onAddStagesClicked?(collection)
    }
    
    @objc private func changeScreenpackClicked() {
        guard let collection = collection else { return }
        onChangeScreenpackClicked?(collection)
    }
    
    // MARK: - Context Menu for Roster Items
    
    func buildRosterContextMenu(for index: Int) -> NSMenu? {
        guard let collection = collection, index < collection.characters.count else { return nil }
        let entry = collection.characters[index]
        
        let menu = NSMenu()
        
        // Remove
        let removeItem = NSMenuItem(title: "Remove", action: #selector(removeRosterEntry(_:)), keyEquivalent: "")
        removeItem.target = self
        removeItem.representedObject = entry.id
        menu.addItem(removeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Insert Empty Slot After
        let emptySlotItem = NSMenuItem(title: "Insert Empty Slot After", action: #selector(insertEmptySlotAfter(_:)), keyEquivalent: "")
        emptySlotItem.target = self
        emptySlotItem.representedObject = index
        menu.addItem(emptySlotItem)
        
        // Insert Random Select After
        let randomSelectItem = NSMenuItem(title: "Insert Random Select After", action: #selector(insertRandomSelectAfter(_:)), keyEquivalent: "")
        randomSelectItem.target = self
        randomSelectItem.representedObject = index
        menu.addItem(randomSelectItem)
        
        return menu
    }
    
    @objc private func removeRosterEntry(_ sender: NSMenuItem) {
        guard let entryId = sender.representedObject as? UUID,
              let collection = collection else { return }
        
        CollectionStore.shared.removeCharacter(entryId: entryId, from: collection.id)
    }
    
    @objc private func insertEmptySlotAfter(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int,
              var collection = collection else { return }
        
        let emptySlot = RosterEntry.emptySlot()
        collection.characters.insert(emptySlot, at: index + 1)
        CollectionStore.shared.update(collection)
    }
    
    @objc private func insertRandomSelectAfter(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int,
              var collection = collection else { return }
        
        let randomSelect = RosterEntry.randomSelect()
        collection.characters.insert(randomSelect, at: index + 1)
        CollectionStore.shared.update(collection)
    }
    
    // MARK: - Context Menu for Stage Items
    
    func buildStageContextMenu(for index: Int) -> NSMenu? {
        guard let collection = collection, index < collection.stages.count else { return nil }
        let stageFolder = collection.stages[index]
        
        let menu = NSMenu()
        
        let removeItem = NSMenuItem(title: "Remove", action: #selector(removeStageEntry(_:)), keyEquivalent: "")
        removeItem.target = self
        removeItem.representedObject = stageFolder
        menu.addItem(removeItem)
        
        return menu
    }
    
    @objc private func removeStageEntry(_ sender: NSMenuItem) {
        guard let stageFolder = sender.representedObject as? String,
              let collection = collection else { return }
        
        CollectionStore.shared.removeStage(folder: stageFolder, from: collection.id)
    }
}

// MARK: - NSTextFieldDelegate

extension CollectionEditorView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField == titleLabel,
              var collection = collection else { return }
        
        let newName = textField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != collection.name else {
            textField.stringValue = collection.name
            return
        }
        
        collection.name = newName
        CollectionStore.shared.update(collection)
    }
}

// MARK: - NSCollectionViewDataSource

extension CollectionEditorView: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let collection = collection else { return 0 }
        
        if collectionView == rosterCollectionView {
            return collection.characters.count
        } else if collectionView == stagesCollectionView {
            return collection.stages.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if collectionView == rosterCollectionView {
            let item = collectionView.makeItem(withIdentifier: RosterEntryItem.identifier, for: indexPath) as! RosterEntryItem
            if let entry = collection?.characters[indexPath.item] {
                item.configure(with: entry)
            }
            return item
        } else if collectionView == stagesCollectionView {
            let item = collectionView.makeItem(withIdentifier: StageEntryItem.identifier, for: indexPath) as! StageEntryItem
            if let stageFolder = collection?.stages[indexPath.item] {
                item.configure(with: stageFolder)
            }
            return item
        }
        
        fatalError("Unknown collection view")
    }
}

// MARK: - NSCollectionViewDelegate

extension CollectionEditorView: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Handle selection if needed
    }
    
    // Context menu
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> NSSize {
        return .zero
    }
    
    // Drag and drop for reordering roster
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        return collectionView == rosterCollectionView
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        guard collectionView == rosterCollectionView else { return nil }
        
        let item = NSPasteboardItem()
        item.setString(String(indexPath.item), forType: .rosterEntryDrag)
        return item
    }
    
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard collectionView == rosterCollectionView else { return [] }
        proposedDropOperation.pointee = .before
        return .move
    }
    
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard collectionView == rosterCollectionView,
              let collection = collection else { return false }
        
        guard let items = draggingInfo.draggingPasteboard.pasteboardItems,
              let item = items.first,
              let indexString = item.string(forType: .rosterEntryDrag),
              let sourceIndex = Int(indexString) else { return false }
        
        var destIndex = indexPath.item
        if sourceIndex < destIndex {
            destIndex -= 1
        }
        
        CollectionStore.shared.reorderCharacters(in: collection.id, from: sourceIndex, to: destIndex)
        return true
    }
}

// MARK: - Roster Entry Item

class RosterEntryItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("RosterEntryItem")
    
    private var containerView: NSView!
    private var thumbnailView: NSImageView!
    private var nameLabel: NSTextField!
    private var entry: RosterEntry?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 130))
        
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.zinc800.cgColor
        containerView.layer?.cornerRadius = 6
        view.addSubview(containerView)
        
        thumbnailView = NSImageView()
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 4
        thumbnailView.layer?.masksToBounds = true
        containerView.addSubview(thumbnailView)
        
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.caption(size: 11)
        nameLabel.textColor = DesignColors.textSecondary
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            thumbnailView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            thumbnailView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            thumbnailView.heightAnchor.constraint(equalToConstant: 90),
            
            nameLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
        ])
    }
    
    func configure(with entry: RosterEntry) {
        self.entry = entry
        
        switch entry.entryType {
        case .character:
            nameLabel.stringValue = entry.characterFolder ?? "Unknown"
            thumbnailView.image = NSImage(systemSymbolName: "person.fill", accessibilityDescription: nil)
            thumbnailView.contentTintColor = DesignColors.textSecondary
            
            // Load actual thumbnail
            if let folder = entry.characterFolder {
                loadThumbnail(for: folder)
            }
            
        case .randomSelect:
            nameLabel.stringValue = "Random"
            thumbnailView.image = NSImage(systemSymbolName: "questionmark.circle.fill", accessibilityDescription: nil)
            thumbnailView.contentTintColor = DesignColors.warning
            
        case .emptySlot:
            nameLabel.stringValue = "Empty"
            thumbnailView.image = NSImage(systemSymbolName: "square.dashed", accessibilityDescription: nil)
            thumbnailView.contentTintColor = DesignColors.zinc600
        }
    }
    
    private func loadThumbnail(for folder: String) {
        guard let ikemenPath = IkemenBridge.shared.workingDirectory else { return }
        
        // Find the character in the bridge's loaded characters
        if let character = IkemenBridge.shared.characters.first(where: { $0.directory.lastPathComponent == folder }) {
            if let cached = ImageCache.shared.getPortrait(for: character) {
                thumbnailView.image = cached
                thumbnailView.contentTintColor = nil
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            containerView.layer?.borderWidth = isSelected ? 2 : 0
            containerView.layer?.borderColor = isSelected ? DesignColors.badgeCharacter.cgColor : nil
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let collectionView = view.superview?.superview?.superview as? NSCollectionView,
              let indexPath = collectionView.indexPath(for: self),
              let editorView = findCollectionEditorView() else {
            super.rightMouseDown(with: event)
            return
        }
        
        if let menu = editorView.buildRosterContextMenu(for: indexPath.item) {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
    }
    
    private func findCollectionEditorView() -> CollectionEditorView? {
        var responder: NSResponder? = view
        while let next = responder?.nextResponder {
            if let editor = next as? CollectionEditorView {
                return editor
            }
            responder = next
        }
        return nil
    }
}

// MARK: - Stage Entry Item

class StageEntryItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("StageEntryItem")
    
    private var containerView: NSView!
    private var thumbnailView: NSImageView!
    private var nameLabel: NSTextField!
    private var stageFolder: String?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 90))
        
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.zinc800.cgColor
        containerView.layer?.cornerRadius = 6
        view.addSubview(containerView)
        
        thumbnailView = NSImageView()
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 4
        thumbnailView.layer?.masksToBounds = true
        containerView.addSubview(thumbnailView)
        
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.caption(size: 11)
        nameLabel.textColor = .white
        nameLabel.alignment = .center
        nameLabel.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        nameLabel.drawsBackground = true
        nameLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            thumbnailView.topAnchor.constraint(equalTo: containerView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            nameLabel.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    func configure(with folder: String) {
        self.stageFolder = folder
        nameLabel.stringValue = folder
        
        // Default icon
        thumbnailView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        thumbnailView.contentTintColor = DesignColors.textSecondary
        
        // Try to load stage thumbnail
        loadThumbnail(for: folder)
    }
    
    private func loadThumbnail(for folder: String) {
        guard let ikemenPath = IkemenBridge.shared.workingDirectory else { return }
        let stagePath = ikemenPath.appendingPathComponent("stages/\(folder)")
        
        // Look for preview image
        let possibleNames = ["\(folder).png", "preview.png", "\(folder).jpg", "preview.jpg"]
        for name in possibleNames {
            let imagePath = stagePath.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: imagePath.path),
               let image = NSImage(contentsOf: imagePath) {
                thumbnailView.image = image
                thumbnailView.contentTintColor = nil
                break
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            containerView.layer?.borderWidth = isSelected ? 2 : 0
            containerView.layer?.borderColor = isSelected ? DesignColors.badgeCharacter.cgColor : nil
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let collectionView = view.superview?.superview?.superview as? NSCollectionView,
              let indexPath = collectionView.indexPath(for: self),
              let editorView = findCollectionEditorView() else {
            super.rightMouseDown(with: event)
            return
        }
        
        if let menu = editorView.buildStageContextMenu(for: indexPath.item) {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
    }
    
    private func findCollectionEditorView() -> CollectionEditorView? {
        var responder: NSResponder? = view
        while let next = responder?.nextResponder {
            if let editor = next as? CollectionEditorView {
                return editor
            }
            responder = next
        }
        return nil
    }
}
