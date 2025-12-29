import Cocoa

// MARK: - Custom Search Field

/// Custom styled search field matching the HTML design
/// bg-zinc-900/50, border-white/5, rounded-md, placeholder-zinc-700
/// Includes hover, focus, and disabled states
class StyledSearchField: NSView {
    
    var onTextChanged: ((String) -> Void)?
    
    private var textField: NSTextField!
    private var searchIcon: NSImageView!
    private var clearButton: NSButton!
    private var trackingArea: NSTrackingArea?
    
    // State tracking
    private var isHovered = false
    private var isFocused = false
    
    // Colors for different states - matches HTML: border-white/5, focus:border-zinc-700, bg-zinc-900/50, focus:bg-zinc-900
    private let normalBorderColor = NSColor.white.withAlphaComponent(0.05)  // border-white/5
    private let hoverBorderColor = NSColor.white.withAlphaComponent(0.10)   // hover:border-white/10
    private let focusBorderColor = NSColor(red: 0x3f/255.0, green: 0x3f/255.0, blue: 0x46/255.0, alpha: 1.0)  // focus:border-zinc-700 (#3f3f46)
    private let normalBgColor = NSColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x1b/255.0, alpha: 0.5)  // bg-zinc-900/50
    private let focusBgColor = NSColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x1b/255.0, alpha: 1.0)   // focus:bg-zinc-900 (100% opacity)
    
    var stringValue: String {
        get { textField.stringValue }
        set { 
            textField.stringValue = newValue
            clearButton.isHidden = newValue.isEmpty
        }
    }
    
    var isEnabled: Bool = true {
        didSet {
            textField.isEnabled = isEnabled
            updateAppearance()
        }
    }
    
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
        
        // Background: bg-zinc-900/50 (#18181b at 50% opacity)
        layer?.backgroundColor = normalBgColor.cgColor
        
        // Border: border-white/5
        layer?.borderColor = normalBorderColor.cgColor
        layer?.borderWidth = 1
        
        // Rounded: rounded-md (6px)
        layer?.cornerRadius = 6
        
        // Search icon (magnifying glass)
        searchIcon = NSImageView()
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = DesignColors.textTertiary // zinc-500
        searchIcon.imageScaling = .scaleProportionallyDown
        addSubview(searchIcon)
        
        // Text field
        textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = DesignFonts.caption(size: 12) // text-xs
        // Input text: text-zinc-300 (#d4d4d8) - brighter than secondary text
        textField.textColor = NSColor(red: 0xd4/255.0, green: 0xd4/255.0, blue: 0xd8/255.0, alpha: 1.0)
        textField.placeholderString = "Search assets..."
        textField.placeholderAttributedString = NSAttributedString(
            string: "Search assets...",
            attributes: [
                // Placeholder: text-zinc-700 (#3f3f46) per HTML spec
                .foregroundColor: NSColor(red: 0x3f/255.0, green: 0x3f/255.0, blue: 0x46/255.0, alpha: 1.0),
                .font: DesignFonts.caption(size: 12)
            ]
        )
        textField.delegate = self
        textField.target = self
        textField.action = #selector(textFieldAction(_:))
        addSubview(textField)
        
        // Clear button (x icon)
        clearButton = NSButton()
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.isBordered = false
        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear")
        clearButton.contentTintColor = DesignColors.textTertiary
        clearButton.target = self
        clearButton.action = #selector(clearClicked)
        clearButton.isHidden = true
        addSubview(clearButton)
        
        NSLayoutConstraint.activate([
            // Height: py-1.5 = 6px top + 6px bottom + ~20px text = ~32px
            heightAnchor.constraint(equalToConstant: 32),
            
            // Search icon: left-3 (12px from left), centered vertically
            searchIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            searchIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 14),
            searchIcon.heightAnchor.constraint(equalToConstant: 14),
            
            // Text field: pl-9 (36px from left after icon), pr-3 (12px from right)
            textField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Clear button: 12px from right
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 16),
            clearButton.heightAnchor.constraint(equalToConstant: 16),
        ])
        
        // Setup mouse tracking for hover state
        setupTrackingArea()
    }
    
    // MARK: - Tracking Area for Hover
    
    private func setupTrackingArea() {
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        setupTrackingArea()
    }
    
    // MARK: - Mouse Events
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }
    
    override func mouseDown(with event: NSEvent) {
        // Focus the text field when clicking anywhere in the search box
        window?.makeFirstResponder(textField)
    }
    
    // MARK: - Appearance Updates
    
    private func updateAppearance() {
        guard let layer = layer else { return }
        
        // Tailwind transition-all: 150ms cubic-bezier(0.4, 0, 0.2, 1)
        // Using CATransaction for smooth layer property animations
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)  // Tailwind's default ease
        )
        
        if !isEnabled {
            // Disabled state: dimmed
            layer.backgroundColor = normalBgColor.withAlphaComponent(0.3).cgColor
            layer.borderColor = normalBorderColor.withAlphaComponent(0.5).cgColor
            searchIcon.animator().alphaValue = 0.5
            textField.animator().alphaValue = 0.5
        } else if isFocused {
            // Focus state: focus:border-zinc-700, focus:bg-zinc-900 (100% opacity)
            layer.backgroundColor = focusBgColor.cgColor
            layer.borderColor = focusBorderColor.cgColor
            searchIcon.animator().alphaValue = 1.0
            textField.animator().alphaValue = 1.0
        } else if isHovered {
            // Hover state: border-white/10, slightly brighter bg
            layer.backgroundColor = normalBgColor.withAlphaComponent(0.6).cgColor
            layer.borderColor = hoverBorderColor.cgColor
            searchIcon.animator().alphaValue = 1.0
            textField.animator().alphaValue = 1.0
        } else {
            // Normal state: border-white/5, bg-zinc-900/50
            layer.backgroundColor = normalBgColor.cgColor
            layer.borderColor = normalBorderColor.cgColor
            searchIcon.animator().alphaValue = 1.0
            textField.animator().alphaValue = 1.0
        }
        
        CATransaction.commit()
    }
    
    @objc private func textFieldAction(_ sender: NSTextField) {
        clearButton.isHidden = sender.stringValue.isEmpty
        onTextChanged?(sender.stringValue)
    }
    
    @objc private func clearClicked() {
        textField.stringValue = ""
        clearButton.isHidden = true
        onTextChanged?("")
        window?.makeFirstResponder(textField)
    }
}

