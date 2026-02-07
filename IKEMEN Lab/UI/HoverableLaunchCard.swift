import Cocoa

// MARK: - Hoverable Launch Card

/// Launch card with special hover effect - adds gradient overlay on hover
/// CSS: glass-panel with bg-gradient-to-br from-white/5 to-transparent on hover
class HoverableLaunchCard: NSView, ThemeApplicable {
    
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    private var hoverGradientLayer: CAGradientLayer?
    var onClick: (() -> Void)?  // Click callback
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    private var isPressed = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    // MARK: - Mouse Click Handling
    
    override func mouseDown(with event: NSEvent) {
        guard onClick != nil else {
            super.mouseDown(with: event)
            return
        }
        
        isPressed = true
        
        // Visual press feedback
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.08)
        layer?.setAffineTransform(CGAffineTransform(scaleX: 0.98, y: 0.98))
        CATransaction.commit()
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isPressed else {
            super.mouseUp(with: event)
            return
        }
        
        isPressed = false
        
        // Visual release feedback
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        layer?.setAffineTransform(.identity)
        CATransaction.commit()
        
        // Check if mouse is still inside the card
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            // Trigger click callback
            onClick?()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Accept click without requiring window to be active first
        return true
    }
    
    // Make the entire card clickable by returning self when we have a click handler
    // This prevents subviews (labels, icons, stack views) from intercepting mouse events
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert point from superview coordinates to local coordinates
        let localPoint = convert(point, from: superview)
        
        // If we have an onClick handler and the point is inside our bounds,
        // return self so we receive the mouseDown event
        if onClick != nil && bounds.contains(localPoint) {
            return self
        }
        return super.hitTest(point)
    }
    
    // Show pointer cursor when hoverable
    override func resetCursorRects() {
        if onClick != nil {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
    
    private func setupAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        // Base glass gradient
        let gradient = CAGradientLayer()
        gradient.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.cornerRadius = 8
        layer?.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
        
        // Hover gradient (initially invisible)
        // bg-gradient-to-br from-white/5 to-transparent
        let hoverGrad = CAGradientLayer()
        hoverGrad.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        hoverGrad.startPoint = CGPoint(x: 0, y: 0)
        hoverGrad.endPoint = CGPoint(x: 1, y: 1)
        hoverGrad.cornerRadius = 8
        hoverGrad.opacity = 0
        layer?.addSublayer(hoverGrad)
        hoverGradientLayer = hoverGrad
    }
    
    override func layout() {
        super.layout()
        // Disable implicit animations for frame changes during resize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer?.frame = bounds
        hoverGradientLayer?.frame = bounds
        CATransaction.commit()
    }
    
    private func updateAppearance(animated: Bool) {
        // Tailwind default: 150ms cubic-bezier(0.4, 0, 0.2, 1)
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        // Tailwind's default timing: cubic-bezier(0.4, 0, 0.2, 1)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = DesignColors.borderHover.cgColor
            hoverGradientLayer?.opacity = 1.0
        } else {
            layer?.borderColor = DesignColors.borderSubtle.cgColor
            hoverGradientLayer?.opacity = 0.0
        }
        
        CATransaction.commit()
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
    
    func applyTheme() {
        gradientLayer?.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        hoverGradientLayer?.colors = [
            DesignColors.overlayHighlightStrong.cgColor,
            DesignColors.overlayHighlight.cgColor
        ]
        updateAppearance(animated: false)
    }
}
