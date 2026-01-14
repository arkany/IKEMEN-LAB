import Foundation
import AppKit
@testable import IKEMEN_Lab

// MARK: - Mock IkemenBridge

class MockIkemenBridge: IkemenBridgeProtocol {
    var workingDirectory: URL?
    var characters: [CharacterInfo] = []
    var stages: [StageInfo] = []
    var screenpacks: [ScreenpackInfo] = []
    var isEngineRunning: Bool = false
    
    var setWorkingDirectoryCalled = false
    var loadContentCalled = false
    var refreshStagesCalled = false
    var launchEngineCalled = false
    var terminateEngineCalled = false
    var installContentCalled = false
    var installContentFolderCalled = false
    var setActiveScreenpackCalled = false
    
    func setWorkingDirectory(_ url: URL) {
        setWorkingDirectoryCalled = true
        workingDirectory = url
    }
    
    func loadContent() {
        loadContentCalled = true
    }
    
    func refreshStages() {
        refreshStagesCalled = true
    }
    
    func launchEngine() throws {
        launchEngineCalled = true
        isEngineRunning = true
    }
    
    func terminateEngine() {
        terminateEngineCalled = true
        isEngineRunning = false
    }
    
    func installContent(from archiveURL: URL, overwrite: Bool) throws -> String {
        installContentCalled = true
        return "Test Content Installed"
    }
    
    func installContentFolder(from folderURL: URL, overwrite: Bool) throws -> String {
        installContentFolderCalled = true
        return "Test Folder Installed"
    }
    
    func setActiveScreenpack(_ screenpack: ScreenpackInfo) {
        setActiveScreenpackCalled = true
    }
}

// MARK: - Mock ImageCache

class MockImageCache: ImageCacheProtocol {
    var cache: [String: NSImage] = [:]
    var getCalled = false
    var setCalled = false
    var removeCalled = false
    var clearCalled = false
    var clearCharacterCalled = false
    var clearStageCalled = false
    
    func get(_ key: String) -> NSImage? {
        getCalled = true
        return cache[key]
    }
    
    func set(_ image: NSImage, for key: String) {
        setCalled = true
        cache[key] = image
    }
    
    func remove(_ key: String) {
        removeCalled = true
        cache.removeValue(forKey: key)
    }
    
    func clear() {
        clearCalled = true
        cache.removeAll()
    }
    
    func getPortrait(for character: CharacterInfo) -> NSImage? {
        return get("portrait:\(character.id)")
    }
    
    func getStagePreview(for stage: StageInfo) -> NSImage? {
        return get("stage:\(stage.id)")
    }
    
    func clearCharacter(_ characterId: String) {
        clearCharacterCalled = true
        remove("portrait:\(characterId)")
    }
    
    func clearStage(_ stageId: String) {
        clearStageCalled = true
        remove("stage:\(stageId)")
    }
}

// MARK: - Mock MetadataStore

class MockMetadataStore: MetadataStoreProtocol {
    var isInitialized: Bool = true
    var characterRecords: [CharacterRecord] = []
    var stageRecords: [StageRecord] = []
    var recentInstalls: [RecentInstall] = []
    
    var initializeCalled = false
    var indexCharacterCalled = false
    var indexStageCalled = false
    var deleteCharacterCalled = false
    var deleteStageCalled = false
    var searchCharactersCalled = false
    var searchStagesCalled = false
    var recentlyInstalledCalled = false
    var reindexAllCalled = false
    
    func initialize(workingDir: URL) throws {
        initializeCalled = true
        isInitialized = true
    }
    
    func indexCharacter(_ info: CharacterInfo) throws {
        indexCharacterCalled = true
        let record = CharacterRecord(
            id: info.id,
            name: info.displayName,
            author: info.author,
            versionDate: nil,
            spriteFile: info.spriteFile,
            folderPath: info.directory.path,
            installedAt: Date(),
            updatedAt: Date(),
            sourceGame: nil,
            style: nil,
            isHD: nil,
            hasAI: nil,
            tags: nil
        )
        characterRecords.append(record)
    }
    
