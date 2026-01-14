import Cocoa
import Combine

/// A flipped NSView that draws content from top-left instead of bottom-left
/// Used for scroll view document views to align content to top
private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// A detail panel showing character metadata
/// Matches HTML design: hero header with gradient, quick stats, attributes, move list
/// Always visible when Characters tab is active (no close button)
class CharacterDetailsView: NSView {
    
    // MARK: - Properties
    
    // Hero header elements
    private var heroContainerView: NSView!
    private var heroImageView: NSImageView!
    private var heroGradientLayer: CAGradientLayer!
    private var heroNameLabel: NSTextField!
    private var heroSeriesBadge: NSView!
    private var heroSeriesLabel: NSTextField!
    private var heroDateLabel: NSTextField!
    
    // Hero action buttons (shown on hover)
    private var heroActionsContainer: NSStackView!
    private var openFolderButton: NSButton!
    private var deleteButton: NSButton!
    private var heroTrackingArea: NSTrackingArea?
    
    // Quick stats
    private var statsGridView: NSStackView!
    private var authorStatView: NSView!
    private var versionStatView: NSView!
    
    // Source info section (from browser extension)
    private var sourceInfoHeader: NSTextField!
    private var sourceInfoContainer: NSView!
    private var sourceUrlLabel: NSTextField!
    private var scrapedDescriptionLabel: NSTextField!
    
    // Tags section
    private var tagsHeader: NSTextField!
    private var tagsContainerView: NSView!
    
    // Attributes section
    private var attributesHeader: NSTextField!
    private var attributesSubtitle: NSTextField!
    private var lifeBar: AttributeBarView!
    private var atkBar: AttributeBarView!
    private var defBar: AttributeBarView!
    private var powBar: AttributeBarView!
    
    // Palettes section
    private var palettesHeader: NSTextField!
    private var paletteStackView: NSStackView!
    
    // Move list section
    private var moveListHeader: NSTextField!
    private var moveListStackView: NSStackView!
    
    // Definition file section
    private var defFileHeader: NSTextField!
    private var defFileNameLabel: NSTextField!
    private var defFileCodeView: NSTextView!
    private var defFileScrollView: NSScrollView!
    
    // Scroll view
    private var scrollView: NSScrollView!
    private var contentView: NSView!
    
    // Dynamic constraints
    private var tagsTopConstraint: NSLayoutConstraint?
    
    private var currentCharacter: CharacterInfo?
    
    /// Callback when name is changed
    var onNameChanged: ((CharacterInfo, String) -> Void)?
    
    /// Callback when play is clicked
    var onPlayCharacter: ((CharacterInfo) -> Void)?
    
    /// Callback when open folder is clicked
    var onOpenFolder: ((CharacterInfo) -> Void)?
    
