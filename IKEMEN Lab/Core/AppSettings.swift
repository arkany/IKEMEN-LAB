import Foundation

/// Centralized app settings using UserDefaults
/// Provides type-safe access to all MacMugen preferences
public final class AppSettings {
    
    // MARK: - Singleton
    
    public static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    private init() {
        registerDefaults()
    }
    
    // MARK: - Default Values
    
    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.enablePNGStageCreation: false,
            Keys.defaultStageZoom: 1.0,
            Keys.defaultStageBoundLeft: -150,
            Keys.defaultStageBoundRight: 150,
        ])
    }
    
    // MARK: - Keys
    
    private enum Keys {
        static let enablePNGStageCreation = "enablePNGStageCreation"
        static let defaultStageZoom = "defaultStageZoom"
        static let defaultStageBoundLeft = "defaultStageBoundLeft"
        static let defaultStageBoundRight = "defaultStageBoundRight"
    }
    
    // MARK: - Advanced Features
    
    /// Whether the "Create Stage from PNG" feature is enabled
    public var enablePNGStageCreation: Bool {
        get { defaults.bool(forKey: Keys.enablePNGStageCreation) }
        set { 
            defaults.set(newValue, forKey: Keys.enablePNGStageCreation)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    // MARK: - Stage Creation Defaults
    
    /// Default zoom level for created stages (1.0 = normal)
    public var defaultStageZoom: Double {
        get { defaults.double(forKey: Keys.defaultStageZoom) }
        set { defaults.set(newValue, forKey: Keys.defaultStageZoom) }
    }
    
    /// Default camera left bound for created stages
    public var defaultStageBoundLeft: Int {
        get { defaults.integer(forKey: Keys.defaultStageBoundLeft) }
        set { defaults.set(newValue, forKey: Keys.defaultStageBoundLeft) }
    }
    
    /// Default camera right bound for created stages
    public var defaultStageBoundRight: Int {
        get { defaults.integer(forKey: Keys.defaultStageBoundRight) }
        set { defaults.set(newValue, forKey: Keys.defaultStageBoundRight) }
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let settingsChanged = Notification.Name("AppSettingsChanged")
}
