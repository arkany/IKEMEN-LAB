import Foundation

// MARK: - Notifications

extension Notification.Name {
    static let collectionActivated = Notification.Name("collectionActivated")
}

// MARK: - CollectionStore

/// Manages persistence and retrieval of collections
class CollectionStore: ObservableObject {
    static let shared = CollectionStore()
    
    @Published private(set) var collections: [Collection] = []
    @Published private(set) var activeCollectionId: UUID?
    
    private let collectionsDirectory: URL
    private let activeCollectionKey = "activeCollectionId"
    
    private init() {
        // ~/Library/Application Support/IKEMEN Lab/collections/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        collectionsDirectory = appSupport.appendingPathComponent("IKEMEN Lab/collections", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: collectionsDirectory, withIntermediateDirectories: true)
        
        // Load collections
        loadCollections()
        loadActiveCollectionId()
        
        // Ensure default collection exists
        ensureDefaultCollection()
    }
    
    // MARK: - Public API
    
    /// Get collection by ID
    func collection(withId id: UUID) -> Collection? {
        collections.first { $0.id == id }
    }
    
    /// Get the currently active collection
    var activeCollection: Collection? {
        guard let id = activeCollectionId else { return nil }
        return collection(withId: id)
    }
    
    /// Create a new collection
    func createCollection(name: String, icon: String = "folder.fill") -> Collection {
        let collection = Collection(name: name, icon: icon)
        collections.append(collection)
        save(collection)
        return collection
    }
    
    /// Update an existing collection
    func update(_ collection: Collection) {
        var updated = collection
        updated.modifiedAt = Date()
        
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = updated
        }
        save(updated)
    }
    
    /// Delete a collection (cannot delete default)
    func delete(_ collection: Collection) {
        guard !collection.isDefault else { return }
        
        collections.removeAll { $0.id == collection.id }
        
        let fileURL = collectionsDirectory.appendingPathComponent("\(collection.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
        
        // If deleted collection was active, switch to default
        if activeCollectionId == collection.id {
            if let defaultCollection = collections.first(where: { $0.isDefault }) {
                setActive(defaultCollection)
            }
        }
    }
    
    /// Set a collection as active (generates select.def)
    func setActive(_ collection: Collection) {
        activeCollectionId = collection.id
        UserDefaults.standard.set(collection.id.uuidString, forKey: activeCollectionKey)
        
        // Notify that we need to generate select.def
        NotificationCenter.default.post(name: .collectionActivated, object: collection)
    }
    
    // MARK: - Characters
    
    /// Add a character to a collection
    func addCharacter(folder: String, def: String? = nil, to collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        
        // Don't add duplicates
        guard !collection.characters.contains(where: { $0.characterFolder == folder }) else { return }
        
        collection.characters.append(.character(folder: folder, def: def))
        update(collection)
    }
    
    /// Remove a character from a collection
    func removeCharacter(entryId: UUID, from collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        collection.characters.removeAll { $0.id == entryId }
        update(collection)
    }
    
    /// Reorder characters in a collection
    func reorderCharacters(in collectionId: UUID, from sourceIndex: Int, to destinationIndex: Int) {
        guard var collection = collection(withId: collectionId) else { return }
        let entry = collection.characters.remove(at: sourceIndex)
        collection.characters.insert(entry, at: destinationIndex)
        update(collection)
    }
    
    /// Add a randomselect placeholder
    func addRandomSelect(to collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        collection.characters.append(.randomSelect())
        update(collection)
    }
    
    /// Add an empty slot for grid spacing
    func addEmptySlot(to collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        collection.characters.append(.emptySlot())
        update(collection)
    }
    
    // MARK: - Stages
    
    /// Add a stage to a collection
    func addStage(folder: String, to collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        guard !collection.stages.contains(folder) else { return }
        collection.stages.append(folder)
        update(collection)
    }
    
    /// Remove a stage from a collection
    func removeStage(folder: String, from collectionId: UUID) {
        guard var collection = collection(withId: collectionId) else { return }
        collection.stages.removeAll { $0 == folder }
        update(collection)
    }
    
    // MARK: - Private
    
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
    
    private func loadActiveCollectionId() {
        if let idString = UserDefaults.standard.string(forKey: activeCollectionKey),
           let id = UUID(uuidString: idString) {
            activeCollectionId = id
        }
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
    
    private func ensureDefaultCollection() {
        // Check if default collection exists
        if !collections.contains(where: { $0.isDefault }) {
            var defaultCollection = Collection(name: "All Characters", icon: "square.grid.3x3.fill")
            defaultCollection.isDefault = true
            
            // Populate with all characters from library
            // This will be done by EmulatorBridge when it loads characters
            
            collections.insert(defaultCollection, at: 0)
            save(defaultCollection)
            
            // Set as active if nothing is active
            if activeCollectionId == nil {
                setActive(defaultCollection)
            }
        }
    }
}
