# Smart Collections — Implementation Spec

## Overview

Smart Collections are auto-populated collections that dynamically include content based on filter rules. Unlike manual collections where users explicitly add characters/stages, smart collections automatically update when content matching their criteria is added or removed.

## Examples

| Smart Collection | Rule |
|------------------|------|
| Recently Added | `installedAt` within last 7 days |
| Marvel Characters | Has tag "Marvel" |
| HD Characters | `isHD = true` |
| By Author: Vyn | `author contains "Vyn"` |
| Wide Stages | `totalWidth > 400` |
| Street Fighter | Has tag "Street Fighter" OR `sourceGame = "Street Fighter"` |

---

## Data Model

### SmartCollection (extends or parallels Collection)

```swift
struct SmartCollection: Codable, Identifiable {
    let id: UUID
    var name: String
    var icon: String                    // SF Symbol
    var rules: [FilterRule]             // AND-combined rules
    var ruleOperator: RuleOperator      // .all (AND) or .any (OR)
    var includeCharacters: Bool         // Apply rules to characters
    var includeStages: Bool             // Apply rules to stages
    var createdAt: Date
    var modifiedAt: Date
    
    enum RuleOperator: String, Codable {
        case all    // All rules must match (AND)
        case any    // Any rule can match (OR)
    }
}
```

### FilterRule

```swift
struct FilterRule: Codable, Identifiable {
    let id: UUID
    var field: FilterField
    var comparison: ComparisonOperator
    var value: String                   // String representation of value
    
    enum FilterField: String, Codable, CaseIterable {
        // Character/Stage shared
        case name
        case author
        case tag                        // Custom tags
        case installedAt
        case sourceGame
        
        // Character-specific
        case isHD
        case hasAI
        case style                      // POTS, MVC, etc.
        
        // Stage-specific  
        case totalWidth                 // Camera bounds
        case hasMusic
        case resolution
    }
    
    enum ComparisonOperator: String, Codable, CaseIterable {
        case equals
        case notEquals
        case contains
        case notContains
        case greaterThan
        case lessThan
        case withinDays                 // For date fields
        case isEmpty
        case isNotEmpty
    }
}
```

### Integration with Collection

**Option A: Separate SmartCollection type**
- Pro: Clean separation, different storage
- Con: Duplicate activation logic, UI divergence

**Option B: Add `isSmartCollection` flag to existing Collection**
```swift
struct Collection {
    // ... existing fields ...
    var isSmartCollection: Bool = false
    var smartRules: [FilterRule]?
    var smartRuleOperator: RuleOperator?
}
```
- Pro: Reuses existing activation, UI components
- Con: Optional fields feel awkward

**Recommendation**: Option B — extend existing Collection model. Smart collections can share the same activation flow, screenpack assignment, and UI. The `characters` and `stages` arrays become computed/cached rather than manually managed.

---

## Storage

Smart collections stored alongside regular collections in:
`~/Library/Application Support/IKEMEN Lab/collections/`

Add fields to Collection JSON:
```json
{
  "id": "...",
  "name": "Marvel Characters",
  "icon": "star.fill",
  "isSmartCollection": true,
  "smartRules": [
    {
      "id": "...",
      "field": "tag",
      "comparison": "contains",
      "value": "Marvel"
    }
  ],
  "smartRuleOperator": "all",
  "includeCharacters": true,
  "includeStages": false,
  "characters": [],        // Cached results (regenerated)
  "stages": [],            // Cached results (regenerated)
  "screenpackPath": null,
  "createdAt": "...",
  "modifiedAt": "..."
}
```

---

## Rule Evaluation

### SmartCollectionEvaluator

