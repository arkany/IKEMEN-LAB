import Cocoa

// MARK: - Collection Icon Option

/// Available icons for collections
struct CollectionIconOption {
    let name: String
    let symbolName: String
    
    static let allOptions: [CollectionIconOption] = [
        // Gaming
        CollectionIconOption(name: "Gamepad", symbolName: "gamecontroller.fill"),
        CollectionIconOption(name: "Trophy", symbolName: "trophy.fill"),
        CollectionIconOption(name: "Star", symbolName: "star.fill"),
        CollectionIconOption(name: "Crown", symbolName: "crown.fill"),
        CollectionIconOption(name: "Bolt", symbolName: "bolt.fill"),
        CollectionIconOption(name: "Flame", symbolName: "flame.fill"),
        
        // Organization
        CollectionIconOption(name: "Folder", symbolName: "folder.fill"),
        CollectionIconOption(name: "Bookmark", symbolName: "bookmark.fill"),
        CollectionIconOption(name: "Tag", symbolName: "tag.fill"),
        CollectionIconOption(name: "Flag", symbolName: "flag.fill"),
        CollectionIconOption(name: "Pin", symbolName: "pin.fill"),
        CollectionIconOption(name: "Heart", symbolName: "heart.fill"),
        
        // Nature & Elements
        CollectionIconOption(name: "Leaf", symbolName: "leaf.fill"),
        CollectionIconOption(name: "Moon", symbolName: "moon.fill"),
        CollectionIconOption(name: "Sun", symbolName: "sun.max.fill"),
        CollectionIconOption(name: "Snowflake", symbolName: "snowflake"),
        CollectionIconOption(name: "Drop", symbolName: "drop.fill"),
        CollectionIconOption(name: "Mountain", symbolName: "mountain.2.fill"),
        
        // Tech & Objects
        CollectionIconOption(name: "Cube", symbolName: "cube.fill"),
        CollectionIconOption(name: "Shield", symbolName: "shield.fill"),
        CollectionIconOption(name: "Sparkles", symbolName: "sparkles"),
        CollectionIconOption(name: "Target", symbolName: "target"),
        CollectionIconOption(name: "Wand", symbolName: "wand.and.stars"),
        CollectionIconOption(name: "Lab", symbolName: "flask.fill"),
    ]
}

// MARK: - NewCollectionSheet

/// Sheet for creating a new collection with name and icon selection
class NewCollectionSheet: NSView {
    
    // MARK: - Properties
    
    var onCancel: (() -> Void)?
    var onCreateCollection: ((String, String) -> Void)?
    
    private var nameField: NSTextField!
    private var iconCollectionView: NSCollectionView!
    private var createButton: NSButton!
    private var cancelButton: NSButton!
    private var selectedIconIndex: Int = 0
    
    private var createButtonTrackingArea: NSTrackingArea?
    private var cancelButtonTrackingArea: NSTrackingArea?
    
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
        layer?.backgroundColor = DesignColors.panelBackground.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Add shadow for floating effect
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 20
        layer?.shadowOffset = CGSize(width: 0, height: -5)
        
