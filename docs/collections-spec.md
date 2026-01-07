# Collections System — Implementation Spec for Copilot Agent

> **Purpose:** This spec provides everything a Copilot agent needs to implement the Collections feature in IKEMEN Lab, a macOS native app for managing IKEMEN GO content.

## Overview

Collections are **game profiles** that define complete playable rosters. Each collection specifies which characters and stages to include, in what order, and optionally which screenpack to use. When a collection is "activated," it generates a `select.def` file that IKEMEN GO reads at launch.

**Key insight:** Collections don't store characters — they store *references* to characters already in the user's library. This is like a playlist referencing songs in your music library.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Collections System                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │ CollectionStore │────▶│ Collection      │────▶│ select.def      │   │
│  │ (JSON files)    │     │ (Swift model)   │     │ (generated)     │   │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘   │
│           │                      │                       │              │
│           ▼                      ▼                       ▼              │
│  ~/Library/App Support/    In-memory model        data/select.def      │
│  IKEMEN Lab/collections/   with validation        (IKEMEN GO reads)    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Phase 1: Data Model & Storage

### Task 1.1: Create Collection Model

**File:** `IKEMEN Lab/Models/Collection.swift`

```swift
import Foundation

/// A collection represents a complete game profile (roster + stages + screenpack)
struct Collection: Codable, Identifiable {
    let id: UUID
    var name: String
    var icon: String                        // SF Symbol name (e.g., "folder.fill")
    var characters: [RosterEntry]           // Ordered list with optional grid positions
    var stages: [String]                    // Stage folder names (e.g., "Bifrost")
    var screenpackPath: String?             // Relative path to screenpack (e.g., "data/MvC2")
    var isDefault: Bool                     // True for "All Characters" collection
    var createdAt: Date
    var modifiedAt: Date
    
    init(id: UUID = UUID(), name: String, icon: String = "folder.fill") {
        self.id = id
        self.name = name
        self.icon = icon
        self.characters = []
        self.stages = []
        self.screenpackPath = nil
        self.isDefault = false
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

/// A single entry in the roster (character reference, randomselect, or empty slot)
struct RosterEntry: Codable, Identifiable {
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

/// Grid position for manual layout control
struct GridPosition: Codable, Equatable {
    var row: Int
    var column: Int
}
```

**Acceptance Criteria:**
- [ ] Models compile without errors
- [ ] All properties are Codable for JSON serialization
- [ ] Convenience initializers work correctly
- [ ] Unit tests pass for model creation and encoding/decoding

---

### Task 1.2: Create CollectionStore

**File:** `IKEMEN Lab/Core/CollectionStore.swift`

```swift
import Foundation

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
        var collection = Collection(name: name, icon: icon)
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
        
        collections = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Collection? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(Collection.self, from: data)
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

// MARK: - Notifications

extension Notification.Name {
    static let collectionActivated = Notification.Name("collectionActivated")
}
```

**Acceptance Criteria:**
- [ ] Collections persist to JSON files in `~/Library/Application Support/IKEMEN Lab/collections/`
- [ ] Default "All Characters" collection is created on first launch
- [ ] Active collection ID persists across app restarts
- [ ] CRUD operations work correctly
- [ ] Notification posted when collection is activated

---

### Task 1.3: Add select.def Generation

**File:** `IKEMEN Lab/Core/SelectDefGenerator.swift`

