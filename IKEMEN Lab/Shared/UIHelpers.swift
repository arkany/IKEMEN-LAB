import AppKit

// MARK: - View Mode

/// View mode for content browsers (characters, stages, etc.)
public enum BrowserViewMode {
    case grid
    case list
}

// MARK: - Registration Filter

/// Filter for content registration status
public enum RegistrationFilter {
    case all
    case registeredOnly
    case unregisteredOnly
}

// MARK: - Dark Theme Raw Colors

/// Raw dark theme color values - use DesignColors for theme-aware access
private struct DarkThemeColors {
    static let zinc950 = NSColor(red: 0x09/255.0, green: 0x09/255.0, blue: 0x0b/255.0, alpha: 1.0)
    static let zinc900 = NSColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x1b/255.0, alpha: 1.0)
    static let zinc800 = NSColor(red: 0x27/255.0, green: 0x27/255.0, blue: 0x2a/255.0, alpha: 1.0)
    static let zinc700 = NSColor(red: 0x3f/255.0, green: 0x3f/255.0, blue: 0x46/255.0, alpha: 1.0)
    static let zinc600 = NSColor(red: 0x52/255.0, green: 0x52/255.0, blue: 0x5b/255.0, alpha: 1.0)
    static let zinc500 = NSColor(red: 0x71/255.0, green: 0x71/255.0, blue: 0x7a/255.0, alpha: 1.0)
    static let zinc400 = NSColor(red: 0xa1/255.0, green: 0xa1/255.0, blue: 0xaa/255.0, alpha: 1.0)
    static let zinc300 = NSColor(red: 0xd4/255.0, green: 0xd4/255.0, blue: 0xd8/255.0, alpha: 1.0)
    static let zinc200 = NSColor(red: 0xe4/255.0, green: 0xe4/255.0, blue: 0xe7/255.0, alpha: 1.0)
    static let zinc100 = NSColor(red: 0xf4/255.0, green: 0xf4/255.0, blue: 0xf5/255.0, alpha: 1.0)
    static let emerald500 = NSColor(red: 0x10/255.0, green: 0xb9/255.0, blue: 0x81/255.0, alpha: 1.0)
    static let emerald400 = NSColor(red: 0x34/255.0, green: 0xd3/255.0, blue: 0x99/255.0, alpha: 1.0)
}

// MARK: - Light Theme Raw Colors

/// Raw light theme color values - use DesignColors for theme-aware access
private struct LightThemeColors {
    static let zinc950 = NSColor(red: 0x09/255.0, green: 0x09/255.0, blue: 0x0b/255.0, alpha: 1.0)
    static let zinc900 = NSColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x1b/255.0, alpha: 1.0)
    static let zinc800 = NSColor(red: 0x27/255.0, green: 0x27/255.0, blue: 0x2a/255.0, alpha: 1.0)
    static let zinc700 = NSColor(red: 0x3f/255.0, green: 0x3f/255.0, blue: 0x46/255.0, alpha: 1.0)
    static let zinc600 = NSColor(red: 0x52/255.0, green: 0x52/255.0, blue: 0x5b/255.0, alpha: 1.0)
    static let zinc500 = NSColor(red: 0x71/255.0, green: 0x71/255.0, blue: 0x7a/255.0, alpha: 1.0)
    static let zinc400 = NSColor(red: 0xa1/255.0, green: 0xa1/255.0, blue: 0xaa/255.0, alpha: 1.0)
    static let zinc300 = NSColor(red: 0xd4/255.0, green: 0xd4/255.0, blue: 0xd8/255.0, alpha: 1.0)
    static let zinc200 = NSColor(red: 0xe4/255.0, green: 0xe4/255.0, blue: 0xe7/255.0, alpha: 1.0)
    static let zinc100 = NSColor(red: 0xf4/255.0, green: 0xf4/255.0, blue: 0xf5/255.0, alpha: 1.0)
    static let zinc50 = NSColor(red: 0xfa/255.0, green: 0xfa/255.0, blue: 0xfa/255.0, alpha: 1.0)
    static let emerald600 = NSColor(red: 0x05/255.0, green: 0x96/255.0, blue: 0x69/255.0, alpha: 1.0)
    static let emerald500 = NSColor(red: 0x10/255.0, green: 0xb9/255.0, blue: 0x81/255.0, alpha: 1.0)
}

