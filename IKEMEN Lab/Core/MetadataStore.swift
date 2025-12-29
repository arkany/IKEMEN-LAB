import Foundation
import GRDB

// MARK: - Database Records

/// Character metadata stored in SQLite
public struct CharacterRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public static let databaseTableName = "characters"
    
    public var id: String              // Folder name (primary key)
    public var name: String            // Display name from .def
    public var author: String
    public var versionDate: String?
    public var spriteFile: String?
    public var folderPath: String      // Full path to character directory
    public var installedAt: Date
    public var updatedAt: Date
    
    // Future fields for tagging/collections
    public var sourceGame: String?     // e.g., "Street Fighter", "KOF"
    public var style: String?          // e.g., "POTS", "MVC2", "Anime"
    public var isHD: Bool?
    public var hasAI: Bool?
}

/// Stage metadata stored in SQLite
public struct StageRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public static let databaseTableName = "stages"
    
    public var id: String              // Stage filename without extension (primary key)
    public var name: String            // Display name from .def
    public var author: String
    public var filePath: String        // Full path to .def file
    public var installedAt: Date
    public var updatedAt: Date
    
    // Future fields
    public var sourceGame: String?
    public var resolution: String?     // e.g., "1280x720", "640x480"
}

/// Recently installed content for dashboard
public struct RecentInstall: Codable, FetchableRecord {
    public var id: String
    public var name: String
    public var type: String            // "character" or "stage"
    public var installedAt: Date
}

// MARK: - Metadata Store

/// SQLite-backed metadata index for characters and stages
/// Provides fast search, filtering, and recently installed queries
public final class MetadataStore {
    
    // MARK: - Singleton
    
    public static let shared = MetadataStore()
    
    // MARK: - Properties
    
    private var dbQueue: DatabaseQueue?
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Database Setup
    
    /// Initialize the database at the given location
    /// Call this once at app startup with the Ikemen GO working directory
    public func initialize(workingDir: URL) throws {
        let dbPath = workingDir.appendingPathComponent("ikemenlab.sqlite").path
        
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.readonly = false
        
        dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
        
        try dbQueue?.write { db in
            try createTablesIfNeeded(db)
        }
    }
    