```swift
import Foundation

/// Generates select.def content from a Collection
class SelectDefGenerator {
    
    /// Generate select.def content for a collection
    /// - Parameters:
    ///   - collection: The collection to generate from
    ///   - ikemenPath: Path to IKEMEN GO installation
    /// - Returns: String content for select.def
    static func generate(from collection: Collection, ikemenPath: URL) -> String {
        var lines: [String] = []
        
        // Header comment
        lines.append("; Generated by IKEMEN Lab")
        lines.append("; Collection: \(collection.name)")
        lines.append("; Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("; DO NOT EDIT - This file is managed by IKEMEN Lab")
        lines.append("")
        
        // [Characters] section
        lines.append("[Characters]")
        
        for entry in collection.characters {
            switch entry.entryType {
            case .character:
                if let folder = entry.characterFolder {
                    if let def = entry.defFile {
                        lines.append("\(folder)/\(def)")
                    } else {
                        // Find the .def file in the folder
                        let defFile = findDefFile(in: folder, ikemenPath: ikemenPath)
                        lines.append("\(folder)/\(defFile)")
                    }
                }
                
            case .randomSelect:
                lines.append("randomselect")
                
            case .emptySlot:
                lines.append("")  // Empty line for grid spacing
            }
        }
        
        lines.append("")
        
        // [ExtraStages] section
        lines.append("[ExtraStages]")
        
        for stageFolder in collection.stages {
            let defFile = findStageDefFile(in: stageFolder, ikemenPath: ikemenPath)
            lines.append("stages/\(stageFolder)/\(defFile)")
        }
        
        lines.append("")
        
        // [Options] section (standard defaults)
        lines.append("[Options]")
        lines.append("arcade.maxmatches = 6,1,1,0,0,0,0,0,0,0")
        lines.append("team.maxmatches = 4,1,1,0,0,0,0,0,0,0")
        
        return lines.joined(separator: "\n")
    }
    
    /// Write select.def to disk with backup
    /// - Parameters:
    ///   - collection: Collection to generate from
    ///   - ikemenPath: Path to IKEMEN GO installation
    /// - Returns: Result with path to generated file or error
    static func writeSelectDef(for collection: Collection, ikemenPath: URL) -> Result<URL, Error> {
        let selectDefPath = ikemenPath.appendingPathComponent("data/select.def")
        
        // Create backup if file exists
        if FileManager.default.fileExists(atPath: selectDefPath.path) {
            let backupPath = createBackup(of: selectDefPath)
            print("Backed up select.def to: \(backupPath?.path ?? "failed")")
        }
        
        // Generate content
        let content = generate(from: collection, ikemenPath: ikemenPath)
        
        // Write file
        do {
            try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
            return .success(selectDefPath)
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private static func findDefFile(in characterFolder: String, ikemenPath: URL) -> String {
        let charPath = ikemenPath.appendingPathComponent("chars/\(characterFolder)")
        
        // Look for .def files
        if let contents = try? FileManager.default.contentsOfDirectory(at: charPath, includingPropertiesForKeys: nil) {
            let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
            
            // Prefer file matching folder name
            if let match = defFiles.first(where: { 
                $0.deletingPathExtension().lastPathComponent.lowercased() == characterFolder.lowercased() 
            }) {
                return match.lastPathComponent
            }
            
            // Otherwise use first .def
            if let first = defFiles.first {
                return first.lastPathComponent
            }
        }
        
        // Fallback to folder name
        return "\(characterFolder).def"
    }
    
    private static func findStageDefFile(in stageFolder: String, ikemenPath: URL) -> String {
        let stagePath = ikemenPath.appendingPathComponent("stages/\(stageFolder)")
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: stagePath, includingPropertiesForKeys: nil) {
            let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
            
            if let match = defFiles.first(where: { 
                $0.deletingPathExtension().lastPathComponent.lowercased() == stageFolder.lowercased() 
            }) {
                return match.lastPathComponent
            }
            
            if let first = defFiles.first {
                return first.lastPathComponent
            }
        }
        
        return "\(stageFolder).def"
    }
    
    private static func createBackup(of url: URL) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        
        let backupName = "select.def.backup.\(timestamp)"
        let backupURL = url.deletingLastPathComponent().appendingPathComponent(backupName)
        
        do {
            try FileManager.default.copyItem(at: url, to: backupURL)
            return backupURL
        } catch {
            print("Failed to create backup: \(error)")
            return nil
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Generates valid select.def syntax
- [ ] Creates timestamped backup before overwriting
- [ ] Handles randomselect and empty slots correctly
- [ ] Finds correct .def file when not explicitly specified
- [ ] Generated file loads correctly in IKEMEN GO

---

## Phase 2: Sidebar UI

### Task 2.1: Add Collections Section to Sidebar

**Context:** The sidebar is defined in `MainMenu.xib` and managed by the main window controller. Collections should appear as a new section between LIBRARY and settings.

**File to modify:** `IKEMEN Lab/UI/SidebarView.swift` (or equivalent AppKit code)

**UI Structure:**
```
┌─────────────────────────────────┐
│ LIBRARY                         │  ← Existing
│   👤 Characters              127│
│   🏔️ Stages                   45│
│   🎨 Screenpacks               8│
├─────────────────────────────────┤
│ COLLECTIONS                     │  ← NEW SECTION
│   📁 All Characters     ● ✓  127│  ← Default (always exists)
│   📁 Marvel vs Capcom   ●      52│  ← User collection (active)
│   📁 Tournament Legal   ◐      38│  ← Yellow = incomplete
│   ＋ New Collection...          │  ← Create button
├─────────────────────────────────┤
│ SMART COLLECTIONS               │  ← Phase 5
│   🕐 Recently Added            15│
│   🦸 Marvel                    34│
└─────────────────────────────────┘
```

**Status Indicators:**
- `●` Green filled circle = Active collection
- `◐` Yellow half circle = Has missing characters (references chars not in library)
- No indicator = Valid but not active
- `✓` Checkmark = Default collection

**Implementation Notes:**
- Use `NSOutlineView` with sections
- Section headers should be non-selectable
- "New Collection..." row should open name prompt
- Right-click on collection → Rename, Duplicate, Delete (except default)
- Double-click to activate collection

**Acceptance Criteria:**
- [ ] COLLECTIONS section appears in sidebar
- [ ] "All Characters" default collection always visible
- [ ] User collections appear in creation order
- [ ] Status indicators render correctly (●, ◐)
- [ ] "New Collection..." creates new collection with name prompt
- [ ] Right-click context menu works
- [ ] Double-click activates collection

---

### Task 2.2: Collection Selection State

**File to modify:** `IKEMEN Lab/App/AppDelegate.swift` or main coordinator

When a collection is selected in sidebar:
1. Update main content area to show Collection Editor (see Phase 3)
2. Update window title or breadcrumb
3. Highlight selected row in sidebar

**Acceptance Criteria:**
- [ ] Selecting collection in sidebar updates main content area
- [ ] Selected collection is visually highlighted
- [ ] Window title reflects selected collection name

---

## Phase 3: Collection Editor View

### Task 3.1: Create CollectionEditorView

**File:** `IKEMEN Lab/UI/CollectionEditorView.swift`

This view displays when a collection is selected in the sidebar.

**Layout:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│ ← Back to Characters    Marvel vs Capcom              [Activate] [⋯]   │
├─────────────────────────────────────────────────────────────────────────┤
│ ROSTER (52 characters)                          [+ Add] [Grid View ▼]  │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ [NSCollectionView - drag-to-reorder grid of character cards]        │ │
│ │                                                                     │ │
│ │  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐    │ │
│ │  │Ryu │ │Ken │ │Chun│ │ ? │ │Wlvr│ │Mgnt│ │Strm│ │ ▢ │ │Cycl│    │ │
│ │  └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘    │ │
│ │                                                                     │ │
│ │    ?  = randomselect        ▢ = empty slot                          │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│ STAGES (12)                                                    [+ Add] │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ...                               │
│  │Bifr│ │Trai│ │Bugl│ │Metr│ │City│                                   │
│  └────┘ └────┘ └────┘ └────┘ └────┘                                   │
├─────────────────────────────────────────────────────────────────────────┤
│ SCREENPACK                                                    [Change] │
│  MvC2 HD Screenpack (60 slots)                                         │
│  ⚠️ Collection has 52 chars, screenpack shows 60 — 8 empty slots       │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key Components:**

1. **Header Bar**
   - Back button (returns to previous view)
   - Collection name (editable on double-click)
   - [Activate] button (green when not active, disabled when already active)
   - [⋯] menu: Duplicate, Export, Delete

2. **Roster Section**
   - Character count in header
   - [+ Add] opens character picker sheet
   - View toggle: Grid / List
   - `NSCollectionView` with drag-to-reorder
   - Special items: `?` for randomselect, `▢` for empty slot
   - Right-click character: Remove, Insert Empty Slot After, Insert Random Select After

3. **Stages Section**
   - Horizontal scroll or wrap grid of stage thumbnails
   - [+ Add] opens stage picker sheet
   - Right-click: Remove

4. **Screenpack Section**
   - Shows current screenpack (or "Default" if none)
   - Slot count from screenpack's system.def
   - Warning if collection exceeds slot count
   - [Change] opens screenpack picker

**Acceptance Criteria:**
- [ ] View displays collection data correctly
- [ ] Drag-to-reorder works in roster grid
- [ ] [+ Add] opens picker sheet for characters/stages
- [ ] [Activate] button generates select.def and updates status
- [ ] Right-click menus work on roster items
- [ ] Screenpack slot warning displays when applicable

---

### Task 3.2: Character Picker Sheet

**File:** `IKEMEN Lab/UI/CharacterPickerSheet.swift`

A sheet/popover that shows all characters in library with checkmarks for ones already in collection.

**Layout:**
```
┌────────────────────────────────────────────────────────┐
│ Add Characters to Collection              [Done]       │
├────────────────────────────────────────────────────────┤
│ 🔍 [Search...]                                        │
├────────────────────────────────────────────────────────┤
│ ☑️ Ryu              │ ☐ Akuma           │ ☐ Sagat     │
│ ☑️ Ken              │ ☐ Bison           │ ☐ Vega      │
│ ☑️ Chun-Li          │ ☐ Cammy           │ ☐ Balrog    │
│ ☑️ Wolverine        │ ☐ Cable           │ ☐ Sentinel  │
│ ...                                                    │
├────────────────────────────────────────────────────────┤
│ Selected: 52 characters                    [Add All]   │
└────────────────────────────────────────────────────────┘
```

**Behavior:**
- Checkmark = already in collection
- Clicking unchecked adds to collection
- Clicking checked removes from collection
- [Add All] adds all visible (filtered) characters
- Search filters by name/author
- [Done] closes sheet

**Acceptance Criteria:**
- [ ] Shows all characters from library
- [ ] Pre-checks characters already in collection
- [ ] Toggle adds/removes from collection
- [ ] Search filters list
- [ ] [Add All] works with current filter

---

## Phase 4: Integration with EmulatorBridge

### Task 4.1: Hook Collection Activation

**File to modify:** `IKEMEN Lab/Core/EmulatorBridge.swift`

When `NotificationCenter` receives `.collectionActivated`:
1. Get the activated collection from notification
2. Call `SelectDefGenerator.writeSelectDef(for:ikemenPath:)`
3. Update UI to show green status dot
4. Show toast notification: "Collection activated: Marvel vs Capcom"

```swift
// In EmulatorBridge.init() or appropriate setup
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleCollectionActivated(_:)),
    name: .collectionActivated,
    object: nil
)

