import Cocoa

// MARK: - Hoverable Stat Card

/// A stats card with hover effect matching CSS:
/// glass-panel p-5 rounded-lg border border-white/5 hover:border-white/10 transition-colors
class HoverableStatCard: NSView, ThemeApplicable {
    
    var onClick: (() -> Void)?  // Click callback for navigation
    
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    private func setupAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 8  // rounded-lg
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor  // border-white/5
        
        // Glass panel gradient: linear-gradient(180deg, rgba(255,255,255,0.03) 0%, rgba(255,255,255,0) 100%)
        let gradient = CAGradientLayer()
        gradient.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.cornerRadius = 8
        layer?.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }
    
    override func layout() {
        super.layout()
        // Disable implicit animations for frame changes during resize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer?.frame = bounds
        CATransaction.commit()
    }
    
    private func updateAppearance(animated: Bool) {
        // Border: white/5 -> white/10 on hover (transition-colors)
        // Tailwind default: 150ms cubic-bezier(0.4, 0, 0.2, 1)
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        // Tailwind's default timing: cubic-bezier(0.4, 0, 0.2, 1)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = DesignColors.borderHover.cgColor  // hover:border-white/10
        } else {
            layer?.borderColor = DesignColors.borderSubtle.cgColor  // border-white/5
        }
        
        CATransaction.commit()
        
        // Also update icon color (group-hover:text-white)
        updateIconColor(animated: animated)
    }
    
    private func updateIconColor(animated: Bool) {
        // Find icon view and update its color
        guard let iconView = findSubview(withIdentifier: "iconView") as? NSImageView else { return }
        
        let newColor = isHovered ? DesignColors.textPrimary : DesignColors.textSecondary
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                iconView.contentTintColor = newColor
            }
        } else {
            iconView.contentTintColor = newColor
        }
    }
    
    private func findSubview(withIdentifier identifier: String) -> NSView? {
        for subview in subviews {
            if subview.identifier?.rawValue == identifier {
                return subview
            }
            if let found = findInSubviews(of: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
    
    func applyTheme() {
        gradientLayer?.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        updateAppearance(animated: false)
        refreshThemeLayers(in: self)
        refreshThemeLabels(in: self)
    }
    
    private func findInSubviews(of view: NSView, identifier: String) -> NSView? {
        for subview in view.subviews {
            if subview.identifier?.rawValue == identifier {
                return subview
            }
            if let found = findInSubviews(of: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        // .assumeInside ensures mouseExited fires even if mouse was already inside when tracking started
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
        guard onClick != nil else { return }
        // Visual feedback - slightly dim on press
        alphaValue = 0.8
    }
    
    override func mouseUp(with event: NSEvent) {
        guard onClick != nil else { return }
        alphaValue = 1.0
        
        // Check if still inside bounds (user didn't drag out)
        let localPoint = convert(event.locationInWindow, from: nil)
        if bounds.contains(localPoint) {
            onClick?()
        }
    }
    
    override var acceptsFirstResponder: Bool { onClick != nil }
    
    override func resetCursorRects() {
        if onClick != nil {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}