        setupHeader()
        setupNameField()
        setupIconPicker()
        setupButtons()
    }
    
    private func setupHeader() {
        let titleLabel = NSTextField(labelWithString: "New Collection")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.header(size: 16)
        titleLabel.textColor = DesignColors.textPrimary
        addSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Create a collection to organize your characters and stages")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = DesignFonts.caption(size: 12)
        subtitleLabel.textColor = DesignColors.textTertiary
        addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
        ])
    }
    
    private func setupNameField() {
        let nameLabel = NSTextField(labelWithString: "NAME")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.label(size: 10)
        nameLabel.textColor = DesignColors.textTertiary
        addSubview(nameLabel)
        
        nameField = NSTextField()
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.placeholderString = "My Collection"
        nameField.font = DesignFonts.body(size: 14)
        nameField.textColor = DesignColors.textPrimary
        nameField.backgroundColor = DesignColors.inputBackground
        nameField.isBordered = false
        nameField.focusRingType = .none
        nameField.wantsLayer = true
        nameField.layer?.cornerRadius = 8
        nameField.layer?.borderWidth = 1
        nameField.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Add padding
        let paddedField = NSView()
        paddedField.translatesAutoresizingMaskIntoConstraints = false
        paddedField.wantsLayer = true
        paddedField.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        paddedField.layer?.cornerRadius = 8
        paddedField.layer?.borderWidth = 1
        paddedField.layer?.borderColor = DesignColors.borderSubtle.cgColor
        addSubview(paddedField)
        paddedField.addSubview(nameField)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 80),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            
            paddedField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            paddedField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            paddedField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            paddedField.heightAnchor.constraint(equalToConstant: 40),
            
            nameField.leadingAnchor.constraint(equalTo: paddedField.leadingAnchor, constant: 12),
            nameField.trailingAnchor.constraint(equalTo: paddedField.trailingAnchor, constant: -12),
            nameField.centerYAnchor.constraint(equalTo: paddedField.centerYAnchor),
        ])
        
        // Focus animation
        nameField.delegate = self
    }
    
    private func setupIconPicker() {
        let iconLabel = NSTextField(labelWithString: "ICON")
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = DesignFonts.label(size: 10)
        iconLabel.textColor = DesignColors.textTertiary
        addSubview(iconLabel)
        
        // Icon grid
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 44, height: 44)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        iconCollectionView = NSCollectionView()
        iconCollectionView.translatesAutoresizingMaskIntoConstraints = false
        iconCollectionView.collectionViewLayout = layout
        iconCollectionView.dataSource = self
        iconCollectionView.delegate = self
        iconCollectionView.backgroundColors = [.clear]
        iconCollectionView.isSelectable = true
        iconCollectionView.allowsMultipleSelection = false
        iconCollectionView.register(IconPickerItem.self, forItemWithIdentifier: IconPickerItem.identifier)
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = iconCollectionView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: topAnchor, constant: 148),
            iconLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            
            scrollView.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            scrollView.heightAnchor.constraint(equalToConstant: 120),
        ])
        
        // Select first icon by default
        DispatchQueue.main.async { [weak self] in
            self?.iconCollectionView.selectItems(at: [IndexPath(item: 0, section: 0)], scrollPosition: [])
        }
    }
    
    private func setupButtons() {
        // Button container
        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.alignment = .centerY
        addSubview(buttonStack)
        
        // Cancel button
        cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.bezelStyle = .inline
        cancelButton.isBordered = false
        cancelButton.wantsLayer = true
        cancelButton.layer?.cornerRadius = 8
        cancelButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
        cancelButton.layer?.borderWidth = 1
        cancelButton.layer?.borderColor = DesignColors.borderSubtle.cgColor
        cancelButton.font = DesignFonts.label(size: 13)
        cancelButton.attributedTitle = NSAttributedString(
            string: "Cancel",
            attributes: [
                .font: DesignFonts.label(size: 13),
                .foregroundColor: DesignColors.textSecondary
            ]
        )
        buttonStack.addArrangedSubview(cancelButton)
        
        // Create button
        createButton = NSButton(title: "Create Collection", target: self, action: #selector(createClicked))
        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.bezelStyle = .inline
        createButton.isBordered = false
        createButton.wantsLayer = true
        createButton.layer?.cornerRadius = 8
        createButton.layer?.backgroundColor = DesignColors.positive.cgColor
        createButton.font = DesignFonts.label(size: 13)
        createButton.attributedTitle = NSAttributedString(
            string: "Create Collection",
            attributes: [
                .font: DesignFonts.label(size: 13),
                .foregroundColor: DesignColors.textOnAccent
            ]
        )
        buttonStack.addArrangedSubview(createButton)
        
        NSLayoutConstraint.activate([
            buttonStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 36),
            
            createButton.widthAnchor.constraint(equalToConstant: 140),
            createButton.heightAnchor.constraint(equalToConstant: 36),
        ])
        
        setupButtonHoverEffects()
    }
    
    private func setupButtonHoverEffects() {
        // Cancel button hover
        cancelButtonTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["button": "cancel"]
        )
        cancelButton.addTrackingArea(cancelButtonTrackingArea!)
        
        // Create button hover
        createButtonTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["button": "create"]
        )
        createButton.addTrackingArea(createButtonTrackingArea!)
    }
    
    // MARK: - Mouse Tracking
    
    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: String] else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            
            if userInfo["button"] == "cancel" {
                cancelButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackgroundHover.cgColor
            } else if userInfo["button"] == "create" {
                // Slightly brighter green on hover
                createButton.layer?.backgroundColor = DesignColors.positive.blended(withFraction: 0.1, of: .white)?.cgColor
                // Scale up slightly
                createButton.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 1.02, y: 1.02))
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: String] else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            
            if userInfo["button"] == "cancel" {
                cancelButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
            } else if userInfo["button"] == "create" {
                createButton.layer?.backgroundColor = DesignColors.positive.cgColor
                createButton.animator().layer?.setAffineTransform(.identity)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func cancelClicked() {
        animateDismiss { [weak self] in
            self?.onCancel?()
        }
    }
    
    @objc private func createClicked() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            shakeNameField()
            return
        }
        
        let icon = CollectionIconOption.allOptions[selectedIconIndex].symbolName
        
        animateDismiss { [weak self] in
            self?.onCreateCollection?(name, icon)
        }
    }
    
    private func shakeNameField() {
        guard let parentView = nameField.superview else { return }
        
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.5
        animation.values = [-10, 10, -8, 8, -5, 5, -2, 2, 0]
        parentView.layer?.add(animation, forKey: "shake")
        
        // Flash border red
        parentView.layer?.borderColor = DesignColors.negative.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            parentView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        }
    }
    
    // MARK: - Animations
    
    func animateAppear() {
        alphaValue = 0
        layer?.setAffineTransform(CGAffineTransform(scaleX: 0.95, y: 0.95).translatedBy(x: 0, y: 20))
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().layer?.setAffineTransform(.identity)
        }
        
        // Auto-focus name field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.window?.makeFirstResponder(self?.nameField)
        }
    }
    
    func animateDismiss(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 0.95, y: 0.95).translatedBy(x: 0, y: 20))
        } completionHandler: {
            completion()
        }
    }
}

