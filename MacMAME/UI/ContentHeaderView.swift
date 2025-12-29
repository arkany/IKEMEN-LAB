import Cocoa

// MARK: - Content Header View

/// Shared header view for content pages with breadcrumb navigation and search field
/// Design matches generated-page-3.html header section
class ContentHeaderView: NSView {
    
    // MARK: - Callbacks
    
    var onSearch: ((String) -> Void)?
    var onHomeClicked: (() -> Void)?
    
    // MARK: - Properties
    
    private var breadcrumbStack: NSStackView!
    private var searchField: NSSearchField!
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
        // Custom search field to match HTML design
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search assets..."
        searchField.font = DesignFonts.caption(size: 12)
        searchField.focusRingType = .none
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = false
        
        // Style the search field
        // Note: AppKit doesn't allow full customization, but we can get close
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.searchButtonCell?.isTransparent = false
        }
        
        // Apply dark styling via appearance
        searchField.appearance = NSAppearance(named: .darkAqua)
        
        addSubview(searchField)
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
    
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        // Debounce search to avoid too many queries while typing
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.onSearch?(sender.stringValue)
        }
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
