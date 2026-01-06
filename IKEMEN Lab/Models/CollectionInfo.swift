import Foundation
import AppKit

// MARK: - Collection Item Type

/// Types of content that can be added to a collection
public enum CollectionItemType: String, Codable {
    case character
    case stage
    case screenpack
}

// MARK: - Collection Item

/// An item within a collection (character, stage, or screenpack)
public struct CollectionItem: Identifiable, Codable, Hashable {
    public let id: String              // Item ID (character folder name, stage def name, or screenpack folder)
    public let type: CollectionItemType
    public let addedAt: Date
    
    public init(id: String, type: CollectionItemType, addedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.addedAt = addedAt
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
    }
    
    public static func == (lhs: CollectionItem, rhs: CollectionItem) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
    }
}

// MARK: - Collection Info

/// A named collection of characters, stages, and/or screenpacks
public struct CollectionInfo: Identifiable, Codable, Hashable {
    public let id: String              // Unique ID (UUID)
    public var name: String            // Collection name (e.g., "Marvel", "SNK Bosses")
    public var description: String     // Optional description
    public var items: [CollectionItem] // Items in this collection
    public let createdAt: Date
    public var updatedAt: Date
    
    /// Number of characters in this collection
    public var characterCount: Int {
        return items.filter { $0.type == .character }.count
    }
    
    /// Number of stages in this collection
    public var stageCount: Int {
        return items.filter { $0.type == .stage }.count
    }
    
    /// Number of screenpacks in this collection
    public var screenpackCount: Int {
        return items.filter { $0.type == .screenpack }.count
    }
    
    /// Total number of items
    public var totalCount: Int {
        return items.count
    }
    
    /// Summary string for display (e.g., "5 characters, 3 stages")
    public var itemSummary: String {
        var components: [String] = []
        if characterCount > 0 {
            components.append("\(characterCount) character\(characterCount == 1 ? "" : "s")")
        }
        if stageCount > 0 {
            components.append("\(stageCount) stage\(stageCount == 1 ? "" : "s")")
        }
        if screenpackCount > 0 {
            components.append("\(screenpackCount) screenpack\(screenpackCount == 1 ? "" : "s")")
        }
        
        if components.isEmpty {
            return "Empty collection"
        }
        
        return components.joined(separator: ", ")
    }
    
    public init(id: String = UUID().uuidString, 
                name: String, 
                description: String = "", 
                items: [CollectionItem] = [],
                createdAt: Date = Date(),
                updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Add an item to the collection
    public mutating func addItem(_ item: CollectionItem) {
        // Don't add duplicates
        if !items.contains(item) {
            items.append(item)
            updatedAt = Date()
        }
    }
    
    /// Remove an item from the collection
    public mutating func removeItem(_ item: CollectionItem) {
        items.removeAll { $0 == item }
        updatedAt = Date()
    }
    
    /// Check if an item is in this collection
    public func contains(_ item: CollectionItem) -> Bool {
        return items.contains(item)
    }
    
    /// Check if a specific ID and type is in this collection
    public func contains(id: String, type: CollectionItemType) -> Bool {
        return items.contains { $0.id == id && $0.type == type }
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: CollectionInfo, rhs: CollectionInfo) -> Bool {
        lhs.id == rhs.id
    }
}