    /// Callback when delete is clicked
    var onDeleteCharacter: ((CharacterInfo) -> Void)?
    
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
        layer?.backgroundColor = DesignColors.zinc950.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        
        setupScrollView()
        setupContent()
    }
    
    // MARK: - Event Handling
    
    // Note: Removed custom hitTest override - was incorrectly checking bounds.contains(point)
    // without converting point to local coordinates. The default NSView.hitTest behavior is correct.
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        scrollView = NSScrollView(frame: bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)
        
        // Use FlippedView so content starts from top instead of bottom
        contentView = FlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
    
    private func setupContent() {
        let padding: CGFloat = 24
        let spacing: CGFloat = 32
        
        // === Hero Header ===
        heroContainerView = NSView()
        heroContainerView.translatesAutoresizingMaskIntoConstraints = false
        heroContainerView.wantsLayer = true
        heroContainerView.layer?.backgroundColor = DesignColors.zinc900.cgColor
        contentView.addSubview(heroContainerView)
        
        // Hero background image
        heroImageView = NSImageView()
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.imageScaling = .scaleProportionallyUpOrDown
        heroImageView.wantsLayer = true
        heroImageView.alphaValue = 0.3
        heroContainerView.addSubview(heroImageView)
        
        // Gradient overlay from-zinc-950 via-zinc-950/80 to-transparent
        heroGradientLayer = CAGradientLayer()
        heroGradientLayer.colors = [
            NSColor.clear.cgColor,
            DesignColors.zinc950.withAlphaComponent(0.8).cgColor,
            DesignColors.zinc950.cgColor
        ]
        heroGradientLayer.locations = [0.0, 0.5, 1.0]
        heroGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        heroGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        heroContainerView.layer?.addSublayer(heroGradientLayer)
        
        // Name label - large, bold, Montserrat-like
        heroNameLabel = NSTextField(labelWithString: "")
        heroNameLabel.translatesAutoresizingMaskIntoConstraints = false
        heroNameLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        heroNameLabel.textColor = .white
        heroNameLabel.lineBreakMode = .byTruncatingTail
        heroContainerView.addSubview(heroNameLabel)
        
        // Series badge + date row
        let badgeRow = NSStackView()
        badgeRow.translatesAutoresizingMaskIntoConstraints = false
        badgeRow.orientation = .horizontal
        badgeRow.alignment = .centerY
        badgeRow.spacing = 8
        heroContainerView.addSubview(badgeRow)
        
        heroSeriesBadge = NSView()
        heroSeriesBadge.translatesAutoresizingMaskIntoConstraints = false
        heroSeriesBadge.wantsLayer = true
        heroSeriesBadge.layer?.cornerRadius = 4
        heroSeriesBadge.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        badgeRow.addArrangedSubview(heroSeriesBadge)
        
        heroSeriesLabel = NSTextField(labelWithString: "MUGEN")
        heroSeriesLabel.translatesAutoresizingMaskIntoConstraints = false
        heroSeriesLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        heroSeriesLabel.textColor = .white
        heroSeriesBadge.addSubview(heroSeriesLabel)
        
        heroDateLabel = NSTextField(labelWithString: "")
        heroDateLabel.font = DesignFonts.caption(size: 12)
        heroDateLabel.textColor = DesignColors.zinc500
        badgeRow.addArrangedSubview(heroDateLabel)
        
        // Hero action buttons container (shown on hover)
        heroActionsContainer = NSStackView()
        heroActionsContainer.translatesAutoresizingMaskIntoConstraints = false
        heroActionsContainer.orientation = .horizontal
        heroActionsContainer.spacing = 8
        heroActionsContainer.alphaValue = 0  // Hidden by default
        heroContainerView.addSubview(heroActionsContainer)
        
        // Open folder button
        openFolderButton = createHeroActionButton(icon: "folder", action: #selector(openFolderClicked))
        heroActionsContainer.addArrangedSubview(openFolderButton)
        
        // Delete button
        deleteButton = createHeroActionButton(icon: "trash", action: #selector(deleteClicked))
        heroActionsContainer.addArrangedSubview(deleteButton)
        
        // === Quick Stats Grid ===
        statsGridView = NSStackView()
        statsGridView.translatesAutoresizingMaskIntoConstraints = false
        statsGridView.orientation = .horizontal
        statsGridView.distribution = .fillEqually
        statsGridView.spacing = 16
        contentView.addSubview(statsGridView)
        
        authorStatView = createStatCard(title: "Author", value: "—")
        versionStatView = createStatCard(title: "Version", value: "—")
        statsGridView.addArrangedSubview(authorStatView)
        statsGridView.addArrangedSubview(versionStatView)
        
        // === Source Info Section (from browser extension) ===
        sourceInfoHeader = NSTextField(labelWithString: "Source")
        sourceInfoHeader.translatesAutoresizingMaskIntoConstraints = false
        sourceInfoHeader.font = DesignFonts.body(size: 12)
        sourceInfoHeader.textColor = DesignColors.zinc400
        sourceInfoHeader.isHidden = true  // Hidden by default, shown when scraped data exists
        contentView.addSubview(sourceInfoHeader)
        
        sourceInfoContainer = NSView()
        sourceInfoContainer.translatesAutoresizingMaskIntoConstraints = false
        sourceInfoContainer.wantsLayer = true
        sourceInfoContainer.layer?.backgroundColor = DesignColors.zinc900.cgColor
        sourceInfoContainer.layer?.cornerRadius = 8
        sourceInfoContainer.layer?.borderWidth = 1
        sourceInfoContainer.layer?.borderColor = DesignColors.zinc800.cgColor
        sourceInfoContainer.isHidden = true  // Hidden by default
        contentView.addSubview(sourceInfoContainer)
        
        sourceUrlLabel = NSTextField(labelWithString: "")
        sourceUrlLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceUrlLabel.font = DesignFonts.caption(size: 11)
        sourceUrlLabel.textColor = NSColor.systemBlue
        sourceUrlLabel.isBordered = false
        sourceUrlLabel.drawsBackground = false
        sourceUrlLabel.lineBreakMode = .byTruncatingMiddle
        sourceUrlLabel.maximumNumberOfLines = 1
        sourceInfoContainer.addSubview(sourceUrlLabel)
        
        scrapedDescriptionLabel = NSTextField(labelWithString: "")
        scrapedDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        scrapedDescriptionLabel.font = DesignFonts.caption(size: 11)
        scrapedDescriptionLabel.textColor = DesignColors.zinc400
        scrapedDescriptionLabel.isBordered = false
        scrapedDescriptionLabel.drawsBackground = false
        scrapedDescriptionLabel.lineBreakMode = .byWordWrapping
        scrapedDescriptionLabel.maximumNumberOfLines = 3
        sourceInfoContainer.addSubview(scrapedDescriptionLabel)
        
        // === Tags Section ===
        tagsHeader = NSTextField(labelWithString: "Tags")
        tagsHeader.translatesAutoresizingMaskIntoConstraints = false
        tagsHeader.font = DesignFonts.body(size: 12)
        tagsHeader.textColor = DesignColors.zinc400
        contentView.addSubview(tagsHeader)
        
        tagsContainerView = NSView()
        tagsContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagsContainerView)
        
        // === Attributes Section ===
        let attributesContainer = NSView()
        attributesContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(attributesContainer)
        
        attributesHeader = NSTextField(labelWithString: "Attributes")
        attributesHeader.translatesAutoresizingMaskIntoConstraints = false
        attributesHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        attributesHeader.textColor = DesignColors.zinc100
        attributesContainer.addSubview(attributesHeader)
        
        attributesSubtitle = NSTextField(labelWithString: "Based on CNS data")
        attributesSubtitle.translatesAutoresizingMaskIntoConstraints = false
        attributesSubtitle.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        attributesSubtitle.textColor = DesignColors.zinc500
        attributesContainer.addSubview(attributesSubtitle)
        
        let barsStack = NSStackView()
        barsStack.translatesAutoresizingMaskIntoConstraints = false
        barsStack.orientation = .vertical
        barsStack.spacing = 12
        attributesContainer.addSubview(barsStack)
        
        lifeBar = AttributeBarView(label: "Life", value: 1000, maxValue: 1000, color: .white)
        atkBar = AttributeBarView(label: "Atk", value: 100, maxValue: 150, color: DesignColors.zinc400)
        defBar = AttributeBarView(label: "Def", value: 105, maxValue: 150, color: DesignColors.zinc400)
        powBar = AttributeBarView(label: "Pow", value: 3000, maxValue: 5000, color: NSColor.systemBlue.withAlphaComponent(0.7))
        
        barsStack.addArrangedSubview(lifeBar)
        barsStack.addArrangedSubview(atkBar)
        barsStack.addArrangedSubview(defBar)
        barsStack.addArrangedSubview(powBar)
        
        // === Palettes Section ===
        palettesHeader = NSTextField(labelWithString: "Palettes (1)")
        palettesHeader.translatesAutoresizingMaskIntoConstraints = false
        palettesHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        palettesHeader.textColor = DesignColors.zinc100
        contentView.addSubview(palettesHeader)
        
        paletteStackView = NSStackView()
        paletteStackView.translatesAutoresizingMaskIntoConstraints = false
        paletteStackView.orientation = .horizontal
        paletteStackView.spacing = 8
        paletteStackView.alignment = .centerY
        contentView.addSubview(paletteStackView)
        
        // === Move List Section ===
        moveListHeader = NSTextField(labelWithString: "Move List")
        moveListHeader.translatesAutoresizingMaskIntoConstraints = false
        moveListHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        moveListHeader.textColor = DesignColors.zinc100
        contentView.addSubview(moveListHeader)
        
        moveListStackView = NSStackView()
        moveListStackView.translatesAutoresizingMaskIntoConstraints = false
        moveListStackView.orientation = .vertical
        moveListStackView.alignment = .leading
        moveListStackView.spacing = 8
        contentView.addSubview(moveListStackView)
        
        // === Definition File Section ===
        let defFileHeaderRow = NSStackView()
        defFileHeaderRow.translatesAutoresizingMaskIntoConstraints = false
        defFileHeaderRow.orientation = .horizontal
        defFileHeaderRow.alignment = .centerY
        contentView.addSubview(defFileHeaderRow)
        
        defFileHeader = NSTextField(labelWithString: "Definition File")
        defFileHeader.translatesAutoresizingMaskIntoConstraints = false
        defFileHeader.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        defFileHeader.textColor = DesignColors.zinc100
        defFileHeaderRow.addArrangedSubview(defFileHeader)
        
        let defFileSpacer = NSView()
        defFileSpacer.translatesAutoresizingMaskIntoConstraints = false
        defFileSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        defFileHeaderRow.addArrangedSubview(defFileSpacer)
        
        defFileNameLabel = NSTextField(labelWithString: "")
        defFileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        defFileNameLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        defFileNameLabel.textColor = DesignColors.zinc600
        defFileHeaderRow.addArrangedSubview(defFileNameLabel)
        
        // Code view container
        let defFileContainer = NSView()
        defFileContainer.translatesAutoresizingMaskIntoConstraints = false
        defFileContainer.wantsLayer = true
        defFileContainer.layer?.cornerRadius = 8
        defFileContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        defFileContainer.layer?.borderWidth = 1
        defFileContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        contentView.addSubview(defFileContainer)
        
        defFileScrollView = NSScrollView()
        defFileScrollView.translatesAutoresizingMaskIntoConstraints = false
        defFileScrollView.hasVerticalScroller = false
        defFileScrollView.hasHorizontalScroller = false
        defFileScrollView.drawsBackground = false
        defFileScrollView.backgroundColor = .clear
        defFileContainer.addSubview(defFileScrollView)
        
        defFileCodeView = NSTextView()
        defFileCodeView.isEditable = false
        defFileCodeView.isSelectable = true
        defFileCodeView.backgroundColor = .clear
        defFileCodeView.drawsBackground = false
        defFileCodeView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        defFileCodeView.textColor = DesignColors.zinc400
        defFileScrollView.documentView = defFileCodeView
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Hero container
            heroContainerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            heroContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heroContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            heroContainerView.heightAnchor.constraint(equalToConstant: 192),
            
            heroImageView.topAnchor.constraint(equalTo: heroContainerView.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: heroContainerView.leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: heroContainerView.trailingAnchor),
            heroImageView.bottomAnchor.constraint(equalTo: heroContainerView.bottomAnchor),
            
            // Hero action buttons (top-right)
            heroActionsContainer.topAnchor.constraint(equalTo: heroContainerView.topAnchor, constant: 16),
            heroActionsContainer.trailingAnchor.constraint(equalTo: heroContainerView.trailingAnchor, constant: -16),
            
            heroNameLabel.leadingAnchor.constraint(equalTo: heroContainerView.leadingAnchor, constant: padding),
            heroNameLabel.bottomAnchor.constraint(equalTo: badgeRow.topAnchor, constant: -4),
            heroNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: heroContainerView.trailingAnchor, constant: -padding),
            
            badgeRow.leadingAnchor.constraint(equalTo: heroContainerView.leadingAnchor, constant: padding),
            badgeRow.bottomAnchor.constraint(equalTo: heroContainerView.bottomAnchor, constant: -padding),
            
            heroSeriesLabel.topAnchor.constraint(equalTo: heroSeriesBadge.topAnchor, constant: 2),
            heroSeriesLabel.bottomAnchor.constraint(equalTo: heroSeriesBadge.bottomAnchor, constant: -2),
            heroSeriesLabel.leadingAnchor.constraint(equalTo: heroSeriesBadge.leadingAnchor, constant: 8),
            heroSeriesLabel.trailingAnchor.constraint(equalTo: heroSeriesBadge.trailingAnchor, constant: -8),
            
            // Quick stats grid
            statsGridView.topAnchor.constraint(equalTo: heroContainerView.bottomAnchor, constant: padding),
            statsGridView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            statsGridView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            // Source info section
            sourceInfoHeader.topAnchor.constraint(equalTo: statsGridView.bottomAnchor, constant: spacing),
            sourceInfoHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            
            sourceInfoContainer.topAnchor.constraint(equalTo: sourceInfoHeader.bottomAnchor, constant: 12),
            sourceInfoContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            sourceInfoContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            sourceUrlLabel.topAnchor.constraint(equalTo: sourceInfoContainer.topAnchor, constant: 12),
            sourceUrlLabel.leadingAnchor.constraint(equalTo: sourceInfoContainer.leadingAnchor, constant: 12),
            sourceUrlLabel.trailingAnchor.constraint(equalTo: sourceInfoContainer.trailingAnchor, constant: -12),
            
            scrapedDescriptionLabel.topAnchor.constraint(equalTo: sourceUrlLabel.bottomAnchor, constant: 8),
            scrapedDescriptionLabel.leadingAnchor.constraint(equalTo: sourceInfoContainer.leadingAnchor, constant: 12),
            scrapedDescriptionLabel.trailingAnchor.constraint(equalTo: sourceInfoContainer.trailingAnchor, constant: -12),
            scrapedDescriptionLabel.bottomAnchor.constraint(equalTo: sourceInfoContainer.bottomAnchor, constant: -12),
            
            // Tags section - leadingAnchor only (topAnchor set dynamically)
            tagsHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            
            tagsContainerView.topAnchor.constraint(equalTo: tagsHeader.bottomAnchor, constant: 12),
            tagsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            tagsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            tagsContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
            
            // Attributes section
            attributesContainer.topAnchor.constraint(equalTo: tagsContainerView.bottomAnchor, constant: spacing),
            attributesContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            attributesContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            attributesHeader.topAnchor.constraint(equalTo: attributesContainer.topAnchor),
            attributesHeader.leadingAnchor.constraint(equalTo: attributesContainer.leadingAnchor),
            
            attributesSubtitle.centerYAnchor.constraint(equalTo: attributesHeader.centerYAnchor),
            attributesSubtitle.trailingAnchor.constraint(equalTo: attributesContainer.trailingAnchor),
            
            barsStack.topAnchor.constraint(equalTo: attributesHeader.bottomAnchor, constant: 16),
            barsStack.leadingAnchor.constraint(equalTo: attributesContainer.leadingAnchor),
            barsStack.trailingAnchor.constraint(equalTo: attributesContainer.trailingAnchor),
            barsStack.bottomAnchor.constraint(equalTo: attributesContainer.bottomAnchor),
            
            // Palettes section
            palettesHeader.topAnchor.constraint(equalTo: attributesContainer.bottomAnchor, constant: spacing),
            palettesHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            
            paletteStackView.topAnchor.constraint(equalTo: palettesHeader.bottomAnchor, constant: 12),
            paletteStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            paletteStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -padding),
            
            // Move list section
            moveListHeader.topAnchor.constraint(equalTo: paletteStackView.bottomAnchor, constant: spacing),
            moveListHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            
            moveListStackView.topAnchor.constraint(equalTo: moveListHeader.bottomAnchor, constant: 8),
            moveListStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            moveListStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            // Definition file section
            defFileHeaderRow.topAnchor.constraint(equalTo: moveListStackView.bottomAnchor, constant: spacing),
            defFileHeaderRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            defFileHeaderRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            defFileHeader.leadingAnchor.constraint(equalTo: defFileHeaderRow.leadingAnchor),
            defFileHeader.centerYAnchor.constraint(equalTo: defFileHeaderRow.centerYAnchor),
            
            defFileNameLabel.trailingAnchor.constraint(equalTo: defFileHeaderRow.trailingAnchor),
            defFileNameLabel.centerYAnchor.constraint(equalTo: defFileHeaderRow.centerYAnchor),
            defFileNameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: defFileHeader.trailingAnchor, constant: 8),
            defFileHeaderRow.heightAnchor.constraint(equalToConstant: 20),
            
            defFileContainer.topAnchor.constraint(equalTo: defFileHeaderRow.bottomAnchor, constant: 12),
            defFileContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            defFileContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            defFileContainer.heightAnchor.constraint(equalToConstant: 200),
            defFileContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),
            
            defFileScrollView.topAnchor.constraint(equalTo: defFileContainer.topAnchor),
            defFileScrollView.leadingAnchor.constraint(equalTo: defFileContainer.leadingAnchor),
            defFileScrollView.trailingAnchor.constraint(equalTo: defFileContainer.trailingAnchor),
            defFileScrollView.bottomAnchor.constraint(equalTo: defFileContainer.bottomAnchor),
        ])
        
        // Set initial dynamic constraint (no source info by default)
        tagsTopConstraint = tagsHeader.topAnchor.constraint(equalTo: statsGridView.bottomAnchor, constant: spacing)
        tagsTopConstraint?.isActive = true
        
        // Set up tracking area for hero hover
        setupHeroTracking()
    }
    
    override func layout() {
        super.layout()
        heroGradientLayer.frame = heroContainerView.bounds
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Update tracking area when bounds change
        if let existingArea = heroTrackingArea {
            heroContainerView.removeTrackingArea(existingArea)
        }
        
        heroTrackingArea = NSTrackingArea(
            rect: heroContainerView.bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        
        if let area = heroTrackingArea {
            heroContainerView.addTrackingArea(area)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            heroActionsContainer.animator().alphaValue = 1
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            heroActionsContainer.animator().alphaValue = 0
        }
    }
    
    private func setupHeroTracking() {
        heroTrackingArea = NSTrackingArea(
            rect: heroContainerView.bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        
        if let area = heroTrackingArea {
            heroContainerView.addTrackingArea(area)
        }
    }
    
    private func createHeroActionButton(icon: String, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setButtonType(.momentaryChange)
        button.bezelStyle = .smallSquare
        button.isBordered = false
        button.title = ""
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: icon) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
        }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.contentTintColor = DesignColors.zinc400
        button.target = self
        button.action = action
        
        // Force exact size - prevent intrinsic content size from overriding
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        
        let widthConstraint = button.widthAnchor.constraint(equalToConstant: 30)
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 30)
        widthConstraint.priority = .required
        heightConstraint.priority = .required
        NSLayoutConstraint.activate([widthConstraint, heightConstraint])
        
        return button
    }
    
    private func createStatCard(title: String, value: String) -> NSView {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = DesignColors.zinc900.withAlphaComponent(0.3).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        
        let titleLabel = NSTextField(labelWithString: title.uppercased())
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        titleLabel.textColor = DesignColors.zinc500
        card.addSubview(titleLabel)
        
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        valueLabel.textColor = DesignColors.zinc200
        valueLabel.tag = 100 // For updating later
        card.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 64),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),
        ])
        
        return card
    }
    
    private func createTagBadge(_ text: String) -> NSView {
        let badge = NSView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.wantsLayer = true
        badge.layer?.backgroundColor = DesignColors.zinc800.cgColor
        badge.layer?.cornerRadius = 6
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.caption(size: 11)
        label.textColor = DesignColors.zinc300
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        badge.addSubview(label)
        
        NSLayoutConstraint.activate([
            // Fixed height for consistent badge sizing
            badge.heightAnchor.constraint(equalToConstant: 24),
            
            // Center label vertically, pin horizontally
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -8),
        ])
        
        return badge
    }
    
    /// Layouts tag badges in a flow/wrap pattern
    private func layoutTagsInFlowLayout(badges: [NSView], in container: NSView) {
        guard !badges.isEmpty else { return }
        
        let horizontalSpacing: CGFloat = 8
        let verticalSpacing: CGFloat = 8
        let containerWidth = container.bounds.width > 0 ? container.bounds.width : 280 // fallback width
        
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowBadges: [[NSView]] = [[]]
        
        // First pass: calculate intrinsic sizes and determine rows
        for badge in badges {
            badge.layoutSubtreeIfNeeded()
            let badgeSize = badge.fittingSize
            
            // Check if badge fits in current row
            if currentX + badgeSize.width > containerWidth && currentX > 0 {
                // Start new row
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
                rowBadges.append([])
            }
            
            rowBadges[rowBadges.count - 1].append(badge)
            currentX += badgeSize.width + horizontalSpacing
            rowHeight = max(rowHeight, badgeSize.height)
        }
        
        // Second pass: apply constraints
        currentX = 0
        currentY = 0
        rowHeight = 0
        var previousBadgeInRow: NSView? = nil
        var previousRowFirstBadge: NSView? = nil
        
        for (rowIndex, row) in rowBadges.enumerated() {
            previousBadgeInRow = nil
            
            for (badgeIndex, badge) in row.enumerated() {
                let badgeSize = badge.fittingSize
                
                if badgeIndex == 0 {
                    // First badge in row - anchor to leading edge
                    badge.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
                    
                    if rowIndex == 0 {
                        // First row - anchor to top
                        badge.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
                    } else if let prevRowBadge = previousRowFirstBadge {
                        // Subsequent rows - anchor below previous row
                        badge.topAnchor.constraint(equalTo: prevRowBadge.bottomAnchor, constant: verticalSpacing).isActive = true
                    }
                    previousRowFirstBadge = badge
                } else if let prevBadge = previousBadgeInRow {
                    // Subsequent badges - anchor to previous badge
                    badge.leadingAnchor.constraint(equalTo: prevBadge.trailingAnchor, constant: horizontalSpacing).isActive = true
                    badge.topAnchor.constraint(equalTo: prevBadge.topAnchor).isActive = true
                }
                
                previousBadgeInRow = badge
            }
        }
        
        // Set container height based on last row
        if let lastBadge = badges.last {
            lastBadge.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func openFolderClicked() {
        if let character = currentCharacter {
            onOpenFolder?(character)
        }
    }
    
    @objc private func deleteClicked() {
        if let character = currentCharacter {
            onDeleteCharacter?(character)
        }
    }
    
    // MARK: - Public Methods
    
    func configure(with character: CharacterInfo) {
        currentCharacter = character
        
        // Hero
        heroNameLabel.stringValue = character.displayName
        let formattedDate = VersionDateFormatter.formatToStandard(character.versionDate)
        heroDateLabel.stringValue = formattedDate.isEmpty ? "" : "Updated \(formattedDate)"
        
        // Load extended info (includes CNS stats)
        let extendedInfo = CharacterExtendedInfo(from: character)
        
        // Quick stats
        if let authorValue = authorStatView.viewWithTag(100) as? NSTextField {
            authorValue.stringValue = character.author
        }
        if let versionValue = versionStatView.viewWithTag(100) as? NSTextField {
            let versionDateFormatted = VersionDateFormatter.formatToStandard(extendedInfo.versionDate)
            versionValue.stringValue = versionDateFormatted.isEmpty ? "1.0" : versionDateFormatted
        }
        
        // Update attribute bars with real CNS data
        lifeBar.update(value: extendedInfo.life, maxValue: CNSParser.CharacterStats.maxLife)
        atkBar.update(value: extendedInfo.attack, maxValue: CNSParser.CharacterStats.maxAttack)
        defBar.update(value: extendedInfo.defence, maxValue: CNSParser.CharacterStats.maxDefence)
        powBar.update(value: extendedInfo.power, maxValue: CNSParser.CharacterStats.maxPower)
        
        // Palettes
        updatePalettes(count: extendedInfo.paletteCount)
        
        // Tags
        updateTags(for: character)
        
        // Load scraped metadata from database
        loadScrapedMetadata(for: character)
        
        // Load move list
        loadMoveList(for: character)
        
        // Load definition file content
        loadDefinitionFile(for: character)
        
        // Load portrait for hero background
        loadPortrait(for: character)
    }
    
    private func loadPortrait(for character: CharacterInfo) {
        let cacheKey = ImageCache.portraitKey(for: character.id)
        if let cached = ImageCache.shared.get(cacheKey) {
            heroImageView.image = cached
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let portrait = character.getPortraitImage()
            
            DispatchQueue.main.async {
                if let portrait = portrait {
                    self?.heroImageView.image = portrait
                    ImageCache.shared.set(portrait, for: cacheKey)
                }
            }
        }
    }
    
    private func updatePalettes(count: Int) {
        palettesHeader.stringValue = "Palettes (\(count))"
        
        // Clear existing
        paletteStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add palette dots (up to 6, then +N)
        let colors: [NSColor] = [.white, DesignColors.zinc700, .systemBlue, .systemRed, .systemPurple, .systemYellow]
        let displayCount = min(count, 6)
        
        for i in 0..<displayCount {
            let dot = NSView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 12
            dot.layer?.backgroundColor = colors[i % colors.count].cgColor
            dot.layer?.borderWidth = 1
            dot.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
            
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 24),
                dot.heightAnchor.constraint(equalToConstant: 24),
            ])
            
            paletteStackView.addArrangedSubview(dot)
        }
        
        // Add +N if more palettes
        if count > 6 {
            let moreContainer = NSView()
            moreContainer.translatesAutoresizingMaskIntoConstraints = false
            moreContainer.wantsLayer = true
            moreContainer.layer?.cornerRadius = 12
            moreContainer.layer?.backgroundColor = DesignColors.zinc900.cgColor
            moreContainer.layer?.borderWidth = 1
            moreContainer.layer?.borderColor = DesignColors.zinc700.cgColor
            
            let moreLabel = NSTextField(labelWithString: "+\(count - 6)")
            moreLabel.translatesAutoresizingMaskIntoConstraints = false
            moreLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            moreLabel.textColor = DesignColors.zinc500
            moreLabel.isBordered = false
            moreLabel.drawsBackground = false
            moreLabel.alignment = .center
            moreContainer.addSubview(moreLabel)
            
            NSLayoutConstraint.activate([
                moreContainer.widthAnchor.constraint(equalToConstant: 24),
                moreContainer.heightAnchor.constraint(equalToConstant: 24),
                moreLabel.centerXAnchor.constraint(equalTo: moreContainer.centerXAnchor),
                moreLabel.centerYAnchor.constraint(equalTo: moreContainer.centerYAnchor),
            ])
            
            paletteStackView.addArrangedSubview(moreContainer)
        }
    }
    
    private func updateTags(for character: CharacterInfo) {
        // Clear existing tags
        tagsContainerView.subviews.forEach { $0.removeFromSuperview() }
        
        let tags = character.inferredTags
        
        if tags.isEmpty {
            // Show "No tags detected" message
            let noTagsLabel = NSTextField(labelWithString: "No tags detected")
            noTagsLabel.translatesAutoresizingMaskIntoConstraints = false
            noTagsLabel.font = DesignFonts.caption(size: 11)
            noTagsLabel.textColor = DesignColors.zinc500
            noTagsLabel.isBordered = false
            noTagsLabel.drawsBackground = false
            tagsContainerView.addSubview(noTagsLabel)
            
            NSLayoutConstraint.activate([
                noTagsLabel.topAnchor.constraint(equalTo: tagsContainerView.topAnchor),
                noTagsLabel.leadingAnchor.constraint(equalTo: tagsContainerView.leadingAnchor),
                noTagsLabel.bottomAnchor.constraint(equalTo: tagsContainerView.bottomAnchor),
            ])
        } else {
            // Create badges and manually position them in a wrapping flow layout
            var badges: [NSView] = []
            for tag in tags {
                let badge = createTagBadge(tag)
                tagsContainerView.addSubview(badge)
                badges.append(badge)
            }
            
            // Layout badges in a flow/wrap pattern
            layoutTagsInFlowLayout(badges: badges, in: tagsContainerView)
        }
    }
    
    // MARK: - Scraped Metadata
    
    private func loadScrapedMetadata(for character: CharacterInfo) {
        // Try to load scraped metadata from database
        guard let metadata = try? MetadataStore.shared.scrapedMetadata(for: character.id) else {
            // No scraped metadata - hide the section
            sourceInfoHeader.isHidden = true
            sourceInfoContainer.isHidden = true
            
            // Update dynamic constraint to anchor tags to stats grid
            tagsTopConstraint?.isActive = false
            tagsTopConstraint = tagsHeader.topAnchor.constraint(equalTo: statsGridView.bottomAnchor, constant: 32)
            tagsTopConstraint?.isActive = true
            return
        }
        
        // Show the source info section
        sourceInfoHeader.isHidden = false
        sourceInfoContainer.isHidden = false
        
        // Update dynamic constraint to anchor tags to source info
        tagsTopConstraint?.isActive = false
        tagsTopConstraint = tagsHeader.topAnchor.constraint(equalTo: sourceInfoContainer.bottomAnchor, constant: 32)
        tagsTopConstraint?.isActive = true
        
        // Display source URL
        if let url = URL(string: metadata.sourceUrl) {
            sourceUrlLabel.stringValue = "🔗 \(url.host ?? metadata.sourceUrl)"
        } else {
            sourceUrlLabel.stringValue = "🔗 \(metadata.sourceUrl)"
        }
        
        // Display description if available
        if let description = metadata.description, !description.isEmpty {
            scrapedDescriptionLabel.stringValue = description
        } else {
            scrapedDescriptionLabel.stringValue = "No description available"
        }
        
        // Override version if scraped version is available
        if let version = metadata.version, !version.isEmpty,
           let versionValue = versionStatView.viewWithTag(100) as? NSTextField {
            versionValue.stringValue = version
        }
        
        // Override author if scraped author is available
        if let author = metadata.author, !author.isEmpty,
           let authorValue = authorStatView.viewWithTag(100) as? NSTextField {
            authorValue.stringValue = author
        }
    }
    
    // MARK: - Move List
    
    private func loadMoveList(for character: CharacterInfo) {
        moveListStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let moves = CMDParser.parseMoves(for: character)
        
        if moves.isEmpty {
            let noMovesLabel = NSTextField(labelWithString: "No special moves found")
            noMovesLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            noMovesLabel.textColor = DesignColors.zinc500
            moveListStackView.addArrangedSubview(noMovesLabel)
        } else {
            for move in moves.prefix(10) { // Limit to 10 for UI
                let moveView = createMoveRow(move)
                moveListStackView.addArrangedSubview(moveView)
            }
            
            if moves.count > 10 {
                let moreLabel = NSTextField(labelWithString: "+\(moves.count - 10) more moves...")
                moreLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
                moreLabel.textColor = DesignColors.zinc600
                moveListStackView.addArrangedSubview(moreLabel)
            }
        }
    }
    
    // MARK: - Definition File
    
    private func loadDefinitionFile(for character: CharacterInfo) {
        // Update the filename label
        let defFileName = character.defFile.lastPathComponent
        defFileNameLabel.stringValue = defFileName
        
        // Read and display the definition file content
        if let content = DEFParser.readFileContent(from: character.defFile) {
            let attributedContent = syntaxHighlightDEF(content)
            defFileCodeView.textStorage?.setAttributedString(attributedContent)
        } else {
            let errorAttr = NSAttributedString(
                string: "Unable to read definition file",
                attributes: [
                    .foregroundColor: DesignColors.zinc500,
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                ]
            )
            defFileCodeView.textStorage?.setAttributedString(errorAttr)
        }
    }
    
    /// Apply syntax highlighting to DEF file content
    private func syntaxHighlightDEF(_ content: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        let defaultFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            var lineAttr: NSAttributedString
            
            if trimmed.hasPrefix(";") {
                // Comment - gray
                lineAttr = NSAttributedString(
                    string: line,
                    attributes: [
                        .foregroundColor: DesignColors.zinc600,
                        .font: defaultFont
                    ]
                )
            } else if trimmed.hasPrefix("[") && trimmed.contains("]") {
                // Section header - blue
                lineAttr = NSAttributedString(
                    string: line,
                    attributes: [
                        .foregroundColor: NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0),
                        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
                    ]
                )
            } else if trimmed.contains("=") {
                // Key-value pair
                let parts = line.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let keyPart = NSAttributedString(
                        string: String(parts[0]) + "=",
                        attributes: [
                            .foregroundColor: NSColor(red: 0.8, green: 0.6, blue: 1.0, alpha: 1.0),
                            .font: defaultFont
                        ]
                    )
                    let valuePart = NSAttributedString(
                        string: String(parts[1]),
                        attributes: [
                            .foregroundColor: DesignColors.zinc300,
                            .font: defaultFont
                        ]
                    )
                    let combined = NSMutableAttributedString()
                    combined.append(keyPart)
                    combined.append(valuePart)
                    lineAttr = combined
                } else {
                    lineAttr = NSAttributedString(
                        string: line,
                        attributes: [
                            .foregroundColor: DesignColors.zinc400,
                            .font: defaultFont
                        ]
                    )
                }
            } else {
                // Default - light gray
                lineAttr = NSAttributedString(
                    string: line,
                    attributes: [
                        .foregroundColor: DesignColors.zinc400,
                        .font: defaultFont
                    ]
                )
            }
            
            result.append(lineAttr)
            
            // Add newline except for last line
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        
        return result
    }
    
    private func createMoveRow(_ move: MoveCommand) -> NSView {
        let row = NSStackView()
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 2
        
        let nameLabel = NSTextField(labelWithString: move.displayName)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = DesignColors.zinc300
        row.addArrangedSubview(nameLabel)
        
        let inputLabel = NSTextField(labelWithString: move.notation)
        inputLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        inputLabel.textColor = DesignColors.zinc500
        row.addArrangedSubview(inputLabel)
        
        return row
    }
    
    /// Show placeholder when no character is selected
    func showPlaceholder() {
        currentCharacter = nil
        heroNameLabel.stringValue = "Select a Character"
        heroDateLabel.stringValue = ""
        heroImageView.image = nil
        
        if let authorValue = authorStatView.viewWithTag(100) as? NSTextField {
            authorValue.stringValue = "—"
        }
        if let versionValue = versionStatView.viewWithTag(100) as? NSTextField {
            versionValue.stringValue = "—"
        }
        
        palettesHeader.stringValue = "Palettes"
        paletteStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Clear tags
        tagsContainerView.subviews.forEach { $0.removeFromSuperview() }
        
        moveListStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let placeholderLabel = NSTextField(labelWithString: "Select a character to view details")
        placeholderLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        placeholderLabel.textColor = DesignColors.zinc500
        moveListStackView.addArrangedSubview(placeholderLabel)
        
        // Clear definition file
        defFileNameLabel.stringValue = ""
        defFileCodeView.string = ""
    }
}

