import AppKit

// MARK: - View Mode

/// View mode for content browsers (characters, stages, etc.)
public enum BrowserViewMode {
    case grid
    case list
}

// MARK: - Design System Colors (Zinc Palette from HTML/Tailwind)

/// Modern dark theme design system colors
/// Based on Tailwind zinc palette with subtle white overlays
public struct DesignColors {
    
    // MARK: - Zinc Palette (Tailwind)
    
    /// zinc-950 (#09090b)
    public static let zinc950 = NSColor(red: 0x09/255.0, green: 0x09/255.0, blue: 0x0b/255.0, alpha: 1.0)
    
    /// zinc-900 (#18181b)
    public static let zinc900 = NSColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x1b/255.0, alpha: 1.0)
    
    /// zinc-800 (#27272a)
    public static let zinc800 = NSColor(red: 0x27/255.0, green: 0x27/255.0, blue: 0x2a/255.0, alpha: 1.0)
    
    /// zinc-700 (#3f3f46)
    public static let zinc700 = NSColor(red: 0x3f/255.0, green: 0x3f/255.0, blue: 0x46/255.0, alpha: 1.0)
    
    /// zinc-600 (#52525b)
    public static let zinc600 = NSColor(red: 0x52/255.0, green: 0x52/255.0, blue: 0x5b/255.0, alpha: 1.0)
    
    /// zinc-500 (#71717a)
    public static let zinc500 = NSColor(red: 0x71/255.0, green: 0x71/255.0, blue: 0x7a/255.0, alpha: 1.0)
    
    /// zinc-400 (#a1a1aa)
    public static let zinc400 = NSColor(red: 0xa1/255.0, green: 0xa1/255.0, blue: 0xaa/255.0, alpha: 1.0)
    
    /// zinc-300 (#d4d4d8)
    public static let zinc300 = NSColor(red: 0xd4/255.0, green: 0xd4/255.0, blue: 0xd8/255.0, alpha: 1.0)
    
    /// zinc-200 (#e4e4e7)
    public static let zinc200 = NSColor(red: 0xe4/255.0, green: 0xe4/255.0, blue: 0xe7/255.0, alpha: 1.0)
    
    /// zinc-100 (#f4f4f5)
    public static let zinc100 = NSColor(red: 0xf4/255.0, green: 0xf4/255.0, blue: 0xf5/255.0, alpha: 1.0)
    
    // MARK: - Emerald Palette (Tailwind)
    
    /// emerald-500 (#10b981)
    public static let emerald500 = NSColor(red: 0x10/255.0, green: 0xb9/255.0, blue: 0x81/255.0, alpha: 1.0)
    
    /// emerald-400 (#34d399)
    public static let emerald400 = NSColor(red: 0x34/255.0, green: 0xd3/255.0, blue: 0x99/255.0, alpha: 1.0)
    
    // MARK: - Red Palette (Tailwind)
    
    /// red-900 (#7f1d1d)
    public static let red900 = NSColor(red: 0x7f/255.0, green: 0x1d/255.0, blue: 0x1d/255.0, alpha: 1.0)
    
    /// red-200 (#fecaca)
    public static let red200 = NSColor(red: 0xfe/255.0, green: 0xca/255.0, blue: 0xca/255.0, alpha: 1.0)
    
    // MARK: - Core Backgrounds
    
    /// Main app background - zinc-950 (#09090b)
    public static let background = zinc950
    
    /// Sidebar/panel background - zinc-950
    public static let sidebarBackground = zinc950
    
    /// Card/panel backgrounds - zinc-900 (#18181b)
    public static let cardBackground = zinc900
    
    /// Transparent card background - zinc-900/20 rgba(24, 24, 27, 0.2)
    public static let cardBackgroundTransparent = zinc900.withAlphaComponent(0.2)
    
    /// Slightly darker than card - zinc-900/50 with black overlay
    public static let panelBackground = NSColor(red: 0x0c/255.0, green: 0x0c/255.0, blue: 0x0e/255.0, alpha: 1.0)
    
    /// Input/control backgrounds - zinc-900/50
    public static let inputBackground = zinc900.withAlphaComponent(0.5)
    
    /// Header background - matches primary theme (zinc-950)
    public static let headerBackground = zinc950
    
    // MARK: - Text Colors
    
    /// Primary text - white
    public static let textPrimary = NSColor.white
    
    /// Secondary text - zinc-400 (#a1a1aa)
    public static let textSecondary = zinc400
    
    /// Tertiary/muted text - zinc-500 (#71717a)
    public static let textTertiary = zinc500
    
    /// Disabled/placeholder text - zinc-600 (#52525b)
    public static let textDisabled = zinc600
    
    /// Hover text - zinc-200 (#e4e4e7)
    public static let textHover = zinc200
    
    // MARK: - Borders
    
    /// Subtle border - white at 5% opacity
    public static let borderSubtle = NSColor.white.withAlphaComponent(0.05)
    
    /// Hover border - white at 10% opacity
    public static let borderHover = NSColor.white.withAlphaComponent(0.10)
    
    /// Active/selected border - zinc-700 (#3f3f46)
    public static let borderActive = NSColor(red: 0x3f/255.0, green: 0x3f/255.0, blue: 0x46/255.0, alpha: 1.0)
    
    /// Dashed border for drop zones - zinc-800 (#27272a)
    public static let borderDashed = NSColor(red: 0x27/255.0, green: 0x27/255.0, blue: 0x2a/255.0, alpha: 1.0)
    
    // MARK: - Interactive States
    
    /// Hover background - zinc-900/50
    public static let hoverBackground = NSColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x1b/255.0, alpha: 0.5)
    
    /// Selected/active nav item - zinc-900 with border
    public static let selectedBackground = NSColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x1b/255.0, alpha: 1.0)
    
    /// Toggle/switch on state - white
    public static let toggleOn = NSColor.white
    
    /// Toggle/switch off state - zinc-800
    public static let toggleOff = NSColor(red: 0x27/255.0, green: 0x27/255.0, blue: 0x2a/255.0, alpha: 1.0)
    
    // MARK: - Accent Colors
    
    /// Positive/success - emerald-500
    public static let positive = NSColor(red: 0x10/255.0, green: 0xb9/255.0, blue: 0x81/255.0, alpha: 1.0)
    
    /// Positive background - emerald-500/10
    public static let positiveBackground = NSColor(red: 0x10/255.0, green: 0xb9/255.0, blue: 0x81/255.0, alpha: 0.1)
    
    /// Warning - amber-500
    public static let warning = NSColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 1.0)
    
    /// Warning background - amber-500/10
    public static let warningBackground = NSColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 0.1)
    
    /// Character badge - blue-500
    public static let badgeCharacter = NSColor(red: 0x3b/255.0, green: 0x82/255.0, blue: 0xf6/255.0, alpha: 1.0)
    
    /// Character badge background - blue-500/10
    public static let badgeCharacterBackground = NSColor(red: 0x3b/255.0, green: 0x82/255.0, blue: 0xf6/255.0, alpha: 0.1)
    
    /// Stage badge - purple/violet
    public static let badgeStage = NSColor(red: 0x8b/255.0, green: 0x5c/255.0, blue: 0xf6/255.0, alpha: 1.0)
    
    /// Stage badge background
    public static let badgeStageBackground = NSColor(red: 0x8b/255.0, green: 0x5c/255.0, blue: 0xf6/255.0, alpha: 0.1)
    
    /// Primary action button - white
    public static let buttonPrimary = NSColor.white
    
    /// Primary button text - zinc-950
    public static let buttonPrimaryText = NSColor(red: 0x09/255.0, green: 0x09/255.0, blue: 0x0b/255.0, alpha: 1.0)
    
    // MARK: - Legacy Colors (for compatibility)
    
    public static let placeholderBackground = NSColor(red: 0x18/255.0, green: 0x18/255.0, blue: 0x1b/255.0, alpha: 1.0)
    public static let defaultPlaceholder = NSColor(red: 0x52/255.0, green: 0x52/255.0, blue: 0x5b/255.0, alpha: 1.0)
    public static let creamText = NSColor.white
    public static let grayText = NSColor(red: 0x71/255.0, green: 0x71/255.0, blue: 0x7a/255.0, alpha: 1.0)
    public static let selectedBorder = NSColor.white.withAlphaComponent(0.10)
    public static let greenAccent = NSColor(red: 0x10/255.0, green: 0xb9/255.0, blue: 0x81/255.0, alpha: 1.0)
    public static let redAccent = NSColor(red: 0xef/255.0, green: 0x44/255.0, blue: 0x44/255.0, alpha: 1.0)
    
    // MARK: - Glass Panel Effect
    
    /// Create a glass panel gradient layer
    public static func glassGradient() -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor.white.withAlphaComponent(0.03).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
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
