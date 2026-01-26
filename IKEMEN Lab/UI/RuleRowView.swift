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
    private var tagInputView: TagInputView?
    private var deleteButton: NSButton!
    
    // MARK: - Colors (from DesignColors)
    
    private var inputBgColor: NSColor { DesignColors.inputBackground }
    private var inputBorderColor: NSColor { DesignColors.borderHover }
    private var textPrimary: NSColor { DesignColors.textPrimary }
    private var textSecondary: NSColor { DesignColors.textSecondary }
    private var textMuted: NSColor { DesignColors.textTertiary }
    private var deleteHoverColor: NSColor { DesignColors.negative }
    
    // MARK: - Field Options (from HTML)
    
    private let fieldOptions: [(title: String, field: FilterField)] = [
        ("Name", .name),
        ("Author", .author),
        ("Tags", .tag),
        ("Date Added", .installedAt),
        ("Source Game", .sourceGame),
        ("Is HD", .isHD),
        ("Has AI", .hasAI),
        ("Style", .style),
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
        case .name, .author, .sourceGame, .style:
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
            comparisons = [
                ("is", .equals),
                ("is not", .notEquals),
            ]
        case .totalWidth:
            comparisons = [
                ("equals", .equals),
                ("greater than", .greaterThan),
                ("less than", .lessThan),
            ]
        case .hasMusic, .resolution:
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
        tagInputView?.removeFromSuperview()
        tagInputView = nil
        
        switch field {
        case .tag:
            // Tag input with chips
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
            // Boolean popup (true/false)
            let popup = createPopup(width: 100)
            popup.addItems(withTitles: ["Yes", "No"])
            popup.translatesAutoresizingMaskIntoConstraints = false
            popup.target = self
            popup.action = #selector(valueChanged)
            valueContainer.addSubview(popup)
            valuePopup = popup
            
            NSLayoutConstraint.activate([
                popup.leadingAnchor.constraint(equalTo: valueContainer.leadingAnchor),
                popup.trailingAnchor.constraint(equalTo: valueContainer.trailingAnchor),
                popup.topAnchor.constraint(equalTo: valueContainer.topAnchor),
                popup.bottomAnchor.constraint(equalTo: valueContainer.bottomAnchor),
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
            
        default:
            // Standard text input
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
    
    private func createTextField() -> NSTextField {
        let textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = DesignFonts.label(size: 11)
        textField.textColor = textPrimary
        textField.backgroundColor = inputBgColor
        textField.drawsBackground = true
        textField.isBezeled = false
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 4
        textField.layer?.borderWidth = 1
        textField.layer?.borderColor = inputBorderColor.cgColor
        textField.focusRingType = .none
        textField.target = self
        textField.action = #selector(valueChanged)
        
        // Add padding by using a custom cell
        let cell = NSTextFieldCell()
        cell.wraps = false
        cell.isScrollable = true
        
        return textField
    }
    
    private func placeholderForField(_ field: FilterField) -> String {
        switch field {
        case .name: return "Character name..."
        case .author: return "Author name..."
        case .sourceGame: return "Street Fighter, Marvel..."
        case .style: return "POTS, MvC2..."
        case .tag: return "Type to add tag..."
        default: return ""
        }
    }
    
    private func setValueInputValue(_ value: String) {
        if let textField = valueTextField {
            textField.stringValue = value
        } else if let popup = valuePopup {
            // For boolean fields
            popup.selectItem(at: value.lowercased() == "true" ? 0 : 1)
        } else if let tagInput = tagInputView {
            // For tag fields
            let tags = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            tagInput.setTags(tags)
        }
    }
    
    private func getCurrentValue() -> String {
        if let textField = valueTextField {
            return textField.stringValue
        } else if let popup = valuePopup {
            return popup.indexOfSelectedItem == 0 ? "true" : "false"
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
