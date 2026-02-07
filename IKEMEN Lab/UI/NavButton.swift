import Cocoa

// MARK: - Nav Button with Hover Support

/// Navigation button with built-in hover tracking for sidebar navigation.
class NavButton: NSButton {
    
    var isHovered = false {
        didSet {
            if isHovered != oldValue {
                onHoverChanged?(isHovered)
            }
        }
    }
    
    var onHoverChanged: ((Bool) -> Void)?
    
    private var trackingArea: NSTrackingArea?
    
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
    
    override var acceptsFirstResponder: Bool { true }
    
    override func drawFocusRingMask() {
        bounds.fill()
    }
    
    override var focusRingMaskBounds: NSRect {
        return bounds
    }
}