// MARK: - Attribute Bar View

class AttributeBarView: NSView {
    private let labelText: String
    private var currentValue: Int
    private var currentMaxValue: Int
    private let barColor: NSColor
    
    private var barFillView: NSView!
    private var barTrack: NSView!
    private var valueLabel: NSTextField!
    private var barFillWidthConstraint: NSLayoutConstraint?
    
    init(label: String, value: Int, maxValue: Int, color: NSColor) {
        self.labelText = label
        self.currentValue = value
        self.currentMaxValue = maxValue
        self.barColor = color
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // Label (fixed width)
        let label = NSTextField(labelWithString: labelText)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.caption(size: 12)
        label.textColor = DesignColors.zinc500
        addSubview(label)
        
        // Bar track
        barTrack = NSView()
        barTrack.translatesAutoresizingMaskIntoConstraints = false
        barTrack.wantsLayer = true
        barTrack.layer?.cornerRadius = 3
        barTrack.layer?.backgroundColor = DesignColors.zinc800.cgColor
        addSubview(barTrack)
        
        // Bar fill
        barFillView = NSView()
        barFillView.translatesAutoresizingMaskIntoConstraints = false
        barFillView.wantsLayer = true
        barFillView.layer?.cornerRadius = 3
        barFillView.layer?.backgroundColor = barColor.cgColor
        barTrack.addSubview(barFillView)
        
        // Value label
        valueLabel = NSTextField(labelWithString: "\(currentValue)")
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = DesignColors.zinc300
        valueLabel.alignment = .right
        addSubview(valueLabel)
        
        let percentage = CGFloat(currentValue) / CGFloat(currentMaxValue)
        barFillWidthConstraint = barFillView.widthAnchor.constraint(equalTo: barTrack.widthAnchor, multiplier: min(1.0, max(0.0, percentage)))
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 20),
            
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 48),
            
            barTrack.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            barTrack.centerYAnchor.constraint(equalTo: centerYAnchor),
            barTrack.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -12),
            barTrack.heightAnchor.constraint(equalToConstant: 6),
            
            barFillView.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFillView.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFillView.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            barFillWidthConstraint!,
            
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 48),
        ])
    }
    
    func update(value: Int, maxValue: Int) {
        currentValue = value
        currentMaxValue = maxValue
        valueLabel.stringValue = "\(value)"
        
        // Remove old constraint and add new one with updated multiplier
        if let oldConstraint = barFillWidthConstraint {
            oldConstraint.isActive = false
        }
        
        let percentage = CGFloat(value) / CGFloat(maxValue)
        barFillWidthConstraint = barFillView.widthAnchor.constraint(equalTo: barTrack.widthAnchor, multiplier: min(1.0, max(0.01, percentage)))
        barFillWidthConstraint?.isActive = true
        
        // Animate the change
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.layoutSubtreeIfNeeded()
        }
    }
}

