import Foundation
import AppKit

// MARK: - Service Protocols

/// Protocol for the IkemenBridge/EmulatorBridge service
protocol IkemenBridgeProtocol: AnyObject {
    var workingDirectory: URL? { get }
    var characters: [CharacterInfo] { get }
    var stages: [StageInfo] { get }
    var screenpacks: [ScreenpackInfo] { get }
    var isEngineRunning: Bool { get }
    
    func setWorkingDirectory(_ url: URL)
    func loadContent()
    func refreshStages()
    func launchEngine() throws
    func terminateEngine()
    func installContent(from archiveURL: URL, overwrite: Bool) throws -> String
    func installContentFolder(from folderURL: URL, overwrite: Bool) throws -> String
    func setActiveScreenpack(_ screenpack: ScreenpackInfo)
}

/// Protocol for the ImageCache service
protocol ImageCacheProtocol: AnyObject {
    func get(_ key: String) -> NSImage?
    func set(_ image: NSImage, for key: String)
    func remove(_ key: String)
    func clear()
    func getPortrait(for character: CharacterInfo) -> NSImage?
    func getStagePreview(for stage: StageInfo) -> NSImage?
    func clearCharacter(_ characterId: String)
    func clearStage(_ stageId: String)
}

/// Protocol for the MetadataStore service
protocol MetadataStoreProtocol: AnyObject {
    var isInitialized: Bool { get }
    
    func initialize(workingDir: URL) throws
    func indexCharacter(_ info: CharacterInfo) throws
    func indexStage(_ info: StageInfo) throws
    func deleteCharacter(id: String) throws
    func deleteStage(id: String) throws
    func allCharacters() throws -> [CharacterRecord]
    func allStages() throws -> [StageRecord]
    func searchCharacters(query: String) throws -> [CharacterRecord]
    func searchStages(query: String) throws -> [StageRecord]
    func recentlyInstalled(limit: Int) throws -> [RecentInstall]
    func reindexAll(from workingDir: URL) throws
}

/// Protocol for the CollectionStore service
protocol CollectionStoreProtocol: AnyObject {
    var collections: [Collection] { get }
    var activeCollectionId: UUID? { get }
    var activeCollection: Collection? { get }
    
    func collection(withId id: UUID) -> Collection?
    func createCollection(name: String, icon: String) -> Collection
    func update(_ collection: Collection)
    func delete(_ collection: Collection)
    func setActive(_ collection: Collection)
    func addCharacter(folder: String, def: String?, to collectionId: UUID)
    func removeCharacter(entryId: UUID, from collectionId: UUID)
    func addStage(folder: String, to collectionId: UUID)
    func removeStage(folder: String, from collectionId: UUID)
    func syncDefaultCollectionCharacters(_ characters: [(folder: String, def: String?)])
    func syncDefaultCollectionStages(_ stages: [String])
}

/// Protocol for the AppSettings service
protocol AppSettingsProtocol: AnyObject {
    var hasCompletedFRE: Bool { get set }
    var ikemenGOPath: URL? { get set }
    var hasValidIkemenGOInstallation: Bool { get }
    var enablePNGStageCreation: Bool { get set }
    var defaultStageZoom: Double { get set }
    var defaultStageBoundLeft: Int { get set }
    var defaultStageBoundRight: Int { get set }
}
