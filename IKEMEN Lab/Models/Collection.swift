import Foundation

// MARK: - Collection

/// A collection represents a complete game profile (roster + stages + screenpack)
struct Collection: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var icon: String                        // SF Symbol name (e.g., "folder.fill")
    var characters: [RosterEntry]           // Ordered list with optional grid positions
    var stages: [String]                    // Stage folder names (e.g., "Bifrost")
    var screenpackPath: String?             // Relative path to screenpack (e.g., "data/MvC2")
    var lifebarsPath: String?               // Relative path to lifebars (e.g., "data/fight.def")
    var fonts: [String]                     // Font filenames owned by this collection (e.g., "motu.fnt")
    var sounds: [String]                    // Sound filenames owned by this collection (e.g., "select.mp3")
    var isDefault: Bool                     // True for "All Characters" collection
    var isActive: Bool                      // True if this collection is currently active
    var createdAt: Date
    var modifiedAt: Date
    
    init(id: UUID = UUID(), name: String, icon: String = "folder.fill") {
        self.id = id
        self.name = name
        self.icon = icon
        self.characters = []
        self.stages = []
        self.screenpackPath = nil
        self.lifebarsPath = nil
        self.fonts = []
        self.sounds = []
        self.isDefault = false
        self.isActive = false
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - RosterEntry

/// A single entry in the roster (character reference, randomselect, or empty slot)
struct RosterEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var characterFolder: String?            // nil for randomselect/empty
    var defFile: String?                    // e.g., "Ryu.def" (for chars with multiple .defs)
    var gridPosition: GridPosition?         // Optional manual grid position
    var entryType: RosterEntryType
    
    enum RosterEntryType: String, Codable {
        case character
        case randomSelect                   // "randomselect" in select.def
        case emptySlot                      // Empty line in select.def for spacing
    }
    
    /// Create a character entry
    static func character(folder: String, def: String? = nil) -> RosterEntry {
        RosterEntry(
            id: UUID(),
            characterFolder: folder,
            defFile: def,
            gridPosition: nil,
            entryType: .character
        )
    }
    
    /// Create a randomselect placeholder
    static func randomSelect() -> RosterEntry {
        RosterEntry(
            id: UUID(),
            characterFolder: nil,
            defFile: nil,
            gridPosition: nil,
            entryType: .randomSelect
        )
    }
    
    /// Create an empty slot for grid spacing
    static func emptySlot() -> RosterEntry {
        RosterEntry(
            id: UUID(),
            characterFolder: nil,
            defFile: nil,
            gridPosition: nil,
            entryType: .emptySlot
        )
    }
}

// MARK: - GridPosition

/// Grid position for manual layout control
struct GridPosition: Codable, Hashable {
    var row: Int
    var column: Int
}