// MARK: - Design System Colors (Theme-Aware)

/// Theme-aware design system colors
/// Automatically returns dark or light theme colors based on AppSettings.shared.useLightTheme
public struct DesignColors {
    
    /// Check if currently using light theme
    private static var isLight: Bool { AppSettings.shared.useLightTheme }
    
    // MARK: - Zinc Palette (Tailwind)
    
    public static var zinc950: NSColor { isLight ? LightThemeColors.zinc950 : DarkThemeColors.zinc950 }
    public static var zinc900: NSColor { isLight ? LightThemeColors.zinc900 : DarkThemeColors.zinc900 }
    public static var zinc800: NSColor { isLight ? LightThemeColors.zinc800 : DarkThemeColors.zinc800 }
    public static var zinc700: NSColor { isLight ? LightThemeColors.zinc700 : DarkThemeColors.zinc700 }
    public static var zinc600: NSColor { isLight ? LightThemeColors.zinc600 : DarkThemeColors.zinc600 }
    public static var zinc500: NSColor { isLight ? LightThemeColors.zinc500 : DarkThemeColors.zinc500 }
    public static var zinc400: NSColor { isLight ? LightThemeColors.zinc400 : DarkThemeColors.zinc400 }
    public static var zinc300: NSColor { isLight ? LightThemeColors.zinc300 : DarkThemeColors.zinc300 }
    public static var zinc200: NSColor { isLight ? LightThemeColors.zinc200 : DarkThemeColors.zinc200 }
    public static var zinc100: NSColor { isLight ? LightThemeColors.zinc100 : DarkThemeColors.zinc100 }
    
    // MARK: - Emerald Palette (Tailwind)
    
    public static var emerald500: NSColor { isLight ? LightThemeColors.emerald500 : DarkThemeColors.emerald500 }
    public static var emerald400: NSColor { isLight ? LightThemeColors.emerald500 : DarkThemeColors.emerald400 }
    
    // MARK: - Core Backgrounds
    
    public static var background: NSColor {
        isLight ? NSColor.white : DarkThemeColors.zinc950
    }
    
    public static var sidebarBackground: NSColor {
        isLight ? LightThemeColors.zinc50 : DarkThemeColors.zinc950
    }
    
    public static var cardBackground: NSColor {
        isLight ? NSColor.white : DarkThemeColors.zinc900
    }
    
    public static var cardBackgroundTransparent: NSColor {
        isLight ? NSColor.white.withAlphaComponent(0.8) : DarkThemeColors.zinc900.withAlphaComponent(0.2)
    }
    
    public static var cardBackgroundHover: NSColor {
        isLight ? NSColor.white : DarkThemeColors.zinc900.withAlphaComponent(0.4)
    }
    
    public static var panelBackground: NSColor {
        isLight ? LightThemeColors.zinc50 : NSColor(red: 0x0c/255.0, green: 0x0c/255.0, blue: 0x0e/255.0, alpha: 1.0)
    }
    
    public static var inputBackground: NSColor {
        isLight ? LightThemeColors.zinc50 : DarkThemeColors.zinc900.withAlphaComponent(0.5)
    }
    
    public static var headerBackground: NSColor {
        isLight ? NSColor.white.withAlphaComponent(0.85) : DarkThemeColors.zinc950
    }
    
    // MARK: - Text Colors
    
    public static var textPrimary: NSColor {
        isLight ? LightThemeColors.zinc900 : NSColor.white
    }
    
    public static var textSecondary: NSColor {
        isLight ? LightThemeColors.zinc600 : DarkThemeColors.zinc400
    }
    
    public static var textTertiary: NSColor {
        isLight ? LightThemeColors.zinc500 : DarkThemeColors.zinc500
    }
    
    public static var textDisabled: NSColor {
        isLight ? LightThemeColors.zinc400 : DarkThemeColors.zinc600
    }
    
    public static var textHover: NSColor {
        isLight ? LightThemeColors.zinc700 : DarkThemeColors.zinc200
    }
    
    // MARK: - Borders
    
    public static var borderSubtle: NSColor {
        isLight ? LightThemeColors.zinc200 : NSColor.white.withAlphaComponent(0.05)
    }
    
