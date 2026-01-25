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
    public var tags: String?           // Comma-separated inferred tags
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
    public var folderPath: String       // Full path to character folder or stage def file
    public var author: String           // Author for display
    
    /// Check if the content still exists on disk
    public var existsOnDisk: Bool {
        // folderPath is already the full path from the database
        // For characters: full path to character directory
        // For stages: full path to .def file
        return FileManager.default.fileExists(atPath: folderPath)
    }
}

/// Metadata scraped from web browser extension
public struct ScrapedMetadata: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "scraped_metadata"
    
    public var characterId: String      // Foreign key to characters.id
    public var name: String?
    public var author: String?
    public var version: String?
    public var description: String?
    public var tags: String?            // Comma-separated tags
    public var sourceUrl: String
    public var scrapedAt: Date
    
    public init(characterId: String, name: String?, author: String?, version: String?, description: String?, tags: [String]?, sourceUrl: String, scrapedAt: Date) {
        self.characterId = characterId
        self.name = name
        self.author = author
        self.version = version
        self.description = description
        self.tags = tags?.joined(separator: ",")
        self.sourceUrl = sourceUrl
        self.scrapedAt = scrapedAt
    }
}

/// Custom tags assigned by users
public struct CharacterCustomTag: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "character_custom_tags"
    
    public var characterId: String
    public var tag: String
    public var createdAt: Date
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
        
        // Scraped metadata table (from browser extension)
        try db.create(table: "scraped_metadata", ifNotExists: true) { t in
            t.column("characterId", .text).notNull()
                .indexed()
                .references("characters", onDelete: .cascade)
            t.column("name", .text)
            t.column("author", .text)
            t.column("version", .text)
            t.column("description", .text)
            t.column("tags", .text)
            t.column("sourceUrl", .text).notNull()
            t.column("scrapedAt", .datetime).notNull()
        }

        // Custom tags assigned to characters
        try db.create(table: "character_custom_tags", ifNotExists: true) { t in
            t.column("characterId", .text).notNull()
                .indexed()
                .references("characters", onDelete: .cascade)
            t.column("tag", .text).notNull()
            t.column("createdAt", .datetime).notNull()
        }
        
        // Add tags column if it doesn't exist (migration)
        let characterColumns = try db.columns(in: "characters").map { $0.name }
        if !characterColumns.contains("tags") {
            try db.alter(table: "characters") { t in
                t.add(column: "tags", .text)
            }
        }
        
        // Full-text search indexes (for future advanced search)
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_characters_name_author 
            ON characters(name COLLATE NOCASE, author COLLATE NOCASE)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_characters_tags 
            ON characters(tags COLLATE NOCASE)
        """)

        try db.execute(sql: """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_character_custom_tags_unique
            ON character_custom_tags(characterId, tag COLLATE NOCASE)
        """)

        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_character_custom_tags_tag
            ON character_custom_tags(tag COLLATE NOCASE)
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
        let tagsString = info.inferredTags.joined(separator: ",")
        
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
            hasAI: nil,
            tags: tagsString.isEmpty ? nil : tagsString
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
    
    /// Search characters by name, author, or tags
    public func searchCharacters(query: String) throws -> [CharacterRecord] {
        guard !query.isEmpty else {
            return try allCharacters()
        }
        
        let pattern = "%\(query)%"
        return try dbQueue?.read { db in
            let sql = """
                SELECT DISTINCT characters.*
                FROM characters
                LEFT JOIN character_custom_tags
                    ON characters.id = character_custom_tags.characterId
                WHERE characters.name LIKE ?
                   OR characters.author LIKE ?
                   OR characters.tags LIKE ?
                   OR character_custom_tags.tag LIKE ?
                ORDER BY characters.name COLLATE NOCASE
            """
            return try CharacterRecord.fetchAll(db, sql: sql, arguments: [pattern, pattern, pattern, pattern])
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
                SELECT id, name, 'character' as type, installedAt, folderPath, author FROM characters
                UNION ALL
                SELECT id, name, 'stage' as type, installedAt, filePath as folderPath, author FROM stages
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
            
            // Skip non-stage .def files (storyboards, characters, fonts, etc.)
            guard DEFParser.isValidStageDefFile(file) else { continue }
            
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

    // MARK: - Custom Tag Operations

    private func normalizeTag(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get all custom tags (distinct)
    public func allCustomTags() throws -> [String] {
        try dbQueue?.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT DISTINCT tag
                FROM character_custom_tags
                ORDER BY tag COLLATE NOCASE
            """)
            return rows.compactMap { $0["tag"] as String? }
        } ?? []
    }
    
    /// Get the most recently used tags (by most recent createdAt)
    public func recentCustomTags(limit: Int = 5) throws -> [String] {
        try dbQueue?.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT tag, MAX(createdAt) as lastUsed
                FROM character_custom_tags
                GROUP BY tag
                ORDER BY lastUsed DESC
                LIMIT ?
            """, arguments: [limit])
            return rows.compactMap { $0["tag"] as String? }
        } ?? []
    }

    /// Get custom tags for a character
    public func customTags(for characterId: String) throws -> [String] {
        try dbQueue?.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT tag
                    FROM character_custom_tags
                    WHERE characterId = ?
                    ORDER BY tag COLLATE NOCASE
                """,
                arguments: [characterId]
            )
            return rows.compactMap { $0["tag"] as String? }
        } ?? []
    }

    /// Get custom tags map for multiple characters
    public func customTagsMap(for characterIds: [String]) throws -> [String: [String]] {
        guard !characterIds.isEmpty else { return [:] }
        return try dbQueue?.read { db in
            let placeholders = Array(repeating: "?", count: characterIds.count).joined(separator: ",")
            let sql = """
                SELECT characterId, tag
                FROM character_custom_tags
                WHERE characterId IN (\(placeholders))
                ORDER BY tag COLLATE NOCASE
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(characterIds))
            var result: [String: [String]] = [:]
            for row in rows {
                guard let id = row["characterId"] as String?,
                      let tag = row["tag"] as String? else { continue }
                result[id, default: []].append(tag)
            }
            return result
        } ?? [:]
    }

    /// Assign a custom tag to characters
    /// Uses case-insensitive matching: if "DC" exists, adding "dc" will use "DC"
    public func assignCustomTag(_ tag: String, to characterIds: [String]) throws {
        let normalized = normalizeTag(tag)
        guard !normalized.isEmpty else { return }
        guard !characterIds.isEmpty else { return }

        try dbQueue?.write { db in
            // Check if a tag with this name already exists (case-insensitive)
            // If so, use the existing casing to maintain consistency
            let existingTag = try String.fetchOne(db, sql: """
                SELECT tag FROM character_custom_tags
                WHERE tag = ? COLLATE NOCASE
                LIMIT 1
            """, arguments: [normalized])
            
            let tagToUse = existingTag ?? normalized
            
            for id in characterIds {
                try db.execute(
                    sql: """
                        INSERT OR IGNORE INTO character_custom_tags
                        (characterId, tag, createdAt)
                        VALUES (?, ?, ?)
                    """,
                    arguments: [id, tagToUse, Date()]
                )
            }
        }

        NotificationCenter.default.post(name: .customTagsChanged, object: nil)
    }

    /// Remove a custom tag from characters
    public func removeCustomTag(_ tag: String, from characterIds: [String]) throws {
        let normalized = normalizeTag(tag)
        guard !normalized.isEmpty else { return }
        guard !characterIds.isEmpty else { return }

        try dbQueue?.write { db in
            let placeholders = Array(repeating: "?", count: characterIds.count).joined(separator: ",")
            let sql = """
                DELETE FROM character_custom_tags
                WHERE tag = ? COLLATE NOCASE
                  AND characterId IN (\(placeholders))
            """
            var args: [DatabaseValueConvertible] = [normalized]
            for id in characterIds {
                args.append(id)
            }
            try db.execute(sql: sql, arguments: StatementArguments(args))
        }

        NotificationCenter.default.post(name: .customTagsChanged, object: nil)
    }

    /// Rename a custom tag (affects all characters)
    public func renameCustomTag(_ tag: String, to newTag: String) throws {
        let normalizedOld = normalizeTag(tag)
        let normalizedNew = normalizeTag(newTag)
        guard !normalizedOld.isEmpty, !normalizedNew.isEmpty else { return }
        guard normalizedOld.caseInsensitiveCompare(normalizedNew) != .orderedSame else { return }

        try dbQueue?.write { db in
            try db.execute(
                sql: """
                    INSERT OR IGNORE INTO character_custom_tags
                    (characterId, tag, createdAt)
                    SELECT characterId, ?, createdAt
                    FROM character_custom_tags
                    WHERE tag = ? COLLATE NOCASE
                """,
                arguments: [normalizedNew, normalizedOld]
            )
            try db.execute(
                sql: """
                    DELETE FROM character_custom_tags
                    WHERE tag = ? COLLATE NOCASE
                """,
                arguments: [normalizedOld]
            )
        }

        NotificationCenter.default.post(name: .customTagsChanged, object: nil)
    }

    /// Delete a custom tag entirely
    public func deleteCustomTag(_ tag: String) throws {
        let normalized = normalizeTag(tag)
        guard !normalized.isEmpty else { return }

        try dbQueue?.write { db in
            try db.execute(
                sql: """
                    DELETE FROM character_custom_tags
                    WHERE tag = ? COLLATE NOCASE
                """,
                arguments: [normalized]
            )
        }

        NotificationCenter.default.post(name: .customTagsChanged, object: nil)
    }
    
    // MARK: - Scraped Metadata Operations
    
    /// Store metadata scraped from browser extension
    public func storeScrapedMetadata(_ metadata: ScrapedMetadata) throws {
        try dbQueue?.write { db in
            try metadata.insert(db)
        }
    }
    
    /// Get scraped metadata for a character
    public func scrapedMetadata(for characterId: String) throws -> ScrapedMetadata? {
        try dbQueue?.read { db in
            try ScrapedMetadata
                .filter(Column("characterId") == characterId)
                .order(Column("scrapedAt").desc)
                .fetchOne(db)
        }
    }
    
    /// Delete scraped metadata for a character
    public func deleteScrapedMetadata(for characterId: String) throws {
        try dbQueue?.write { db in
            try ScrapedMetadata
                .filter(Column("characterId") == characterId)
                .deleteAll(db)
        }
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

// MARK: - Protocol Conformance

extension MetadataStore: MetadataStoreProtocol {}

public extension Notification.Name {
    static let customTagsChanged = Notification.Name("CustomTagsChanged")
}
