import XCTest
@testable import IKEMEN_Lab

/// Tests demonstrating the dependency injection container
final class DependencyInjectionTests: XCTestCase {
    
    var mockBridge: MockIkemenBridge!
    var mockCache: MockImageCache!
    var mockStore: MockMetadataStore!
    var mockCollections: MockCollectionStore!
    var mockSettings: MockAppSettings!
    var container: DependencyContainer!
    
    override func setUp() {
        super.setUp()
        
        mockBridge = MockIkemenBridge()
        mockCache = MockImageCache()
        mockStore = MockMetadataStore()
        mockCollections = MockCollectionStore()
        mockSettings = MockAppSettings()
        
        container = DependencyContainer(
            ikemenBridge: mockBridge,
            imageCache: mockCache,
            metadataStore: mockStore,
            collectionStore: mockCollections,
            appSettings: mockSettings
        )
    }
    
    override func tearDown() {
        container = nil
        mockBridge = nil
        mockCache = nil
        mockStore = nil
        mockCollections = nil
        mockSettings = nil
        super.tearDown()
    }
    
    // MARK: - Container Tests
    
    func testContainerResolvesIkemenBridge() {
        // When
        let bridge = container.resolveIkemenBridge()
        
        // Then
        XCTAssertTrue(bridge is MockIkemenBridge)
        XCTAssertIdentical(bridge as AnyObject, mockBridge)
    }
    
    func testContainerResolvesImageCache() {
        // When
        let cache = container.resolveImageCache()
        
        // Then
        XCTAssertTrue(cache is MockImageCache)
        XCTAssertIdentical(cache as AnyObject, mockCache)
    }
    
    func testContainerResolvesMetadataStore() {
        // When
        let store = container.resolveMetadataStore()
        
        // Then
        XCTAssertTrue(store is MockMetadataStore)
        XCTAssertIdentical(store as AnyObject, mockStore)
    }
    
    func testContainerResolvesCollectionStore() {
        // When
        let store = container.resolveCollectionStore()
        
        // Then
        XCTAssertTrue(store is MockCollectionStore)
        XCTAssertIdentical(store as AnyObject, mockCollections)
    }
    
    func testContainerResolvesAppSettings() {
        // When
        let settings = container.resolveAppSettings()
        
        // Then
        XCTAssertTrue(settings is MockAppSettings)
        XCTAssertIdentical(settings as AnyObject, mockSettings)
    }
    
    // MARK: - Mock Functionality Tests
    
    func testMockIkemenBridgeTracksMethodCalls() {
        // Given
        let bridge = container.resolveIkemenBridge() as! MockIkemenBridge
        
        // When
        bridge.loadContent()
        bridge.refreshStages()
        
        // Then
        XCTAssertTrue(bridge.loadContentCalled)
        XCTAssertTrue(bridge.refreshStagesCalled)
    }
    
    func testMockImageCacheCachesImages() throws {
        // Given
        let cache = container.resolveImageCache() as! MockImageCache
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        
        // When
        cache.set(testImage, for: "test_key")
        let retrieved = cache.get("test_key")
        
        // Then
        XCTAssertTrue(cache.setCalled)
        XCTAssertTrue(cache.getCalled)
        XCTAssertNotNil(retrieved)
    }
    
    func testMockMetadataStoreIndexesCharacters() throws {
        // Given
        let store = container.resolveMetadataStore() as! MockMetadataStore
        let testURL = URL(fileURLWithPath: "/test/chars/ryu")
        let testDefURL = URL(fileURLWithPath: "/test/chars/ryu/ryu.def")
        let character = CharacterInfo(directory: testURL, defFile: testDefURL)
        
        // When
        try store.indexCharacter(character)
        let characters = try store.allCharacters()
        
        // Then
        XCTAssertTrue(store.indexCharacterCalled)
        XCTAssertEqual(characters.count, 1)
        XCTAssertEqual(characters.first?.id, character.id)
    }
    
    func testMockCollectionStoreManagesCollections() {
        // Given
        let store = container.resolveCollectionStore() as! MockCollectionStore
        
        // When
        let collection = store.createCollection(name: "Test Collection", icon: "star")
        store.setActive(collection)
        
        // Then
        XCTAssertTrue(store.createCollectionCalled)
        XCTAssertTrue(store.setActiveCalled)
        XCTAssertEqual(store.collections.count, 1)
        XCTAssertEqual(store.activeCollectionId, collection.id)
    }
    
    func testMockAppSettingsStoresPreferences() {
        // Given
        let settings = container.resolveAppSettings() as! MockAppSettings
        
        // When
        settings.hasCompletedFRE = true
        settings.enablePNGStageCreation = true
        
        // Then
        XCTAssertTrue(settings.hasCompletedFRE)
        XCTAssertTrue(settings.enablePNGStageCreation)
    }
    
    // MARK: - Integration Tests
    
    func testContainerCanBeUsedWithInjectableViewController() {
        // Given
        let viewController = TestableInjectableViewController(container: container)
        
        // When
        let bridge = viewController.ikemenBridge
        
        // Then
        XCTAssertTrue(bridge is MockIkemenBridge)
    }
    
    func testDefaultContainerUsesSharedInstance() {
        // Given
        let viewController = TestableInjectableViewController()
        
        // When
        let container = viewController.container
        
        // Then
        XCTAssertIdentical(container as AnyObject, DependencyContainer.shared as AnyObject)
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testDefaultContainerResolvesToRealSingletons() {
        // Given
        let defaultContainer = DependencyContainer.shared
        
        // When
        let bridge = defaultContainer.resolveIkemenBridge()
        let cache = defaultContainer.resolveImageCache()
        let store = defaultContainer.resolveMetadataStore()
        let collections = defaultContainer.resolveCollectionStore()
        let settings = defaultContainer.resolveAppSettings()
        
        // Then - All resolve to actual singletons, not mocks
        XCTAssertTrue(bridge is IkemenBridge)
        XCTAssertTrue(cache is ImageCache)
        XCTAssertTrue(store is MetadataStore)
        XCTAssertTrue(collections is CollectionStore)
        XCTAssertTrue(settings is AppSettings)
    }
}

// MARK: - Test Helper Classes

/// Testable injectable view controller for DI tests
private class TestableInjectableViewController: InjectableViewController {
    // Exposes container and services for testing
}