    public static var borderHover: NSColor {
        isLight ? LightThemeColors.zinc300 : NSColor.white.withAlphaComponent(0.10)
    }

    public static var borderStrong: NSColor {
        isLight ? LightThemeColors.zinc300 : NSColor.white.withAlphaComponent(0.20)
    }
    
    public static var borderActive: NSColor {
        isLight ? LightThemeColors.zinc300 : DarkThemeColors.zinc700
    }
    
    public static var borderDashed: NSColor {
        isLight ? LightThemeColors.zinc200 : DarkThemeColors.zinc800
    }
    
    // MARK: - Interactive States
    
    public static var hoverBackground: NSColor {
        isLight ? LightThemeColors.zinc200.withAlphaComponent(0.5) : DarkThemeColors.zinc900.withAlphaComponent(0.5)
    }
    
    public static var selectedBackground: NSColor {
        isLight ? NSColor.white : DarkThemeColors.zinc900
    }
    
    public static var toggleOn: NSColor {
        isLight ? LightThemeColors.zinc900 : NSColor.white
    }
    
    public static var toggleOff: NSColor {
        isLight ? LightThemeColors.zinc300 : DarkThemeColors.zinc800
    }
    
    // MARK: - Accent Colors
    
    public static var positive: NSColor {
        isLight ? LightThemeColors.emerald600 : DarkThemeColors.emerald500
    }
    
    public static var positiveBackground: NSColor {
        isLight ? NSColor(red: 0x10/255.0, green: 0xb9/255.0, blue: 0x81/255.0, alpha: 0.1) : NSColor(red: 0x10/255.0, green: 0xb9/255.0, blue: 0x81/255.0, alpha: 0.1)
    }
    
