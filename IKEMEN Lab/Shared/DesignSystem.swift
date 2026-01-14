import SwiftUI

// MARK: - SwiftUI Design System
// This file bridges the existing AppKit DesignColors and DesignFonts to SwiftUI

// MARK: - SwiftUI Color Extensions

extension Color {
    // MARK: - Zinc Palette
    static let zinc950 = Color(nsColor: DesignColors.zinc950)
    static let zinc900 = Color(nsColor: DesignColors.zinc900)
    static let zinc800 = Color(nsColor: DesignColors.zinc800)
    static let zinc700 = Color(nsColor: DesignColors.zinc700)
    static let zinc600 = Color(nsColor: DesignColors.zinc600)
    static let zinc500 = Color(nsColor: DesignColors.zinc500)
    static let zinc400 = Color(nsColor: DesignColors.zinc400)
    static let zinc300 = Color(nsColor: DesignColors.zinc300)
    static let zinc200 = Color(nsColor: DesignColors.zinc200)
    static let zinc100 = Color(nsColor: DesignColors.zinc100)
    
    // MARK: - Emerald Palette
    static let emerald500 = Color(nsColor: DesignColors.emerald500)
    static let emerald400 = Color(nsColor: DesignColors.emerald400)
    
    // MARK: - Semantic Colors
    static let background = Color(nsColor: DesignColors.background)
    static let sidebarBackground = Color(nsColor: DesignColors.sidebarBackground)
    static let cardBackground = Color(nsColor: DesignColors.cardBackground)
    static let cardBackgroundTransparent = Color(nsColor: DesignColors.cardBackgroundTransparent)
    static let panelBackground = Color(nsColor: DesignColors.panelBackground)
    static let inputBackground = Color(nsColor: DesignColors.inputBackground)
    static let headerBackground = Color(nsColor: DesignColors.headerBackground)
    
    // MARK: - Text Colors
    static let textPrimary = Color(nsColor: DesignColors.textPrimary)
    static let textSecondary = Color(nsColor: DesignColors.textSecondary)
    static let textTertiary = Color(nsColor: DesignColors.textTertiary)
    static let textDisabled = Color(nsColor: DesignColors.textDisabled)
    static let textHover = Color(nsColor: DesignColors.textHover)
    
    // MARK: - Borders
    static let borderSubtle = Color(nsColor: DesignColors.borderSubtle)
    static let borderHover = Color(nsColor: DesignColors.borderHover)
    static let borderActive = Color(nsColor: DesignColors.borderActive)
    static let borderDashed = Color(nsColor: DesignColors.borderDashed)
    
    // MARK: - Interactive States
    static let hoverBackground = Color(nsColor: DesignColors.hoverBackground)
    static let selectedBackground = Color(nsColor: DesignColors.selectedBackground)
    static let toggleOn = Color(nsColor: DesignColors.toggleOn)
    static let toggleOff = Color(nsColor: DesignColors.toggleOff)
    
    // MARK: - Accent Colors
    static let positive = Color(nsColor: DesignColors.positive)
    static let positiveBackground = Color(nsColor: DesignColors.positiveBackground)
    static let warning = Color(nsColor: DesignColors.warning)
    static let warningBackground = Color(nsColor: DesignColors.warningBackground)
    static let badgeCharacter = Color(nsColor: DesignColors.badgeCharacter)
    static let badgeCharacterBackground = Color(nsColor: DesignColors.badgeCharacterBackground)
    static let badgeStage = Color(nsColor: DesignColors.badgeStage)
    static let badgeStageBackground = Color(nsColor: DesignColors.badgeStageBackground)
    static let buttonPrimary = Color(nsColor: DesignColors.buttonPrimary)
    static let buttonPrimaryText = Color(nsColor: DesignColors.buttonPrimaryText)
    
    // MARK: - Legacy Colors
    static let accentBlue = Color(nsColor: DesignColors.badgeCharacter)
    static let greenAccent = Color(nsColor: DesignColors.greenAccent)
    static let redAccent = Color(nsColor: DesignColors.redAccent)
}

// MARK: - SwiftUI Font Extensions

extension Font {
    /// Header font - Montserrat semibold
    static func header(size: CGFloat) -> Font {
        if let _ = NSFont(name: "Montserrat-SemiBold", size: size) {
            return Font.custom("Montserrat-SemiBold", size: size)
        }
        return Font.system(size: size, weight: .semibold)
    }
    
    /// Body font - Manrope medium
    static func body(size: CGFloat) -> Font {
        if let _ = NSFont(name: "Manrope-Medium", size: size) {
            return Font.custom("Manrope-Medium", size: size)
        }
        return Font.system(size: size, weight: .medium)
    }
    
    /// Label font - Manrope regular
    static func label(size: CGFloat) -> Font {
        if let _ = NSFont(name: "Manrope-Regular", size: size) {
            return Font.custom("Manrope-Regular", size: size)
        }
        return Font.system(size: size, weight: .regular)
    }
    
    /// Caption/small text - Inter regular
    static func caption(size: CGFloat) -> Font {
        if let _ = NSFont(name: "Inter-Regular", size: size) {
            return Font.custom("Inter-Regular", size: size)
        }
        return Font.system(size: size, weight: .regular)
    }
    
    /// Stat/numeric font - Montserrat semibold
    static func stat(size: CGFloat) -> Font {
        return header(size: size)
    }
}

// MARK: - Common View Modifiers

/// Card style matching the AppKit design system
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
    }
}

/// Input field style matching the AppKit design system
struct InputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(Color.inputBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
    }
}

/// Primary button style
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body(size: 14))
            .foregroundColor(.buttonPrimaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.buttonPrimary)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

/// Secondary button style (outline)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body(size: 14))
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card styling
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    /// Apply input field styling
    func inputStyle() -> some View {
        modifier(InputStyle())
    }
}
