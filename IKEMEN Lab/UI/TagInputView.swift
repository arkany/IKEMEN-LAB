import AppKit

// MARK: - TagInputViewDelegate

protocol TagInputViewDelegate: AnyObject {
    func tagInputViewDidChange(_ tagInput: TagInputView)
}

// MARK: - TagInputView

/// Tag input with chips display and autocomplete suggestions
/// Shows tags as removable chips with a text input for adding new ones
class TagInputView: NSView, NSTextFieldDelegate, NSTableViewDelegate, NSTableViewDataSource {
    
    // MARK: - Properties
    
    weak var delegate: TagInputViewDelegate?
    private(set) var tags: [String] = []
    
    /// All available tags for autocomplete
    private var availableTags: [String] = []
    private var filteredSuggestions: [String] = []
    
    // MARK: - UI Components
    
    private var containerView: NSView!
    private var stackView: NSStackView!
    private var inputField: NSTextField!
    private var suggestionsWindow: NSWindow?
    private var suggestionsTableView: NSTableView?
    
    // MARK: - Colors (from DesignColors)
    
    private var bgColor: NSColor { DesignColors.inputBackground }
    private var borderColor: NSColor { DesignColors.borderHover }
    private var chipBgColor: NSColor { DesignColors.buttonSecondaryBackground }
    private var chipBorderColor: NSColor { DesignColors.borderSubtle }
    private var chipTextColor: NSColor { DesignColors.textSecondary }
    private var textPrimary: NSColor { DesignColors.textPrimary }
    private var textMuted: NSColor { DesignColors.textTertiary }
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        loadAvailableTags()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        wantsLayer = true
        
        // Container with border
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = bgColor.cgColor
        containerView.layer?.cornerRadius = 4
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = borderColor.cgColor
        addSubview(containerView)
        
        // Stack view for tags + input
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.spacing = 6
        stackView.alignment = .centerY
        stackView.distribution = .fill
        containerView.addSubview(stackView)
        