```swift
class SmartCollectionEvaluator {
    
    /// Evaluate rules against all content, return matching items
    func evaluate(_ collection: Collection) -> (characters: [String], stages: [String]) {
        guard collection.isSmartCollection, let rules = collection.smartRules else {
            return ([], [])
        }
        
        var matchingCharacters: [String] = []
        var matchingStages: [String] = []
        
        if collection.includeCharacters != false {
            let allCharacters = try? MetadataStore.shared.allCharacters()
            matchingCharacters = allCharacters?.filter { matches($0, rules: rules, op: collection.smartRuleOperator) }
                .map { $0.id } ?? []
        }
        
        if collection.includeStages != false {
            let allStages = try? MetadataStore.shared.allStages()
            matchingStages = allStages?.filter { matches($0, rules: rules, op: collection.smartRuleOperator) }
                .map { $0.id } ?? []
        }
        
        return (matchingCharacters, matchingStages)
    }
    
    /// Check if a single item matches the rules
    private func matches(_ record: CharacterRecord, rules: [FilterRule], op: RuleOperator?) -> Bool {
        let results = rules.map { evaluate($0, against: record) }
        return op == .any ? results.contains(true) : !results.contains(false)
    }
    
    /// Evaluate a single rule against a record
    private func evaluate(_ rule: FilterRule, against record: CharacterRecord) -> Bool {
        // Implementation per field/operator combination
    }
}
```

### Tag Matching

Tags are stored as comma-separated string in `CharacterRecord.tags`. For tag rules:
1. Split tags by comma
2. Check if any tag matches the rule value (case-insensitive)

```swift
case .tag:
    let tags = record.tags?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? []
    let searchTag = rule.value.lowercased()
    
    switch rule.comparison {
    case .contains:
        return tags.contains { $0.contains(searchTag) }
    case .equals:
        return tags.contains { $0 == searchTag }
    // ...
    }
```

---

## Refresh Strategy

### When to Refresh

1. **On content change**: When characters/stages are added, removed, or modified
2. **On collection access**: Lazy evaluation when viewing collection
3. **On app launch**: Refresh all smart collections in background

### Notification-Based Refresh

```swift
// In CollectionStore
NotificationCenter.default.addObserver(
    forName: .contentChanged,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.refreshSmartCollections()
}

func refreshSmartCollections() {
    for i in 0..<collections.count where collections[i].isSmartCollection {
        let (chars, stages) = SmartCollectionEvaluator().evaluate(collections[i])
        collections[i].characters = chars.map { .character(folder: $0) }
        collections[i].stages = stages
        save(collections[i])
    }
}
```

### Post-Content Notifications

Add to ContentManager after install/delete:
```swift
NotificationCenter.default.post(name: .contentChanged, object: nil)
```

---

## UI Components

### Smart Collection Editor Sheet

When creating/editing a smart collection, show a sheet with:

```
┌─────────────────────────────────────────────────────────┐
│  Smart Collection                                    ✕  │
├─────────────────────────────────────────────────────────┤
│  Name: [Marvel Characters          ]                    │
│  Icon: [⭐ ▼]                                           │
│                                                         │
│  Include: [✓] Characters  [✓] Stages                    │
│                                                         │
│  Match: (•) All rules  ( ) Any rule                     │
│                                                         │
│  RULES                                          + Add   │
│  ┌────────────────────────────────────────────────────┐ │
│  │ [Tag        ▼] [contains ▼] [Marvel      ] [✕]    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  Preview: 12 characters, 3 stages                       │
│                                                         │
│                              [Cancel]  [Save Collection] │
└─────────────────────────────────────────────────────────┘
```

### Rule Row Component

```swift
class SmartRuleRow: NSView {
    var rule: FilterRule
    var onChanged: ((FilterRule) -> Void)?
    var onDelete: (() -> Void)?
    
    // Field popup: Name, Author, Tag, Installed Date, Source Game, etc.
    // Operator popup: changes based on field type
    // Value field: text field, or date picker for date fields
    // Delete button
}
```

### Field-Specific Operators

| Field Type | Available Operators |
|------------|---------------------|
| String (name, author, tag) | equals, contains, notContains, isEmpty |
| Boolean (isHD, hasAI) | equals (Yes/No popup) |
| Number (totalWidth) | equals, greaterThan, lessThan |
| Date (installedAt) | withinDays, greaterThan, lessThan |

