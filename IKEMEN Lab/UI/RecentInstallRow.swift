import Cocoa

// MARK: - Recent Install Row

/// A table row for recently installed content
/// Matches HTML: hover:bg-white/5 transition-colors cursor-pointer
class RecentInstallRow: NSView, ThemeApplicable {
    
    var onClick: (() -> Void)?
    var onStatusChanged: ((Bool) -> Void)?
    
    private let install: RecentInstall
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { updateAppearance(animated: true) }
    }
    
    // UI Elements
    private var iconView: NSView!
    private var iconLabel: NSTextField!
    private var thumbnailImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var typeBadge: NSView!
    private var typeDot: NSView!
    private var typeLabel: NSTextField!
    private var dateLabel: NSTextField!
    private var statusToggle: NSSwitch!
    
    // Colors for type badges
    private let charBadgeColor = DesignColors.badgeCharacter
    private let stageBadgeColor = DesignColors.badgeStage
    
    init(install: RecentInstall, showBorder: Bool) {
        self.install = install
        super.init(frame: .zero)
        setupUI(showBorder: showBorder)
        loadThumbnail()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(showBorder: Bool) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Bottom border (if not last row)
        if showBorder {
            let border = NSView()
            border.translatesAutoresizingMaskIntoConstraints = false
            border.wantsLayer = true
            tagThemeBackground(border, role: .borderSubtle)
            addSubview(border)
            
            NSLayoutConstraint.activate([
                border.leadingAnchor.constraint(equalTo: leadingAnchor),
                border.trailingAnchor.constraint(equalTo: trailingAnchor),
                border.bottomAnchor.constraint(equalTo: bottomAnchor),
                border.heightAnchor.constraint(equalToConstant: 1),
            ])
        }
        
        // Icon container (40x40, darker background)
        iconView = NSView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6
        tagThemeBackground(iconView, role: .zinc900)
        iconView.layer?.borderWidth = 1
        tagThemeBorder(iconView, role: .subtle)
        iconView.layer?.masksToBounds = true  // Clip thumbnail to rounded corners
        addSubview(iconView)
        
        // Thumbnail image view (hidden until image loads)
        thumbnailImageView = NSImageView()
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.isHidden = true
        iconView.addSubview(thumbnailImageView)
        
        // Icon initial letter (fallback when no thumbnail)
        let initial = String(install.name.prefix(1)).uppercased()
        iconLabel = NSTextField(labelWithString: initial)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        tagThemeLabel(iconLabel, role: .tertiary)
        iconLabel.alignment = .center
        iconView.addSubview(iconLabel)
        
        // Name + Author stack
        let nameStack = NSStackView()
        nameStack.translatesAutoresizingMaskIntoConstraints = false
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = 2
        addSubview(nameStack)
        
        // Name label
        nameLabel = NSTextField(labelWithString: install.name)
        nameLabel.font = DesignFonts.body(size: 14)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameStack.addArrangedSubview(nameLabel)
        
        // Author label (from metadata)
        authorLabel = NSTextField(labelWithString: install.author)
        authorLabel.font = DesignFonts.body(size: 12)
        authorLabel.lineBreakMode = .byTruncatingTail
        nameStack.addArrangedSubview(authorLabel)
        
        // Check if content still exists on disk
        let isDeleted = !install.existsOnDisk
        
        // Apply styling based on deletion state
        if isDeleted {
            // Strikethrough for deleted items
            let nameAttr = NSMutableAttributedString(string: install.name)
            nameAttr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: nameAttr.length))
            nameAttr.addAttribute(.foregroundColor, value: DesignColors.textTertiary, range: NSRange(location: 0, length: nameAttr.length))
            nameLabel.attributedStringValue = nameAttr
            
            let authorAttr = NSMutableAttributedString(string: install.author)
            authorAttr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: authorAttr.length))
            authorAttr.addAttribute(.foregroundColor, value: DesignColors.textTertiary, range: NSRange(location: 0, length: authorAttr.length))
            authorLabel.attributedStringValue = authorAttr
        } else {
            tagThemeLabel(nameLabel, role: .primary)
            tagThemeLabel(authorLabel, role: .tertiary)
        }
        
        // Type badge with colored dot
        let isCharacter = install.type == "character"
        let badgeColor = isCharacter ? charBadgeColor : stageBadgeColor
        
        typeBadge = NSView()
        typeBadge.translatesAutoresizingMaskIntoConstraints = false
        typeBadge.wantsLayer = true
        typeBadge.layer?.cornerRadius = 12
        typeBadge.layer?.backgroundColor = badgeColor.withAlphaComponent(0.15).cgColor
        typeBadge.layer?.borderWidth = 1
        typeBadge.layer?.borderColor = badgeColor.withAlphaComponent(0.3).cgColor
        addSubview(typeBadge)
        
        // Colored dot inside badge
        typeDot = NSView()
        typeDot.translatesAutoresizingMaskIntoConstraints = false
        typeDot.wantsLayer = true
        typeDot.layer?.cornerRadius = 3
        typeDot.layer?.backgroundColor = badgeColor.cgColor
        typeBadge.addSubview(typeDot)
        
        let typeText = isCharacter ? "Char" : "Stage"
        typeLabel = NSTextField(labelWithString: typeText)
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        typeLabel.textColor = badgeColor
        typeBadge.addSubview(typeLabel)
        
        // Date label (formatted nicely)
        let dateText = formatDate(install.installedAt)
        dateLabel = NSTextField(labelWithString: dateText)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        tagThemeLabel(dateLabel, role: .tertiary)
        dateLabel.alignment = .left
        addSubview(dateLabel)
        
        // Status toggle (hidden for deleted items)
        statusToggle = NSSwitch()
        statusToggle.translatesAutoresizingMaskIntoConstraints = false
        statusToggle.state = .on  // Default to enabled
        statusToggle.target = self
        statusToggle.action = #selector(statusToggled(_:))
        statusToggle.isHidden = isDeleted  // Hide toggle for deleted items
        addSubview(statusToggle)
        
        NSLayoutConstraint.activate([
            // Icon (40x40)
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            // Thumbnail fills the icon container
            thumbnailImageView.topAnchor.constraint(equalTo: iconView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: iconView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: iconView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: iconView.bottomAnchor),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            // Name stack
            nameStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameStack.trailingAnchor.constraint(lessThanOrEqualTo: typeBadge.leadingAnchor, constant: -12),
            
            // Type badge - positioned relative to date
            typeBadge.trailingAnchor.constraint(equalTo: dateLabel.leadingAnchor, constant: -20),
            typeBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            typeBadge.heightAnchor.constraint(equalToConstant: 24),
            
            typeDot.leadingAnchor.constraint(equalTo: typeBadge.leadingAnchor, constant: 10),
            typeDot.centerYAnchor.constraint(equalTo: typeBadge.centerYAnchor),
            typeDot.widthAnchor.constraint(equalToConstant: 6),
            typeDot.heightAnchor.constraint(equalToConstant: 6),
            
            typeLabel.leadingAnchor.constraint(equalTo: typeDot.trailingAnchor, constant: 6),
            typeLabel.trailingAnchor.constraint(equalTo: typeBadge.trailingAnchor, constant: -12),
            typeLabel.centerYAnchor.constraint(equalTo: typeBadge.centerYAnchor),
            
            // Date
            dateLabel.trailingAnchor.constraint(equalTo: statusToggle.leadingAnchor, constant: -20),
            dateLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Status toggle (right side)
            statusToggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statusToggle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    @objc private func statusToggled(_ sender: NSSwitch) {
        onStatusChanged?(sender.state == .on)
    }
    
    // MARK: - Thumbnail Loading
    
    private func loadThumbnail() {
        let folderPath = install.folderPath
        let itemType = install.type
        let itemId = install.id
        
        // Check cache first
        let cacheKey = "recent_\(itemType)_\(itemId)"
        if let cached = ImageCache.shared.get(cacheKey) {
            showThumbnail(cached)
            return
        }
        
        // Load asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var thumbnail: NSImage? = nil
            let folderURL = URL(fileURLWithPath: folderPath)
            
            if itemType == "character" {
                // For characters, load portrait from folder
                thumbnail = self?.loadCharacterPortrait(from: folderURL)
            } else {
                // For stages, load preview from SFF
                thumbnail = self?.loadStagePreview(defFileURL: folderURL)
            }
            
            DispatchQueue.main.async { [weak self] in
                if let image = thumbnail {
                    ImageCache.shared.set(image, for: cacheKey)
                    self?.showThumbnail(image)
                }
            }
        }
    }
    
    private func showThumbnail(_ image: NSImage) {
        thumbnailImageView.image = image
        thumbnailImageView.isHidden = false
        iconLabel.isHidden = true
    }
    
    private func loadCharacterPortrait(from folderURL: URL) -> NSImage? {
        let fileManager = FileManager.default
        
        // First check for portrait.png
        let portraitPng = folderURL.appendingPathComponent("portrait.png")
        if fileManager.fileExists(atPath: portraitPng.path),
           let image = NSImage(contentsOf: portraitPng) {
            return image
        }
        
        // Check for any .png file that might be a portrait
        if let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            for file in contents where file.pathExtension.lowercased() == "png" {
                let name = file.deletingPathExtension().lastPathComponent.lowercased()
                if name.contains("portrait") || name.contains("select") {
                    if let image = NSImage(contentsOf: file) {
                        return image
                    }
                }
            }
        }
        
        // Find def file to get sprite reference
        if let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) {
            let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
            if let defFile = defFiles.first {
                let parsed = DEFParser.parse(url: defFile)
                if let spriteFileName = parsed?.spriteFile {
                    let sffFile = folderURL.appendingPathComponent(spriteFileName)
                    if fileManager.fileExists(atPath: sffFile.path) {
                        return SFFParser.extractPortrait(from: sffFile)
                    }
                }
            }
            
            // Fallback: try any SFF file
            let sffFiles = contents.filter { $0.pathExtension.lowercased() == "sff" }
            if let sffFile = sffFiles.first {
                return SFFParser.extractPortrait(from: sffFile)
            }
        }
        
        return nil
    }
    
    private func loadStagePreview(defFileURL: URL) -> NSImage? {
        let fileManager = FileManager.default
        
        // Parse the def file to get SFF reference
        if fileManager.fileExists(atPath: defFileURL.path) {
            let parsed = DEFParser.parse(url: defFileURL)
            if let sprName = parsed?.spriteFile {
                // Normalize path separators
                let normalizedPath = sprName.replacingOccurrences(of: "\\", with: "/")
                
                let sffURL: URL
                if normalizedPath.contains("/") {
                    // Root-relative path
                    let rootDir = defFileURL.deletingLastPathComponent().deletingLastPathComponent()
                    sffURL = rootDir.appendingPathComponent(normalizedPath)
                } else {
                    // File-relative path
                    sffURL = defFileURL.deletingLastPathComponent().appendingPathComponent(normalizedPath)
                }
                
                if fileManager.fileExists(atPath: sffURL.path) {
                    return SFFParser.extractStagePreview(from: sffURL)
                }
            }
        }
        
        return nil
    }
    
    override func layout() {
        super.layout()
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return "\(days) days ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        }
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        
        if isHovered {
            layer?.backgroundColor = DesignColors.overlayHighlightStrong.cgColor
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        CATransaction.commit()
    }
    
    func applyTheme() {
        refreshThemeLabels(in: self)
        refreshThemeLayers(in: self)
        updateAppearance(animated: false)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .assumeInside],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override func mouseDown(with event: NSEvent) {
        // Don't dim if clicking on toggle
        let localPoint = convert(event.locationInWindow, from: nil)
        if !statusToggle.frame.contains(localPoint) {
            alphaValue = 0.8
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        alphaValue = 1.0
        
        let localPoint = convert(event.locationInWindow, from: nil)
        // Don't trigger onClick if clicking on toggle
        if bounds.contains(localPoint) && !statusToggle.frame.contains(localPoint) {
            onClick?()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func resetCursorRects() {
        // Add pointer cursor except over the toggle area
        var cursorRect = bounds
        cursorRect.size.width -= 80  // Exclude toggle area
        addCursorRect(cursorRect, cursor: .pointingHand)
    }
}
