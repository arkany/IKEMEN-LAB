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
    private var playButton: NSButton!
    
    // Quick stats
    private var statsGridView: NSStackView!
    private var authorStatView: NSView!
    private var versionStatView: NSView!
    
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
    
    // Scroll view
    private var scrollView: NSScrollView!
    private var contentView: NSView!
    
    private var currentCharacter: CharacterInfo?
    
    /// Callback when name is changed
    var onNameChanged: ((CharacterInfo, String) -> Void)?
    
    /// Callback when play is clicked
    var onPlayCharacter: ((CharacterInfo) -> Void)?
    
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
        
        // Play button (white circle with play icon)
        playButton = NSButton(title: "▶", target: self, action: #selector(playClicked))
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.bezelStyle = .inline
        playButton.isBordered = false
        playButton.wantsLayer = true
        playButton.layer?.cornerRadius = 16
        playButton.layer?.backgroundColor = NSColor.white.cgColor
        playButton.contentTintColor = DesignColors.zinc950
        playButton.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        heroContainerView.addSubview(playButton)
        
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
            
            heroNameLabel.leadingAnchor.constraint(equalTo: heroContainerView.leadingAnchor, constant: padding),
            heroNameLabel.bottomAnchor.constraint(equalTo: badgeRow.topAnchor, constant: -4),
            heroNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -16),
            
            badgeRow.leadingAnchor.constraint(equalTo: heroContainerView.leadingAnchor, constant: padding),
            badgeRow.bottomAnchor.constraint(equalTo: heroContainerView.bottomAnchor, constant: -padding),
            
            heroSeriesLabel.topAnchor.constraint(equalTo: heroSeriesBadge.topAnchor, constant: 2),
            heroSeriesLabel.bottomAnchor.constraint(equalTo: heroSeriesBadge.bottomAnchor, constant: -2),
            heroSeriesLabel.leadingAnchor.constraint(equalTo: heroSeriesBadge.leadingAnchor, constant: 8),
            heroSeriesLabel.trailingAnchor.constraint(equalTo: heroSeriesBadge.trailingAnchor, constant: -8),
            
            playButton.trailingAnchor.constraint(equalTo: heroContainerView.trailingAnchor, constant: -padding),
            playButton.bottomAnchor.constraint(equalTo: heroContainerView.bottomAnchor, constant: -padding),
            playButton.widthAnchor.constraint(equalToConstant: 32),
            playButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Quick stats grid
            statsGridView.topAnchor.constraint(equalTo: heroContainerView.bottomAnchor, constant: padding),
            statsGridView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            statsGridView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            // Attributes section
            attributesContainer.topAnchor.constraint(equalTo: statsGridView.bottomAnchor, constant: spacing),
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
            moveListStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),
        ])
    }
    
    override func layout() {
        super.layout()
        heroGradientLayer.frame = heroContainerView.bounds
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
    
    // MARK: - Actions
    
    @objc private func playClicked() {
        if let character = currentCharacter {
            onPlayCharacter?(character)
        }
    }
    
    // MARK: - Public Methods
    
    func configure(with character: CharacterInfo) {
        currentCharacter = character
        
        // Hero
        heroNameLabel.stringValue = character.displayName
        heroDateLabel.stringValue = character.versionDate.isEmpty ? "" : "Updated \(character.versionDate)"
        
        // Load extended info (includes CNS stats)
        let extendedInfo = CharacterExtendedInfo(from: character)
        
        // Quick stats
        if let authorValue = authorStatView.viewWithTag(100) as? NSTextField {
            authorValue.stringValue = character.author
        }
        if let versionValue = versionStatView.viewWithTag(100) as? NSTextField {
            versionValue.stringValue = extendedInfo.versionDate.isEmpty ? "1.0" : extendedInfo.versionDate
        }
        
        // Update attribute bars with real CNS data
        lifeBar.update(value: extendedInfo.life, maxValue: CNSParser.CharacterStats.maxLife)
        atkBar.update(value: extendedInfo.attack, maxValue: CNSParser.CharacterStats.maxAttack)
        defBar.update(value: extendedInfo.defence, maxValue: CNSParser.CharacterStats.maxDefence)
        powBar.update(value: extendedInfo.power, maxValue: CNSParser.CharacterStats.maxPower)
        
        // Palettes
        updatePalettes(count: extendedInfo.paletteCount)
        
        // Load move list
        loadMoveList(for: character)
        
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
            let moreLabel = NSTextField(labelWithString: "+\(count - 6)")
            moreLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            moreLabel.textColor = DesignColors.zinc500
            moreLabel.wantsLayer = true
            moreLabel.layer?.cornerRadius = 12
            moreLabel.layer?.backgroundColor = DesignColors.zinc900.cgColor
            moreLabel.layer?.borderWidth = 1
            moreLabel.layer?.borderColor = DesignColors.zinc700.cgColor
            moreLabel.alignment = .center
            
            NSLayoutConstraint.activate([
                moreLabel.widthAnchor.constraint(equalToConstant: 24),
                moreLabel.heightAnchor.constraint(equalToConstant: 24),
            ])
            
            paletteStackView.addArrangedSubview(moreLabel)
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
        
        moveListStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let placeholderLabel = NSTextField(labelWithString: "Select a character to view details")
        placeholderLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        placeholderLabel.textColor = DesignColors.zinc500
        moveListStackView.addArrangedSubview(placeholderLabel)
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
        
        if let content = try? String(contentsOf: defFile, encoding: .utf8) {
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
        if let content = try? String(contentsOf: character.defFile, encoding: .utf8) {
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
