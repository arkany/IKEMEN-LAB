import Cocoa

// MARK: - Dashboard Theme Infrastructure
// Shared theme tagging system for dashboard widgets.
// Uses associated objects to tag views with semantic roles,
// enabling batch theme refresh when light/dark mode changes.

enum ThemeTextRole: String {
    case primary
    case secondary
    case tertiary
}

enum ThemeBackgroundRole: String {
    case card
    case cardTransparent
    case panel
    case zinc900
    case zinc800
    case borderSubtle
    case featureCard
    case featureCardIcon
    case buttonSecondary
}

enum ThemeBorderRole: String {
    case subtle
    case hover
}

private var themeLabelRoleKey: UInt8 = 0
private var themeBackgroundRoleKey: UInt8 = 0
private var themeBorderRoleKey: UInt8 = 0

func themeTextColor(for role: ThemeTextRole) -> NSColor {
    switch role {
    case .primary:
        return DesignColors.textPrimary
    case .secondary:
        return DesignColors.textSecondary
    case .tertiary:
        return DesignColors.textTertiary
    }
}

func themeBackgroundColor(for role: ThemeBackgroundRole) -> NSColor {
    switch role {
    case .card:
        return DesignColors.cardBackground
    case .cardTransparent:
        return DesignColors.cardBackgroundTransparent
    case .panel:
        return DesignColors.panelBackground
    case .zinc900:
        return DesignColors.zinc900
    case .zinc800:
        return DesignColors.zinc800
    case .borderSubtle:
        return DesignColors.borderSubtle
    case .featureCard:
        return DesignColors.panelBackground
    case .featureCardIcon:
        return DesignColors.inputBackground
    case .buttonSecondary:
        return DesignColors.buttonSecondaryBackground
    }
}

func themeBorderColor(for role: ThemeBorderRole) -> NSColor {
    switch role {
    case .subtle:
        return DesignColors.borderSubtle
    case .hover:
        return DesignColors.borderHover
    }
}

func tagThemeLabel(_ label: NSTextField, role: ThemeTextRole) {
    objc_setAssociatedObject(label, &themeLabelRoleKey, role.rawValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    label.textColor = themeTextColor(for: role)
}

func tagThemeBackground(_ view: NSView, role: ThemeBackgroundRole) {
    objc_setAssociatedObject(view, &themeBackgroundRoleKey, role.rawValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    view.wantsLayer = true
    view.layer?.backgroundColor = themeBackgroundColor(for: role).cgColor
}

func tagThemeBorder(_ view: NSView, role: ThemeBorderRole) {
    objc_setAssociatedObject(view, &themeBorderRoleKey, role.rawValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    view.wantsLayer = true
    view.layer?.borderColor = themeBorderColor(for: role).cgColor
}

func refreshThemeLabels(in view: NSView) {
    if let label = view as? NSTextField,
       let rawRole = objc_getAssociatedObject(label, &themeLabelRoleKey) as? String,
       let role = ThemeTextRole(rawValue: rawRole) {
        label.textColor = themeTextColor(for: role)
    }
    
    for subview in view.subviews {
        refreshThemeLabels(in: subview)
    }
}

func refreshThemeLayers(in view: NSView) {
    if let rawRole = objc_getAssociatedObject(view, &themeBackgroundRoleKey) as? String,
       let role = ThemeBackgroundRole(rawValue: rawRole) {
        view.layer?.backgroundColor = themeBackgroundColor(for: role).cgColor
    }
    
    if let rawRole = objc_getAssociatedObject(view, &themeBorderRoleKey) as? String,
       let role = ThemeBorderRole(rawValue: rawRole) {
        view.layer?.borderColor = themeBorderColor(for: role).cgColor
    }
    
    for subview in view.subviews {
        refreshThemeLayers(in: subview)
    }
}

/// Protocol for views that support theme switching
protocol ThemeApplicable: AnyObject {
    func applyTheme()
}
