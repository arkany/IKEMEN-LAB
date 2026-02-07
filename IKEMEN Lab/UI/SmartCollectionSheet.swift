import AppKit

// MARK: - SmartCollectionSheet

/// Modal sheet for creating/editing smart collections
/// Design matches smart-tag-modal.html reference, using DesignColors/DesignFonts
class SmartCollectionSheet: NSViewController {
    
    // MARK: - Properties
    
    private var collection: Collection?
    private var rules: [FilterRule] = []
    private var ruleOperator: RuleOperator = .all
    private var isEditMode: Bool { collection != nil }
    
    weak var delegate: SmartCollectionSheetDelegate?
    
    // MARK: - UI Components
    
    private var containerView: NSView!
    private var headerView: NSView!
    private var bodyScrollView: NSScrollView!
    private var bodyContentView: NSView!
    private var footerView: NSView!
    
    private var nameTextField: NSTextField!
    private var nameTextFieldWrapper: NSView!
    private var nameErrorLabel: NSTextField!
    private var matchPopup: NSPopUpButton!
    private var rulesStackView: NSStackView!
    private var matchCountLabel: NSTextField!
    private var createButton: NSButton!
    private var addConditionButton: NSButton!
    
    private var ruleRowViews: [RuleRowView] = []
    
    // MARK: - Initialization
    
    init(collection: Collection? = nil) {
        self.collection = collection
        if let collection = collection, collection.isSmartCollection {
            self.rules = collection.smartRules ?? []
            self.ruleOperator = collection.smartRuleOperator ?? .all
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 500))
        view.wantsLayer = true
        view.layer?.backgroundColor = DesignColors.background.cgColor
        view.layer?.cornerRadius = 12
        view.layer?.borderWidth = 1
        view.layer?.borderColor = DesignColors.borderHover.cgColor
        
        setupHeader()
        setupBody()
        setupFooter()
        
        // Add initial rule if empty
        if rules.isEmpty {
            addRule()
        } else {
            // Populate existing rules
            for rule in rules {
                addRuleRow(with: rule)
            }
        }
        
        updateMatchCount()
        
