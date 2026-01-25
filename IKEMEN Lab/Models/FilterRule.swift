import Foundation

// MARK: - FilterRule

/// A single filter rule for smart collections
struct FilterRule: Codable, Identifiable, Hashable {
    let id: UUID
    var field: FilterField
    var comparison: ComparisonOperator
    var value: String                       // String representation of value
    
    init(id: UUID = UUID(), field: FilterField, comparison: ComparisonOperator, value: String) {
        self.id = id
        self.field = field
        self.comparison = comparison
        self.value = value
    }
}

// MARK: - FilterField

/// Fields available for filtering
enum FilterField: String, Codable, CaseIterable {
    // Character/Stage shared
    case name
    case author
    case tag                                // Custom tags
    case installedAt
    case sourceGame
    
    // Character-specific
    case isHD
    case hasAI
    case style                              // POTS, MVC2, etc.
    
    // Stage-specific
    case totalWidth                         // Camera bounds
    case hasMusic
    case resolution
}

// MARK: - ComparisonOperator

/// Comparison operators for filter rules
enum ComparisonOperator: String, Codable, CaseIterable {
    case equals
    case notEquals
    case contains
    case notContains
    case greaterThan
    case lessThan
    case withinDays                         // For date fields
    case isEmpty
    case isNotEmpty
}