// MARK: - NSTextFieldDelegate

extension NewCollectionSheet: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField == nameField,
              let parentView = textField.superview else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            parentView.layer?.borderColor = DesignColors.positive.cgColor
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField == nameField,
              let parentView = textField.superview else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            parentView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            createClicked()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelClicked()
            return true
        }
        return false
    }
}

// MARK: - NSCollectionViewDataSource

extension NewCollectionSheet: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return CollectionIconOption.allOptions.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: IconPickerItem.identifier, for: indexPath) as! IconPickerItem
        let icon = CollectionIconOption.allOptions[indexPath.item]
        item.configure(with: icon, isSelected: indexPath.item == selectedIconIndex)
        return item
    }
}

// MARK: - NSCollectionViewDelegate

extension NewCollectionSheet: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        
        let previousIndex = selectedIconIndex
        selectedIconIndex = indexPath.item
        
        // Update previous and new selection
        if let previousItem = collectionView.item(at: IndexPath(item: previousIndex, section: 0)) as? IconPickerItem {
            previousItem.setSelected(false, animated: true)
        }
        if let newItem = collectionView.item(at: indexPath) as? IconPickerItem {
            newItem.setSelected(true, animated: true)
        }
    }
}

// MARK: - IconPickerItem

class IconPickerItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("IconPickerItem")
    
    private var containerView: NSView!
    private var iconView: NSImageView!
    private var trackingArea: NSTrackingArea?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
        
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        containerView.layer?.cornerRadius = 10
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        view.addSubview(containerView)
        
        iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = DesignColors.textSecondary
        containerView.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            iconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])
        
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard !isSelected else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            containerView.layer?.borderColor = DesignColors.borderHover.cgColor
            containerView.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 1.05, y: 1.05))
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard !isSelected else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
            containerView.animator().layer?.setAffineTransform(.identity)
        }
    }
    
    func configure(with icon: CollectionIconOption, isSelected: Bool) {
        iconView.image = NSImage(systemSymbolName: icon.symbolName, accessibilityDescription: icon.name)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        
        if isSelected {
            setSelected(true, animated: false)
        }
    }
    
    func setSelected(_ selected: Bool, animated: Bool) {
        let duration = animated ? 0.2 : 0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            if selected {
                containerView.layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.15).cgColor
                containerView.layer?.borderColor = DesignColors.positive.cgColor
                containerView.layer?.borderWidth = 2
                iconView.contentTintColor = DesignColors.positive
                containerView.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 1.1, y: 1.1))
            } else {
                containerView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
                containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
                containerView.layer?.borderWidth = 1
                iconView.contentTintColor = DesignColors.textSecondary
                containerView.animator().layer?.setAffineTransform(.identity)
            }
        }
    }
}