    public static var warning: NSColor {
        isLight ? NSColor(red: 0xd9/255.0, green: 0x77/255.0, blue: 0x06/255.0, alpha: 1.0) : NSColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 1.0)
    }
    
    public static var warningBackground: NSColor {
        isLight ? NSColor(red: 0xfe/255.0, green: 0xf3/255.0, blue: 0xc7/255.0, alpha: 1.0) : NSColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 0.1)
    }
    
    public static var amber900: NSColor { NSColor(red: 0x78/255.0, green: 0x35/255.0, blue: 0x0f/255.0, alpha: 1.0) }
    public static var amber200: NSColor { NSColor(red: 0xfd/255.0, green: 0xe6/255.0, blue: 0x8a/255.0, alpha: 1.0) }
    
    public static var negative: NSColor {
        isLight ? NSColor(red: 0xdc/255.0, green: 0x26/255.0, blue: 0x26/255.0, alpha: 1.0) : NSColor(red: 0xef/255.0, green: 0x44/255.0, blue: 0x44/255.0, alpha: 1.0)
    }
    
    public static var negativeBackground: NSColor {
        isLight ? NSColor(red: 0xfe/255.0, green: 0xe2/255.0, blue: 0xe2/255.0, alpha: 1.0) : NSColor(red: 0xef/255.0, green: 0x44/255.0, blue: 0x44/255.0, alpha: 0.15)
    }
    
    public static var info: NSColor {
        isLight ? NSColor(red: 0x25/255.0, green: 0x63/255.0, blue: 0xeb/255.0, alpha: 1.0) : NSColor(red: 0x3b/255.0, green: 0x82/255.0, blue: 0xf6/255.0, alpha: 1.0)
    }
    
    public static var toastBackground: NSColor {
        isLight ? NSColor.white : DarkThemeColors.zinc800
    }
    
    public static var toastBorder: NSColor {
        isLight ? LightThemeColors.zinc200 : NSColor.white.withAlphaComponent(0.1)
    }
    
    public static var red900: NSColor { NSColor(red: 0x7f/255.0, green: 0x1d/255.0, blue: 0x1d/255.0, alpha: 1.0) }
    public static var red400: NSColor { NSColor(red: 0xf8/255.0, green: 0x71/255.0, blue: 0x71/255.0, alpha: 1.0) }
    public static var red300: NSColor { NSColor(red: 0xfc/255.0, green: 0xa5/255.0, blue: 0xa5/255.0, alpha: 1.0) }
    public static var red200: NSColor { NSColor(red: 0xfe/255.0, green: 0xca/255.0, blue: 0xca/255.0, alpha: 1.0) }
    
    public static var badgeCharacter: NSColor {
        isLight ? NSColor(red: 0x25/255.0, green: 0x63/255.0, blue: 0xeb/255.0, alpha: 1.0) : NSColor(red: 0x3b/255.0, green: 0x82/255.0, blue: 0xf6/255.0, alpha: 1.0)
    }
    
    public static var badgeCharacterBackground: NSColor {
        isLight ? NSColor(red: 0xdb/255.0, green: 0xea/255.0, blue: 0xfe/255.0, alpha: 1.0) : NSColor(red: 0x3b/255.0, green: 0x82/255.0, blue: 0xf6/255.0, alpha: 0.1)
    }
    
    public static var badgeStage: NSColor {
        isLight ? NSColor(red: 0x7c/255.0, green: 0x3a/255.0, blue: 0xed/255.0, alpha: 1.0) : NSColor(red: 0x8b/255.0, green: 0x5c/255.0, blue: 0xf6/255.0, alpha: 1.0)
    }
    
    public static var badgeStageBackground: NSColor {
        isLight ? NSColor(red: 0xed/255.0, green: 0xe9/255.0, blue: 0xfe/255.0, alpha: 1.0) : NSColor(red: 0x8b/255.0, green: 0x5c/255.0, blue: 0xf6/255.0, alpha: 0.1)
    }
    
    public static var buttonPrimary: NSColor {
        isLight ? LightThemeColors.zinc900 : NSColor.white
    }
    
    public static var buttonPrimaryText: NSColor {
        isLight ? NSColor.white : DarkThemeColors.zinc950
    }

    public static var textOnAccent: NSColor {
        NSColor.white
    }

    public static var iconOnLightSurface: NSColor {
        DarkThemeColors.zinc900
    }

    // MARK: - Picker Surfaces

    public static var pickerBackground: NSColor {
        isLight ? LightThemeColors.zinc50 : DarkThemeColors.zinc900
    }

    public static var pickerScrollBackground: NSColor {
        isLight ? LightThemeColors.zinc100 : DarkThemeColors.zinc800
    }

    public static var pickerItemBackground: NSColor {
        isLight ? LightThemeColors.zinc200 : DarkThemeColors.zinc700
    }

    public static var pickerItemSelectedBackground: NSColor {
        isLight ? LightThemeColors.zinc300 : DarkThemeColors.zinc600
    }

    // MARK: - Overlays & Media

    public static var overlayDim: NSColor {
        isLight ? NSColor.black.withAlphaComponent(0.35) : NSColor.black.withAlphaComponent(0.8)
    }

    public static var overlayHighlight: NSColor {
        isLight ? LightThemeColors.zinc100.withAlphaComponent(0.7) : NSColor.white.withAlphaComponent(0.05)
    }

    public static var overlayHighlightStrong: NSColor {
        isLight ? LightThemeColors.zinc100.withAlphaComponent(0.95) : NSColor.white.withAlphaComponent(0.1)
    }

    public static var imageOverlay: NSColor {
        isLight ? NSColor.white.withAlphaComponent(0.85) : NSColor.black.withAlphaComponent(0.9)
    }

    public static var imageLabelBackground: NSColor {
        isLight ? LightThemeColors.zinc200.withAlphaComponent(0.8) : NSColor.black.withAlphaComponent(0.6)
    }
    
    /// Text color for labels over image overlays (opposite of background)
    public static var textOnImageOverlay: NSColor {
        isLight ? LightThemeColors.zinc900 : NSColor.white
    }

    public static var buttonSecondaryBackground: NSColor {
        isLight ? LightThemeColors.zinc100 : NSColor.white.withAlphaComponent(0.05)
    }

    public static var buttonSecondaryBackgroundHover: NSColor {
        isLight ? LightThemeColors.zinc200 : NSColor.white.withAlphaComponent(0.1)
    }
    
    // MARK: - Legacy Colors (for compatibility)
    
    public static var placeholderBackground: NSColor {
        isLight ? LightThemeColors.zinc100 : DarkThemeColors.zinc900
    }
    
    public static var defaultPlaceholder: NSColor {
        isLight ? LightThemeColors.zinc400 : DarkThemeColors.zinc600
    }
    
    public static var creamText: NSColor {
        isLight ? LightThemeColors.zinc900 : NSColor.white
    }
    
    public static var grayText: NSColor {
        isLight ? LightThemeColors.zinc500 : DarkThemeColors.zinc500
    }
    
    public static var selectedBorder: NSColor {
        isLight ? LightThemeColors.zinc300 : NSColor.white.withAlphaComponent(0.10)
    }
    
    public static var greenAccent: NSColor {
        isLight ? LightThemeColors.emerald600 : DarkThemeColors.emerald500
    }
    
    public static var redAccent: NSColor {
        isLight ? NSColor(red: 0xdc/255.0, green: 0x26/255.0, blue: 0x26/255.0, alpha: 1.0) : NSColor(red: 0xef/255.0, green: 0x44/255.0, blue: 0x44/255.0, alpha: 1.0)
    }
    
    // MARK: - Glass Panel Effect
    
    public static func glassGradient() -> CAGradientLayer {
        let gradient = CAGradientLayer()
        if isLight {
            gradient.colors = [
                NSColor.white.withAlphaComponent(0.6).cgColor,
                NSColor.white.withAlphaComponent(0.2).cgColor
            ]
        } else {
            gradient.colors = [
                NSColor.white.withAlphaComponent(0.03).cgColor,
                NSColor.white.withAlphaComponent(0.0).cgColor
            ]
        }
        gradient.locations = [0.0, 1.0]
        return gradient
    }
}

