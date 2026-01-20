import Cocoa

/// A text field with auto-suggest dropdown for tag input
/// Shows suggestions from existing tags as the user types
class TagInputView: NSView, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    
    // MARK: - Properties
    
    private var textField: NSTextField!
    private var suggestionsTable: NSTableView!
    private var suggestionsScrollView: NSScrollView!
    private var suggestionsContainer: NSView!
    private var suggestionsHeaderLabel: NSTextField!
    
    private var allTags: [String] = []
    private var filteredTags: [String] = []
    private var selectedSuggestionIndex: Int = -1
    
    /// The current text value
    var stringValue: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }
    
    /// Callback when user commits a tag (Enter or click suggestion)
    var onTagCommitted: ((String) -> Void)?
    
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
        
        // Load all existing tags
        allTags = (try? MetadataStore.shared.allCustomTags()) ?? []
        
        setupTextField()
        setupSuggestionsDropdown()
        setupConstraints()
    }
    
    // MARK: - Setup
    
    private func setupTextField() {
        textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = "Tag name"
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.delegate = self
        textField.focusRingType = .exterior
        textField.bezelStyle = .roundedBezel
        addSubview(textField)
    }
    
    private func setupSuggestionsDropdown() {
        // Container for dropdown shadow and border
        suggestionsContainer = NSView()
        suggestionsContainer.translatesAutoresizingMaskIntoConstraints = false
        suggestionsContainer.wantsLayer = true
        suggestionsContainer.layer?.backgroundColor = DesignColors.panelBackground.cgColor
        suggestionsContainer.layer?.cornerRadius = 6
        suggestionsContainer.layer?.borderWidth = 1
        suggestionsContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        suggestionsContainer.layer?.shadowColor = NSColor.black.cgColor
        suggestionsContainer.layer?.shadowOpacity = 0.3
        suggestionsContainer.layer?.shadowOffset = CGSize(width: 0, height: -2)
        suggestionsContainer.layer?.shadowRadius = 8
        suggestionsContainer.isHidden = true
        addSubview(suggestionsContainer)
        
        // Header label "Suggestions"
        suggestionsHeaderLabel = NSTextField(labelWithString: "Suggestions")
        suggestionsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        suggestionsHeaderLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        suggestionsHeaderLabel.textColor = DesignColors.textTertiary
        suggestionsContainer.addSubview(suggestionsHeaderLabel)
        
        // Scroll view for suggestions
        suggestionsScrollView = NSScrollView()
        suggestionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsScrollView.hasVerticalScroller = true
        suggestionsScrollView.hasHorizontalScroller = false
        suggestionsScrollView.autohidesScrollers = true
        suggestionsScrollView.drawsBackground = false
        suggestionsScrollView.borderType = .noBorder
        suggestionsContainer.addSubview(suggestionsScrollView)
        
        // Table view for suggestions
        suggestionsTable = NSTableView()
        suggestionsTable.backgroundColor = .clear
        suggestionsTable.headerView = nil
        suggestionsTable.rowHeight = 28
        suggestionsTable.intercellSpacing = NSSize(width: 0, height: 0)
        suggestionsTable.selectionHighlightStyle = .regular
        suggestionsTable.dataSource = self
        suggestionsTable.delegate = self
        suggestionsTable.target = self
        suggestionsTable.action = #selector(suggestionClicked)
        suggestionsTable.doubleAction = #selector(suggestionDoubleClicked)
        
        // Single column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TagColumn"))
        column.width = 230
        suggestionsTable.addTableColumn(column)
        
        suggestionsScrollView.documentView = suggestionsTable
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Text field at top
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.heightAnchor.constraint(equalToConstant: 24),
            
            // Suggestions container below text field
            suggestionsContainer.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 4),
            suggestionsContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            suggestionsContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            suggestionsContainer.heightAnchor.constraint(equalToConstant: 140),
            
            // Header label
            suggestionsHeaderLabel.topAnchor.constraint(equalTo: suggestionsContainer.topAnchor, constant: 8),
            suggestionsHeaderLabel.leadingAnchor.constraint(equalTo: suggestionsContainer.leadingAnchor, constant: 10),
            
            // Scroll view below header
            suggestionsScrollView.topAnchor.constraint(equalTo: suggestionsHeaderLabel.bottomAnchor, constant: 4),
            suggestionsScrollView.leadingAnchor.constraint(equalTo: suggestionsContainer.leadingAnchor, constant: 4),
            suggestionsScrollView.trailingAnchor.constraint(equalTo: suggestionsContainer.trailingAnchor, constant: -4),
            suggestionsScrollView.bottomAnchor.constraint(equalTo: suggestionsContainer.bottomAnchor, constant: -4),
        ])
    }
    
    // MARK: - Suggestions Logic
    
    private func updateSuggestions() {
        let query = textField.stringValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if query.isEmpty {
            // Show all tags when empty (up to 20)
            filteredTags = Array(allTags.prefix(20))
        } else {
            // Filter tags that contain the query, prioritizing prefix matches
            let prefixMatches = allTags.filter { $0.lowercased().hasPrefix(query) }
            let containsMatches = allTags.filter { 
                $0.lowercased().contains(query) && !$0.lowercased().hasPrefix(query) 
            }
            filteredTags = prefixMatches + containsMatches
        }
        
        // Only show dropdown if we have suggestions and they're different from exact input
        let exactMatch = filteredTags.count == 1 && filteredTags[0].lowercased() == query
        suggestionsContainer.isHidden = filteredTags.isEmpty || exactMatch
        
        selectedSuggestionIndex = -1
        suggestionsTable.reloadData()
        suggestionsTable.deselectAll(nil)
    }
    
    private func selectSuggestion(at index: Int) {
        guard index >= 0 && index < filteredTags.count else { return }
        textField.stringValue = filteredTags[index]
        hideSuggestions()
        
        // Move cursor to end of text
        if let editor = textField.currentEditor() {
            editor.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
        }
    }
    
    private func hideSuggestions() {
        suggestionsContainer.isHidden = true
        selectedSuggestionIndex = -1
    }
    
    // MARK: - NSTextFieldDelegate
    
    func controlTextDidBeginEditing(_ obj: Notification) {
        // Show suggestions when field gains focus (if we have tags)
        if !allTags.isEmpty {
            updateSuggestions()
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        updateSuggestions()
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(moveDown(_:)) {
            // Arrow down - navigate suggestions
            if !suggestionsContainer.isHidden {
                selectedSuggestionIndex = min(selectedSuggestionIndex + 1, filteredTags.count - 1)
                suggestionsTable.selectRowIndexes(IndexSet(integer: selectedSuggestionIndex), byExtendingSelection: false)
                suggestionsTable.scrollRowToVisible(selectedSuggestionIndex)
                return true
            }
        } else if commandSelector == #selector(moveUp(_:)) {
            // Arrow up - navigate suggestions
            if !suggestionsContainer.isHidden && selectedSuggestionIndex > 0 {
                selectedSuggestionIndex -= 1
                suggestionsTable.selectRowIndexes(IndexSet(integer: selectedSuggestionIndex), byExtendingSelection: false)
                suggestionsTable.scrollRowToVisible(selectedSuggestionIndex)
                return true
            } else if selectedSuggestionIndex == 0 {
                // Deselect when going above first item
                selectedSuggestionIndex = -1
                suggestionsTable.deselectAll(nil)
                return true
            }
        } else if commandSelector == #selector(insertNewline(_:)) {
            // Enter - select current suggestion or commit text
            if selectedSuggestionIndex >= 0 && selectedSuggestionIndex < filteredTags.count {
                selectSuggestion(at: selectedSuggestionIndex)
            }
            // Let the alert handle the actual submission
            return false
        } else if commandSelector == #selector(cancelOperation(_:)) {
            // Escape - hide suggestions
            if !suggestionsContainer.isHidden {
                hideSuggestions()
                return true
            }
        }
        return false
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredTags.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("TagSuggestionCell")
        
        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = identifier
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.textColor = DesignColors.textPrimary
            textField.lineBreakMode = .byTruncatingTail
            cellView?.addSubview(textField)
            cellView?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
            ])
        }
        
        cellView?.textField?.stringValue = filteredTags[row]
        
        // Highlight the matching portion
        let tag = filteredTags[row]
        let query = textField.stringValue.lowercased()
        if !query.isEmpty, let range = tag.lowercased().range(of: query) {
            let attrString = NSMutableAttributedString(string: tag)
            let nsRange = NSRange(range, in: tag)
            attrString.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: nsRange)
            cellView?.textField?.attributedStringValue = attrString
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedSuggestionIndex = suggestionsTable.selectedRow
    }
    
    @objc private func suggestionClicked() {
        let row = suggestionsTable.clickedRow
        if row >= 0 {
            selectSuggestion(at: row)
        }
    }
    
    @objc private func suggestionDoubleClicked() {
        let row = suggestionsTable.clickedRow
        if row >= 0 {
            selectSuggestion(at: row)
        }
    }
    
    // MARK: - First Responder
    
    override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    /// Make the text field first responder
    func focus() {
        window?.makeFirstResponder(textField)
    }
    
    // MARK: - Public Methods
    
    /// Reload the suggestions from the database
    func reloadTags() {
        allTags = (try? MetadataStore.shared.allCustomTags()) ?? []
        updateSuggestions()
    }
}
