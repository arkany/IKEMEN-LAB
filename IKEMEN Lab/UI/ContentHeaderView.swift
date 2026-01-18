import Cocoa

// MARK: - View Mode Toggle

/// Icon-based grid/list view toggle matching stages-list view.html design
/// Two icon buttons: grid icon and list icon
/// Active state: text-white bg-white/5 rounded
/// Inactive state: text-zinc-600 hover:text-white
class ViewModeToggle: NSView {
    
    enum Mode {
        case grid
        case list
    }
    
    var onModeChanged: ((Mode) -> Void)?
    
    private(set) var currentMode: Mode = .grid {
        didSet {
            updateAppearance()
        }
    }
    
    private var gridButton: NSButton!
    private var listButton: NSButton!
    private var gridTrackingArea: NSTrackingArea?
    private var listTrackingArea: NSTrackingArea?
    private var isGridHovered = false
    private var isListHovered = false
    
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
        
        // Container for buttons with gap-2 (8px)
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        addSubview(stack)
        
        // Grid button
        gridButton = createIconButton(symbolName: "square.grid.2x2", tooltip: "Grid view")
        gridButton.target = self
        gridButton.action = #selector(gridClicked)
        stack.addArrangedSubview(gridButton)
        
        // List button
        listButton = createIconButton(symbolName: "list.bullet", tooltip: "List view")
        listButton.target = self
        listButton.action = #selector(listClicked)
        stack.addArrangedSubview(listButton)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        updateAppearance()
        setupTrackingAreas()
    }
    
    private func createIconButton(symbolName: String, tooltip: String) -> NSButton {
        let button = NSButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .inline
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.wantsLayer = true
        button.layer?.cornerRadius = 4
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28),
        ])
        
        return button
    }
    
    private func setupTrackingAreas() {
        // Grid button tracking
        gridTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["button": "grid"]
        )
        gridButton.addTrackingArea(gridTrackingArea!)
        
        // List button tracking
        listTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["button": "list"]
        )
        listButton.addTrackingArea(listTrackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: String],
              let buttonId = userInfo["button"] else { return }
        
        if buttonId == "grid" {
            isGridHovered = true
        } else {
            isListHovered = true
        }
        updateAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: String],
              let buttonId = userInfo["button"] else { return }
        
        if buttonId == "grid" {
            isGridHovered = false
        } else {
            isListHovered = false
        }
        updateAppearance()
    }
    
    private func updateAppearance() {
        // Grid button
        if currentMode == .grid {
            gridButton.contentTintColor = .white
            gridButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        } else if isGridHovered {
            gridButton.contentTintColor = .white
            gridButton.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            gridButton.contentTintColor = DesignColors.textTertiary
            gridButton.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        // List button
        if currentMode == .list {
            listButton.contentTintColor = .white
            listButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        } else if isListHovered {
            listButton.contentTintColor = .white
            listButton.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            listButton.contentTintColor = DesignColors.textTertiary
            listButton.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    @objc private func gridClicked() {
        if currentMode != .grid {
            currentMode = .grid
            onModeChanged?(.grid)
        }
    }
    
    @objc private func listClicked() {
        if currentMode != .list {
            currentMode = .list
            onModeChanged?(.list)
        }
    }
    
    /// Set the current mode without triggering callback
    func setMode(_ mode: Mode) {
        currentMode = mode
    }
}

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
    
    // Colors for different states - theme-aware
    private var normalBorderColor: NSColor { DesignColors.borderSubtle }
    private var hoverBorderColor: NSColor { DesignColors.borderHover }
    private var focusBorderColor: NSColor { DesignColors.borderActive }
    private var normalBgColor: NSColor { DesignColors.inputBackground }
    private var focusBgColor: NSColor { DesignColors.cardBackground }
    
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
    var onViewModeChanged: ((ViewModeToggle.Mode) -> Void)?
    
    // MARK: - Properties
    
    private var breadcrumbStack: NSStackView!
    private var searchField: StyledSearchField!
    private var viewModeToggle: ViewModeToggle!
    private var homeLabel: NSTextField!  // Legacy, kept for compatibility
    private var homeButtonRef: NSButton!
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
        
        // Header background - matches primary theme color
        layer?.backgroundColor = DesignColors.headerBackground.cgColor
        
        // Border at bottom
        let borderLayer = CALayer()
        borderLayer.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: 10000, height: 1)
        layer?.addSublayer(borderLayer)
        
        setupBreadcrumb()
        setupViewModeToggle()
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
        
        // Home link - clickable button styled as text
        let homeButton = NSButton(frame: .zero)
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        homeButton.isBordered = false
        homeButton.title = "Home"
        homeButton.font = DesignFonts.body(size: 13)
        homeButton.contentTintColor = DesignColors.textSecondary
        homeButton.target = self
        homeButton.action = #selector(homeClicked)
        homeButton.setButtonType(.momentaryChange)
        
        // Style to look like a label
        homeButton.attributedTitle = NSAttributedString(
            string: "Home",
            attributes: [
                .font: DesignFonts.body(size: 13),
                .foregroundColor: DesignColors.textSecondary
            ]
        )
        
        // Track mouse for hover - use the button itself
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["view": "home", "button": homeButton]
        )
        homeButton.addTrackingArea(trackingArea)
        
        // Store reference to update on hover
        homeLabel = NSTextField(labelWithString: "") // Dummy, we use button now
        self.homeButtonRef = homeButton
        
        breadcrumbStack.addArrangedSubview(homeButton)
        
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
    
    private func setupViewModeToggle() {
        // View mode toggle (grid/list icons)
        viewModeToggle = ViewModeToggle(frame: .zero)
        viewModeToggle.translatesAutoresizingMaskIntoConstraints = false
        viewModeToggle.isHidden = true  // Hidden by default, shown for browser views
        viewModeToggle.onModeChanged = { [weak self] mode in
            self?.onViewModeChanged?(mode)
        }
        addSubview(viewModeToggle)
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
            
            // View mode toggle before search field (gap-4 = 16px)
            viewModeToggle.trailingAnchor.constraint(equalTo: searchField.leadingAnchor, constant: -16),
            viewModeToggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            
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
    
    /// Show or hide the view mode toggle
    func setViewModeToggleVisible(_ visible: Bool) {
        viewModeToggle.isHidden = !visible
    }
    
    /// Set the current view mode (without triggering callback)
    func setViewMode(_ mode: ViewModeToggle.Mode) {
        viewModeToggle.setMode(mode)
    }
    
    /// Get current view mode
    var currentViewMode: ViewModeToggle.Mode {
        viewModeToggle.currentMode
    }
    
    // MARK: - Actions
    
    @objc private func homeClicked() {
        onHomeClicked?()
    }
    
    // MARK: - Mouse Tracking
    
    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo as? [String: Any],
           userInfo["view"] as? String == "home" {
            // Update button title with hover color
            homeButtonRef?.attributedTitle = NSAttributedString(
                string: "Home",
                attributes: [
                    .font: DesignFonts.body(size: 13),
                    .foregroundColor: DesignColors.textPrimary
                ]
            )
            NSCursor.pointingHand.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo as? [String: Any],
           userInfo["view"] as? String == "home" {
            // Restore button title with normal color
            homeButtonRef?.attributedTitle = NSAttributedString(
                string: "Home",
                attributes: [
                    .font: DesignFonts.body(size: 13),
                    .foregroundColor: DesignColors.textSecondary
                ]
            )
            NSCursor.arrow.set()
        }
    }
}