// MARK: - Font Helpers

/// Design system fonts
/// Primary: Inter (system-like), Manrope (body), Montserrat (headers)
public struct DesignFonts {
    
    // MARK: - Primary Fonts
    
    /// Header font - Montserrat semibold with wide tracking
    public static func header(size: CGFloat) -> NSFont {
        if let font = NSFont(name: "Montserrat-SemiBold", size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: .semibold)
    }
    
    /// Body font - Manrope medium
    public static func body(size: CGFloat) -> NSFont {
        if let font = NSFont(name: "Manrope-Medium", size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: .medium)
    }
    
    /// Label font - Manrope regular
    public static func label(size: CGFloat) -> NSFont {
        if let font = NSFont(name: "Manrope-Regular", size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: .regular)
    }
    
    /// Navigation font - Manrope medium
    public static func navigation(size: CGFloat) -> NSFont {
        return body(size: size)
    }
    
    /// Small text/caption - Inter or system
    public static func caption(size: CGFloat) -> NSFont {
        if let font = NSFont(name: "Inter-Regular", size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size, weight: .regular)
    }
    
    /// Stat number font - Montserrat semibold
    public static func stat(size: CGFloat) -> NSFont {
        return header(size: size)
    }
}

// MARK: - Typography Styles

/// Pre-defined text styles matching the HTML design
public struct TextStyle {
    let font: NSFont
    let color: NSColor
    let tracking: CGFloat // letter-spacing
    
    public static let pageTitle = TextStyle(
        font: DesignFonts.header(size: 24),
        color: DesignColors.textPrimary,
        tracking: 1.5 // tracking-wider
    )
    
    public static let sectionTitle = TextStyle(
        font: DesignFonts.body(size: 14),
        color: DesignColors.textPrimary,
        tracking: 0
    )
    
    public static let statValue = TextStyle(
        font: DesignFonts.stat(size: 24),
        color: DesignColors.textPrimary,
        tracking: 1.5
    )
    
    public static let statLabel = TextStyle(
        font: DesignFonts.label(size: 12),
        color: DesignColors.textTertiary,
        tracking: 0
    )
    
    public static let navItem = TextStyle(
        font: DesignFonts.navigation(size: 14),
        color: DesignColors.textSecondary,
        tracking: 0
    )
    
    public static let navItemActive = TextStyle(
        font: DesignFonts.navigation(size: 14),
        color: DesignColors.textPrimary,
        tracking: 0
    )
    
    public static let bodyText = TextStyle(
        font: DesignFonts.body(size: 14),
        color: DesignColors.textSecondary,
        tracking: 0
    )
    
    public static let caption = TextStyle(
        font: DesignFonts.caption(size: 12),
        color: DesignColors.textTertiary,
        tracking: 0
    )
    
    public static let badge = TextStyle(
        font: DesignFonts.body(size: 12),
        color: DesignColors.textDisabled,
        tracking: 0
    )
}

