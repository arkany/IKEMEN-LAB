# Task: Implement Dependency Injection to Replace Singletons

## Context
IKEMEN Lab uses several singletons:
- `EmulatorBridge.shared`
- `ImageCache.shared`
- `MetadataStore.shared`
- `CollectionStore.shared`
- `AppSettings.shared`

Singletons make testing difficult and create hidden dependencies. We want to introduce dependency injection while maintaining backward compatibility.

## Objective
Implement a dependency injection container that:
1. Provides the same convenience as singletons for production code
2. Allows injecting mock dependencies for testing
3. Doesn't require rewriting all existing code at once

## Technical Requirements

### 1. Create Service Protocol Definitions
Create: `IKEMEN Lab/Core/Protocols/Services.swift`

```swift
import Foundation
import AppKit

// MARK: - Service Protocols

protocol EmulatorBridgeProtocol: AnyObject {
    var ikemenPath: URL? { get set }
    var characters: [CharacterInfo] { get }
    var stages: [StageInfo] { get }
    var screenpacks: [ScreenpackInfo] { get }
    
    func scanContent()
    func launchGame()
    func extractPortrait(for character: CharacterInfo) -> NSImage?
    func extractStagePreview(for stage: StageInfo) -> NSImage?
}

protocol ImageCacheProtocol: AnyObject {
    func cachedPortrait(for characterPath: String) -> NSImage?
    func cachePortrait(_ image: NSImage, for characterPath: String)
    func cachedStagePreview(for stagePath: String) -> NSImage?
    func cacheStagePreview(_ image: NSImage, for stagePath: String)
    func clearCache()
}

protocol MetadataStoreProtocol: AnyObject {
    func indexCharacter(_ character: CharacterInfo) throws
    func indexStage(_ stage: StageInfo) throws
    func searchCharacters(query: String) throws -> [CharacterInfo]
    func searchStages(query: String) throws -> [StageInfo]
    func getRecentlyInstalled(limit: Int) throws -> [Any]
}

protocol CollectionStoreProtocol: AnyObject {
    var collections: [Collection] { get }
    func loadCollections()
    func saveCollection(_ collection: Collection) throws
    func deleteCollection(_ collection: Collection) throws
    func activateCollection(_ collection: Collection) throws
}

protocol AppSettingsProtocol: AnyObject {
    var enablePNGStageCreation: Bool { get set }
    var lastUpdateCheck: Date? { get set }
    var hasCompletedFRE: Bool { get set }
}
```

### 2. Create Dependency Container
Create: `IKEMEN Lab/Core/DependencyContainer.swift`

```swift
import Foundation

/// Central dependency container for the app
final class DependencyContainer {
    /// Shared instance for production use
    static let shared = DependencyContainer()
    
    // MARK: - Service Storage
    private var emulatorBridge: EmulatorBridgeProtocol?
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
        emulatorBridge: EmulatorBridgeProtocol? = nil,
        imageCache: ImageCacheProtocol? = nil,
        metadataStore: MetadataStoreProtocol? = nil,
        collectionStore: CollectionStoreProtocol? = nil,
        appSettings: AppSettingsProtocol? = nil
    ) {
        self.emulatorBridge = emulatorBridge
        self.imageCache = imageCache
        self.metadataStore = metadataStore
        self.collectionStore = collectionStore
        self.appSettings = appSettings
    }
    
    private func registerDefaults() {
        // Lazy initialization - actual singletons created on first access
    }
    
    // MARK: - Service Accessors
    
    func resolveEmulatorBridge() -> EmulatorBridgeProtocol {
        if let bridge = emulatorBridge {
            return bridge
        }
        let bridge = EmulatorBridge.shared
        emulatorBridge = bridge
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
    
    func register(emulatorBridge: EmulatorBridgeProtocol) {
        self.emulatorBridge = emulatorBridge
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
```

### 3. Conform Existing Classes to Protocols
Modify existing singletons to conform to their protocols:

```swift
// In EmulatorBridge.swift
extension EmulatorBridge: EmulatorBridgeProtocol { }

// In ImageCache.swift  
extension ImageCache: ImageCacheProtocol { }

// In MetadataStore.swift
extension MetadataStore: MetadataStoreProtocol { }

// In CollectionStore.swift
extension CollectionStore: CollectionStoreProtocol { }

// In AppSettings.swift
extension AppSettings: AppSettingsProtocol { }
```

### 4. Create Injectable Base Class
Create: `IKEMEN Lab/Shared/Injectable.swift`