@objc private func handleCollectionActivated(_ notification: Notification) {
    guard let collection = notification.object as? Collection,
          let ikemenPath = self.ikemenPath else { return }
    
    let result = SelectDefGenerator.writeSelectDef(for: collection, ikemenPath: ikemenPath)
    
    switch result {
    case .success(let path):
        print("Generated select.def at: \(path)")
        // Show success toast
        ToastNotification.show(message: "Activated: \(collection.name)", type: .success)
        
    case .failure(let error):
        print("Failed to generate select.def: \(error)")
        // Show error toast
        ToastNotification.show(message: "Failed to activate collection", type: .error)
    }
}
```

### Task 4.2: Populate Default Collection

When `EmulatorBridge.loadCharacters()` runs, update the default "All Characters" collection:

```swift
func loadCharacters() {
    // ... existing character loading code ...
    
    // Update default collection with all characters
    if var defaultCollection = CollectionStore.shared.collections.first(where: { $0.isDefault }) {
        defaultCollection.characters = loadedCharacters.map { char in
            RosterEntry.character(folder: char.folderName, def: char.defFileName)
        }
        CollectionStore.shared.update(defaultCollection)
    }
}
```

**Acceptance Criteria:**
- [ ] Activating collection writes select.def
- [ ] Toast notification confirms activation
- [ ] Default collection stays in sync with library
- [ ] IKEMEN GO launches with correct roster after activation

---

## Phase 5: Smart Collections (Future)

> This phase is documented for future implementation. Do not implement in initial release.

### Smart Collection Rules

```swift
struct SmartCollection: Codable, Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var rules: [SmartRule]
    var isBuiltIn: Bool              // true for "Recently Added", "Marvel", etc.
    
    /// Evaluate which characters match this smart collection
    func matchingCharacters(from library: [CharacterInfo]) -> [CharacterInfo] {
        library.filter { character in
            rules.allSatisfy { rule in
                rule.matches(character)
            }
        }
    }
}

