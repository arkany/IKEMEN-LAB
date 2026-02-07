import Cocoa
import Combine

// MARK: - Pasteboard Type for Roster Drag

extension NSPasteboard.PasteboardType {
    static let rosterEntryDrag = NSPasteboard.PasteboardType("com.ikemenlab.roster-entry-drag")
}

// MARK: - CollectionEditorView

/// View for editing a collection's roster, stages, and screenpack
class CollectionEditorView: NSView {
    
    // MARK: - Properties
    
    private var collection: Collection?
    private var cancellables = Set<AnyCancellable>()
    
    // For smart collections, store the evaluated results
    private var evaluatedCharacters: [RosterEntry] = []
    private var evaluatedStages: [String] = []
    
    // Use these for display (handles both regular and smart collections)
    private var displayCharacters: [RosterEntry] {
        if let collection = collection, collection.isSmartCollection {
            return evaluatedCharacters
        }
        return collection?.characters ?? []
    }
    
    private var displayStages: [String] {
        if let collection = collection, collection.isSmartCollection {
            return evaluatedStages
        }
        return collection?.stages ?? []
    }
    
    // Callbacks
    var onBackClicked: (() -> Void)?
    var onActivateClicked: ((Collection) -> Void)?
    var onAddCharactersClicked: ((Collection) -> Void)?
    var onAddStagesClicked: ((Collection) -> Void)?
    var onChangeScreenpackClicked: ((Collection) -> Void)?
    var onChangeLifebarsClicked: ((Collection) -> Void)?
    
    // UI Components
    private var scrollView: NSScrollView!
    private var contentStack: NSStackView!
    
    // Header
    private var headerView: NSView!
    private var backButton: NSButton!
    private var titleLabel: NSTextField!
    private var activeBadge: NSView!
    private var activeBadgeDot: NSView!
    private var activeBadgeLabel: NSTextField!
    private var activateButton: NSButton!
    private var menuButton: NSButton!
    private var backButtonTrackingArea: NSTrackingArea?
    
    // Roster Section
    private var rosterHeaderView: NSView!
    private var rosterCountLabel: NSTextField!
    private var addCharactersButton: NSButton!
    private var rosterCollectionView: NSCollectionView!
    private var rosterContainerView: NSView!
    private var rosterHeightConstraint: NSLayoutConstraint?
    
    // Stages Section
    private var stagesHeaderView: NSView!
    private var stagesCountLabel: NSTextField!
    private var addStagesButton: NSButton!
    private var stagesCollectionView: NSCollectionView!
    private var stagesContainerView: NSView!
    private var stagesHeightConstraint: NSLayoutConstraint?
    
    // Screenpack Section
    private var screenpackView: NSView!
    private var screenpackIconView: NSView!
    private var screenpackLabel: NSTextField!
    private var screenpackDescLabel: NSTextField!
    private var changeScreenpackButton: NSButton!
    private var screenpackTrackingArea: NSTrackingArea?
    private var isScreenpackHovered = false
    