// MARK: - Layout Constants

/// Common layout constants used across browser views
public struct BrowserLayout {
    // Grid view
    public static let gridItemWidth: CGFloat = 160
    public static let gridItemHeight: CGFloat = 180
    public static let stageGridItemWidth: CGFloat = 320  // Stages are twice as wide
    public static let stageGridItemHeight: CGFloat = 160
    
    // List view
    public static let listItemHeight: CGFloat = 52  // Character list rows
    public static let stageListItemHeight: CGFloat = 98  // Stage list rows (includes preview thumbnail)
    public static let screenpackListItemHeight: CGFloat = 64  // Screenpack list rows (includes thumbnail + action button)
    
    // Spacing
    public static let cardSpacing: CGFloat = 16  // gap-4
    public static let sectionInset: CGFloat = 0
    
    // Sidebar
    public static let sidebarWidth: CGFloat = 256 // w-64
    
    // Dashboard
    public static let dashboardPadding: CGFloat = 32 // p-8
    public static let cardPadding: CGFloat = 20 // p-5
    public static let cardCornerRadius: CGFloat = 12 // rounded-lg/xl
    public static let iconSize: CGFloat = 16
    public static let iconContainerSize: CGFloat = 32 // w-8 h-8
}

// MARK: - Spacing Constants

public struct Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

// MARK: - NSView Extensions

public extension NSView {
    /// Apply glass panel styling to a view
    func applyGlassPanel() {
        wantsLayer = true
        layer?.cornerRadius = BrowserLayout.cardCornerRadius
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor
        layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.2).cgColor
        
        // Add gradient overlay
        let gradient = DesignColors.glassGradient()
        gradient.frame = bounds
        gradient.cornerRadius = BrowserLayout.cardCornerRadius
        layer?.insertSublayer(gradient, at: 0)
    }
    
    /// Apply card styling to a view
    func applyCardStyle() {
        wantsLayer = true
        layer?.cornerRadius = BrowserLayout.cardCornerRadius
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.borderSubtle.cgColor
        layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.2).cgColor
    }
}

// MARK: - NSTextField Extensions

public extension NSTextField {
    /// Apply a text style to this label
    func apply(_ style: TextStyle) {
        font = style.font
        textColor = style.color
        
        if style.tracking > 0 {
            let attributed = NSMutableAttributedString(string: stringValue)
            attributed.addAttribute(.kern, value: style.tracking, range: NSRange(location: 0, length: stringValue.count))
            attributedStringValue = attributed
        }
    }
    
    /// Create a label with a specific text style
    static func label(text: String, style: TextStyle) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.apply(style)
        return label
    }
}

// MARK: - Date Formatting

/// Utility for formatting version dates consistently across the app
public struct VersionDateFormatter {
    
    /// Shared output formatter for consistent display (MM/dd/yyyy)
    private static let outputFormatter: Foundation.DateFormatter = {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()
    
    /// Input formatters for common date patterns in DEF files
    private static let inputFormatters: [Foundation.DateFormatter] = {
        let formats = [
            "dd.MM.yyyy",    // European: 04.14.2001
            "MM.dd.yyyy",    // US with dots: 04.14.2001
            "dd/MM/yyyy",    // European with slashes
            "MM/dd/yyyy",    // US format
            "yyyy-MM-dd",    // ISO format
            "MM/dd/yy",      // Short year US
            "dd.MM.yy",      // Short year European
            "MM,dd,yyyy",    // Comma separated
            "dd,MM,yyyy",    // Comma separated European
        ]
        return formats.map { format in
            let formatter = Foundation.DateFormatter()
            formatter.dateFormat = format
            return formatter
        }
    }()
    
    /// Format a date string to MM/DD/YYYY
    /// Handles common formats: DD.MM.YYYY, MM/DD/YY, YYYY-MM-DD, etc.
    public static func formatToStandard(_ dateString: String) -> String {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "" }
        
        // Try each input formatter
        for formatter in inputFormatters {
            if let date = formatter.date(from: trimmed) {
                return outputFormatter.string(from: date)
            }
        }
        
        // If no pattern matched, return original
        return trimmed
    }
}

// MARK: - NSImage Tinting Extension

extension NSImage {
    /// Returns a tinted copy of the image with the specified color
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