        // Focus on name field after a brief delay to allow view to be added to window
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.makeFirstResponder(self?.nameTextField)
        }
    }
    
    // MARK: - Setup
    
    private func setupHeader() {
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        view.addSubview(headerView)
        
        // Header border (bottom)
        let headerBorder = NSView()
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBorder.wantsLayer = true
        headerBorder.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        headerView.addSubview(headerBorder)
        
        // Icon container
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        headerView.addSubview(iconContainer)
        
        // Magic wand icon (using SF Symbol)
        let iconImage = NSImageView()
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconImage.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)
        iconImage.contentTintColor = DesignColors.textSecondary
        iconImage.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        iconContainer.addSubview(iconImage)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Smart Collection")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.body(size: 15)
        titleLabel.textColor = DesignColors.textPrimary
        headerView.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Automatically organize assets based on rules.")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = DesignFonts.label(size: 11)
        subtitleLabel.textColor = DesignColors.textTertiary
        headerView.addSubview(subtitleLabel)
        
        // Close button
        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Close")
        closeButton.contentTintColor = DesignColors.textTertiary
        closeButton.target = self
        closeButton.action = #selector(cancelTapped)
        closeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        headerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 72),
            
            headerBorder.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            headerBorder.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerBorder.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerBorder.heightAnchor.constraint(equalToConstant: 1),
            
            iconContainer.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24),
            iconContainer.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            
            iconImage.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 2),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    private func setupBody() {
        bodyScrollView = NSScrollView()
        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.hasHorizontalScroller = false
        bodyScrollView.drawsBackground = false
        bodyScrollView.borderType = .noBorder
        view.addSubview(bodyScrollView)
        
        // Use flipped view for top-aligned content
        bodyContentView = FlippedContentView()
        bodyContentView.translatesAutoresizingMaskIntoConstraints = false
        bodyScrollView.documentView = bodyContentView
        
        // Collection Name label
        let nameLabel = NSTextField(labelWithString: "Collection Name")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.label(size: 11)
        nameLabel.textColor = DesignColors.textSecondary
        bodyContentView.addSubview(nameLabel)
        
        // Name input wrapper (for padding)
        nameTextFieldWrapper = NSView()
        nameTextFieldWrapper.translatesAutoresizingMaskIntoConstraints = false
        nameTextFieldWrapper.wantsLayer = true
        nameTextFieldWrapper.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        nameTextFieldWrapper.layer?.cornerRadius = 8
        nameTextFieldWrapper.layer?.borderWidth = 1
        nameTextFieldWrapper.layer?.borderColor = DesignColors.borderHover.cgColor
        bodyContentView.addSubview(nameTextFieldWrapper)
        
        nameTextField = NSTextField()
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.font = DesignFonts.label(size: 13)
        nameTextField.textColor = DesignColors.textPrimary
        nameTextField.backgroundColor = .clear
        nameTextField.drawsBackground = false
        nameTextField.isBezeled = false
        nameTextField.focusRingType = .none
        nameTextField.placeholderString = "Enter collection name..."
        nameTextField.stringValue = collection?.name ?? ""
        nameTextField.delegate = self
        nameTextFieldWrapper.addSubview(nameTextField)
        
        // Error label (hidden by default)
        nameErrorLabel = NSTextField(labelWithString: "Collection name is required")
        nameErrorLabel.translatesAutoresizingMaskIntoConstraints = false
        nameErrorLabel.font = DesignFonts.label(size: 10)
        nameErrorLabel.textColor = DesignColors.negative
        nameErrorLabel.isHidden = true
        bodyContentView.addSubview(nameErrorLabel)
        
        // Match row: "Match [All/Any] of the following rules:"
        let matchLabel1 = NSTextField(labelWithString: "Match")
        matchLabel1.translatesAutoresizingMaskIntoConstraints = false
        matchLabel1.font = DesignFonts.label(size: 13)
        matchLabel1.textColor = DesignColors.textSecondary
        bodyContentView.addSubview(matchLabel1)
        
        matchPopup = NSPopUpButton()
        matchPopup.translatesAutoresizingMaskIntoConstraints = false
        matchPopup.addItems(withTitles: ["All", "Any"])
        matchPopup.selectItem(at: ruleOperator == .all ? 0 : 1)
        matchPopup.font = DesignFonts.label(size: 13)
        matchPopup.bezelStyle = .roundedDisclosure
        matchPopup.isBordered = false
        matchPopup.wantsLayer = true
        matchPopup.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        matchPopup.layer?.cornerRadius = 4
        matchPopup.layer?.borderWidth = 1
        matchPopup.layer?.borderColor = DesignColors.borderHover.cgColor
        matchPopup.target = self
        matchPopup.action = #selector(matchOperatorChanged)
        bodyContentView.addSubview(matchPopup)
        
        let matchLabel2 = NSTextField(labelWithString: "of the following rules:")
        matchLabel2.translatesAutoresizingMaskIntoConstraints = false
        matchLabel2.font = DesignFonts.label(size: 13)
        matchLabel2.textColor = DesignColors.textSecondary
        bodyContentView.addSubview(matchLabel2)
        
        // Rules stack
        rulesStackView = NSStackView()
        rulesStackView.translatesAutoresizingMaskIntoConstraints = false
        rulesStackView.orientation = .vertical
        rulesStackView.alignment = .leading
        rulesStackView.spacing = 8
        bodyContentView.addSubview(rulesStackView)
        
        // Add Condition button - use a clickable stack view for proper hit testing
        addConditionButton = NSButton()
        addConditionButton.translatesAutoresizingMaskIntoConstraints = false
        addConditionButton.title = ""
        addConditionButton.bezelStyle = .regularSquare
        addConditionButton.isBordered = false
        addConditionButton.target = self
        addConditionButton.action = #selector(addRuleTapped)
        addConditionButton.wantsLayer = true
        bodyContentView.addSubview(addConditionButton)
        
        let plusIcon = NSImageView()
        plusIcon.translatesAutoresizingMaskIntoConstraints = false
        plusIcon.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        plusIcon.contentTintColor = DesignColors.positive
        plusIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        addConditionButton.addSubview(plusIcon)
        
        let addLabel = NSTextField(labelWithString: "Add Condition")
        addLabel.translatesAutoresizingMaskIntoConstraints = false
        addLabel.font = DesignFonts.label(size: 11)
        addLabel.textColor = DesignColors.positive
        addConditionButton.addSubview(addLabel)
        
        // Position icon and label within button
        NSLayoutConstraint.activate([
            plusIcon.leadingAnchor.constraint(equalTo: addConditionButton.leadingAnchor),
            plusIcon.centerYAnchor.constraint(equalTo: addConditionButton.centerYAnchor),
            addLabel.leadingAnchor.constraint(equalTo: plusIcon.trailingAnchor, constant: 6),
            addLabel.centerYAnchor.constraint(equalTo: addConditionButton.centerYAnchor),
            addLabel.trailingAnchor.constraint(equalTo: addConditionButton.trailingAnchor),
        ])
        
        NSLayoutConstraint.activate([
            bodyScrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            bodyScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bodyScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bodyScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -72),
            
            bodyContentView.topAnchor.constraint(equalTo: bodyScrollView.contentView.topAnchor),
            bodyContentView.leadingAnchor.constraint(equalTo: bodyScrollView.contentView.leadingAnchor),
            bodyContentView.trailingAnchor.constraint(equalTo: bodyScrollView.contentView.trailingAnchor),
            bodyContentView.widthAnchor.constraint(equalTo: bodyScrollView.widthAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: bodyContentView.topAnchor, constant: 24),
            nameLabel.leadingAnchor.constraint(equalTo: bodyContentView.leadingAnchor, constant: 24),
            
            nameTextFieldWrapper.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            nameTextFieldWrapper.leadingAnchor.constraint(equalTo: bodyContentView.leadingAnchor, constant: 24),
            nameTextFieldWrapper.trailingAnchor.constraint(equalTo: bodyContentView.trailingAnchor, constant: -24),
            nameTextFieldWrapper.heightAnchor.constraint(equalToConstant: 36),
            
            nameTextField.leadingAnchor.constraint(equalTo: nameTextFieldWrapper.leadingAnchor, constant: 12),
            nameTextField.trailingAnchor.constraint(equalTo: nameTextFieldWrapper.trailingAnchor, constant: -12),
            nameTextField.centerYAnchor.constraint(equalTo: nameTextFieldWrapper.centerYAnchor),
            
            nameErrorLabel.topAnchor.constraint(equalTo: nameTextFieldWrapper.bottomAnchor, constant: 4),
            nameErrorLabel.leadingAnchor.constraint(equalTo: nameTextFieldWrapper.leadingAnchor),
            
            matchLabel1.topAnchor.constraint(equalTo: nameTextFieldWrapper.bottomAnchor, constant: 24),
            matchLabel1.leadingAnchor.constraint(equalTo: bodyContentView.leadingAnchor, constant: 24),
            
            matchPopup.centerYAnchor.constraint(equalTo: matchLabel1.centerYAnchor),
            matchPopup.leadingAnchor.constraint(equalTo: matchLabel1.trailingAnchor, constant: 12),
            matchPopup.widthAnchor.constraint(equalToConstant: 60),
            
            matchLabel2.centerYAnchor.constraint(equalTo: matchLabel1.centerYAnchor),
            matchLabel2.leadingAnchor.constraint(equalTo: matchPopup.trailingAnchor, constant: 12),
            
            rulesStackView.topAnchor.constraint(equalTo: matchLabel1.bottomAnchor, constant: 16),
            rulesStackView.leadingAnchor.constraint(equalTo: bodyContentView.leadingAnchor, constant: 24),
            rulesStackView.trailingAnchor.constraint(equalTo: bodyContentView.trailingAnchor, constant: -24),
            
            addConditionButton.topAnchor.constraint(equalTo: rulesStackView.bottomAnchor, constant: 12),
            addConditionButton.leadingAnchor.constraint(equalTo: bodyContentView.leadingAnchor, constant: 24),
            addConditionButton.heightAnchor.constraint(equalToConstant: 24),
            addConditionButton.bottomAnchor.constraint(equalTo: bodyContentView.bottomAnchor, constant: -24),
        ])
    }
    
    private func setupFooter() {
        footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = DesignColors.panelBackground.withAlphaComponent(0.5).cgColor
        view.addSubview(footerView)
        
        // Top border
        let footerBorder = NSView()
        footerBorder.translatesAutoresizingMaskIntoConstraints = false
        footerBorder.wantsLayer = true
        footerBorder.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        footerView.addSubview(footerBorder)
        
        // Match count label
        matchCountLabel = NSTextField(labelWithString: "0 items match these rules")
        matchCountLabel.translatesAutoresizingMaskIntoConstraints = false
        matchCountLabel.font = DesignFonts.label(size: 11)
        matchCountLabel.textColor = DesignColors.textTertiary
        footerView.addSubview(matchCountLabel)
        
        // Cancel button
        let cancelButton = NSButton()
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .regularSquare
        cancelButton.isBordered = false
        cancelButton.font = DesignFonts.body(size: 13)
        cancelButton.contentTintColor = DesignColors.textSecondary
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        footerView.addSubview(cancelButton)
        
        // Create button
        createButton = NSButton()
        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.title = isEditMode ? "Save Changes" : "Create Collection"
        createButton.bezelStyle = .regularSquare
        createButton.isBordered = false
        createButton.font = DesignFonts.body(size: 13)
        createButton.wantsLayer = true
        createButton.layer?.backgroundColor = DesignColors.buttonPrimary.cgColor
        createButton.layer?.cornerRadius = 8
        createButton.contentTintColor = DesignColors.buttonPrimaryText
        createButton.target = self
        createButton.action = #selector(createTapped)
        footerView.addSubview(createButton)
        
        // Add shadow to create button
        createButton.layer?.shadowColor = DesignColors.buttonPrimary.withAlphaComponent(0.1).cgColor
        createButton.layer?.shadowOffset = CGSize(width: 0, height: 2)
        createButton.layer?.shadowRadius = 8
        createButton.layer?.shadowOpacity = 1
        
        NSLayoutConstraint.activate([
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 72),
            
            footerBorder.topAnchor.constraint(equalTo: footerView.topAnchor),
            footerBorder.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            footerBorder.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            footerBorder.heightAnchor.constraint(equalToConstant: 1),
            
            matchCountLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            matchCountLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 24),
            
            createButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            createButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -24),
            createButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            createButton.heightAnchor.constraint(equalToConstant: 36),
            
            cancelButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: createButton.leadingAnchor, constant: -12),
        ])
    }
    
    // MARK: - Rule Management
    
    private func addRule() {
        let rule = FilterRule(field: .tag, comparison: .contains, value: "")
        rules.append(rule)
        addRuleRow(with: rule)
    }
    
    private func addRuleRow(with rule: FilterRule) {
        let ruleRow = RuleRowView(rule: rule)
        ruleRow.translatesAutoresizingMaskIntoConstraints = false
        ruleRow.delegate = self
        ruleRowViews.append(ruleRow)
        rulesStackView.addArrangedSubview(ruleRow)
        
        NSLayoutConstraint.activate([
            ruleRow.leadingAnchor.constraint(equalTo: rulesStackView.leadingAnchor),
            ruleRow.trailingAnchor.constraint(equalTo: rulesStackView.trailingAnchor),
            ruleRow.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
    
    private func removeRule(at index: Int) {
        guard index < ruleRowViews.count else { return }
        
        let rowView = ruleRowViews[index]
        rulesStackView.removeArrangedSubview(rowView)
        rowView.removeFromSuperview()
        ruleRowViews.remove(at: index)
        rules.remove(at: index)
        
        updateMatchCount()
    }
    
    private func updateMatchCount() {
        // Build collection with current rules to evaluate
        var testCollection = Collection(name: "Test")
        testCollection.isSmartCollection = true
        testCollection.smartRules = collectRulesFromUI()
        testCollection.smartRuleOperator = matchPopup.indexOfSelectedItem == 0 ? .all : .any
        testCollection.includeCharacters = true
        testCollection.includeStages = true
        
        let evaluator = SmartCollectionEvaluator()
        let result = evaluator.evaluate(testCollection)
        let total = result.characters.count + result.stages.count
        
        // Update label with bold count
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "\(total)", attributes: [
            .font: DesignFonts.body(size: 11),
            .foregroundColor: DesignColors.positive
        ]))
        text.append(NSAttributedString(string: " items match these rules", attributes: [
            .font: DesignFonts.label(size: 11),
            .foregroundColor: DesignColors.textTertiary
        ]))
        matchCountLabel.attributedStringValue = text
    }
    
    private func collectRulesFromUI() -> [FilterRule] {
        return ruleRowViews.map { $0.currentRule }
    }
    
    // MARK: - Actions
    
    @objc private func addRuleTapped() {
        addRule()
        updateMatchCount()
    }
    
    @objc private func matchOperatorChanged() {
        updateMatchCount()
    }
    
    @objc private func cancelTapped() {
        delegate?.smartCollectionSheetDidCancel(self)
    }
    
    @objc private func createTapped() {
        let name = nameTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            // Show error state
            showNameError()
            return
        }
        
        let finalRules = collectRulesFromUI()
        let finalOperator: RuleOperator = matchPopup.indexOfSelectedItem == 0 ? .all : .any
        
        if isEditMode, let existingCollection = collection {
            delegate?.smartCollectionSheet(self, didUpdateCollection: existingCollection.id, name: name, rules: finalRules, ruleOperator: finalOperator)
        } else {
            delegate?.smartCollectionSheet(self, didCreateCollectionNamed: name, rules: finalRules, ruleOperator: finalOperator)
        }
        
        dismiss(nil)
    }
    
    private func showNameError() {
        // Show error border
        nameTextFieldWrapper.layer?.borderColor = DesignColors.negative.cgColor
        nameTextFieldWrapper.layer?.borderWidth = 2
        
        // Show error label
        nameErrorLabel.isHidden = false
        
        // Focus on name field
        view.window?.makeFirstResponder(nameTextField)
        
        // Shake animation
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-8, 8, -6, 6, -4, 4, -2, 2, 0]
        nameTextFieldWrapper.layer?.add(animation, forKey: "shake")
    }
    
    private func hideNameError() {
        // Restore normal border
        nameTextFieldWrapper.layer?.borderColor = DesignColors.borderHover.cgColor
        nameTextFieldWrapper.layer?.borderWidth = 1
        
        // Hide error label
        nameErrorLabel.isHidden = true
    }
}