    // Lifebars Section
    private var lifebarsView: NSView!
    private var lifebarsIconView: NSView!
    private var lifebarsLabel: NSTextField!
    private var lifebarsDescLabel: NSTextField!
    private var changeLifebarsButton: NSButton!
    private var lifebarsTrackingArea: NSTrackingArea?
    private var isLifebarsHovered = false
    
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
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupScrollView()
        setupHeader()
        setupRosterSection()
        setupStagesSection()
        setupScreenpackSection()
        setupLifebarsSection()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        addSubview(scrollView)
        
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 24
        contentStack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 24, right: 24)
        
        scrollView.documentView = contentStack
        
        // Note: scrollView.topAnchor will be constrained to headerView.bottomAnchor in setupHeader()
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
    
    private func setupHeader() {
        // Header matches ContentHeaderView style: 64px height, matches primary theme, border-b border-white/5
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = DesignColors.headerBackground.cgColor
        
        // Border at bottom
        let borderLayer = CALayer()
        borderLayer.backgroundColor = DesignColors.borderSubtle.cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: 10000, height: 1)
        headerView.layer?.addSublayer(borderLayer)
        
        // Left side: Back button styled as breadcrumb link
        backButton = NSButton(frame: .zero)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.isBordered = false
        backButton.target = self
        backButton.action = #selector(backClicked)
        backButton.setButtonType(.momentaryChange)
        backButton.attributedTitle = NSAttributedString(
            string: "Collections",
            attributes: [
                .font: DesignFonts.body(size: 13),
                .foregroundColor: DesignColors.textSecondary
            ]
        )
        headerView.addSubview(backButton)
        
        // Chevron separator
        let chevronImage = NSImageView()
        chevronImage.translatesAutoresizingMaskIntoConstraints = false
        chevronImage.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevronImage.contentTintColor = DesignColors.textTertiary
        chevronImage.imageScaling = .scaleProportionallyDown
        headerView.addSubview(chevronImage)
        
        // Title label (editable collection name)
        titleLabel = NSTextField(labelWithString: "Collection")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.body(size: 13)
        titleLabel.textColor = DesignColors.textPrimary
        titleLabel.isEditable = true
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.focusRingType = .none
        titleLabel.delegate = self
        headerView.addSubview(titleLabel)
        
        // Right side: Active badge (pill with dot)
        activeBadge = NSView()
        activeBadge.translatesAutoresizingMaskIntoConstraints = false
        activeBadge.wantsLayer = true
        activeBadge.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        activeBadge.layer?.cornerRadius = 12
        activeBadge.layer?.borderWidth = 1
        activeBadge.layer?.borderColor = DesignColors.borderSubtle.cgColor
        activeBadge.isHidden = true
        headerView.addSubview(activeBadge)
        
        // Pulsing dot in badge
        activeBadgeDot = NSView()
        activeBadgeDot.translatesAutoresizingMaskIntoConstraints = false
        activeBadgeDot.wantsLayer = true
        activeBadgeDot.layer?.backgroundColor = DesignColors.positive.cgColor
        activeBadgeDot.layer?.cornerRadius = 3
        activeBadge.addSubview(activeBadgeDot)
        
        // "Active" label in badge
        activeBadgeLabel = NSTextField(labelWithString: "Active")
        activeBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        activeBadgeLabel.font = DesignFonts.label(size: 11)
        activeBadgeLabel.textColor = DesignColors.textSecondary
        activeBadge.addSubview(activeBadgeLabel)
        
        // Activate button (shown when not active)
        activateButton = NSButton(title: "Activate", target: self, action: #selector(activateClicked))
        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.bezelStyle = .inline
        activateButton.isBordered = false
        activateButton.wantsLayer = true
        activateButton.layer?.backgroundColor = DesignColors.positive.cgColor
        activateButton.layer?.cornerRadius = 6
        activateButton.font = DesignFonts.label(size: 12)
        activateButton.attributedTitle = NSAttributedString(
            string: "Activate",
            attributes: [
                .font: DesignFonts.label(size: 12),
                .foregroundColor: DesignColors.textOnAccent
            ]
        )
        headerView.addSubview(activateButton)
        
        // Divider line between badge/button and menu
        let divider = NSView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true
        divider.layer?.backgroundColor = DesignColors.borderSubtle.cgColor
        headerView.addSubview(divider)
        
        // Menu button (three dots)
        menuButton = NSButton(title: "", target: self, action: #selector(menuClicked))
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.bezelStyle = .inline
        menuButton.isBordered = false
        menuButton.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "More options")
        menuButton.contentTintColor = DesignColors.textSecondary
        headerView.addSubview(menuButton)
        
        // Add header directly to the view (not to contentStack) so it stays fixed at top
        addSubview(headerView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 64),
            
            // Left side - breadcrumb style: Collections > [Name]
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 32),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            chevronImage.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            chevronImage.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            chevronImage.widthAnchor.constraint(equalToConstant: 12),
            chevronImage.heightAnchor.constraint(equalToConstant: 12),
            
            titleLabel.leadingAnchor.constraint(equalTo: chevronImage.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Right side - active badge / activate button + divider + menu
            menuButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -32),
            menuButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 28),
            menuButton.heightAnchor.constraint(equalToConstant: 28),
            
            divider.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -12),
            divider.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 16),
            
            // Active badge
            activeBadge.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -12),
            activeBadge.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            activeBadge.heightAnchor.constraint(equalToConstant: 24),
            
            activeBadgeDot.leadingAnchor.constraint(equalTo: activeBadge.leadingAnchor, constant: 10),
            activeBadgeDot.centerYAnchor.constraint(equalTo: activeBadge.centerYAnchor),
            activeBadgeDot.widthAnchor.constraint(equalToConstant: 6),
            activeBadgeDot.heightAnchor.constraint(equalToConstant: 6),
            
            activeBadgeLabel.leadingAnchor.constraint(equalTo: activeBadgeDot.trailingAnchor, constant: 6),
            activeBadgeLabel.trailingAnchor.constraint(equalTo: activeBadge.trailingAnchor, constant: -10),
            activeBadgeLabel.centerYAnchor.constraint(equalTo: activeBadge.centerYAnchor),
            
            // Activate button (overlaps same position as badge)
            activateButton.trailingAnchor.constraint(equalTo: divider.leadingAnchor, constant: -12),
            activateButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            activateButton.heightAnchor.constraint(equalToConstant: 28),
            activateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Connect scrollView to header
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
        ])
        
        // Add tracking area for back button hover effect
        backButtonTrackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["view": "backButton"]
        )
        backButton.addTrackingArea(backButtonTrackingArea!)
        
        // Start pulsing animation on the dot
        startPulsingAnimation()
    }
    
    private func startPulsingAnimation() {
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.4
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        activeBadgeDot.layer?.add(pulse, forKey: "pulse")
    }
    
    // MARK: - Mouse Tracking for Header
    
    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo else { return }
        
        // Handle back button hover
        if let viewType = userInfo["view"] as? String, viewType == "backButton" {
            backButton.attributedTitle = NSAttributedString(
                string: "Collections",
                attributes: [
                    .font: DesignFonts.body(size: 13),
                    .foregroundColor: DesignColors.textPrimary
                ]
            )
            NSCursor.pointingHand.set()
            return
        }
        
        // Handle card hovers
        if let type = userInfo["type"] as? String {
            switch type {
            case "screenpack":
                isScreenpackHovered = true
                animateCardHover(screenpackView, hovered: true)
            case "lifebars":
                isLifebarsHovered = true
                animateCardHover(lifebarsView, hovered: true)
            default:
                break
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo else { return }
        
        // Handle back button hover
        if let viewType = userInfo["view"] as? String, viewType == "backButton" {
            backButton.attributedTitle = NSAttributedString(
                string: "Collections",
                attributes: [
                    .font: DesignFonts.body(size: 13),
                    .foregroundColor: DesignColors.textSecondary
                ]
            )
            NSCursor.arrow.set()
            return
        }
        
        // Handle card hovers
        if let type = userInfo["type"] as? String {
            switch type {
            case "screenpack":
                isScreenpackHovered = false
                animateCardHover(screenpackView, hovered: false)
            case "lifebars":
                isLifebarsHovered = false
                animateCardHover(lifebarsView, hovered: false)
            default:
                break
            }
        }
    }
    
    private func animateCardHover(_ view: NSView?, hovered: Bool) {
        guard let view = view else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            if hovered {
                view.layer?.borderColor = DesignColors.borderHover.cgColor
                view.layer?.backgroundColor = DesignColors.cardBackgroundHover.cgColor
            } else {
                view.layer?.borderColor = DesignColors.borderSubtle.cgColor
                view.layer?.backgroundColor = DesignColors.cardBackgroundTransparent.cgColor
            }
        }
    }
    
    private func setupRosterSection() {
        // Section header
        rosterHeaderView = createSectionHeader(
            title: "ROSTER",
            countLabel: &rosterCountLabel,
            buttonTitle: "Add Characters",
            buttonAction: #selector(addCharactersClicked)
        )
        addCharactersButton = rosterHeaderView.subviews.compactMap { $0 as? NSButton }.first
        contentStack.addArrangedSubview(rosterHeaderView)
        
        // Roster collection view - grid layout matching HTML mockup
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 96, height: 120) // Square-ish aspect with name below
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        rosterCollectionView = NSCollectionView()
        rosterCollectionView.collectionViewLayout = layout
        rosterCollectionView.delegate = self
        rosterCollectionView.dataSource = self
        rosterCollectionView.backgroundColors = [.clear]
        rosterCollectionView.isSelectable = true
        rosterCollectionView.allowsMultipleSelection = false
        rosterCollectionView.register(RosterEntryItem.self, forItemWithIdentifier: RosterEntryItem.identifier)
        
        // Enable drag reordering
        rosterCollectionView.registerForDraggedTypes([.rosterEntryDrag])
        rosterCollectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        // Container view (no scroll view - parent handles scrolling)
        rosterContainerView = NSView()
        rosterContainerView.translatesAutoresizingMaskIntoConstraints = false
        rosterContainerView.wantsLayer = true
        rosterContainerView.addSubview(rosterCollectionView)
        
        rosterCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rosterCollectionView.topAnchor.constraint(equalTo: rosterContainerView.topAnchor),
            rosterCollectionView.leadingAnchor.constraint(equalTo: rosterContainerView.leadingAnchor),
            rosterCollectionView.trailingAnchor.constraint(equalTo: rosterContainerView.trailingAnchor),
            rosterCollectionView.bottomAnchor.constraint(equalTo: rosterContainerView.bottomAnchor),
        ])
        
        contentStack.addArrangedSubview(rosterContainerView)
        
        // Create height constraint (will be updated based on content)
        rosterHeightConstraint = rosterContainerView.heightAnchor.constraint(equalToConstant: 120)
        
        NSLayoutConstraint.activate([
            rosterHeaderView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            rosterHeaderView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            
            rosterContainerView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            rosterContainerView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            rosterHeightConstraint!,
        ])
    }
    
    private func setupStagesSection() {
        // Section header
        stagesHeaderView = createSectionHeader(
            title: "STAGES",
            countLabel: &stagesCountLabel,
            buttonTitle: "Add Stages",
            buttonAction: #selector(addStagesClicked)
        )
        addStagesButton = stagesHeaderView.subviews.compactMap { $0 as? NSButton }.first
        contentStack.addArrangedSubview(stagesHeaderView)
        
        // Stages collection view - grid layout with 16:9 aspect ratio
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 192, height: 120) // ~16:10 aspect with name below
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        stagesCollectionView = NSCollectionView()
        stagesCollectionView.collectionViewLayout = layout
        stagesCollectionView.delegate = self
        stagesCollectionView.dataSource = self
        stagesCollectionView.backgroundColors = [.clear]
        stagesCollectionView.isSelectable = true
        stagesCollectionView.register(StageEntryItem.self, forItemWithIdentifier: StageEntryItem.identifier)
        
        // Container view (no scroll view - parent handles scrolling)
        stagesContainerView = NSView()
        stagesContainerView.translatesAutoresizingMaskIntoConstraints = false
        stagesContainerView.wantsLayer = true
        stagesContainerView.addSubview(stagesCollectionView)
        
        stagesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stagesCollectionView.topAnchor.constraint(equalTo: stagesContainerView.topAnchor),
            stagesCollectionView.leadingAnchor.constraint(equalTo: stagesContainerView.leadingAnchor),
            stagesCollectionView.trailingAnchor.constraint(equalTo: stagesContainerView.trailingAnchor),
            stagesCollectionView.bottomAnchor.constraint(equalTo: stagesContainerView.bottomAnchor),
        ])
        
        contentStack.addArrangedSubview(stagesContainerView)
        
        // Create height constraint (will be updated based on content)
        stagesHeightConstraint = stagesContainerView.heightAnchor.constraint(equalToConstant: 120)
        
        NSLayoutConstraint.activate([
            stagesHeaderView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            stagesHeaderView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            
            stagesContainerView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            stagesContainerView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            stagesHeightConstraint!,
        ])
    }
    
    private func setupScreenpackSection() {
        // Section header
        let screenpackHeaderLabel = NSTextField(labelWithString: "SCREENPACK")
        screenpackHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        screenpackHeaderLabel.font = DesignFonts.label(size: 11)
        screenpackHeaderLabel.textColor = DesignColors.textTertiary
        contentStack.addArrangedSubview(screenpackHeaderLabel)
        
        // Card container matching HTML mockup
        screenpackView = NSView()
        screenpackView.translatesAutoresizingMaskIntoConstraints = false
        screenpackView.wantsLayer = true
        screenpackView.layer?.backgroundColor = DesignColors.cardBackgroundTransparent.cgColor
        screenpackView.layer?.cornerRadius = 8
        screenpackView.layer?.borderWidth = 1
        screenpackView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Icon container (left side)
        screenpackIconView = NSView()
        screenpackIconView.translatesAutoresizingMaskIntoConstraints = false
        screenpackIconView.wantsLayer = true
        screenpackIconView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        screenpackIconView.layer?.cornerRadius = 4
        screenpackIconView.layer?.borderWidth = 1
        screenpackIconView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        screenpackView.addSubview(screenpackIconView)
        
        // Icon image
        let screenpackIcon = NSImageView()
        screenpackIcon.translatesAutoresizingMaskIntoConstraints = false
        screenpackIcon.image = NSImage(systemSymbolName: "tv", accessibilityDescription: nil)
        screenpackIcon.contentTintColor = DesignColors.textTertiary
        screenpackIcon.imageScaling = .scaleProportionallyDown
        screenpackIconView.addSubview(screenpackIcon)
        
        // Screenpack name
        screenpackLabel = NSTextField(labelWithString: "Default")
        screenpackLabel.translatesAutoresizingMaskIntoConstraints = false
        screenpackLabel.font = DesignFonts.body(size: 14)
        screenpackLabel.textColor = DesignColors.textPrimary
        screenpackView.addSubview(screenpackLabel)
        
        // Description label
        screenpackDescLabel = NSTextField(labelWithString: "Default configuration")
        screenpackDescLabel.translatesAutoresizingMaskIntoConstraints = false
        screenpackDescLabel.font = DesignFonts.caption(size: 12)
        screenpackDescLabel.textColor = DesignColors.textTertiary
        screenpackView.addSubview(screenpackDescLabel)
        
        // Change button - styled to match HTML mockup
        changeScreenpackButton = NSButton(title: "Change", target: self, action: #selector(changeScreenpackClicked))
        changeScreenpackButton.translatesAutoresizingMaskIntoConstraints = false
        changeScreenpackButton.bezelStyle = .inline
        changeScreenpackButton.isBordered = false
        changeScreenpackButton.wantsLayer = true
        changeScreenpackButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
        changeScreenpackButton.layer?.cornerRadius = 6
        changeScreenpackButton.layer?.borderWidth = 1
        changeScreenpackButton.layer?.borderColor = DesignColors.borderSubtle.cgColor
        changeScreenpackButton.font = DesignFonts.label(size: 12)
        changeScreenpackButton.attributedTitle = NSAttributedString(
            string: "Change",
            attributes: [
                .font: DesignFonts.label(size: 12),
                .foregroundColor: DesignColors.textSecondary
            ]
        )
        screenpackView.addSubview(changeScreenpackButton)
        
        contentStack.addArrangedSubview(screenpackView)
        
        NSLayoutConstraint.activate([
            screenpackHeaderLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            
            screenpackView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            screenpackView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            screenpackView.heightAnchor.constraint(equalToConstant: 72),
            
            screenpackIconView.leadingAnchor.constraint(equalTo: screenpackView.leadingAnchor, constant: 16),
            screenpackIconView.centerYAnchor.constraint(equalTo: screenpackView.centerYAnchor),
            screenpackIconView.widthAnchor.constraint(equalToConstant: 64),
            screenpackIconView.heightAnchor.constraint(equalToConstant: 40),
            
            screenpackIcon.centerXAnchor.constraint(equalTo: screenpackIconView.centerXAnchor),
            screenpackIcon.centerYAnchor.constraint(equalTo: screenpackIconView.centerYAnchor),
            screenpackIcon.widthAnchor.constraint(equalToConstant: 22),
            screenpackIcon.heightAnchor.constraint(equalToConstant: 22),
            
            screenpackLabel.leadingAnchor.constraint(equalTo: screenpackIconView.trailingAnchor, constant: 16),
            screenpackLabel.topAnchor.constraint(equalTo: screenpackView.topAnchor, constant: 16),
            
            screenpackDescLabel.leadingAnchor.constraint(equalTo: screenpackIconView.trailingAnchor, constant: 16),
            screenpackDescLabel.topAnchor.constraint(equalTo: screenpackLabel.bottomAnchor, constant: 2),
            
            changeScreenpackButton.trailingAnchor.constraint(equalTo: screenpackView.trailingAnchor, constant: -16),
            changeScreenpackButton.centerYAnchor.constraint(equalTo: screenpackView.centerYAnchor),
            changeScreenpackButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            changeScreenpackButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }
    
    private func setupLifebarsSection() {
        // Section header
        let lifebarsHeaderLabel = NSTextField(labelWithString: "LIFE BARS")
        lifebarsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        lifebarsHeaderLabel.font = DesignFonts.label(size: 11)
        lifebarsHeaderLabel.textColor = DesignColors.textTertiary
        contentStack.addArrangedSubview(lifebarsHeaderLabel)
        
        // Card container matching HTML mockup
        lifebarsView = NSView()
        lifebarsView.translatesAutoresizingMaskIntoConstraints = false
        lifebarsView.wantsLayer = true
        lifebarsView.layer?.backgroundColor = DesignColors.cardBackgroundTransparent.cgColor
        lifebarsView.layer?.cornerRadius = 8
        lifebarsView.layer?.borderWidth = 1
        lifebarsView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Icon container (left side)
        lifebarsIconView = NSView()
        lifebarsIconView.translatesAutoresizingMaskIntoConstraints = false
        lifebarsIconView.wantsLayer = true
        lifebarsIconView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        lifebarsIconView.layer?.cornerRadius = 4
        lifebarsIconView.layer?.borderWidth = 1
        lifebarsIconView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        lifebarsView.addSubview(lifebarsIconView)
        
        // Icon image
        let lifebarsIcon = NSImageView()
        lifebarsIcon.translatesAutoresizingMaskIntoConstraints = false
        lifebarsIcon.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
        lifebarsIcon.contentTintColor = DesignColors.textTertiary
        lifebarsIcon.imageScaling = .scaleProportionallyDown
        lifebarsIconView.addSubview(lifebarsIcon)
        
        // Lifebars name
        lifebarsLabel = NSTextField(labelWithString: "Default")
        lifebarsLabel.translatesAutoresizingMaskIntoConstraints = false
        lifebarsLabel.font = DesignFonts.body(size: 14)
        lifebarsLabel.textColor = DesignColors.textPrimary
        lifebarsView.addSubview(lifebarsLabel)
        
        // Description label
        lifebarsDescLabel = NSTextField(labelWithString: "Standard 2-Player")
        lifebarsDescLabel.translatesAutoresizingMaskIntoConstraints = false
        lifebarsDescLabel.font = DesignFonts.caption(size: 12)
        lifebarsDescLabel.textColor = DesignColors.textTertiary
        lifebarsView.addSubview(lifebarsDescLabel)
        
        // Change button - styled to match HTML mockup
        changeLifebarsButton = NSButton(title: "Change", target: self, action: #selector(changeLifebarsClicked))
        changeLifebarsButton.translatesAutoresizingMaskIntoConstraints = false
        changeLifebarsButton.bezelStyle = .inline
        changeLifebarsButton.isBordered = false
        changeLifebarsButton.wantsLayer = true
        changeLifebarsButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
        changeLifebarsButton.layer?.cornerRadius = 6
        changeLifebarsButton.layer?.borderWidth = 1
        changeLifebarsButton.layer?.borderColor = DesignColors.borderSubtle.cgColor
        changeLifebarsButton.font = DesignFonts.label(size: 12)
        changeLifebarsButton.attributedTitle = NSAttributedString(
            string: "Change",
            attributes: [
                .font: DesignFonts.label(size: 12),
                .foregroundColor: DesignColors.textSecondary
            ]
        )
        lifebarsView.addSubview(changeLifebarsButton)
        
        contentStack.addArrangedSubview(lifebarsView)
        
        NSLayoutConstraint.activate([
            lifebarsHeaderLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            
            lifebarsView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: 24),
            lifebarsView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -24),
            lifebarsView.heightAnchor.constraint(equalToConstant: 72),
            
            lifebarsIconView.leadingAnchor.constraint(equalTo: lifebarsView.leadingAnchor, constant: 16),
            lifebarsIconView.centerYAnchor.constraint(equalTo: lifebarsView.centerYAnchor),
            lifebarsIconView.widthAnchor.constraint(equalToConstant: 64),
            lifebarsIconView.heightAnchor.constraint(equalToConstant: 40),
            
            lifebarsIcon.centerXAnchor.constraint(equalTo: lifebarsIconView.centerXAnchor),
            lifebarsIcon.centerYAnchor.constraint(equalTo: lifebarsIconView.centerYAnchor),
            lifebarsIcon.widthAnchor.constraint(equalToConstant: 22),
            lifebarsIcon.heightAnchor.constraint(equalToConstant: 22),
            
            lifebarsLabel.leadingAnchor.constraint(equalTo: lifebarsIconView.trailingAnchor, constant: 16),
            lifebarsLabel.topAnchor.constraint(equalTo: lifebarsView.topAnchor, constant: 16),
            
            lifebarsDescLabel.leadingAnchor.constraint(equalTo: lifebarsIconView.trailingAnchor, constant: 16),
            lifebarsDescLabel.topAnchor.constraint(equalTo: lifebarsLabel.bottomAnchor, constant: 2),
            
            changeLifebarsButton.trailingAnchor.constraint(equalTo: lifebarsView.trailingAnchor, constant: -16),
            changeLifebarsButton.centerYAnchor.constraint(equalTo: lifebarsView.centerYAnchor),
            changeLifebarsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            changeLifebarsButton.heightAnchor.constraint(equalToConstant: 28),
        ])
    }
    
    private func createSectionHeader(title: String, countLabel: inout NSTextField!, buttonTitle: String, buttonAction: Selector) -> NSView {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        
        // Title with count - matching HTML: text-xs font-semibold text-zinc-500 uppercase tracking-widest
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.label(size: 11)
        titleLabel.textColor = DesignColors.textTertiary
        header.addSubview(titleLabel)
        
        // Count label - matching HTML: text-zinc-600 font-mono
        countLabel = NSTextField(labelWithString: "(0)")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = DesignColors.textDisabled
        header.addSubview(countLabel)
        
        // Add button - matching HTML: text-emerald-500 with icon
        let button = NSButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.target = self
        button.action = buttonAction
        button.setButtonType(.momentaryChange)
        
        // Create attributed title with icon - vertically centered
        let attachment = NSTextAttachment()
        attachment.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium))
        attachment.image = attachment.image?.tinted(with: DesignColors.positive)
        // Adjust vertical alignment of icon
        attachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        
        let iconString = NSAttributedString(attachment: attachment)
        let textString = NSAttributedString(
            string: " \(buttonTitle)",
            attributes: [
                .font: DesignFonts.label(size: 12),
                .foregroundColor: DesignColors.positive,
                .baselineOffset: 0
            ]
        )
        
        let fullString = NSMutableAttributedString()
        fullString.append(iconString)
        fullString.append(textString)
        button.attributedTitle = fullString
        
        header.addSubview(button)
        
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            countLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            button.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            button.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        
        return header
    }
    
    private func setupObservers() {
        // Observe collection store changes
        CollectionStore.shared.$collections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshIfNeeded()
            }
            .store(in: &cancellables)
        
        CollectionStore.shared.$activeCollectionId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActivateButton()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    func configure(with collection: Collection) {
        self.collection = collection
        
        // For smart collections, evaluate the rules to get matching content
        if collection.isSmartCollection {
            let evaluator = SmartCollectionEvaluator()
            let result = evaluator.evaluate(collection)
            
            // Convert character IDs to RosterEntries
            evaluatedCharacters = result.characters.map { characterId in
                RosterEntry.character(folder: characterId, def: nil)
            }
            evaluatedStages = result.stages
        } else {
            evaluatedCharacters = []
            evaluatedStages = []
        }
        
        updateUI()
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        guard let collection = collection else { return }
        
        titleLabel.stringValue = collection.name
        rosterCountLabel.stringValue = "(\(displayCharacters.count))"
        stagesCountLabel.stringValue = "(\(displayStages.count))"
        
        // Screenpack
        if let screenpackPath = collection.screenpackPath {
            let name = URL(fileURLWithPath: screenpackPath).lastPathComponent
            screenpackLabel.stringValue = name
            screenpackDescLabel.stringValue = "Custom configuration"
        } else {
            screenpackLabel.stringValue = "Default"
            screenpackDescLabel.stringValue = "Default configuration"
        }
        
        // Lifebars
        if let lifebarsPath = collection.lifebarsPath {
            let name = URL(fileURLWithPath: lifebarsPath).lastPathComponent
            lifebarsLabel.stringValue = name
            lifebarsDescLabel.stringValue = "Custom lifebars"
        } else {
            lifebarsLabel.stringValue = "Default"
            lifebarsDescLabel.stringValue = "Standard 2-Player"
        }
        
        // For smart collections, hide the add buttons since content is dynamic
        let isSmartCollection = collection.isSmartCollection
        addCharactersButton.isHidden = isSmartCollection
        addStagesButton.isHidden = isSmartCollection
        
        updateActivateButton()
        
        // Reload collection views
        rosterCollectionView.reloadData()
        stagesCollectionView.reloadData()
        
        // Update scroll view heights based on content
        updateCollectionViewHeights()
    }
    
    private func updateCollectionViewHeights() {
        guard collection != nil else { return }
        
        // Calculate roster height based on item count and available width
        let availableWidth = rosterContainerView.frame.width > 0 ? rosterContainerView.frame.width : (bounds.width - 48)
        let rosterItemWidth: CGFloat = 96
        let rosterItemHeight: CGFloat = 120
        let spacing: CGFloat = 16
        
        let rosterColumns = max(1, Int((availableWidth + spacing) / (rosterItemWidth + spacing)))
        let rosterRows = displayCharacters.isEmpty ? 0 : Int(ceil(Double(displayCharacters.count) / Double(rosterColumns)))
        let rosterHeight = max(120, CGFloat(rosterRows) * (rosterItemHeight + spacing) - spacing)
        rosterHeightConstraint?.constant = rosterHeight
        
        // Calculate stages height
        let stageItemWidth: CGFloat = 192
        let stageItemHeight: CGFloat = 120
        
        let stageColumns = max(1, Int((availableWidth + spacing) / (stageItemWidth + spacing)))
        let stageRows = displayStages.isEmpty ? 0 : Int(ceil(Double(displayStages.count) / Double(stageColumns)))
        let stagesHeight = max(120, CGFloat(stageRows) * (stageItemHeight + spacing) - spacing)
        stagesHeightConstraint?.constant = stagesHeight
        
        // Force layout update
        layoutSubtreeIfNeeded()
    }
    
    override func layout() {
        super.layout()
        // Recalculate heights when view resizes
        updateCollectionViewHeights()
    }
    
    private func refreshIfNeeded() {
        guard let currentId = collection?.id,
              let updated = CollectionStore.shared.collection(withId: currentId) else { return }
        collection = updated
        updateUI()
    }
    
    private func updateActivateButton() {
        guard let collection = collection else { return }
        
        let isActive = CollectionStore.shared.activeCollectionId == collection.id
        
        // Show badge when active, button when not
        activeBadge.isHidden = !isActive
        activateButton.isHidden = isActive
        
        if !isActive {
            activateButton.attributedTitle = NSAttributedString(
                string: "Activate",
                attributes: [
                    .font: DesignFonts.label(size: 12),
                    .foregroundColor: DesignColors.textOnAccent
                ]
            )
        }
    }
    
    // MARK: - Actions
    
    @objc private func backClicked() {
        onBackClicked?()
    }
    
    @objc private func activateClicked() {
        guard let collection = collection else { return }
        onActivateClicked?(collection)
    }
    
    @objc private func menuClicked() {
        guard let collection = collection else { return }
        
        let menu = NSMenu()
        
        // Duplicate
        let duplicateItem = NSMenuItem(title: "Duplicate Collection", action: #selector(duplicateCollection), keyEquivalent: "")
        duplicateItem.target = self
        menu.addItem(duplicateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Delete (only if not default)
        if !collection.isDefault {
            let deleteItem = NSMenuItem(title: "Delete Collection…", action: #selector(deleteCollection), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
        }
        
        let location = NSPoint(x: menuButton.frame.midX, y: menuButton.frame.minY)
        menu.popUp(positioning: nil, at: location, in: headerView)
    }
    
    @objc private func duplicateCollection() {
        guard let collection = collection else { return }
        
        var newCollection = CollectionStore.shared.createCollection(name: "\(collection.name) Copy")
        newCollection.characters = collection.characters
        newCollection.stages = collection.stages
        newCollection.screenpackPath = collection.screenpackPath
        newCollection.lifebarsPath = collection.lifebarsPath
        CollectionStore.shared.update(newCollection)
        
        ToastManager.shared.showSuccess(title: "Created copy: \(newCollection.name)")
    }
    
    @objc private func deleteCollection() {
        guard let collection = collection else { return }
        guard !collection.isDefault else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Collection?"
        alert.informativeText = "Are you sure you want to delete \"\(collection.name)\"? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            CollectionStore.shared.delete(collection)
            onBackClicked?()
            ToastManager.shared.showInfo(title: "Deleted: \(collection.name)")
        }
    }
    
    @objc private func addCharactersClicked() {
        guard let collection = collection else { return }
        onAddCharactersClicked?(collection)
    }
    
    @objc private func addStagesClicked() {
        guard let collection = collection else { return }
        onAddStagesClicked?(collection)
    }
    
    @objc private func changeScreenpackClicked() {
        guard let collection = collection else { return }
        onChangeScreenpackClicked?(collection)
    }
    
    @objc private func changeLifebarsClicked() {
        guard let collection = collection else { return }
        onChangeLifebarsClicked?(collection)
    }
    
    // MARK: - Context Menu for Roster Items
    
    func buildRosterContextMenu(for index: Int) -> NSMenu? {
        guard let collection = collection, index < collection.characters.count else { return nil }
        let entry = collection.characters[index]
        
        let menu = NSMenu()
        
        // Remove
        let removeItem = NSMenuItem(title: "Remove", action: #selector(removeRosterEntry(_:)), keyEquivalent: "")
        removeItem.target = self
        removeItem.representedObject = entry.id
        menu.addItem(removeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Insert Empty Slot After
        let emptySlotItem = NSMenuItem(title: "Insert Empty Slot After", action: #selector(insertEmptySlotAfter(_:)), keyEquivalent: "")
        emptySlotItem.target = self
        emptySlotItem.representedObject = index
        menu.addItem(emptySlotItem)
        
        // Insert Random Select After
        let randomSelectItem = NSMenuItem(title: "Insert Random Select After", action: #selector(insertRandomSelectAfter(_:)), keyEquivalent: "")
        randomSelectItem.target = self
        randomSelectItem.representedObject = index
        menu.addItem(randomSelectItem)
        
        return menu
    }
    
    @objc private func removeRosterEntry(_ sender: NSMenuItem) {
        guard let entryId = sender.representedObject as? UUID,
              let collection = collection else { return }
        
        CollectionStore.shared.removeCharacter(entryId: entryId, from: collection.id)
    }
    
    @objc private func insertEmptySlotAfter(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int,
              var collection = collection else { return }
        
        let emptySlot = RosterEntry.emptySlot()
        collection.characters.insert(emptySlot, at: index + 1)
        CollectionStore.shared.update(collection)
    }
    
    @objc private func insertRandomSelectAfter(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int,
              var collection = collection else { return }
        
        let randomSelect = RosterEntry.randomSelect()
        collection.characters.insert(randomSelect, at: index + 1)
        CollectionStore.shared.update(collection)
    }
    
    // MARK: - Context Menu for Stage Items
    
    func buildStageContextMenu(for index: Int) -> NSMenu? {
        guard let collection = collection, index < collection.stages.count else { return nil }
        let stageFolder = collection.stages[index]
        
        let menu = NSMenu()
        
        let removeItem = NSMenuItem(title: "Remove", action: #selector(removeStageEntry(_:)), keyEquivalent: "")
        removeItem.target = self
        removeItem.representedObject = stageFolder
        menu.addItem(removeItem)
        
        return menu
    }
    
    @objc private func removeStageEntry(_ sender: NSMenuItem) {
        guard let stageFolder = sender.representedObject as? String,
              let collection = collection else { return }
        
        CollectionStore.shared.removeStage(folder: stageFolder, from: collection.id)
    }
    
    // MARK: - Hover State Tracking
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Screenpack tracking area
        if let oldArea = screenpackTrackingArea {
            screenpackView?.removeTrackingArea(oldArea)
        }
        if let screenpackView = screenpackView {
            let area = NSTrackingArea(
                rect: screenpackView.bounds,
                options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self,
                userInfo: ["type": "screenpack"]
            )
            screenpackView.addTrackingArea(area)
            screenpackTrackingArea = area
        }
        
        // Lifebars tracking area
        if let oldArea = lifebarsTrackingArea {
            lifebarsView?.removeTrackingArea(oldArea)
        }
        if let lifebarsView = lifebarsView {
            let area = NSTrackingArea(
                rect: lifebarsView.bounds,
                options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                owner: self,
                userInfo: ["type": "lifebars"]
            )
            lifebarsView.addTrackingArea(area)
            lifebarsTrackingArea = area
        }
    }
}

// MARK: - NSTextFieldDelegate

extension CollectionEditorView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField == titleLabel,
              var collection = collection else { return }
        
        let newName = textField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty, newName != collection.name else {
            textField.stringValue = collection.name
            return
        }
        
        collection.name = newName
        CollectionStore.shared.update(collection)
    }
}

// MARK: - NSCollectionViewDataSource

extension CollectionEditorView: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        guard collection != nil else { return 0 }
        
        if collectionView == rosterCollectionView {
            return displayCharacters.count
        } else if collectionView == stagesCollectionView {
            return displayStages.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if collectionView == rosterCollectionView {
            let item = collectionView.makeItem(withIdentifier: RosterEntryItem.identifier, for: indexPath) as! RosterEntryItem
            if indexPath.item < displayCharacters.count {
                let entry = displayCharacters[indexPath.item]
                item.configure(with: entry)
            }
            return item
        } else if collectionView == stagesCollectionView {
            let item = collectionView.makeItem(withIdentifier: StageEntryItem.identifier, for: indexPath) as! StageEntryItem
            if indexPath.item < displayStages.count {
                let stageFolder = displayStages[indexPath.item]
                item.configure(with: stageFolder)
            }
            return item
        }
        
        fatalError("Unknown collection view")
    }
}

// MARK: - NSCollectionViewDelegate

extension CollectionEditorView: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Handle selection if needed
    }
    
    // Context menu
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> NSSize {
        return .zero
    }
    
    // Drag and drop for reordering roster
    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        // Disable drag for smart collections (content is dynamic)
        guard let collection = collection, !collection.isSmartCollection else { return false }
        return collectionView == rosterCollectionView
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        guard collectionView == rosterCollectionView else { return nil }
        
        let item = NSPasteboardItem()
        item.setString(String(indexPath.item), forType: .rosterEntryDrag)
        return item
    }
    
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard collectionView == rosterCollectionView else { return [] }
        proposedDropOperation.pointee = .before
        return .move
    }
    
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard collectionView == rosterCollectionView,
              let collection = collection else { return false }
        
        guard let items = draggingInfo.draggingPasteboard.pasteboardItems,
              let item = items.first,
              let indexString = item.string(forType: .rosterEntryDrag),
              let sourceIndex = Int(indexString) else { return false }
        
        var destIndex = indexPath.item
        if sourceIndex < destIndex {
            destIndex -= 1
        }
        
        CollectionStore.shared.reorderCharacters(in: collection.id, from: sourceIndex, to: destIndex)
        return true
    }
}