// MARK: - Character Extended Info

struct CharacterExtendedInfo {
    let paletteCount: Int
    let mugenVersion: String
    let versionDate: String
    
    // Stats from CNS file
    let life: Int
    let attack: Int
    let defence: Int
    let power: Int
    
    init(from character: CharacterInfo) {
        let defFile = character.defFile
        
        var palCount = 0
        var mugenVer = "Ikemen GO / MUGEN 1.0+"
        let verDate = character.versionDate
        
        if let content = DEFParser.readFileContent(from: defFile) {
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
                
                // Count palette entries (pal1 through pal12)
                if trimmed.hasPrefix("pal") && trimmed.contains("=") {
                    let parts = trimmed.split(separator: "=")
                    if parts.count == 2 {
                        let palKey = String(parts[0]).trimmingCharacters(in: .whitespaces)
                        let palValue = String(parts[1]).trimmingCharacters(in: .whitespaces)
                        if palKey.hasPrefix("pal"), let _ = Int(String(palKey.dropFirst(3))), !palValue.isEmpty {
                            palCount += 1
                        }
                    }
                }
                
                // Check MUGEN version
                if trimmed.hasPrefix("mugenversion") && trimmed.contains("=") {
                    let parts = trimmed.split(separator: "=")
                    if parts.count == 2 {
                        let version = String(parts[1]).trimmingCharacters(in: .whitespaces)
                        if version.contains("1.1") {
                            mugenVer = "MUGEN 1.1"
                        } else if version.contains("1.0") {
                            mugenVer = "MUGEN 1.0"
                        } else if version.contains("win") || version.contains("04") {
                            mugenVer = "WinMUGEN"
                        } else {
                            mugenVer = "MUGEN \(version)"
                        }
                    }
                }
            }
        }
        
