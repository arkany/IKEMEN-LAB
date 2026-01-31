import AppKit

// MARK: - RuleRowViewDelegate

protocol RuleRowViewDelegate: AnyObject {
    func ruleRowViewDidChange(_ ruleRow: RuleRowView)
    func ruleRowViewDidRequestDelete(_ ruleRow: RuleRowView)
}

// MARK: - RuleRowView

/// A single rule row in the Smart Collection sheet
/// Layout: [Field ▼] [Comparison ▼] [Value Input] [Delete]
class RuleRowView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: RuleRowViewDelegate?
    private(set) var currentRule: FilterRule
    
    // MARK: - UI Components
    
    private var fieldPopup: NSPopUpButton!
    private var comparisonPopup: NSPopUpButton!
    private var valueContainer: NSView!
    private var valueTextField: NSTextField?
    private var valuePopup: NSPopUpButton?
    private var valueComboBox: NSComboBox?
    private var valueSwitch: NSSwitch?
    private var tagInputView: TagInputView?
    private var deleteButton: NSButton!
    
    // MARK: - Colors (from DesignColors)
    
    private var inputBgColor: NSColor { DesignColors.inputBackground }
    private var inputBorderColor: NSColor { DesignColors.borderHover }
    private var textPrimary: NSColor { DesignColors.textPrimary }
    private var textSecondary: NSColor { DesignColors.textSecondary }
    private var textMuted: NSColor { DesignColors.textTertiary }
    private var deleteHoverColor: NSColor { DesignColors.negative }
    
    // MARK: - Field Options
    
    private let fieldOptions: [(title: String, field: FilterField)] = [
        ("Name", .name),
        ("Author", .author),
        ("Tags", .tag),
        ("Date Added", .installedAt),
        ("Is HD", .isHD),
        ("Has AI", .hasAI),
    ]
    
    // MARK: - Initialization
    
    init(rule: FilterRule) {
        self.currentRule = rule
        super.init(frame: .zero)
        setupUI()
        configureForRule(rule)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        wantsLayer = true
        
        // Field popup (128px width from HTML)
        fieldPopup = createPopup(width: 128)
        for option in fieldOptions {
            fieldPopup.addItem(withTitle: option.title)
        }
        fieldPopup.target = self
        fieldPopup.action = #selector(fieldChanged)
        addSubview(fieldPopup)
        
        // Comparison popup (128px width from HTML)
        comparisonPopup = createPopup(width: 128)
        comparisonPopup.target = self
        comparisonPopup.action = #selector(comparisonChanged)
        addSubview(comparisonPopup)
        
        // Value container (flexible width)
        valueContainer = NSView()
        valueContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(valueContainer)
        
        // Delete button (appears on hover)
        deleteButton = NSButton()
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.bezelStyle = .regularSquare
        deleteButton.isBordered = false
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
        deleteButton.contentTintColor = textMuted
        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)
        deleteButton.alphaValue = 0  // Hidden by default, shown on hover
        deleteButton.wantsLayer = true
        deleteButton.layer?.cornerRadius = 4
        addSubview(deleteButton)
        
        // Set up tracking for hover effect
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        
        NSLayoutConstraint.activate([
            fieldPopup.leadingAnchor.constraint(equalTo: leadingAnchor),
            fieldPopup.centerYAnchor.constraint(equalTo: centerYAnchor),
            fieldPopup.widthAnchor.constraint(equalToConstant: 128),
            fieldPopup.heightAnchor.constraint(equalToConstant: 28),
            
            comparisonPopup.leadingAnchor.constraint(equalTo: fieldPopup.trailingAnchor, constant: 8),
            comparisonPopup.centerYAnchor.constraint(equalTo: centerYAnchor),
            comparisonPopup.widthAnchor.constraint(equalToConstant: 128),
            comparisonPopup.heightAnchor.constraint(equalToConstant: 28),
            
            valueContainer.leadingAnchor.constraint(equalTo: comparisonPopup.trailingAnchor, constant: 8),
            valueContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueContainer.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            valueContainer.heightAnchor.constraint(equalToConstant: 28),
            
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            deleteButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 32),
            deleteButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
    
    private func createPopup(width: CGFloat) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.font = DesignFonts.label(size: 11)
        popup.bezelStyle = .roundedDisclosure
        popup.isBordered = false
        popup.wantsLayer = true
        popup.layer?.backgroundColor = inputBgColor.cgColor
        popup.layer?.cornerRadius = 4
        popup.layer?.borderWidth = 1
        popup.layer?.borderColor = inputBorderColor.cgColor
        return popup
    }
    
    private func configureForRule(_ rule: FilterRule) {
        // Set field selection
        if let index = fieldOptions.firstIndex(where: { $0.field == rule.field }) {
            fieldPopup.selectItem(at: index)
        }
        
        // Update comparisons for selected field
        updateComparisonsForField(rule.field)
        
        // Set comparison selection
        selectComparison(rule.comparison)
        
        // Update value input for field type
        updateValueInputForField(rule.field)
        
        // Set value
        setValueInputValue(rule.value)
    }
    
    // MARK: - Dynamic UI Updates
    
    private func updateComparisonsForField(_ field: FilterField) {
        comparisonPopup.removeAllItems()
        
        let comparisons: [(title: String, op: ComparisonOperator)]
        
        switch field {
        case .name, .author:
            comparisons = [
                ("is", .equals),
                ("is not", .notEquals),
                ("contains", .contains),
                ("starts with", .contains),  // We'll handle "starts with" as contains for now
            ]
        case .tag:
            comparisons = [
                ("contains", .contains),
                ("does not contain", .notContains),
                ("is empty", .isEmpty),
                ("is not empty", .isNotEmpty),
            ]
        case .installedAt:
            comparisons = [
                ("within last", .withinDays),
                ("before", .lessThan),
                ("after", .greaterThan),
            ]
        case .isHD, .hasAI:
            // Simplified: no comparison needed, just true/false
            comparisons = [
                ("is", .equals),
            ]
        case .totalWidth:
            comparisons = [
                ("equals", .equals),
                ("greater than", .greaterThan),
                ("less than", .lessThan),
            ]
        case .hasMusic, .resolution, .sourceGame, .style:
            // sourceGame and style are not currently populated
            comparisons = [
                ("is", .equals),
                ("is not", .notEquals),
            ]
        }
        
        for comp in comparisons {
            comparisonPopup.addItem(withTitle: comp.title)
            comparisonPopup.lastItem?.representedObject = comp.op
        }
    }
    
    private func selectComparison(_ comparison: ComparisonOperator) {
        for i in 0..<comparisonPopup.numberOfItems {
            if let op = comparisonPopup.item(at: i)?.representedObject as? ComparisonOperator,
               op == comparison {
                comparisonPopup.selectItem(at: i)
                return
            }
        }
        comparisonPopup.selectItem(at: 0)
    }
    
    private func updateValueInputForField(_ field: FilterField) {
        // Remove existing value input
        valueTextField?.removeFromSuperview()
        valueTextField = nil
        valuePopup?.removeFromSuperview()
        valuePopup = nil
        valueComboBox?.removeFromSuperview()
        valueComboBox = nil
        valueSwitch?.removeFromSuperview()
        valueSwitch = nil
        tagInputView?.removeFromSuperview()
        tagInputView = nil
        
        // Show comparison popup by default (hidden for boolean fields)
        comparisonPopup.isHidden = false
        
        switch field {
        case .tag:
            // Tag input with chips for multiple tags
            let tagInput = TagInputView()
            tagInput.translatesAutoresizingMaskIntoConstraints = false
            tagInput.delegate = self
            valueContainer.addSubview(tagInput)
            tagInputView = tagInput
            
            NSLayoutConstraint.activate([
                tagInput.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor),
                tagInput.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor),
                tagInput.topAnchor.constraint(equalTo: valueContainer.topAnchor),
                tagInput.bottomAnchor.constraint(equalTo: valueContainer.bottomAnchor),
            ])
            
        case .isHD, .hasAI:
            // Simplified boolean - hide comparison popup, show toggle switch
            comparisonPopup.isHidden = true
            
            let toggle = NSSwitch()
            toggle.translatesAutoresizingMaskIntoConstraints = false
            toggle.target = self
            toggle.action = #selector(valueChanged)
            toggle.state = .on  // Default to "yes"
            
            // Apply appearance filter to change the accent color
            toggle.wantsLayer = true
            if let filter = CIFilter(name: "CIColorMonochrome") {
                filter.setValue(CIColor(color: NSColor.white), forKey: "inputColor")
                filter.setValue(1.0, forKey: "inputIntensity")
                toggle.layer?.filters = [filter]
            }
            
            valueContainer.addSubview(toggle)
            valueSwitch = toggle
            
            // Float the toggle to the right (near the delete button)
            NSLayoutConstraint.activate([
                toggle.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor),
                toggle.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
            ])
            
        case .installedAt:
            // Days input
            let textField = createTextField()
            textField.placeholderString = "7"
            valueContainer.addSubview(textField)
            valueTextField = textField
            
            let daysLabel = NSTextField(labelWithString: "days")
            daysLabel.translatesAutoresizingMaskIntoConstraints = false
            daysLabel.font = DesignFonts.label(size: 11)
            daysLabel.textColor = textSecondary
            valueContainer.addSubview(daysLabel)
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor),
                textField.widthAnchor.constraint(equalToConstant: 60),
                textField.topAnchor.constraint(equalTo: valueContainer.topAnchor),
                textField.bottomAnchor.constraint(equalTo: valueContainer.bottomAnchor),
                
                daysLabel.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 8),
                daysLabel.centerYAnchor.constraint(equalTo: valueContainer.centerYAnchor),
            ])
            
        case .author:
            // Autocomplete combo box with suggestions from database
            let comboBox = createComboBox()
            comboBox.placeholderString = placeholderForField(field)
            comboBox.completes = true  // Enable autocomplete
            comboBox.delegate = self
            
            // Load suggestions from database
            loadSuggestionsForComboBox(comboBox, field: field)
            
            valueContainer.addSubview(comboBox)
            valueComboBox = comboBox
            
            NSLayoutConstraint.activate([
                comboBox.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor),
                comboBox.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor),
                comboBox.topAnchor.constraint(equalTo: valueContainer.topAnchor),
                comboBox.bottomAnchor.constraint(equalTo: valueContainer.bottomAnchor),
            ])
            
        default:
            // Standard text input (name, etc.)
            let textField = createTextField()
            textField.placeholderString = placeholderForField(field)
            valueContainer.addSubview(textField)
            valueTextField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor),
                textField.topAnchor.constraint(equalTo: valueContainer.topAnchor),
                textField.bottomAnchor.constraint(equalTo: valueContainer.bottomAnchor),
            ])
        }
    }
    
    private func loadSuggestionsForComboBox(_ comboBox: NSComboBox, field: FilterField) {
        var suggestions: [String] = []
        
        do {
            switch field {
            case .author:
                suggestions = try MetadataStore.shared.distinctAuthors()
            default:
                break
            }
        } catch {
            print("Failed to load suggestions for \(field): \(error)")
        }
        
        comboBox.removeAllItems()
        comboBox.addItems(withObjectValues: suggestions)
    }
    
    private func createTextField() -> NSTextField {
        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = DesignFonts.label(size: 11)
        textField.textColor = textPrimary
        textField.backgroundColor = inputBgColor
        textField.drawsBackground = true
        textField.isBezeled = false
        textField.isEditable = true
        textField.isSelectable = true
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 4
        textField.layer?.borderWidth = 1
        textField.layer?.borderColor = inputBorderColor.cgColor
        textField.focusRingType = .none
        textField.target = self
        textField.action = #selector(valueChanged)
        
        // Use custom cell for vertical centering and padding
        let cell = PaddedTextFieldCell(textCell: "")
        cell.font = textField.font
        cell.textColor = textField.textColor
        cell.drawsBackground = false
        cell.wraps = false
        cell.isScrollable = true
        cell.usesSingleLineMode = true
        cell.isEditable = true
        textField.cell = cell
        
        return textField
    }
    
    private func createComboBox() -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.translatesAutoresizingMaskIntoConstraints = false
        comboBox.font = DesignFonts.label(size: 11)
        comboBox.textColor = textPrimary
        comboBox.drawsBackground = false
        comboBox.isBezeled = false
        comboBox.isBordered = false
        comboBox.wantsLayer = true
        comboBox.layer?.backgroundColor = inputBgColor.cgColor
        comboBox.layer?.cornerRadius = 4
        comboBox.layer?.borderWidth = 1
        comboBox.layer?.borderColor = inputBorderColor.cgColor
        comboBox.focusRingType = .none
        comboBox.target = self
        comboBox.action = #selector(valueChanged)
        comboBox.usesDataSource = false
        comboBox.hasVerticalScroller = true
        comboBox.numberOfVisibleItems = 8
        comboBox.isButtonBordered = false
        comboBox.isEditable = true
        comboBox.isSelectable = true
        
        // Style the cell for padding
        if let cell = comboBox.cell as? NSComboBoxCell {
            cell.drawsBackground = false
        }
        
        return comboBox
    }
    
    private func placeholderForField(_ field: FilterField) -> String {
        switch field {
        case .name: return "Character name..."
        case .author: return "Author name..."
        case .tag: return "Type to add tag..."
        default: return ""
        }
    }
    
    private func setValueInputValue(_ value: String) {
        if let textField = valueTextField {
            textField.stringValue = value
        } else if let popup = valuePopup {
            // For boolean fields (legacy)
            popup.selectItem(at: value.lowercased() == "true" ? 0 : 1)
        } else if let toggle = valueSwitch {
            // For boolean toggle
            toggle.state = value.lowercased() == "true" ? .on : .off
        } else if let comboBox = valueComboBox {
            comboBox.stringValue = value
        } else if let tagInput = tagInputView {
            // For tag fields - value is comma-separated
            let tags = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            tagInput.setTags(tags)
        }
    }
    
    private func getCurrentValue() -> String {
        if let textField = valueTextField {
            return textField.stringValue
        } else if let popup = valuePopup {
            return popup.indexOfSelectedItem == 0 ? "true" : "false"
        } else if let toggle = valueSwitch {
            return toggle.state == .on ? "true" : "false"
        } else if let comboBox = valueComboBox {
            return comboBox.stringValue
        } else if let tagInput = tagInputView {
            return tagInput.tags.joined(separator: ",")
        }
        return ""
    }
    
    private func getCurrentComparison() -> ComparisonOperator {
        if let op = comparisonPopup.selectedItem?.representedObject as? ComparisonOperator {
            return op
        }
        return .contains
    }
    
    private func getCurrentField() -> FilterField {
        let index = fieldPopup.indexOfSelectedItem
        if index >= 0 && index < fieldOptions.count {
            return fieldOptions[index].field
        }
        return .name
    }
    
    // MARK: - Actions
    
    @objc private func fieldChanged() {
        let field = getCurrentField()
        updateComparisonsForField(field)
        updateValueInputForField(field)
        updateCurrentRule()
        delegate?.ruleRowViewDidChange(self)
    }
    
    @objc private func comparisonChanged() {
        updateCurrentRule()
        delegate?.ruleRowViewDidChange(self)
    }
    
    @objc private func valueChanged() {
        updateCurrentRule()
        delegate?.ruleRowViewDidChange(self)
    }
    
    @objc private func deleteTapped() {
        delegate?.ruleRowViewDidRequestDelete(self)
    }
    
    private func updateCurrentRule() {
        currentRule = FilterRule(
            id: currentRule.id,
            field: getCurrentField(),
            comparison: getCurrentComparison(),
            value: getCurrentValue()
        )
    }
    
    // MARK: - Hover Effect
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            deleteButton.animator().alphaValue = 1
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            deleteButton.animator().alphaValue = 0
        }
    }
}