// MARK: - Roster Entry Item

class RosterEntryItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("RosterEntryItem")
    
    private var containerView: NSView!
    private var thumbnailView: NSImageView!
    private var hoverOverlay: NSView!
    private var deleteButton: NSView!
    private var nameLabel: NSTextField!
    private var entry: RosterEntry?
    private var trackingArea: NSTrackingArea?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 96, height: 120))
        
        // Container with square aspect ratio for thumbnail
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        containerView.layer?.masksToBounds = true
        view.addSubview(containerView)
        
        // Thumbnail image (fills container)
        thumbnailView = NSImageView()
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)  // Center anchor for zoom
        thumbnailView.alphaValue = 0.8
        containerView.addSubview(thumbnailView)
        
        // Hover overlay (shown on hover)
        hoverOverlay = NSView()
        hoverOverlay.translatesAutoresizingMaskIntoConstraints = false
        hoverOverlay.wantsLayer = true
        hoverOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        hoverOverlay.alphaValue = 0
        containerView.addSubview(hoverOverlay)
        
        // Delete button (shown on hover) - red circle with trash icon
        // Using custom view approach for precise sizing control
        deleteButton = NSView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.wantsLayer = true
        deleteButton.layer?.backgroundColor = DesignColors.negative.cgColor
        deleteButton.layer?.cornerRadius = 16
        
        let trashIcon = NSImageView(frame: .zero)
        trashIcon.translatesAutoresizingMaskIntoConstraints = false
        trashIcon.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        trashIcon.contentTintColor = .white
        trashIcon.imageScaling = .scaleNone
        trashIcon.imageAlignment = .alignCenter
        deleteButton.addSubview(trashIcon)
        
        NSLayoutConstraint.activate([
            trashIcon.topAnchor.constraint(equalTo: deleteButton.topAnchor),
            trashIcon.leadingAnchor.constraint(equalTo: deleteButton.leadingAnchor),
            trashIcon.trailingAnchor.constraint(equalTo: deleteButton.trailingAnchor),
            trashIcon.bottomAnchor.constraint(equalTo: deleteButton.bottomAnchor),
        ])
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(deleteClicked))
        deleteButton.addGestureRecognizer(clickGesture)
        
        deleteButton.alphaValue = 0
        hoverOverlay.addSubview(deleteButton)
        
        // Name label below the card
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.label(size: 10)
        nameLabel.textColor = DesignColors.textSecondary
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        view.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            // Square container
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor),
            
            // Thumbnail fills container
            thumbnailView.topAnchor.constraint(equalTo: containerView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Hover overlay fills container
            hoverOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            hoverOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hoverOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hoverOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Delete button centered in overlay - fixed 32x32 circle
            deleteButton.centerXAnchor.constraint(equalTo: hoverOverlay.centerXAnchor),
            deleteButton.centerYAnchor.constraint(equalTo: hoverOverlay.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 32),
            deleteButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Name label below container
            nameLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
        ])
        
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            hoverOverlay.animator().alphaValue = 1
            deleteButton.animator().alphaValue = 1
            thumbnailView.animator().alphaValue = 1
            containerView.layer?.borderColor = DesignColors.borderHover.cgColor
        }
        // Scale up 5% centered - need to use CABasicAnimation for centered transform
        let bounds = thumbnailView.bounds
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, bounds.width/2, bounds.height/2, 0)
        transform = CATransform3DScale(transform, 1.05, 1.05, 1)
        transform = CATransform3DTranslate(transform, -bounds.width/2, -bounds.height/2, 0)
        
        let animation = CABasicAnimation(keyPath: "transform")
        animation.toValue = transform
        animation.duration = 0.3
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        thumbnailView.layer?.add(animation, forKey: "scaleUp")
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            hoverOverlay.animator().alphaValue = 0
            deleteButton.animator().alphaValue = 0
            thumbnailView.animator().alphaValue = 0.8
            updateBorderForSelection()
        }
        // Reset scale with animation
        let animation = CABasicAnimation(keyPath: "transform")
        animation.toValue = CATransform3DIdentity
        animation.duration = 0.3
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        thumbnailView.layer?.add(animation, forKey: "scaleDown")
    }
    
    @objc private func deleteClicked() {
        // Walk up the view hierarchy to find the collection view
        var currentView: NSView? = view
        var collectionView: NSCollectionView? = nil
        while let parent = currentView?.superview {
            if let cv = parent as? NSCollectionView {
                collectionView = cv
                break
            }
            currentView = parent
        }
        
        guard let cv = collectionView,
              let indexPath = cv.indexPath(for: self),
              let editorView = findCollectionEditorView(),
              let menu = editorView.buildRosterContextMenu(for: indexPath.item),
              let removeItem = menu.items.first(where: { $0.title == "Remove" }) else { return }
        
        // Trigger the remove action
        _ = removeItem.target?.perform(removeItem.action, with: removeItem)
    }
    
    func configure(with entry: RosterEntry) {
        self.entry = entry
        
        switch entry.entryType {
        case .character:
            // Look up character info for display name
            var displayName = entry.characterFolder ?? "Unknown"
            if let folder = entry.characterFolder,
               let character = IkemenBridge.shared.characters.first(where: { $0.directory.lastPathComponent == folder }) {
                displayName = character.displayName
            }
            nameLabel.stringValue = displayName
            nameLabel.textColor = DesignColors.textSecondary
            thumbnailView.image = NSImage(systemSymbolName: "person.fill", accessibilityDescription: nil)
            thumbnailView.contentTintColor = DesignColors.textSecondary
            
            // Load actual thumbnail
            if let folder = entry.characterFolder {
                loadThumbnail(for: folder)
            }
            
        case .randomSelect:
            nameLabel.stringValue = "Random"
            nameLabel.textColor = DesignColors.warning
            thumbnailView.image = NSImage(systemSymbolName: "questionmark.circle.fill", accessibilityDescription: nil)
            thumbnailView.contentTintColor = DesignColors.warning
            
        case .emptySlot:
            nameLabel.stringValue = "Empty"
            nameLabel.textColor = DesignColors.textDisabled
            thumbnailView.image = NSImage(systemSymbolName: "square.dashed", accessibilityDescription: nil)
            thumbnailView.contentTintColor = DesignColors.textDisabled
        }
    }
    
    private func loadThumbnail(for folder: String) {
        guard let _ = IkemenBridge.shared.workingDirectory else { return }
        
        // Find the character in the bridge's loaded characters
        if let character = IkemenBridge.shared.characters.first(where: { $0.directory.lastPathComponent == folder }) {
            if let cached = ImageCache.shared.getPortrait(for: character) {
                thumbnailView.image = cached
                thumbnailView.contentTintColor = nil
            }
        }
    }
    
    private func updateBorderForSelection() {
        if isSelected {
            containerView.layer?.borderWidth = 2
            containerView.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.8).cgColor
        } else {
            containerView.layer?.borderWidth = 1
            containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        }
    }
    
    override var isSelected: Bool {
        didSet {
            updateBorderForSelection()
            if isSelected {
                nameLabel.textColor = DesignColors.positive
            } else if let entry = entry {
                switch entry.entryType {
                case .character: nameLabel.textColor = DesignColors.textSecondary
                case .randomSelect: nameLabel.textColor = DesignColors.warning
                case .emptySlot: nameLabel.textColor = DesignColors.textDisabled
                }
            }
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let collectionView = view.superview?.superview?.superview as? NSCollectionView,
              let indexPath = collectionView.indexPath(for: self),
              let editorView = findCollectionEditorView() else {
            super.rightMouseDown(with: event)
            return
        }
        
        if let menu = editorView.buildRosterContextMenu(for: indexPath.item) {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
    }
    
    private func findCollectionEditorView() -> CollectionEditorView? {
        var responder: NSResponder? = view
        while let next = responder?.nextResponder {
            if let editor = next as? CollectionEditorView {
                return editor
            }
            responder = next
        }
        return nil
    }
}

// MARK: - Stage Entry Item

class StageEntryItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("StageEntryItem")
    
    private var containerView: NSView!
    private var thumbnailView: NSImageView!
    private var placeholderStack: NSStackView!  // "No Thumbnail" placeholder
    private var nameLabel: NSTextField!
    private var stageFolder: String?
    private var trackingArea: NSTrackingArea?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 192, height: 120))
        
        // Container with 16:9 aspect ratio
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        containerView.layer?.cornerRadius = 12
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        containerView.layer?.masksToBounds = true
        view.addSubview(containerView)
        
        // Thumbnail image
        thumbnailView = NSImageView()
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)  // Center anchor for zoom
        thumbnailView.alphaValue = 0.6
        containerView.addSubview(thumbnailView)
        
        // Placeholder stack for "No Thumbnail" message
        placeholderStack = NSStackView()
        placeholderStack.translatesAutoresizingMaskIntoConstraints = false
        placeholderStack.orientation = .vertical
        placeholderStack.alignment = .centerX
        placeholderStack.spacing = 2
        placeholderStack.isHidden = true
        containerView.addSubview(placeholderStack)
        
        let placeholderTitle = NSTextField(labelWithString: "No Thumbnail")
        placeholderTitle.font = DesignFonts.label(size: 11)
        placeholderTitle.textColor = DesignColors.textTertiary
        placeholderTitle.alignment = .center
        placeholderStack.addArrangedSubview(placeholderTitle)
        
        let placeholderSubtitle = NSTextField(labelWithString: "9000,0 not in SFF")
        placeholderSubtitle.font = DesignFonts.caption(size: 9)
        placeholderSubtitle.textColor = DesignColors.textDisabled
        placeholderSubtitle.alignment = .center
        placeholderStack.addArrangedSubview(placeholderSubtitle)
        
        // Name label below card (not overlaid)
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = DesignFonts.label(size: 10)
        nameLabel.textColor = DesignColors.textSecondary
        nameLabel.lineBreakMode = .byTruncatingTail
        view.addSubview(nameLabel)
        
        NSLayoutConstraint.activate([
            // 16:9 container
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 100),
            
            // Thumbnail fills container
            thumbnailView.topAnchor.constraint(equalTo: containerView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Placeholder centered in container
            placeholderStack.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Name label below
            nameLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
        ])
        
        setupTrackingArea()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.image = nil
        thumbnailView.alphaValue = 0.6
        placeholderStack.isHidden = true
        nameLabel.stringValue = ""
        stageFolder = nil
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
    }
    
    private func setupTrackingArea() {
        trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            thumbnailView.animator().alphaValue = 1.0
            containerView.layer?.borderColor = DesignColors.borderHover.cgColor
        }
        nameLabel.textColor = DesignColors.textPrimary
        
        // Scale up 5% centered
        let bounds = thumbnailView.bounds
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, bounds.width/2, bounds.height/2, 0)
        transform = CATransform3DScale(transform, 1.05, 1.05, 1)
        transform = CATransform3DTranslate(transform, -bounds.width/2, -bounds.height/2, 0)
        
        let animation = CABasicAnimation(keyPath: "transform")
        animation.toValue = transform
        animation.duration = 0.3
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        thumbnailView.layer?.add(animation, forKey: "scaleUp")
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            thumbnailView.animator().alphaValue = 0.6
            updateBorderForSelection()
        }
        nameLabel.textColor = isSelected ? DesignColors.positive : DesignColors.textSecondary
        
        // Reset scale with animation
        let animation = CABasicAnimation(keyPath: "transform")
        animation.toValue = CATransform3DIdentity
        animation.duration = 0.3
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        thumbnailView.layer?.add(animation, forKey: "scaleDown")
    }
    
    func configure(with folder: String) {
        self.stageFolder = folder
        
        // Normalize the folder string - remove .def extension if present
        let normalizedFolder = folder.lowercased().hasSuffix(".def")
            ? String(folder.dropLast(4))
            : folder
        
        // Look up stage info for display name
        let stageInfo = IkemenBridge.shared.stages.first(where: { stage in
            stage.id.lowercased() == normalizedFolder.lowercased()
        })
        
        nameLabel.stringValue = stageInfo?.name ?? normalizedFolder
        
        // Reset to placeholder state
        thumbnailView.image = nil
        thumbnailView.contentTintColor = nil
        placeholderStack.isHidden = true
        
        // Try to load thumbnail
        loadThumbnail(for: normalizedFolder, stageInfo: stageInfo)
    }
    
    private func loadThumbnail(for folder: String, stageInfo: StageInfo?) {
        // Check cache first
        let cacheKey = ImageCache.stagePreviewKey(for: folder)
        if let cached = ImageCache.shared.get(cacheKey) {
            showThumbnail(cached)
            return
        }
        
        // Load asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var image: NSImage? = nil
            
            // Try SFF extraction first (most common source)
            if let stage = stageInfo {
                image = stage.loadPreviewImage()
            }
            
            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                if let finalImage = image {
                    ImageCache.shared.set(finalImage, for: cacheKey)
                    self?.showThumbnail(finalImage)
                } else {
                    self?.showPlaceholder()
                }
            }
        }
    }
    
    private func showThumbnail(_ image: NSImage) {
        thumbnailView.image = image
        thumbnailView.alphaValue = 0.8
        placeholderStack.isHidden = true
    }
    
    private func showPlaceholder() {
        thumbnailView.image = nil
        placeholderStack.isHidden = false
    }
    
    private func updateBorderForSelection() {
        if isSelected {
            containerView.layer?.borderWidth = 2
            containerView.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.8).cgColor
        } else {
            containerView.layer?.borderWidth = 1
            containerView.layer?.borderColor = DesignColors.borderSubtle.cgColor
        }
    }
    
    override var isSelected: Bool {
        didSet {
            updateBorderForSelection()
            nameLabel.textColor = isSelected ? DesignColors.positive : DesignColors.textSecondary
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let collectionView = view.superview?.superview?.superview as? NSCollectionView,
              let indexPath = collectionView.indexPath(for: self),
              let editorView = findCollectionEditorView() else {
            super.rightMouseDown(with: event)
            return
        }
        
        if let menu = editorView.buildStageContextMenu(for: indexPath.item) {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
    }
    
    private func findCollectionEditorView() -> CollectionEditorView? {
        var responder: NSResponder? = view
        while let next = responder?.nextResponder {
            if let editor = next as? CollectionEditorView {
                return editor
            }
            responder = next
        }
        return nil
    }
}
