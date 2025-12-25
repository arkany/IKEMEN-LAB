import AppKit

// MARK: - View Mode

/// View mode for content browsers (characters, stages, etc.)
public enum BrowserViewMode {
    case grid
    case list
}

// MARK: - Design System Colors

/// Figma design system colors used throughout the app
public struct DesignColors {
    // Background colors
    public static let cardBackground = NSColor(red: 0x0f/255.0, green: 0x19/255.0, blue: 0x23/255.0, alpha: 1.0)
    public static let placeholderBackground = NSColor(red: 0x1a/255.0, green: 0x2a/255.0, blue: 0x35/255.0, alpha: 1.0)
    public static let defaultPlaceholder = NSColor(red: 0xd9/255.0, green: 0xd9/255.0, blue: 0xd9/255.0, alpha: 1.0)
    
    // Text colors
    public static let creamText = NSColor(red: 0xff/255.0, green: 0xf0/255.0, blue: 0xe5/255.0, alpha: 1.0)
    public static let grayText = NSColor(red: 0x7a/255.0, green: 0x84/255.0, blue: 0x8f/255.0, alpha: 1.0)
    
    // Accent colors
    public static let selectedBorder = NSColor(red: 0xfd/255.0, green: 0x4e/255.0, blue: 0x5b/255.0, alpha: 1.0)
    public static let greenAccent = NSColor(red: 0x4e/255.0, green: 0xfd/255.0, blue: 0x60/255.0, alpha: 1.0)
    public static let redAccent = NSColor(red: 0xfd/255.0, green: 0x4e/255.0, blue: 0x5b/255.0, alpha: 1.0)
}

// MARK: - Font Helpers

/// Helper functions for custom fonts used in the app
public struct DesignFonts {
    /// Get the Jersey font at the specified size, with fallback to monospaced system font
    public static func jersey(size: CGFloat) -> NSFont {
        if let font = NSFont(name: "Jersey15-Regular", size: size) {
            return font
        }
        if let font = NSFont(name: "Jersey10-Regular", size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

// MARK: - Layout Constants

/// Common layout constants used across browser views
public struct BrowserLayout {
    // Grid view
    public static let gridItemWidth: CGFloat = 160
    public static let gridItemHeight: CGFloat = 160
    public static let stageGridItemWidth: CGFloat = 320  // Stages are twice as wide
    public static let stageGridItemHeight: CGFloat = 160
    
    // List view
    public static let listItemHeight: CGFloat = 60
    
    // Spacing
    public static let cardSpacing: CGFloat = 28
    public static let sectionInset: CGFloat = 0
}
