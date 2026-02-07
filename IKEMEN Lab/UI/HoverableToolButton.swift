import Cocoa

// MARK: - Hoverable Tool Button

/// Tool button with hover effect for the Tools section
class HoverableToolButton: NSView, ThemeApplicable {
    
    var target: AnyObject?
    var action: Selector?
    
    private var trackingArea: NSTrackingArea?
    
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
        layer?.cornerRadius = 8
        layer?.backgroundColor = DesignColors.cardBackground.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor
    }
    
    private func updateAppearance(animated: Bool) {
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = DesignColors.borderHover.cgColor
            layer?.backgroundColor = DesignColors.cardBackgroundHover.cgColor
        } else {
            layer?.borderColor = DesignColors.borderSubtle.cgColor
            layer?.backgroundColor = DesignColors.cardBackground.cgColor
        }
        
        CATransaction.commit()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
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
        alphaValue = 0.8
    }
    
    override func mouseUp(with event: NSEvent) {
        alphaValue = 1.0
        
        let localPoint = convert(event.locationInWindow, from: nil)
        if bounds.contains(localPoint) {
            if let target = target, let action = action {
                _ = target.perform(action)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    func applyTheme() {
        layer?.backgroundColor = DesignColors.cardBackground.cgColor
        layer?.borderColor = DesignColors.borderSubtle.cgColor
        updateAppearance(animated: false)
    }
}