        self.paletteCount = max(palCount, 1)
        self.mugenVersion = mugenVer
        self.versionDate = verDate
        
        // Load stats from CNS file
        let stats = CNSParser.getStats(for: character.directory, defFile: defFile)
        self.life = stats.life
        self.attack = stats.attack
        self.defence = stats.defence
        self.power = stats.power
    }
}

// MARK: - Move Command

struct MoveCommand {
    let name: String       // Internal name (e.g., "SpecialX")
    let displayName: String // Human-readable name
    let command: String    // Raw command (e.g., "~D,DF,F, x")
    let notation: String   // Pretty notation (e.g., "↓↘→ + LP")
}

// MARK: - CMD Parser

struct CMDParser {
    
    /// Parse special moves from a character's CMD file
    static func parseMoves(for character: CharacterInfo) -> [MoveCommand] {
        // Find CMD file
        guard let cmdFile = findCMDFile(for: character),
              let content = try? String(contentsOf: cmdFile, encoding: .utf8) else {
            return []
        }
        
        var moves: [MoveCommand] = []
        var seenCommands = Set<String>()
        
        let lines = content.components(separatedBy: .newlines)
        var currentName: String?
        var currentCommand: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix(";") {
                continue
            }
            
            let lower = trimmed.lowercased()
            
            // Parse name = "..."
            if lower.hasPrefix("name") && lower.contains("=") {
                if let nameMatch = extractQuotedValue(from: trimmed) {
                    currentName = nameMatch
                }
            }
            
            // Parse command = ...
            if lower.hasPrefix("command") && lower.contains("=") {
                if let eqIdx = trimmed.firstIndex(of: "=") {
                    currentCommand = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                }
            }
            
            // If we have both name and command, create a move
            if let name = currentName, let command = currentCommand {
                // Skip AI commands and basic movement
                let skipPrefixes = ["AI_", "holdfwd", "holdback", "holdup", "holddown", "recovery", "fwd", "back", "up", "down"]
                let shouldSkip = skipPrefixes.contains { name.lowercased().hasPrefix($0.lowercased()) } ||
                                 name.lowercased() == "run" ||
                                 name.lowercased() == "dash"
                
                // Only include special/hyper moves
                if !shouldSkip && isSpecialMove(command: command) {
                    let key = "\(name)|\(command)"
                    if !seenCommands.contains(key) {
                        seenCommands.insert(key)
                        
                        let displayName = formatMoveName(name)
                        let notation = formatNotation(command)
                        
                        moves.append(MoveCommand(
                            name: name,
                            displayName: displayName,
                            command: command,
                            notation: notation
                        ))
                    }
                }
                
                currentName = nil
                currentCommand = nil
            }
        }
        