// MARK: - NSTextFieldDelegate

extension SmartCollectionSheet: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        // Clear error when user starts typing in name field
        if let textField = obj.object as? NSTextField, textField === nameTextField {
            if !nameErrorLabel.isHidden {
                hideNameError()
            }
        }
    }
}

// MARK: - RuleRowViewDelegate

extension SmartCollectionSheet: RuleRowViewDelegate {
    func ruleRowViewDidChange(_ ruleRow: RuleRowView) {
        updateMatchCount()
    }
    
    func ruleRowViewDidRequestDelete(_ ruleRow: RuleRowView) {
        guard let index = ruleRowViews.firstIndex(where: { $0 === ruleRow }) else { return }
        guard ruleRowViews.count > 1 else { return }
        removeRule(at: index)
    }
}

// MARK: - Delegate Protocol

protocol SmartCollectionSheetDelegate: AnyObject {
    func smartCollectionSheet(_ sheet: SmartCollectionSheet, didCreateCollectionNamed name: String, rules: [FilterRule], ruleOperator: RuleOperator)
    func smartCollectionSheet(_ sheet: SmartCollectionSheet, didUpdateCollection id: UUID, name: String, rules: [FilterRule], ruleOperator: RuleOperator)
    func smartCollectionSheetDidCancel(_ sheet: SmartCollectionSheet)
}

// MARK: - FlippedContentView

/// NSView subclass that uses flipped coordinates for top-aligned layout
private class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}
