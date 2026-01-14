import Foundation

/// Central dependency container for the app
final class DependencyContainer {
    /// Shared instance for production use
    static let shared = DependencyContainer()
    
    // MARK: - Service Storage
    private var ikemenBridge: IkemenBridgeProtocol?
    private var imageCache: ImageCacheProtocol?
    private var metadataStore: MetadataStoreProtocol?
    private var collectionStore: CollectionStoreProtocol?
    private var appSettings: AppSettingsProtocol?
    
    // MARK: - Initialization
    
    private init() {
        // Register default implementations
        registerDefaults()
    }
    
    /// Create a container with custom dependencies (for testing)
    init(
        ikemenBridge: IkemenBridgeProtocol? = nil,
        imageCache: ImageCacheProtocol? = nil,
        metadataStore: MetadataStoreProtocol? = nil,
        collectionStore: CollectionStoreProtocol? = nil,
        appSettings: AppSettingsProtocol? = nil
    ) {
        self.ikemenBridge = ikemenBridge
        self.imageCache = imageCache
        self.metadataStore = metadataStore
        self.collectionStore = collectionStore
        self.appSettings = appSettings
    }
    
    private func registerDefaults() {
        // Lazy initialization - actual singletons created on first access
    }
    
    // MARK: - Service Accessors
    
    func resolveIkemenBridge() -> IkemenBridgeProtocol {
        if let bridge = ikemenBridge {
            return bridge
        }
        let bridge = IkemenBridge.shared
        ikemenBridge = bridge
        return bridge
    }
    
    func resolveImageCache() -> ImageCacheProtocol {
        if let cache = imageCache {
            return cache
        }
        let cache = ImageCache.shared
        imageCache = cache
        return cache
    }
    
    func resolveMetadataStore() -> MetadataStoreProtocol {
        if let store = metadataStore {
            return store
        }
        let store = MetadataStore.shared
        metadataStore = store
        return store
    }
    
    func resolveCollectionStore() -> CollectionStoreProtocol {
        if let store = collectionStore {
            return store
        }
        let store = CollectionStore.shared
        collectionStore = store
        return store
    }
    
    func resolveAppSettings() -> AppSettingsProtocol {
        if let settings = appSettings {
            return settings
        }
        let settings = AppSettings.shared
        appSettings = settings
        return settings
    }
    
    // MARK: - Registration (for testing)
    
    func register(ikemenBridge: IkemenBridgeProtocol) {
        self.ikemenBridge = ikemenBridge
    }
    
    func register(imageCache: ImageCacheProtocol) {
        self.imageCache = imageCache
    }
    
    func register(metadataStore: MetadataStoreProtocol) {
        self.metadataStore = metadataStore
    }
    
    func register(collectionStore: CollectionStoreProtocol) {
        self.collectionStore = collectionStore
    }
    
    func register(appSettings: AppSettingsProtocol) {
        self.appSettings = appSettings
    }
}

// MARK: - Convenience Accessors (Migration helpers)

/// Global accessor that mirrors singleton pattern but uses DI container
var Services: DependencyContainer { DependencyContainer.shared }
