import XCTest
@testable import IKEMEN_Lab

/// Tests for CollectionStore persistence and CRUD operations
/// Uses a testable wrapper to avoid polluting the real app's data
final class CollectionStoreTests: XCTestCase {
    
    var tempDirectory: URL!
    var store: TestableCollectionStore!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        store = TestableCollectionStore(directory: tempDirectory)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        store = nil
        super.tearDown()
    }
    
    // MARK: - Create Tests
    
    func testCreateCollectionAddsToList() {
        // When
        let collection = store.createCollection(name: "Test Collection")
        
        // Then
        XCTAssertEqual(store.collections.count, 1)
        XCTAssertEqual(store.collections.first?.id, collection.id)
        XCTAssertEqual(store.collections.first?.name, "Test Collection")
    }
    
    func testCreateCollectionWithCustomIcon() {
        // When
        let collection = store.createCollection(name: "Test", icon: "star.fill")
        
        // Then
        XCTAssertEqual(collection.icon, "star.fill")
    }
    
    func testCreateCollectionPersistsToFile() {
        // When
        let collection = store.createCollection(name: "Persisted")
        
        // Then
        let fileURL = tempDirectory.appendingPathComponent("\(collection.id.uuidString).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testCreateCollectionSetsDefaultValues() {
        // When
        let collection = store.createCollection(name: "Test")
        
        // Then
        XCTAssertTrue(collection.characters.isEmpty)
        XCTAssertTrue(collection.stages.isEmpty)
        XCTAssertNil(collection.screenpackPath)
        XCTAssertFalse(collection.isDefault)
    }
    
    // MARK: - Read Tests
    
    func testCollectionWithIdFindsExisting() {
        // Given
        let collection = store.createCollection(name: "Test")
        
        // When
        let found = store.collection(withId: collection.id)
        
        // Then
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Test")
    }
    
    func testCollectionWithIdReturnsNilForUnknown() {
        // When
        let found = store.collection(withId: UUID())
        
        // Then
        XCTAssertNil(found)
    }
    
    // MARK: - Update Tests
    
    func testUpdateCollectionModifiesInMemory() {
        // Given
        var collection = store.createCollection(name: "Original")
        collection.name = "Updated"
        
        // When
        store.update(collection)
        
        // Then
        let found = store.collection(withId: collection.id)
        XCTAssertEqual(found?.name, "Updated")
    }
    
    func testUpdateCollectionPersistsChanges() throws {
        // Given
        var collection = store.createCollection(name: "Original")
        collection.name = "Persisted Update"
        
        // When
        store.update(collection)
        
        // Then - Read file directly
        let fileURL = tempDirectory.appendingPathComponent("\(collection.id.uuidString).json")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Collection.self, from: data)
        XCTAssertEqual(decoded.name, "Persisted Update")
    }
    
    func testUpdateCollectionUpdatesModifiedDate() throws {
        // Given
        var collection = store.createCollection(name: "Test")
        let originalModified = collection.modifiedAt
        
        // Wait a tiny bit to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.01)
        
        collection.name = "Changed"
        
        // When
        store.update(collection)
        
        // Then
        let found = store.collection(withId: collection.id)
        XCTAssertGreaterThan(found!.modifiedAt, originalModified)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteCollectionRemovesFromList() {
        // Given
        let collection = store.createCollection(name: "ToDelete")
        XCTAssertEqual(store.collections.count, 1)
        
        // When
        store.delete(collection)
        
        // Then
        XCTAssertTrue(store.collections.isEmpty)
    }
    
    func testDeleteCollectionRemovesFile() {
        // Given
        let collection = store.createCollection(name: "ToDelete")
        let fileURL = tempDirectory.appendingPathComponent("\(collection.id.uuidString).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // When
        store.delete(collection)
        
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testCannotDeleteDefaultCollection() {
        // Given
        var collection = store.createCollection(name: "Default")
        collection.isDefault = true
        store.update(collection)
        
        // When
        store.delete(collection)
        
        // Then - Should still exist
        XCTAssertEqual(store.collections.count, 1)
    }
    
    // MARK: - Character Management Tests
    
    func testAddCharacterToCollection() {
        // Given
        let collection = store.createCollection(name: "Test")
        
        // When
        store.addCharacter(folder: "Ryu", def: "Ryu.def", to: collection.id)
        
        // Then
        let updated = store.collection(withId: collection.id)
        XCTAssertEqual(updated?.characters.count, 1)
        XCTAssertEqual(updated?.characters.first?.characterFolder, "Ryu")
        XCTAssertEqual(updated?.characters.first?.defFile, "Ryu.def")
    }
    
    func testAddCharacterPreventsDuplicates() {
        // Given
        let collection = store.createCollection(name: "Test")
        store.addCharacter(folder: "Ryu", to: collection.id)
        
        // When - Try to add same character again
        store.addCharacter(folder: "Ryu", to: collection.id)
        
        // Then - Should still only have one
        let updated = store.collection(withId: collection.id)
        XCTAssertEqual(updated?.characters.count, 1)
    }
    
    func testRemoveCharacterFromCollection() {
        // Given
        let collection = store.createCollection(name: "Test")
        store.addCharacter(folder: "Ryu", to: collection.id)
        let updated = store.collection(withId: collection.id)!
        let entryId = updated.characters.first!.id
        
        // When
        store.removeCharacter(entryId: entryId, from: collection.id)
        
        // Then
        let final = store.collection(withId: collection.id)
        XCTAssertTrue(final?.characters.isEmpty ?? false)
    }
    
    func testReorderCharacters() {
        // Given
        let collection = store.createCollection(name: "Test")
        store.addCharacter(folder: "Ryu", to: collection.id)
        store.addCharacter(folder: "Ken", to: collection.id)
        store.addCharacter(folder: "Chun-Li", to: collection.id)
        
        // When - Move Chun-Li (index 2) to first position (index 0)
        store.reorderCharacters(in: collection.id, from: 2, to: 0)
        
        // Then
        let updated = store.collection(withId: collection.id)!
        XCTAssertEqual(updated.characters[0].characterFolder, "Chun-Li")
        XCTAssertEqual(updated.characters[1].characterFolder, "Ryu")
        XCTAssertEqual(updated.characters[2].characterFolder, "Ken")
    }
    
    func testAddRandomSelect() {
        // Given
        let collection = store.createCollection(name: "Test")
        
        // When
        store.addRandomSelect(to: collection.id)
        
        // Then
        let updated = store.collection(withId: collection.id)
        XCTAssertEqual(updated?.characters.count, 1)
        XCTAssertEqual(updated?.characters.first?.entryType, .randomSelect)
    }
    
    func testAddEmptySlot() {
        // Given
        let collection = store.createCollection(name: "Test")
        
        // When
        store.addEmptySlot(to: collection.id)
        
        // Then
        let updated = store.collection(withId: collection.id)
        XCTAssertEqual(updated?.characters.count, 1)
        XCTAssertEqual(updated?.characters.first?.entryType, .emptySlot)
    }
    
    // MARK: - Stage Management Tests
    
    func testAddStageToCollection() {
        // Given
        let collection = store.createCollection(name: "Test")
        
        // When
        store.addStage(folder: "Training", to: collection.id)
        
        // Then
        let updated = store.collection(withId: collection.id)
        XCTAssertEqual(updated?.stages, ["Training"])
    }
    
    func testAddStagePreventsDuplicates() {
        // Given
        let collection = store.createCollection(name: "Test")
        store.addStage(folder: "Training", to: collection.id)
        
        // When
        store.addStage(folder: "Training", to: collection.id)
        
        // Then
        let updated = store.collection(withId: collection.id)
        XCTAssertEqual(updated?.stages.count, 1)
    }
    
    func testRemoveStageFromCollection() {
        // Given
        let collection = store.createCollection(name: "Test")
        store.addStage(folder: "Training", to: collection.id)
        
        // When
        store.removeStage(folder: "Training", from: collection.id)
        
        // Then
        let updated = store.collection(withId: collection.id)
        XCTAssertTrue(updated?.stages.isEmpty ?? false)
    }
    
    // MARK: - Active Collection Tests
    
    func testSetActiveCollection() {
        // Given
        let collection = store.createCollection(name: "Test")
        
        // When
        store.setActive(collection)
        
        // Then
        XCTAssertEqual(store.activeCollectionId, collection.id)
    }
    
    func testActiveCollectionReturnsCorrectCollection() {
        // Given
        let _ = store.createCollection(name: "First")
        let collection2 = store.createCollection(name: "Second")
        
        // When
        store.setActive(collection2)
        
        // Then
        XCTAssertEqual(store.activeCollection?.id, collection2.id)
        XCTAssertEqual(store.activeCollection?.name, "Second")
    }
    
    // MARK: - Persistence Tests
    
    func testCollectionsPersistAcrossLoads() throws {
        // Given
        let collection = store.createCollection(name: "Persistent")
        store.addCharacter(folder: "Ryu", to: collection.id)
        let originalId = collection.id
        
        // When - Create new store pointing to same directory
        let newStore = TestableCollectionStore(directory: tempDirectory)
        
        // Then
        XCTAssertEqual(newStore.collections.count, 1)
        XCTAssertEqual(newStore.collections.first?.id, originalId)
        XCTAssertEqual(newStore.collections.first?.name, "Persistent")
        XCTAssertEqual(newStore.collections.first?.characters.count, 1)
    }
}

// MARK: - Testable CollectionStore

/// A testable version of CollectionStore that allows custom directory
/// This mirrors the real CollectionStore API for testing without using the singleton
class TestableCollectionStore {
    private(set) var collections: [Collection] = []
    private(set) var activeCollectionId: UUID?
    
    private let collectionsDirectory: URL
    
    init(directory: URL) {
        self.collectionsDirectory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadCollections()
    }
    
    var activeCollection: Collection? {
        guard let id = activeCollectionId else { return nil }
        return collection(withId: id)
    }
    
    func collection(withId id: UUID) -> Collection? {
        collections.first { $0.id == id }
    }
    
    func createCollection(name: String, icon: String = "folder.fill") -> Collection {
        let collection = Collection(name: name, icon: icon)
        collections.append(collection)
        save(collection)
        return collection
    }
    
    func update(_ collection: Collection) {
        var updated = collection
        updated.modifiedAt = Date()
        
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = updated
        }
        save(updated)
    }
    
    func delete(_ collection: Collection) {
        guard !collection.isDefault else { return }
        
        collections.removeAll { $0.id == collection.id }
        
        let fileURL = collectionsDirectory.appendingPathComponent("\(collection.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func setActive(_ collection: Collection) {
        activeCollectionId = collection.id
    }
    
    func addCharacter(folder: String, def: String? = nil, to collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        guard !collection.characters.contains(where: { $0.characterFolder == folder }) else { return }
        
        collection.characters.append(.character(folder: folder, def: def))
        update(collection)
    }
    
    func removeCharacter(entryId: UUID, from collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        collection.characters.removeAll { $0.id == entryId }
        update(collection)
    }
    
    func reorderCharacters(in collectionId: UUID, from sourceIndex: Int, to destinationIndex: Int) {
        guard var collection = collection(withId: collectionId) else { return }
        let entry = collection.characters.remove(at: sourceIndex)
        collection.characters.insert(entry, at: destinationIndex)
        update(collection)
    }
    
    func addRandomSelect(to collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        collection.characters.append(.randomSelect())
        update(collection)
    }
    
    func addEmptySlot(to collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        collection.characters.append(.emptySlot())
        update(collection)
    }
    
    func addStage(folder: String, to collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        guard !collection.stages.contains(folder) else { return }
        collection.stages.append(folder)
        update(collection)
    }
    
    func removeStage(folder: String, from collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        collection.stages.removeAll { $0 == folder }
        update(collection)
    }
    
    private func loadCollections() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: collectionsDirectory, includingPropertiesForKeys: nil) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        collections = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Collection? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Collection.self, from: data)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private func save(_ collection: Collection) {
        let fileURL = collectionsDirectory.appendingPathComponent("\(collection.id.uuidString).json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(collection) {
            try? data.write(to: fileURL)
        }
    }
}