        // Sort: Hypers first, then specials
        return moves.sorted { m1, m2 in
            let isHyper1 = m1.name.lowercased().contains("hyper") || m1.name.lowercased().contains("super")
            let isHyper2 = m2.name.lowercased().contains("hyper") || m2.name.lowercased().contains("super")
            if isHyper1 != isHyper2 { return isHyper1 }
            return m1.displayName < m2.displayName
        }
    }
    
    private static func findCMDFile(for character: CharacterInfo) -> URL? {
        let fileManager = FileManager.default
        
        // First, check the DEF file for cmd reference
        if let content = DEFParser.readFileContent(from: character.defFile) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
                if trimmed.hasPrefix("cmd") && trimmed.contains("=") {
                    if let eqIdx = line.firstIndex(of: "=") {
                        let cmdName = String(line[line.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                        let cmdPath = character.directory.appendingPathComponent(cmdName)
                        if fileManager.fileExists(atPath: cmdPath.path) {
                            return cmdPath
                        }
                    }
                }
            }
        }
        
        // Fallback: look for .cmd file with same name as character
        let defName = character.defFile.deletingPathExtension().lastPathComponent
        let cmdFile = character.directory.appendingPathComponent("\(defName).cmd")
        if fileManager.fileExists(atPath: cmdFile.path) {
            return cmdFile
        }
        
        // Last resort: any .cmd file
        if let contents = try? fileManager.contentsOfDirectory(at: character.directory, includingPropertiesForKeys: nil) {
            return contents.first { $0.pathExtension.lowercased() == "cmd" }
        }
        
        return nil
    }
    
    private static func extractQuotedValue(from line: String) -> String? {
        guard let firstQuote = line.firstIndex(of: "\""),
              let lastQuote = line.lastIndex(of: "\""),
              firstQuote != lastQuote else {
            return nil
        }
        return String(line[line.index(after: firstQuote)..<lastQuote])
    }
    
    private static func isSpecialMove(command: String) -> Bool {
        let lower = command.lowercased()
        // Special moves typically have direction sequences
        let hasDirectionSequence = lower.contains("~d") || lower.contains("~f") || lower.contains("~b") ||
                                   lower.contains(",d") || lower.contains(",f") || lower.contains(",b") ||
                                   lower.contains("df") || lower.contains("db") || lower.contains("uf") || lower.contains("ub")
        // And end with a button
        let hasButton = lower.contains("x") || lower.contains("y") || lower.contains("z") ||
                       lower.contains("a") || lower.contains("b") || lower.contains("c")
        return hasDirectionSequence && hasButton
    }
    
    private static func formatMoveName(_ name: String) -> String {
        // Convert "SpecialX" to "Special X", "Hyper1" to "Hyper 1", etc.
        let result = name
        
        // Insert space before capital letters and numbers
        var formatted = ""
        for (i, char) in result.enumerated() {
            if i > 0 && (char.isUppercase || char.isNumber) {
                let prevChar = result[result.index(result.startIndex, offsetBy: i - 1)]
                if !prevChar.isUppercase && !prevChar.isNumber && prevChar != " " {
                    formatted += " "
                }
            }
            formatted += String(char)
        }
        
        return formatted
    }
    
    private static func formatNotation(_ command: String) -> String {
        var result = command
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "~", with: "")
        
        // Direction mappings
        let directionMap: [(String, String)] = [
            ("DF", "↘"),
            ("DB", "↙"),
            ("UF", "↗"),
            ("UB", "↖"),
            ("D", "↓"),
            ("U", "↑"),
            ("F", "→"),
            ("B", "←"),
        ]
        
        // Button mappings (case-sensitive for final output)
        let buttonMap: [(String, String)] = [
            ("x+y", "LP+MP"),
            ("y+z", "MP+HP"),
            ("x+z", "LP+HP"),
            ("a+b", "LK+MK"),
            ("b+c", "MK+HK"),
            ("a+c", "LK+HK"),
            ("x", "LP"),
            ("y", "MP"),
            ("z", "HP"),
            ("a", "LK"),
            ("b", "MK"),
            ("c", "HK"),
        ]
        
        // Apply direction mappings (case-insensitive)
        for (from, to) in directionMap {
            result = result.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        
        // Apply button mappings
        for (from, to) in buttonMap {
            result = result.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        
        // Clean up separators
        result = result.replacingOccurrences(of: ",", with: " ")
        
        // Add + before button at the end
        let buttons = ["LP", "MP", "HP", "LK", "MK", "HK", "LP+MP", "MP+HP", "LP+HP", "LK+MK", "MK+HK", "LK+HK"]
        for button in buttons {
            if result.hasSuffix(button) && !result.hasSuffix("+ \(button)") {
                let prefix = String(result.dropLast(button.count)).trimmingCharacters(in: .whitespaces)
                if !prefix.isEmpty {
                    result = "\(prefix) + \(button)"
                }
                break
            }
        }
        
        return result
    }
}
