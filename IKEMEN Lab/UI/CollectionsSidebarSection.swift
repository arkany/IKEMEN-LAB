import Cocoa
import Combine

/// Sidebar section displaying user collections with status indicators
class CollectionsSidebarSection: NSView {
    
    // MARK: - Properties
    
    private let collectionStore = CollectionStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Called when a collection is selected
    var onCollectionSelected: ((Collection) -> Void)?
    
    /// Called when "New Collection..." is clicked
    var onNewCollectionClicked: (() -> Void)?
    
    /// Called when "New Smart Collection..." is clicked
    var onNewSmartCollectionClicked: (() -> Void)?
    
    // UI Elements
    private var headerLabel: NSTextField!
    private var collectionsStack: NSStackView!
    private var collectionButtons: [UUID: NSButton] = [:]
    private var selectedCollectionId: UUID?
    private var themeObserver: NSObjectProtocol?
    
    // Layout constants
    private let itemHeight: CGFloat = 32
    private let horizontalPadding: CGFloat = 12
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        bindToStore()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        bindToStore()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // Section header label
        headerLabel = NSTextField(labelWithString: "COLLECTIONS")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        headerLabel.textColor = DesignColors.textDisabled
        let kerning: [NSAttributedString.Key: Any] = [.kern: 2.0]
        headerLabel.attributedStringValue = NSAttributedString(string: "COLLECTIONS", attributes: kerning)
        addSubview(headerLabel)
        
