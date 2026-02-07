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
    private var gridWrapper: NSView!
    private var listWrapper: NSView!
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
        
        // Grid button with wrapper
        (gridWrapper, gridButton) = createIconButton(symbolName: "square.grid.2x2", tooltip: "Grid view")
        gridButton.target = self
        gridButton.action = #selector(gridClicked)
        stack.addArrangedSubview(gridWrapper)
        
        // List button with wrapper
        (listWrapper, listButton) = createIconButton(symbolName: "list.bullet", tooltip: "List view")
        listButton.target = self
        listButton.action = #selector(listClicked)
        stack.addArrangedSubview(listWrapper)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        updateAppearance()
        setupTrackingAreas()
    }
    
    private func createIconButton(symbolName: String, tooltip: String) -> (NSView, NSButton) {
        // Wrapper view controls the exact size and background
        let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.wantsLayer = true
        wrapper.layer?.cornerRadius = 6
        
        // Button inside wrapper - transparent, just for clicks and icon
        let button = NSButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.title = ""
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)?.withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        wrapper.addSubview(button)
        
        // Wrapper is exactly 28x28
        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: 28),
            wrapper.heightAnchor.constraint(equalToConstant: 28),
            // Button fills wrapper
            button.topAnchor.constraint(equalTo: wrapper.topAnchor),
            button.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])
        
        return (wrapper, button)
    }
    
    private func setupTrackingAreas() {
        // Grid wrapper tracking
        gridTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["button": "grid"]
        )
        gridWrapper.addTrackingArea(gridTrackingArea!)
        
        // List wrapper tracking
        listTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["button": "list"]
        )
        listWrapper.addTrackingArea(listTrackingArea!)
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
        // Grid button - background on wrapper, tint on button
        if currentMode == .grid {
            gridButton.contentTintColor = DesignColors.textPrimary
            gridWrapper.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
        } else if isGridHovered {
            gridButton.contentTintColor = DesignColors.textPrimary
            gridWrapper.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            gridButton.contentTintColor = DesignColors.textSecondary
            gridWrapper.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        // List button - background on wrapper, tint on button
        if currentMode == .list {
            listButton.contentTintColor = DesignColors.textPrimary
            listWrapper.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
        } else if isListHovered {
            listButton.contentTintColor = DesignColors.textPrimary
            listWrapper.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            listButton.contentTintColor = DesignColors.textSecondary
            listWrapper.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    func refreshAppearance() {
        updateAppearance()
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
        textField.textColor = DesignColors.textPrimary
        textField.placeholderString = "Search assets..."
        textField.placeholderAttributedString = NSAttributedString(
            string: "Search assets...",
            attributes: [
                .foregroundColor: DesignColors.textTertiary,
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

    func refreshAppearance() {
        textField.textColor = DesignColors.textPrimary
        textField.placeholderAttributedString = NSAttributedString(
            string: "Search assets...",
            attributes: [
                .foregroundColor: DesignColors.textTertiary,
                .font: DesignFonts.caption(size: 12)
            ]
        )
        searchIcon.contentTintColor = DesignColors.textTertiary
        clearButton.contentTintColor = DesignColors.textTertiary
        updateAppearance()
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
    var onRefresh: (() -> Void)?
    
    // MARK: - Properties
    
    private var breadcrumbStack: NSStackView!
    private var searchField: StyledSearchField!
    private var viewModeToggle: ViewModeToggle!
    private var refreshButton: NSButton!
    private var refreshDivider: NSView!
    private var homeLabel: NSTextField!  // Legacy, kept for compatibility
    private var homeButtonRef: NSButton!
    private var chevronImage: NSImageView!
    private var currentPageLabel: NSTextField!
    private var borderLayer: CALayer?
    private var themeObserver: NSObjectProtocol?
    
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
        borderLayer.backgroundColor = DesignColors.borderSubtle.cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: 10000, height: 1)
        layer?.addSublayer(borderLayer)
        self.borderLayer = borderLayer
        
        setupBreadcrumb()
        setupRefreshButton()
        setupViewModeToggle()
        setupSearchField()
        setupConstraints()
        setupThemeObserver()
        applyTheme()
    }

    private func setupThemeObserver() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .themeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    private func applyTheme() {
        layer?.backgroundColor = DesignColors.headerBackground.cgColor
        borderLayer?.backgroundColor = DesignColors.borderSubtle.cgColor
        chevronImage.contentTintColor = DesignColors.textSecondary
        currentPageLabel.textColor = DesignColors.textPrimary
        homeButtonRef?.attributedTitle = NSAttributedString(
            string: "Home",
            attributes: [
                .font: DesignFonts.body(size: 13),
                .foregroundColor: DesignColors.textSecondary
            ]
        )
        refreshButton.contentTintColor = DesignColors.textSecondary
        refreshDivider.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        viewModeToggle.refreshAppearance()
        searchField.refreshAppearance()
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
    
    private func setupRefreshButton() {
        // Refresh button
        refreshButton = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.isBordered = false
        refreshButton.bezelStyle = .smallSquare
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")?.withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
        refreshButton.imagePosition = .imageOnly
        refreshButton.imageScaling = .scaleNone
        refreshButton.toolTip = "Refresh"
        refreshButton.contentTintColor = DesignColors.textSecondary
        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)
        refreshButton.isHidden = true  // Hidden by default, shown for browser views
        refreshButton.setContentHuggingPriority(.required, for: .horizontal)
        refreshButton.setContentHuggingPriority(.required, for: .vertical)
        addSubview(refreshButton)
        
        // Divider between refresh and view mode toggle
        refreshDivider = NSView()
        refreshDivider.translatesAutoresizingMaskIntoConstraints = false
        refreshDivider.wantsLayer = true
        refreshDivider.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        refreshDivider.isHidden = true  // Hidden by default
        addSubview(refreshDivider)
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
            
            // Refresh button before divider
            refreshButton.trailingAnchor.constraint(equalTo: refreshDivider.leadingAnchor, constant: -12),
            refreshButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 28),
            refreshButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Divider between refresh and view mode toggle
            refreshDivider.trailingAnchor.constraint(equalTo: viewModeToggle.leadingAnchor, constant: -12),
            refreshDivider.centerYAnchor.constraint(equalTo: centerYAnchor),
            refreshDivider.widthAnchor.constraint(equalToConstant: 1),
            refreshDivider.heightAnchor.constraint(equalToConstant: 20),
            
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
    
    /// Show or hide the refresh button and divider
    func setRefreshButtonVisible(_ visible: Bool) {
        refreshButton.isHidden = !visible
        refreshDivider.isHidden = !visible
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
    
    @objc private func refreshClicked() {
        onRefresh?()
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

    deinit {
        if let themeObserver = themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }
}
