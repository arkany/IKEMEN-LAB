import AppKit

/// Base class for view controllers that use dependency injection
class InjectableViewController: NSViewController {
    let container: DependencyContainer
    
    var ikemenBridge: IkemenBridgeProtocol {
        container.resolveIkemenBridge()
    }
    
    var imageCache: ImageCacheProtocol {
        container.resolveImageCache()
    }
    
    var metadataStore: MetadataStoreProtocol {
        container.resolveMetadataStore()
    }
    
    var collectionStore: CollectionStoreProtocol {
        container.resolveCollectionStore()
    }
    
    var appSettings: AppSettingsProtocol {
        container.resolveAppSettings()
    }
    
    init(container: DependencyContainer = .shared) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.container = .shared
        super.init(coder: coder)
    }
}

/// Base class for views that use dependency injection
class InjectableView: NSView {
    let container: DependencyContainer
    
    var ikemenBridge: IkemenBridgeProtocol {
        container.resolveIkemenBridge()
    }
    
    var imageCache: ImageCacheProtocol {
        container.resolveImageCache()
    }
    
    var metadataStore: MetadataStoreProtocol {
        container.resolveMetadataStore()
    }
    
    var collectionStore: CollectionStoreProtocol {
        container.resolveCollectionStore()
    }
    
    var appSettings: AppSettingsProtocol {
        container.resolveAppSettings()
    }
    
    init(container: DependencyContainer = .shared) {
        self.container = container
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        self.container = .shared
        super.init(coder: coder)
    }
}