        // Stack for collection items
        collectionsStack = NSStackView()
        collectionsStack.translatesAutoresizingMaskIntoConstraints = false
        collectionsStack.orientation = .vertical
        collectionsStack.spacing = 2
        collectionsStack.alignment = .leading
        addSubview(collectionsStack)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            collectionsStack.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            collectionsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionsStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.headerLabel.textColor = DesignColors.textDisabled
            self?.rebuildCollectionsList()
        }
    }
    
    private func bindToStore() {
        // Observe collections changes
        collectionStore.$collections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildCollectionsList()
            }
            .store(in: &cancellables)
        
        // Observe active collection changes
        collectionStore.$activeCollectionId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActiveIndicators()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Rebuild Collection List
    
    private func rebuildCollectionsList() {
        // Remove existing buttons
        for subview in collectionsStack.arrangedSubviews {
            collectionsStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        collectionButtons.removeAll()
        
        // Add collection items
        for collection in collectionStore.collections {
            let button = createCollectionButton(for: collection)
            collectionButtons[collection.id] = button
            collectionsStack.addArrangedSubview(button)
        }
        
        // Add "New Collection..." button
        let newButton = createNewCollectionButton()
        collectionsStack.addArrangedSubview(newButton)
        
        updateActiveIndicators()
    }
    
    // MARK: - Create Collection Button
    
    private func createCollectionButton(for collection: Collection) -> NSButton {
        let button = HoverButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""
        button.isBordered = false
        button.bezelStyle = .inline
        button.target = self
        button.action = #selector(collectionClicked(_:))
        button.wantsLayer = true
        button.focusRingType = .none
        
        // Container for hover/selection background
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        container.identifier = NSUserInterfaceItemIdentifier("collectionContainer")
        button.addSubview(container)
        
        // Horizontal stack for content
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: collection.icon, accessibilityDescription: collection.name)
        iconView.contentTintColor = DesignColors.textSecondary
        iconView.symbolConfiguration = .init(pointSize: 12, weight: .regular)
        stack.addArrangedSubview(iconView)
        
        // Status indicator (active = green dot, incomplete = yellow)
        let statusView = NSView()
        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusView.wantsLayer = true
        statusView.layer?.cornerRadius = 4
        statusView.identifier = NSUserInterfaceItemIdentifier("statusIndicator")
        NSLayoutConstraint.activate([
            statusView.widthAnchor.constraint(equalToConstant: 8),
            statusView.heightAnchor.constraint(equalToConstant: 8),
        ])
        stack.addArrangedSubview(statusView)
        
        // Name label
        let nameLabel = NSTextField(labelWithString: collection.name)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.body(size: 13)
        nameLabel.textColor = DesignColors.textSecondary
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(nameLabel)
        
        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)
        
        // Count badge
        let countLabel = NSTextField(labelWithString: "\(collection.characters.count)")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = DesignColors.textDisabled
        countLabel.alignment = .right
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        stack.addArrangedSubview(countLabel)
        
        // Default indicator (checkmark for default collection)
        if collection.isDefault {
            let checkmark = NSImageView()
            checkmark.translatesAutoresizingMaskIntoConstraints = false
            checkmark.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Default")
            checkmark.contentTintColor = DesignColors.textDisabled
            checkmark.symbolConfiguration = .init(pointSize: 10, weight: .medium)
            stack.addArrangedSubview(checkmark)
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            container.topAnchor.constraint(equalTo: button.topAnchor),
            container.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalPadding),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            button.heightAnchor.constraint(equalToConstant: itemHeight),
        ])
        
        // Store collection ID for identification
        button.identifier = NSUserInterfaceItemIdentifier(collection.id.uuidString)
        
        // Hover handling
        button.onHoverChanged = { [weak self, weak button] isHovered in
            guard let self = self, let button = button else { return }
            self.updateButtonAppearance(button, isHovered: isHovered)
        }
        
        // Double-click to activate
        button.onDoubleClick = { [weak self] in
            guard let collectionId = UUID(uuidString: button.identifier?.rawValue ?? "") else { return }
            if let collection = self?.collectionStore.collection(withId: collectionId) {
                self?.collectionStore.setActive(collection)
            }
        }
        
        // Setup context menu
        let menu = NSMenu()
        
        if !collection.isDefault {
            let renameItem = NSMenuItem(title: "Rename...", action: #selector(renameCollection(_:)), keyEquivalent: "")
            renameItem.representedObject = collection.id
            renameItem.target = self
            menu.addItem(renameItem)
        }
        
        let duplicateItem = NSMenuItem(title: "Duplicate", action: #selector(duplicateCollection(_:)), keyEquivalent: "")
        duplicateItem.representedObject = collection.id
        duplicateItem.target = self
        menu.addItem(duplicateItem)
        
        if !collection.isDefault {
            menu.addItem(NSMenuItem.separator())
            
            let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteCollection(_:)), keyEquivalent: "")
            deleteItem.representedObject = collection.id
            deleteItem.target = self
            menu.addItem(deleteItem)
        }
        
        button.menu = menu
        
        return button
    }
    
    // MARK: - New Collection Button
    
    private func createNewCollectionButton() -> NSButton {
        let button = HoverButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = ""
        button.isBordered = false
        button.bezelStyle = .inline
        button.target = self
        button.action = #selector(newCollectionClicked(_:))
        button.wantsLayer = true
        button.focusRingType = .none
        
        // Container
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 6
        container.identifier = NSUserInterfaceItemIdentifier("collectionContainer")
        button.addSubview(container)
        
        // Stack
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // Plus icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New")
        iconView.contentTintColor = DesignColors.textTertiary
        iconView.symbolConfiguration = .init(pointSize: 12, weight: .regular)
        stack.addArrangedSubview(iconView)
        
        // Label
        let label = NSTextField(labelWithString: "New Collection...")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.body(size: 13)
        label.textColor = DesignColors.textTertiary
        stack.addArrangedSubview(label)
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            container.topAnchor.constraint(equalTo: button.topAnchor),
            container.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalPadding),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            button.heightAnchor.constraint(equalToConstant: itemHeight),
        ])
        
        button.onHoverChanged = { [weak button] isHovered in
            guard let container = button?.subviews.first(where: { $0.identifier?.rawValue == "collectionContainer" }) else { return }
            container.layer?.backgroundColor = isHovered ? DesignColors.hoverBackground.cgColor : NSColor.clear.cgColor
        }
        
        // Create context menu for collection type choice
        let menu = NSMenu()
        
        let newCollectionItem = NSMenuItem(title: "New Collection", action: #selector(createNewRegularCollection), keyEquivalent: "")
        newCollectionItem.target = self
        newCollectionItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        menu.addItem(newCollectionItem)
        
        let newSmartItem = NSMenuItem(title: "New Smart Collection...", action: #selector(createNewSmartCollection), keyEquivalent: "")
        newSmartItem.target = self
        newSmartItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)
        menu.addItem(newSmartItem)
        
        button.menu = menu
        
        return button
    }
    
    // MARK: - Update Appearance
    
    private func updateButtonAppearance(_ button: NSButton, isHovered: Bool) {
        guard let container = button.subviews.first(where: { $0.identifier?.rawValue == "collectionContainer" }) else { return }
        guard let collectionIdString = button.identifier?.rawValue,
              let collectionId = UUID(uuidString: collectionIdString) else { return }
        
        let isSelected = selectedCollectionId == collectionId
        
        if isSelected {
            container.layer?.backgroundColor = DesignColors.selectedBackground.cgColor
            container.layer?.borderWidth = 1
            container.layer?.borderColor = DesignColors.borderSubtle.cgColor
        } else if isHovered {
            container.layer?.backgroundColor = DesignColors.hoverBackground.cgColor
            container.layer?.borderWidth = 0
        } else {
            container.layer?.backgroundColor = NSColor.clear.cgColor
            container.layer?.borderWidth = 0
        }
    }
    
    private func updateActiveIndicators() {
        for (collectionId, button) in collectionButtons {
            guard let statusView = findStatusIndicator(in: button) else { continue }
            
            let isActive = collectionStore.activeCollectionId == collectionId
            
            if isActive {
                statusView.layer?.backgroundColor = DesignColors.positive.cgColor
            } else {
                statusView.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
    
    private func findStatusIndicator(in view: NSView) -> NSView? {
        if view.identifier?.rawValue == "statusIndicator" {
            return view
        }
        for subview in view.subviews {
            if let found = findStatusIndicator(in: subview) {
                return found
            }
        }
        return nil
    }
    
    // MARK: - Actions
    
    @objc private func collectionClicked(_ sender: NSButton) {
        guard let collectionIdString = sender.identifier?.rawValue,
              let collectionId = UUID(uuidString: collectionIdString),
              let collection = collectionStore.collection(withId: collectionId) else { return }
        
        selectedCollectionId = collectionId
        
        // Update all button appearances
        for (_, button) in collectionButtons {
            updateButtonAppearance(button, isHovered: false)
        }
        updateButtonAppearance(sender, isHovered: false)
        
        onCollectionSelected?(collection)
    }
    
    @objc private func newCollectionClicked(_ sender: NSButton) {
        // Show menu on left click
        if let menu = sender.menu {
            NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: sender)
        }
    }
    
    @objc private func createNewRegularCollection() {
        onNewCollectionClicked?()
    }
    
    @objc private func createNewSmartCollection() {
        onNewSmartCollectionClicked?()
    }
    
    @objc private func renameCollection(_ sender: NSMenuItem) {
        guard let collectionId = sender.representedObject as? UUID,
              let collection = collectionStore.collection(withId: collectionId) else { return }
        
        let alert = NSAlert()
        alert.messageText = "Rename Collection"
        alert.informativeText = "Enter a new name for the collection:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        input.stringValue = collection.name
        alert.accessoryView = input
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let newName = input.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { return }
        
        var updated = collection
        updated.name = newName
        collectionStore.update(updated)
    }
    
    @objc private func duplicateCollection(_ sender: NSMenuItem) {
        guard let collectionId = sender.representedObject as? UUID,
              let collection = collectionStore.collection(withId: collectionId) else { return }
        
        var newCollection = collectionStore.createCollection(name: "\(collection.name) Copy", icon: collection.icon)
        newCollection.characters = collection.characters
        newCollection.stages = collection.stages
        newCollection.screenpackPath = collection.screenpackPath
        collectionStore.update(newCollection)
    }
    
    @objc private func deleteCollection(_ sender: NSMenuItem) {
        guard let collectionId = sender.representedObject as? UUID,
              let collection = collectionStore.collection(withId: collectionId) else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Collection?"
        alert.informativeText = "Are you sure you want to delete '\(collection.name)'? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        collectionStore.delete(collection)
    }
    
    // MARK: - Public API
    
    func selectCollection(_ collection: Collection) {
        selectedCollectionId = collection.id
        for (_, button) in collectionButtons {
            updateButtonAppearance(button, isHovered: false)
        }
    }
    
    func deselectAll() {
        selectedCollectionId = nil
        for (_, button) in collectionButtons {
            updateButtonAppearance(button, isHovered: false)
        }
    }

    deinit {
        if let themeObserver = themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }
}

// MARK: - HoverButton

/// Button subclass that tracks hover state and supports double-click
private class HoverButton: NSButton {
    var onHoverChanged: ((Bool) -> Void)?
    var onDoubleClick: (() -> Void)?
    
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        if let menu = menu {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }
}