struct SmartRule: Codable {
    var field: SmartRuleField
    var operation: SmartRuleOperation
    var value: String
    
    enum SmartRuleField: String, Codable {
        case tag, author, series, dateAdded, name
    }
    
    enum SmartRuleOperation: String, Codable {
        case contains, equals, notEquals, after, before
    }
    
    func matches(_ character: CharacterInfo) -> Bool {
        // Implementation based on field and operation
    }
}
```

**Built-in Smart Collections:**
| Name | Rule |
|------|------|
| Recently Added | `dateAdded after (7 days ago)` |
| Marvel | `tag contains "marvel"` |
| SNK | `tag contains "snk" OR series in ["KOF", "Fatal Fury", "SamSho"]` |
| Capcom | `tag contains "capcom" OR series in ["Street Fighter", "Darkstalkers"]` |
| Favorites | `isFavorite = true` |

---

## Phase 6: Export/Import (Future)

### Export Format: `.ikemencollection`

```json
{
  "version": 1,
  "name": "Marvel vs Capcom",
  "icon": "folder.fill",
  "exportedAt": "2026-01-07T12:00:00Z",
  "exportedBy": "IKEMEN Lab 1.0",
  "characters": [
    { "folder": "Ryu", "def": "Ryu.def" },
    { "folder": "Wolverine", "def": "Wolverine.def" },
    { "type": "randomselect" },
    { "type": "empty" }
  ],
  "stages": [
    { "folder": "Bifrost", "def": "Bifrost.def" },
    { "folder": "Training", "def": "Training.def" }
  ],
  "screenpack": "MvC2_HD"
}
```

### Import Behavior

1. Parse `.ikemencollection` file
2. Validate JSON structure
3. Check which characters/stages exist in user's library
4. Show import summary:
   ```
   Import "Marvel vs Capcom"
   
   Characters: 48 of 52 found
   Stages: 10 of 12 found
   Screenpack: MvC2_HD ✓
   
   Missing content:
   - Cable (character)
   - Sentinel (character)
   - ...
   
   [Import Anyway] [Cancel]
   ```
5. Create collection with found items
6. Mark missing items as "unavailable" (gray, with badge)

---

## Testing Checklist

### Unit Tests

- [ ] `Collection` model encodes/decodes to JSON correctly
- [ ] `RosterEntry` factory methods work correctly
- [ ] `CollectionStore` CRUD operations work
- [ ] `SelectDefGenerator` produces valid select.def syntax
- [ ] `SelectDefGenerator` handles randomselect and empty slots
- [ ] Backup creation works

### Integration Tests

- [ ] Collection persists across app restart
- [ ] Active collection persists across app restart
- [ ] Generated select.def loads in IKEMEN GO
- [ ] Changing collection and re-launching IKEMEN GO shows new roster

### UI Tests

- [ ] Collections appear in sidebar
- [ ] Creating new collection works
- [ ] Deleting collection works (not default)
- [ ] Activating collection shows green dot
- [ ] Character picker sheet opens and functions
- [ ] Drag-to-reorder works in roster grid

---

## File Summary

| File | Purpose | Phase |
|------|---------|-------|
| `Models/Collection.swift` | Data models | 1 |
| `Core/CollectionStore.swift` | Persistence & state | 1 |
| `Core/SelectDefGenerator.swift` | Generate select.def | 1 |
| `UI/SidebarCollectionsSection.swift` | Sidebar UI | 2 |
| `UI/CollectionEditorView.swift` | Main editor view | 3 |
| `UI/CharacterPickerSheet.swift` | Add characters sheet | 3 |
| `UI/StagePickerSheet.swift` | Add stages sheet | 3 |
| `Core/EmulatorBridge.swift` | Integration hooks | 4 |
| `Models/SmartCollection.swift` | Smart rules (future) | 5 |
| `Core/CollectionExporter.swift` | Export/Import (future) | 6 |

---

## Notes for Copilot Agent

1. **Start with Phase 1** — Get the data model and storage working first. Everything else depends on this.

2. **Test with real data** — Use the existing characters in `Ikemen-GO/chars/` to populate the default collection.

3. **Match existing patterns** — Look at how `CharacterBrowserView.swift` is implemented for UI patterns.

4. **Use existing components**:
   - `DesignColors`, `DesignFonts` from `UIHelpers.swift`
   - `ToastNotification` for feedback
   - `ImageCache` for thumbnails

5. **Don't break existing functionality** — The app should still work if Collections feature is incomplete.

6. **JSON storage location**: `~/Library/Application Support/IKEMEN Lab/collections/`

7. **The default collection** should automatically stay in sync with the library — if a character is added via drag-and-drop, it should appear in "All Characters".