    /// Create database schema
    private func createTablesIfNeeded(_ db: Database) throws {
        // Characters table
        try db.create(table: "characters", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull().indexed()
            t.column("author", .text).notNull().indexed()
            t.column("versionDate", .text)
            t.column("spriteFile", .text)
            t.column("folderPath", .text).notNull()
            t.column("installedAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
            t.column("sourceGame", .text)
            t.column("style", .text)
            t.column("isHD", .boolean)
            t.column("hasAI", .boolean)
        }
        
        // Stages table
        try db.create(table: "stages", ifNotExists: true) { t in
            t.column("id", .text).primaryKey()
            t.column("name", .text).notNull().indexed()
            t.column("author", .text).notNull().indexed()
            t.column("filePath", .text).notNull()
            t.column("installedAt", .datetime).notNull()
            t.column("updatedAt", .datetime).notNull()
            t.column("sourceGame", .text)
            t.column("resolution", .text)
        }
        
        // Full-text search indexes (for future advanced search)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_characters_name_author 
            ON characters(name COLLATE NOCASE, author COLLATE NOCASE)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_stages_name_author 
            ON stages(name COLLATE NOCASE, author COLLATE NOCASE)
        """)
    }
    
    // MARK: - Character Operations
    
    /// Insert or update a character record
    public func upsertCharacter(_ record: CharacterRecord) throws {
        try dbQueue?.write { db in
            try record.save(db)
        }
    }
    
    /// Insert or update character from CharacterInfo
    public func indexCharacter(_ info: CharacterInfo) throws {
        let record = CharacterRecord(
            id: info.id,
            name: info.displayName,
            author: info.author,
            versionDate: info.versionDate.isEmpty ? nil : info.versionDate,
            spriteFile: info.spriteFile,
            folderPath: info.directory.path,
            installedAt: Date(),
            updatedAt: Date(),
            sourceGame: nil,
            style: nil,
            isHD: nil,
            hasAI: nil
        )
        try upsertCharacter(record)
    }
    
    /// Delete a character by ID
    public func deleteCharacter(id: String) throws {
        try dbQueue?.write { db in
            _ = try CharacterRecord.deleteOne(db, key: id)
        }
    }
    
    /// Get all characters
    public func allCharacters() throws -> [CharacterRecord] {
        try dbQueue?.read { db in
            try CharacterRecord.order(Column("name").collating(.localizedCaseInsensitiveCompare)).fetchAll(db)
        } ?? []
    }
    
    /// Search characters by name or author
    public func searchCharacters(query: String) throws -> [CharacterRecord] {
        guard !query.isEmpty else {
            return try allCharacters()
        }
        
        let pattern = "%\(query)%"
        return try dbQueue?.read { db in
            try CharacterRecord
                .filter(Column("name").like(pattern) || Column("author").like(pattern))
                .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                .fetchAll(db)
        } ?? []
    }
    
    /// Get character by ID
    public func character(id: String) throws -> CharacterRecord? {
        try dbQueue?.read { db in
            try CharacterRecord.fetchOne(db, key: id)
        }
    }
    
    /// Get character count
    public func characterCount() throws -> Int {
        try dbQueue?.read { db in
            try CharacterRecord.fetchCount(db)
        } ?? 0
    }
    
    // MARK: - Stage Operations
    
    /// Insert or update a stage record
    public func upsertStage(_ record: StageRecord) throws {
        try dbQueue?.write { db in
            try record.save(db)
        }
    }
    
    /// Insert or update stage from StageInfo
    public func indexStage(_ info: StageInfo) throws {
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
        try upsertStage(record)
    }
    
    /// Delete a stage by ID
    public func deleteStage(id: String) throws {
        try dbQueue?.write { db in
            _ = try StageRecord.deleteOne(db, key: id)
        }
    }
    
    /// Get all stages
    public func allStages() throws -> [StageRecord] {
        try dbQueue?.read { db in
            try StageRecord.order(Column("name").collating(.localizedCaseInsensitiveCompare)).fetchAll(db)
        } ?? []
    }
    
    /// Search stages by name or author
    public func searchStages(query: String) throws -> [StageRecord] {
        guard !query.isEmpty else {
            return try allStages()
        }
        
        let pattern = "%\(query)%"
        return try dbQueue?.read { db in
            try StageRecord
                .filter(Column("name").like(pattern) || Column("author").like(pattern))
                .order(Column("name").collating(.localizedCaseInsensitiveCompare))
                .fetchAll(db)
        } ?? []
    }
    
    /// Get stage count
    public func stageCount() throws -> Int {
        try dbQueue?.read { db in
            try StageRecord.fetchCount(db)
        } ?? 0
    }
    
    // MARK: - Combined Operations
    
    /// Get recently installed content (characters + stages combined)
    public func recentlyInstalled(limit: Int = 10) throws -> [RecentInstall] {
        try dbQueue?.read { db in
            let sql = """
                SELECT id, name, 'character' as type, installedAt FROM characters
                UNION ALL
                SELECT id, name, 'stage' as type, installedAt FROM stages
                ORDER BY installedAt DESC
                LIMIT ?
            """
            return try RecentInstall.fetchAll(db, sql: sql, arguments: [limit])
        } ?? []
    }
    
    /// Search both characters and stages
    public func searchAll(query: String) throws -> (characters: [CharacterRecord], stages: [StageRecord]) {
        let characters = try searchCharacters(query: query)
        let stages = try searchStages(query: query)
        return (characters, stages)
    }
    
    // MARK: - Sync Operations
    
    /// Re-index all characters from filesystem
    /// Useful for syncing database with actual content
    public func reindexCharacters(from workingDir: URL) throws {
        let charsDir = workingDir.appendingPathComponent("chars")
        
        guard let folders = try? fileManager.contentsOfDirectory(at: charsDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        // Get current DB records
        let existingIds = Set(try allCharacters().map { $0.id })
        var foundIds = Set<String>()
        
        for folder in folders {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            
            let charName = folder.lastPathComponent
            if charName.hasPrefix(".") { continue }
            
            foundIds.insert(charName)
            
            // Find .def file
            if let contents = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
                if let defFile = defFiles.first {
                    let info = CharacterInfo(directory: folder, defFile: defFile)
                    try indexCharacter(info)
                }
            }
        }
        
        // Remove entries for deleted characters
        let deletedIds = existingIds.subtracting(foundIds)
        for id in deletedIds {
            try deleteCharacter(id: id)
        }
    }
    
    /// Re-index all stages from filesystem
    public func reindexStages(from workingDir: URL) throws {
        let stagesDir = workingDir.appendingPathComponent("stages")
        
        guard let files = try? fileManager.contentsOfDirectory(at: stagesDir, includingPropertiesForKeys: nil) else {
            return
        }
        
        let existingIds = Set(try allStages().map { $0.id })
        var foundIds = Set<String>()
        
        for file in files where file.pathExtension.lowercased() == "def" {
            let stageId = file.deletingPathExtension().lastPathComponent
            if stageId.hasPrefix(".") { continue }
            
            foundIds.insert(stageId)
            
            let info = StageInfo(defFile: file)
            try indexStage(info)
        }
        
        // Remove entries for deleted stages
        let deletedIds = existingIds.subtracting(foundIds)
        for id in deletedIds {
            try deleteStage(id: id)
        }
    }
    
    /// Full reindex of all content
    public func reindexAll(from workingDir: URL) throws {
        try reindexCharacters(from: workingDir)
        try reindexStages(from: workingDir)
    }
    
    // MARK: - Utility
    
    /// Check if database is initialized
    public var isInitialized: Bool {
        dbQueue != nil
    }
    
    /// Close database connection
    public func close() {
        dbQueue = nil
    }
}
