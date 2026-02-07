import Cocoa

// MARK: - Dashboard Drop Zone

class DashboardDropZone: NSView, ThemeApplicable {
    
    var onFilesDropped: (([URL]) -> Void)?
    var onClick: (() -> Void)?
    
    private var isDragging = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    private var trackingArea: NSTrackingArea?
    private var dashedBorderLayer: CAShapeLayer?
    private var iconContainer: NSView!
    private var iconView: NSImageView!
    private var label: NSTextField!
    private var subLabel: NSTextField!
    private var fullgameToggle: NSButton!

    override func mouseDown(with event: NSEvent) {
        if let onClick = onClick {
            onClick()
        } else {
            super.mouseDown(with: event)
        }
    }
    
    // Design colors - now using semantic theme-aware colors
    private var borderDefault: NSColor { DesignColors.borderSubtle }
    private var borderHover: NSColor { DesignColors.borderHover }
    private var bgDefault: NSColor { DesignColors.cardBackground.withAlphaComponent(0.2) }
    private var bgHover: NSColor { DesignColors.cardBackground.withAlphaComponent(0.4) }
    
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
        layer?.cornerRadius = 12
        layer?.backgroundColor = bgDefault.cgColor  // bg-zinc-900/20 default
        
        // Dashed border - zinc-800 default
        let dashedBorder = CAShapeLayer()
        dashedBorder.strokeColor = borderDefault.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [8, 6]
        dashedBorder.lineWidth = 1
        layer?.addSublayer(dashedBorder)
        self.dashedBorderLayer = dashedBorder
        
        // Register for drag
        registerForDraggedTypes([.fileURL])
        
        // Icon container - use Auto Layout, scale via bounds-center transform
        iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        iconContainer.layer?.cornerRadius = 24  // rounded-full for 48px container
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        // Add shadow
        iconContainer.layer?.shadowColor = NSColor.black.cgColor
        iconContainer.layer?.shadowOpacity = 0.3
        iconContainer.layer?.shadowOffset = CGSize(width: 0, height: 2)
        iconContainer.layer?.shadowRadius = 4
        addSubview(iconContainer)
        
        // Icon (cloud download style from HTML)
        iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "icloud.and.arrow.down", accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textSecondary
        iconView.symbolConfiguration = .init(pointSize: 20, weight: .regular)
        iconContainer.addSubview(iconView)
        
        // Label - "Install Content"
        label = NSTextField(labelWithString: "Install Content")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.body(size: 14)
        tagThemeLabel(label, role: .secondary)
        label.alignment = .center
        addSubview(label)
        
        // Sub-label
        subLabel = NSTextField(labelWithString: "Drag and drop .zip, .rar, or .def files here to automatically\ninstall characters or stages.")
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.font = DesignFonts.caption(size: 12)
        tagThemeLabel(subLabel, role: .tertiary)
        subLabel.alignment = .center
        subLabel.maximumNumberOfLines = 2
        addSubview(subLabel)
        
        // Fullgame mode toggle
        fullgameToggle = NSButton(checkboxWithTitle: "Fullgame mode", target: self, action: #selector(fullgameToggleChanged))
        fullgameToggle.translatesAutoresizingMaskIntoConstraints = false
        fullgameToggle.font = DesignFonts.caption(size: 11)
        fullgameToggle.state = AppSettings.shared.fullgameImportEnabled ? .on : .off
        fullgameToggle.contentTintColor = DesignColors.textTertiary
        fullgameToggle.toolTip = "Import entire MUGEN/IKEMEN packages as collections, including characters, stages, screenpack, fonts, and sounds."
        addSubview(fullgameToggle)
        
        NSLayoutConstraint.activate([
            // Icon container: 48x48 centered
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
            iconContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            
            // Icon centered in container
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 16),
            
            subLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            subLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            subLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            
            // Fullgame toggle below sub-label
            fullgameToggle.centerXAnchor.constraint(equalTo: centerXAnchor),
            fullgameToggle.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 12),
        ])
    }
    
    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 12, cornerHeight: 12, transform: nil)
        dashedBorderLayer?.path = path
        dashedBorderLayer?.frame = bounds
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? 0.2 : 0.0
        
        // Animate border and background colors
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            if isDragging {
                dashedBorderLayer?.strokeColor = DesignColors.positive.cgColor
                layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.15).cgColor
            } else if isHovered {
                dashedBorderLayer?.strokeColor = borderHover.cgColor
                layer?.backgroundColor = bgHover.cgColor
            } else {
                dashedBorderLayer?.strokeColor = borderDefault.cgColor
                layer?.backgroundColor = bgDefault.cgColor
            }
        }
        
        // Determine target scale
        let targetScale: CGFloat
        if isDragging {
            targetScale = 1.15
        } else if isHovered {
            targetScale = 1.1
        } else {
            targetScale = 1.0
        }
        
        // Scale from center using bounds-based transform
        // The key: translate to center, scale, translate back
        let bounds = iconContainer.bounds
        let centerX = bounds.midX
        let centerY = bounds.midY
        
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, centerX, centerY, 0)
        transform = CATransform3DScale(transform, targetScale, targetScale, 1.0)
        transform = CATransform3DTranslate(transform, -centerX, -centerY, 0)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                iconContainer.layer?.transform = transform
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            iconContainer.layer?.transform = transform
            CATransaction.commit()
        }
    }
    
    @objc private func fullgameToggleChanged() {
        AppSettings.shared.fullgameImportEnabled = (fullgameToggle.state == .on)
    }

    func applyTheme() {
        layer?.backgroundColor = bgDefault.cgColor
        dashedBorderLayer?.strokeColor = borderDefault.cgColor
        iconContainer.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        iconContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        iconView.contentTintColor = DesignColors.textSecondary
        fullgameToggle.contentTintColor = DesignColors.textTertiary
        refreshThemeLabels(in: self)
        updateAppearance(animated: false)
    }
    
    // MARK: - Cursor (pointer on hover)
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    // MARK: - Hover Tracking
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    // MARK: - Drag & Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasValidFiles(sender) {
            isDragging = true
            return .copy
        }
        return []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        let validURLs = urls.filter { isValidFile($0) }
        if !validURLs.isEmpty {
            onFilesDropped?(validURLs)
            return true
        }
        return false
    }
    
    private func hasValidFiles(_ info: NSDraggingInfo) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        return urls.contains { isValidFile($0) }
    }
    
    private func isValidFile(_ url: URL) -> Bool {
        let validExtensions = ["zip", "rar", "7z"]
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return true
            }
            return validExtensions.contains(url.pathExtension.lowercased())
        }
        return false
    }
}