        // Input field
        inputField = NSTextField()
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.placeholderString = "Type to add tag..."
        inputField.font = DesignFonts.label(size: 11)
        inputField.textColor = textPrimary
        inputField.backgroundColor = .clear
        inputField.drawsBackground = false
        inputField.isBezeled = false
        inputField.focusRingType = .none
        inputField.delegate = self
        inputField.cell?.usesSingleLineMode = true
        inputField.cell?.wraps = false
        inputField.cell?.isScrollable = true
        inputField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inputField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(inputField)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            
            inputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
        ])
    }
    
    private func loadAvailableTags() {
        // Load custom tags from database
        var allTags = Set<String>()
        
        if let customTags = try? MetadataStore.shared.allCustomTags() {
            customTags.forEach { allTags.insert($0) }
        }
        
        // Add common inferred tags (these are the tag categories from TagDetector)
        let inferredTags = [
            // Source games
            "Street Fighter", "KOF", "MVC", "CVS", "Guilty Gear", "Melty Blood",
            "JoJo", "Dragon Ball", "Naruto", "BlazBlue", "Tekken", "Mortal Kombat",
            "Fatal Fury", "Samurai Shodown", "Last Blade", "Darkstalkers",
            "Killer Instinct", "Soul Calibur", "Dead or Alive", "Virtua Fighter",
            // Franchises
            "DC", "Marvel", "Capcom", "SNK", "Namco", "Sega", "Nintendo",
            "Anime", "Original", "MUGEN Original",
            // Styles
            "POTS", "MvC2", "CvS", "Anime Style", "3D Style",
        ]
        inferredTags.forEach { allTags.insert($0) }
        
        availableTags = allTags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    // MARK: - Public API
    
    func setTags(_ newTags: [String]) {
        // Remove existing tag chips
        for view in stackView.arrangedSubviews where view !== inputField {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        tags = newTags
        
        // Add tag chips before the input field
        for tag in tags {
            let chip = createTagChip(for: tag)
            stackView.insertArrangedSubview(chip, at: stackView.arrangedSubviews.count - 1)
        }
    }
    
    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        
        tags.append(trimmed)
        let chip = createTagChip(for: trimmed)
        stackView.insertArrangedSubview(chip, at: stackView.arrangedSubviews.count - 1)
        
        delegate?.tagInputViewDidChange(self)
    }
    
    func removeTag(_ tag: String) {
        guard let index = tags.firstIndex(of: tag) else { return }
        tags.remove(at: index)
        
        // Find and remove the chip view
        for view in stackView.arrangedSubviews {
            if let chip = view as? TagChipView, chip.tagName == tag {
                stackView.removeArrangedSubview(chip)
                chip.removeFromSuperview()
                break
            }
        }
        
        delegate?.tagInputViewDidChange(self)
    }
    
    // MARK: - Private
    
    private func createTagChip(for tag: String) -> TagChipView {
        let chip = TagChipView(tag: tag)
        chip.onRemove = { [weak self] removedTag in
            self?.removeTag(removedTag)
        }
        return chip
    }
    
    // MARK: - NSTextFieldDelegate
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            // Enter pressed - add tag (use selected suggestion if available)
            if let selectedTag = getSelectedSuggestion() {
                addTag(selectedTag)
            } else {
                let text = inputField.stringValue
                addTag(text)
            }
            inputField.stringValue = ""
            hideSuggestions()
            return true
        } else if commandSelector == #selector(deleteBackward(_:)) {
            // Backspace with empty field - remove last tag
            if inputField.stringValue.isEmpty && !tags.isEmpty {
                removeTag(tags.last!)
                return true
            }
        } else if commandSelector == #selector(moveDown(_:)) {
            // Arrow down - navigate suggestions
            selectNextSuggestion()
            return true
        } else if commandSelector == #selector(moveUp(_:)) {
            // Arrow up - navigate suggestions
            selectPreviousSuggestion()
            return true
        } else if commandSelector == #selector(cancelOperation(_:)) {
            // Escape - hide suggestions
            hideSuggestions()
            return true
        }
        return false
    }
    
    func controlTextDidChange(_ obj: Notification) {
        let query = inputField.stringValue.trimmingCharacters(in: .whitespaces)
        
        if query.count >= 2 {
            // Filter suggestions
            filteredSuggestions = availableTags.filter { tag in
                tag.localizedCaseInsensitiveContains(query) && !tags.contains(tag)
            }
            
            if !filteredSuggestions.isEmpty {
                showSuggestions()
            } else {
                hideSuggestions()
            }
        } else {
            hideSuggestions()
        }
    }
    
    // MARK: - Suggestions Window
    
    private func showSuggestions() {
        guard let window = self.window else { return }
        
        if suggestionsWindow == nil {
            createSuggestionsWindow()
        }
        
        guard let suggestionsWindow = suggestionsWindow,
              let tableView = suggestionsTableView else { return }
        
        // Update table data
        tableView.reloadData()
        
        // Position below input field
        let fieldRect = containerView.convert(containerView.bounds, to: nil)
        let screenRect = window.convertToScreen(fieldRect)
        
        let rowHeight: CGFloat = 26
        let padding: CGFloat = 8
        let height = min(CGFloat(filteredSuggestions.count) * rowHeight + padding, 200)
        suggestionsWindow.setFrame(NSRect(
            x: screenRect.origin.x,
            y: screenRect.origin.y - height - 4,
            width: screenRect.width,
            height: height
        ), display: true)
        
        if !suggestionsWindow.isVisible {
            window.addChildWindow(suggestionsWindow, ordered: .above)
            suggestionsWindow.orderFront(nil)
        }
    }
    
    private func hideSuggestions() {
        suggestionsWindow?.orderOut(nil)
        suggestionsWindow?.parent?.removeChildWindow(suggestionsWindow!)
    }
    
    private func createSuggestionsWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .popUpMenu
        panel.hasShadow = true
        
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        contentView.layer?.cornerRadius = 6
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = DesignColors.borderHover.cgColor
        panel.contentView = contentView
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        contentView.addSubview(scrollView)
        
        let tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.headerView = nil
        tableView.rowHeight = 26
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.selectionHighlightStyle = .sourceList
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(suggestionDoubleClicked)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tag"))
        column.width = 200
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        suggestionsTableView = tableView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
        ])
        
        suggestionsWindow = panel
    }
    
    @objc private func suggestionDoubleClicked() {
        if let selected = getSelectedSuggestion() {
            addTag(selected)
            inputField.stringValue = ""
            hideSuggestions()
        }
    }
    
    private func getSelectedSuggestion() -> String? {
        guard let tableView = suggestionsTableView else { return nil }
        let row = tableView.selectedRow
        if row >= 0 && row < filteredSuggestions.count {
            return filteredSuggestions[row]
        }
        return nil
    }
    
    private func selectNextSuggestion() {
        guard let tableView = suggestionsTableView, !filteredSuggestions.isEmpty else { return }
        let newRow = min(tableView.selectedRow + 1, filteredSuggestions.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
    }
    
    private func selectPreviousSuggestion() {
        guard let tableView = suggestionsTableView, !filteredSuggestions.isEmpty else { return }
        let newRow = max(tableView.selectedRow - 1, 0)
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredSuggestions.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tag = filteredSuggestions[row]
        
        let cell = NSTableCellView()
        cell.wantsLayer = true
        
        let label = NSTextField(labelWithString: tag)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.label(size: 12)
        label.textColor = DesignColors.textPrimary
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        cell.addSubview(label)
        cell.textField = label
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 26
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        // Visual feedback handled by table view
    }
}

// MARK: - TagChipView

/// A single tag chip with remove button
private class TagChipView: NSView {
    
    let tagName: String
    var onRemove: ((String) -> Void)?
    
    private var bgColor: NSColor { DesignColors.buttonSecondaryBackground }
    private var borderColor: NSColor { DesignColors.borderSubtle }
    private var textColor: NSColor { DesignColors.textSecondary }
    
    init(tag: String) {
        self.tagName = tag
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = bgColor.cgColor
        layer?.cornerRadius = 3
        layer?.borderWidth = 1
        layer?.borderColor = borderColor.cgColor
        
        // Tag label
        let label = NSTextField(labelWithString: tagName)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.label(size: 9)
        label.textColor = textColor
        addSubview(label)
        
        // Remove button
        let removeButton = NSButton()
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.bezelStyle = .regularSquare
        removeButton.isBordered = false
        removeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Remove")
        removeButton.contentTintColor = textColor.withAlphaComponent(0.6)
        removeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 7, weight: .medium)
        removeButton.target = self
        removeButton.action = #selector(removeTapped)
        addSubview(removeButton)
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 18),
            
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            removeButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 2),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 12),
            removeButton.heightAnchor.constraint(equalToConstant: 12),
        ])
    }
    
    @objc private func removeTapped() {
        onRemove?(tagName)
    }
}