    func indexStage(_ info: StageInfo) throws {
        indexStageCalled = true
        let record = StageRecord(
            id: info.id,
            name: info.name,
            author: info.author,
            filePath: info.defFile.path,
            installedAt: Date(),
            updatedAt: Date(),
            sourceGame: nil,
            resolution: nil
        )
        stageRecords.append(record)
    }
    
    func deleteCharacter(id: String) throws {
        deleteCharacterCalled = true
        characterRecords.removeAll { $0.id == id }
    }
    
    func deleteStage(id: String) throws {
        deleteStageCalled = true
        stageRecords.removeAll { $0.id == id }
    }
    
    func allCharacters() throws -> [CharacterRecord] {
        return characterRecords
    }
    
    func allStages() throws -> [StageRecord] {
        return stageRecords
    }
    
    func searchCharacters(query: String) throws -> [CharacterRecord] {
        searchCharactersCalled = true
        return characterRecords.filter { 
            $0.name.localizedCaseInsensitiveContains(query) || 
            $0.author.localizedCaseInsensitiveContains(query)
        }
    }
    
    func searchStages(query: String) throws -> [StageRecord] {
        searchStagesCalled = true
        return stageRecords.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.author.localizedCaseInsensitiveContains(query)
        }
    }
    
    func recentlyInstalled(limit: Int) throws -> [RecentInstall] {
        recentlyInstalledCalled = true
        return Array(recentInstalls.prefix(limit))
    }
    
    func reindexAll(from workingDir: URL) throws {
        reindexAllCalled = true
    }
}

// MARK: - Mock CollectionStore

class MockCollectionStore: CollectionStoreProtocol {
    var collections: [Collection] = []
    var activeCollectionId: UUID?
    var activeCollection: Collection? {
        guard let id = activeCollectionId else { return nil }
        return collections.first { $0.id == id }
    }
    
    var createCollectionCalled = false
    var updateCalled = false
    var deleteCalled = false
    var setActiveCalled = false
    var addCharacterCalled = false
    var removeCharacterCalled = false
    var addStageCalled = false
    var removeStageCalled = false
    
    func collection(withId id: UUID) -> Collection? {
        return collections.first { $0.id == id }
    }
    
    func createCollection(name: String, icon: String) -> Collection {
        createCollectionCalled = true
        let collection = Collection(name: name, icon: icon)
        collections.append(collection)
        return collection
    }
    
    func update(_ collection: Collection) {
        updateCalled = true
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = collection
        }
    }
    
    func delete(_ collection: Collection) {
        deleteCalled = true
        collections.removeAll { $0.id == collection.id }
    }
    
    func setActive(_ collection: Collection) {
        setActiveCalled = true
        activeCollectionId = collection.id
    }
    
    func addCharacter(folder: String, def: String?, to collectionId: UUID) {
        addCharacterCalled = true
        guard var collection = collection(withId: collectionId) else { return }
        collection.characters.append(.character(folder: folder, def: def))
        update(collection)
    }
    
    func removeCharacter(entryId: UUID, from collectionId: UUID) {
        removeCharacterCalled = true
        guard var collection = collection(withId: collectionId) else { return }
        collection.characters.removeAll { $0.id == entryId }
        update(collection)
    }
    
    func addStage(folder: String, to collectionId: UUID) {
        addStageCalled = true
        guard var collection = collection(withId: collectionId) else { return }
        collection.stages.append(folder)
        update(collection)
    }
    
    func removeStage(folder: String, from collectionId: UUID) {
        removeStageCalled = true
        guard var collection = collection(withId: collectionId) else { return }
        collection.stages.removeAll { $0 == folder }
        update(collection)
    }
    
    func syncDefaultCollectionCharacters(_ characters: [(folder: String, def: String?)]) {
        // Mock implementation
    }
    
    func syncDefaultCollectionStages(_ stages: [String]) {
        // Mock implementation
    }
}

// MARK: - Mock AppSettings

class MockAppSettings: AppSettingsProtocol {
    var hasCompletedFRE: Bool = false
    var ikemenGOPath: URL?
    var hasValidIkemenGOInstallation: Bool = false
    var enablePNGStageCreation: Bool = false
    var defaultStageZoom: Double = 1.0
    var defaultStageBoundLeft: Int = -150
    var defaultStageBoundRight: Int = 150
}