```swift
import AppKit

/// Base class for view controllers that use dependency injection
class InjectableViewController: NSViewController {
    let container: DependencyContainer
    
    var emulatorBridge: EmulatorBridgeProtocol {
        container.resolveEmulatorBridge()
    }
    
    var imageCache: ImageCacheProtocol {
        container.resolveImageCache()
    }
    
    var metadataStore: MetadataStoreProtocol {
        container.resolveMetadataStore()
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
    
    var emulatorBridge: EmulatorBridgeProtocol {
        container.resolveEmulatorBridge()
    }
    
    var imageCache: ImageCacheProtocol {
        container.resolveImageCache()
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
```

### 5. Create Mock Implementations for Testing
Create: `IKEMEN Lab Tests/Mocks/MockServices.swift`

```swift
import Foundation
@testable import IKEMEN_Lab

class MockEmulatorBridge: EmulatorBridgeProtocol {
    var ikemenPath: URL?
    var characters: [CharacterInfo] = []
    var stages: [StageInfo] = []
    var screenpacks: [ScreenpackInfo] = []
    
    var scanContentCalled = false
    var launchGameCalled = false
    
    func scanContent() {
        scanContentCalled = true
    }
    
    func launchGame() {
        launchGameCalled = true
    }
    
    func extractPortrait(for character: CharacterInfo) -> NSImage? {
        return nil
    }
    
    func extractStagePreview(for stage: StageInfo) -> NSImage? {
        return nil
    }
}

class MockImageCache: ImageCacheProtocol {
    var portraits: [String: NSImage] = [:]
    var stagePreviews: [String: NSImage] = [:]
    var clearCacheCalled = false
    
    func cachedPortrait(for characterPath: String) -> NSImage? {
        portraits[characterPath]
    }
    
    func cachePortrait(_ image: NSImage, for characterPath: String) {
        portraits[characterPath] = image
    }
    
    func cachedStagePreview(for stagePath: String) -> NSImage? {
        stagePreviews[stagePath]
    }
    
    func cacheStagePreview(_ image: NSImage, for stagePath: String) {
        stagePreviews[stagePath] = image
    }
    
    func clearCache() {
        clearCacheCalled = true
        portraits.removeAll()
        stagePreviews.removeAll()
    }
}

// Add MockMetadataStore, MockCollectionStore, MockAppSettings similarly
```

### 6. Example Test Using DI
```swift
class CharacterBrowserViewTests: XCTestCase {
    var mockBridge: MockEmulatorBridge!
    var mockCache: MockImageCache!
    var container: DependencyContainer!
    
    override func setUp() {
        mockBridge = MockEmulatorBridge()
        mockCache = MockImageCache()
        container = DependencyContainer(
            emulatorBridge: mockBridge,
            imageCache: mockCache
        )
    }
    
    func testCharacterGridDisplaysCharacters() {
        // Arrange
        mockBridge.characters = [
            CharacterInfo(name: "Ryu", author: "Capcom", folderPath: "/chars/Ryu")
        ]
        
        // Act
        let view = CharacterBrowserView(container: container)
        
        // Assert
        XCTAssertEqual(view.characterCount, 1)
    }
}
```

## Migration Strategy

### Phase 1: Infrastructure (This Task)
- Create protocols
- Create DependencyContainer
- Create base classes
- Conform existing singletons to protocols

### Phase 2: Gradual Migration
- Update new views to use InjectableView/InjectableViewController
- Keep existing views working with `.shared` pattern
- Both patterns work simultaneously

### Phase 3: Full Migration (Optional)
- Update existing views one at a time
- Remove `.shared` accessors (or deprecate)

## Files to Create
1. `IKEMEN Lab/Core/Protocols/Services.swift`
2. `IKEMEN Lab/Core/DependencyContainer.swift`
3. `IKEMEN Lab/Shared/Injectable.swift`
4. `IKEMEN Lab Tests/Mocks/MockServices.swift`

## Files to Modify
1. `IKEMEN Lab/Core/EmulatorBridge.swift` - Add protocol conformance
2. `IKEMEN Lab/Core/ImageCache.swift` - Add protocol conformance
3. `IKEMEN Lab/Core/MetadataStore.swift` - Add protocol conformance
4. `IKEMEN Lab/Core/CollectionStore.swift` - Add protocol conformance
5. `IKEMEN Lab/Core/AppSettings.swift` - Add protocol conformance

## Testing
1. Ensure all existing tests still pass
2. Write new test using mock dependencies
3. Verify `.shared` pattern still works for existing code