### Preview Count

As user edits rules, show live preview count:
```swift
func updatePreview() {
    let (chars, stages) = evaluator.evaluate(draftCollection)
    previewLabel.stringValue = "\(chars.count) characters, \(stages.count) stages"
}
```

---

## Sidebar Integration

### Visual Distinction

Smart collections in sidebar show a different icon or badge:
- Regular collection: `folder.fill`
- Smart collection: `sparkles` or `wand.and.stars`

Or use a section divider:
```
COLLECTIONS
  📁 Marvel vs Capcom
  📁 My Favorites

SMART COLLECTIONS
  ✨ Recently Added
  ✨ HD Characters
  ✨ By Vyn
```

### Context Menu

Right-click smart collection:
- Edit Rules...
- Duplicate
- Delete
- (No "Add Characters" — they're auto-populated)

---

## Activation Behavior

When a smart collection is activated:
1. Evaluate rules to get current matches
2. Generate select.def with matched characters/stages
3. Set screenpack (if assigned) or use default
4. Same flow as regular collection activation

**Note**: Smart collections CAN have a screenpack assigned manually. The rules only determine the roster, not the theme.

---

## Edge Cases

### Empty Results
If rules match nothing, show empty state in collection view:
"No content matches these rules. Try adjusting your filters."

### Deleted Content
When content is deleted, it naturally disappears from smart collection results on next evaluation. No special handling needed.

### Circular References
Smart collections cannot reference other collections (no "In Collection X" rule). Keep it simple.

### Performance
For large libraries (1000+ characters), consider:
- Caching evaluation results
- Debouncing refresh on rapid content changes
- Background evaluation

---

## Implementation Phases

### Phase 1: Core Model & Evaluation
1. Add `isSmartCollection`, `smartRules`, `smartRuleOperator` to Collection model
2. Create `FilterRule` struct with fields and operators
3. Implement `SmartCollectionEvaluator` with basic string/tag matching
4. Add `.contentChanged` notification and refresh logic

### Phase 2: UI - Editor Sheet
1. Create `SmartCollectionEditorSheet` with rule builder
2. Add "New Smart Collection" menu item / button
3. Implement live preview count
4. Wire save/cancel

### Phase 3: UI - Sidebar & Polish
1. Visual distinction for smart collections in sidebar
2. Context menu adjustments (no manual add/remove)
3. Empty state handling
4. Edit existing smart collection

### Phase 4: Advanced Rules
1. Date-based rules (within X days)
2. Numeric comparisons (stage width)
3. Boolean fields (isHD, hasAI)
4. Compound rules (nested AND/OR) — future

---

## Files to Modify

| File | Changes |
|------|---------|
| `Collection.swift` | Add smart collection fields |
| `CollectionStore.swift` | Add refresh logic, create smart collection helper |
| `Services.swift` | Update protocol if needed |
| `MockServices.swift` | Update mock |
| **New**: `SmartCollectionEvaluator.swift` | Rule evaluation engine |
| **New**: `SmartCollectionEditorSheet.swift` | Rule builder UI |
| `CollectionsSidebarSection.swift` | Visual distinction, context menu |
| `ContentManager.swift` | Post `.contentChanged` notification |
| `MetadataStore.swift` | May need query helpers |

---

## Testing

### Unit Tests
- `SmartCollectionEvaluatorTests.swift`
  - Test each field type
  - Test each operator
  - Test AND vs OR combination
  - Test empty rules (match all)
  - Test no matches

### Integration Tests
- Create smart collection, add matching content, verify it appears
- Delete content, verify it disappears from smart collection
- Activate smart collection, verify select.def generation

---

## Success Criteria

1. User can create a smart collection with tag-based rules
2. Smart collection automatically includes matching content
3. Adding new content that matches rules auto-includes it
4. Smart collection can be activated like regular collection
5. UI clearly distinguishes smart vs manual collections
6. Rules can be edited after creation