// MARK: - TagInputViewDelegate

extension RuleRowView: TagInputViewDelegate {
    func tagInputViewDidChange(_ tagInput: TagInputView) {
        updateCurrentRule()
        delegate?.ruleRowViewDidChange(self)
    }
}

// MARK: - NSComboBoxDelegate

extension RuleRowView: NSComboBoxDelegate {
    func comboBoxSelectionDidChange(_ notification: Notification) {
        updateCurrentRule()
        delegate?.ruleRowViewDidChange(self)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        // Handle text changes in combo box for live filtering
        updateCurrentRule()
        delegate?.ruleRowViewDidChange(self)
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        updateCurrentRule()
        delegate?.ruleRowViewDidChange(self)
    }
}

// MARK: - Vertically Centered Text Field Cell

/// Text field cell that centers text vertically and adds horizontal padding
private class PaddedTextFieldCell: NSTextFieldCell {
    private let horizontalPadding: CGFloat = 8
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var newRect = super.drawingRect(forBounds: rect)
        
        // Add horizontal padding
        newRect.origin.x += horizontalPadding
        newRect.size.width -= horizontalPadding * 2
        
        // Center vertically
        let textSize = attributedStringValue.size()
        let heightDelta = newRect.height - textSize.height
        if heightDelta > 0 {
            newRect.origin.y += heightDelta / 2
            newRect.size.height -= heightDelta
        }
        
        return newRect
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: drawingRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }
}
