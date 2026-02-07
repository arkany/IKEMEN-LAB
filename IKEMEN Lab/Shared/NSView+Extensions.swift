import Cocoa

extension NSView {
    /// Recursively search subviews for a view matching the given identifier.
    func viewWithIdentifier(_ identifier: NSUserInterfaceItemIdentifier) -> NSView? {
        if self.identifier == identifier { return self }
        for subview in subviews {
            if let found = subview.viewWithIdentifier(identifier) {
                return found
            }
        }
        return nil
    }
}
