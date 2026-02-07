import Cocoa

/// View that intercepts mouse events on empty areas to prevent clicks passing through to views below
/// but allows clicks to reach subviews (like text fields, buttons, etc.)
class ClickBlockingView: NSView {
    override func mouseDown(with event: NSEvent) {
        // Consume the click - don't pass to superview
    }
    
    override func mouseUp(with event: NSEvent) {
        // Consume the click
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // First check if any subview should handle this
        if let hitView = super.hitTest(point), hitView !== self {
            return hitView
        }
        // If no subview hit, return self to block the click from going through
        return bounds.contains(point) ? self : nil
    }
}