extension StyledSearchField: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        clearButton.isHidden = textField.stringValue.isEmpty
        onTextChanged?(textField.stringValue)
    }
    
    func controlTextDidBeginEditing(_ obj: Notification) {
        isFocused = true
        updateAppearance()
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        isFocused = false
        updateAppearance()
    }
}

// MARK: - Content Header View

/// Shared header view for content pages with breadcrumb navigation and search field
/// Design matches generated-page-3.html header section
class ContentHeaderView: NSView {
    
    // MARK: - Callbacks
    
    var onSearch: ((String) -> Void)?
    var onHomeClicked: (() -> Void)?
    
    // MARK: - Properties
    
    private var breadcrumbStack: NSStackView!
    private var searchField: StyledSearchField!
    private var homeLabel: NSTextField!
    private var chevronImage: NSImageView!
    private var currentPageLabel: NSTextField!
    
    // Search debounce
    private var searchDebounceTimer: Timer?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    // MARK: - Setup
    
    private func setup() {
        wantsLayer = true
        
        // Header background - matches HTML: bg-zinc-950/50 backdrop-blur-sm border-b border-white/5
        layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.5).cgColor
        
        // Border at bottom
        let borderLayer = CALayer()
        borderLayer.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: 10000, height: 1)
        layer?.addSublayer(borderLayer)
        
        setupBreadcrumb()
        setupSearchField()
        setupConstraints()
    }
    
    private func setupBreadcrumb() {
        // Breadcrumb container
        breadcrumbStack = NSStackView()
        breadcrumbStack.translatesAutoresizingMaskIntoConstraints = false
        breadcrumbStack.orientation = .horizontal
        breadcrumbStack.spacing = 8
        breadcrumbStack.alignment = .centerY
        addSubview(breadcrumbStack)
        
        // Home link - clickable
        homeLabel = NSTextField(labelWithString: "Home")
        homeLabel.font = DesignFonts.body(size: 13)
        homeLabel.textColor = DesignColors.textSecondary
        homeLabel.isSelectable = false
        
        // Make home clickable with hover effect
        let homeButton = NSButton(frame: .zero)
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        homeButton.isBordered = false
        homeButton.title = ""
        homeButton.target = self
        homeButton.action = #selector(homeClicked)
        homeLabel.addSubview(homeButton)
        
        // Track mouse for hover
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["view": "home"]
        )
        homeLabel.addTrackingArea(trackingArea)
        
        breadcrumbStack.addArrangedSubview(homeLabel)
        
        // Chevron separator
        chevronImage = NSImageView()
        chevronImage.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevronImage.contentTintColor = DesignColors.textSecondary
        chevronImage.imageScaling = .scaleProportionallyDown
        chevronImage.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            chevronImage.widthAnchor.constraint(equalToConstant: 12),
            chevronImage.heightAnchor.constraint(equalToConstant: 12)
        ])
        breadcrumbStack.addArrangedSubview(chevronImage)
        
        // Current page label
        currentPageLabel = NSTextField(labelWithString: "Dashboard")
        currentPageLabel.font = DesignFonts.body(size: 13)
        currentPageLabel.textColor = DesignColors.textPrimary
        currentPageLabel.isSelectable = false
        breadcrumbStack.addArrangedSubview(currentPageLabel)
    }
    
    private func setupSearchField() {
        // Custom styled search field matching HTML design
        searchField = StyledSearchField(frame: .zero)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.onTextChanged = { [weak self] text in
            self?.handleSearchTextChanged(text)
        }
        addSubview(searchField)
    }
    
    private func handleSearchTextChanged(_ text: String) {
        // Debounce search to avoid too many queries while typing
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            self?.onSearch?(text)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Breadcrumb on left
            breadcrumbStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            breadcrumbStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Search field on right - matches HTML: w-64 (256px)
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 256),
            
            // Fixed height - matches HTML: h-16 (64px)
            heightAnchor.constraint(equalToConstant: 64)
        ])
    }
    
    // MARK: - Public API
    
    /// Update the current page name shown in breadcrumb
    func setCurrentPage(_ pageName: String) {
        currentPageLabel.stringValue = pageName
    }
    
    /// Clear the search field
    func clearSearch() {
        searchField.stringValue = ""
    }
    
    /// Get current search text
    var searchText: String {
        searchField.stringValue
    }
    
    // MARK: - Actions
    
    @objc private func homeClicked() {
        onHomeClicked?()
    }
    
    // MARK: - Mouse Tracking
    
    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           userInfo["view"] == "home" {
            homeLabel.textColor = DesignColors.textPrimary
            NSCursor.pointingHand.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo as? [String: String],
           userInfo["view"] == "home" {
            homeLabel.textColor = DesignColors.textSecondary
            NSCursor.arrow.set()
        }
    }
}
