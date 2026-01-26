import AppKit

// MARK: - TagInputViewDelegate

protocol TagInputViewDelegate: AnyObject {
    func tagInputViewDidChange(_ tagInput: TagInputView)
}

// MARK: - TagInputView

/// Tag input with chips display (matches HTML reference)
/// Shows tags as removable chips with a text input for adding new ones
class TagInputView: NSView, NSTextFieldDelegate {
    
    // MARK: - Properties
    
    weak var delegate: TagInputViewDelegate?
    private(set) var tags: [String] = []
    
    // MARK: - UI Components
    
    private var containerView: NSView!
    private var stackView: NSStackView!
    private var inputField: NSTextField!
    
    // MARK: - Colors (from DesignColors)
    
    private var bgColor: NSColor { DesignColors.inputBackground }
    private var borderColor: NSColor { DesignColors.borderHover }
    private var chipBgColor: NSColor { DesignColors.zinc800 }
    private var chipBorderColor: NSColor { DesignColors.borderSubtle }
    private var chipTextColor: NSColor { DesignColors.textSecondary }
    private var textPrimary: NSColor { DesignColors.textPrimary }
    private var textMuted: NSColor { DesignColors.textTertiary }
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
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
        stackView.addArrangedSubview(inputField)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            inputField.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])
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
            // Enter pressed - add tag
            let text = inputField.stringValue
            addTag(text)
            inputField.stringValue = ""
            return true
        } else if commandSelector == #selector(deleteBackward(_:)) {
            // Backspace with empty field - remove last tag
            if inputField.stringValue.isEmpty && !tags.isEmpty {
                removeTag(tags.last!)
                return true
            }
        }
        return false
    }
}

// MARK: - TagChipView

/// A single tag chip with remove button
private class TagChipView: NSView {
    
    let tagName: String
    var onRemove: ((String) -> Void)?
    
    private var bgColor: NSColor { DesignColors.zinc800 }
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
