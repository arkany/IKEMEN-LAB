# MacMugen — Native macOS MUGEN Experience

## Goal

Create a **Mac-native launcher and content manager** for Ikemen GO that:

* Provides a proper macOS `.app` experience (not just a bare executable)
* Makes character/stage installation drag-and-drop simple
* Handles content organization and discovery
* Wraps Ikemen GO's netplay with a friendlier UI
* Is viable for **Mac App Store distribution**

**Key insight:** Ikemen GO already exists and runs on macOS. We're not rebuilding the engine - we're building the **Mac-native UX layer** that's missing.

### 🛡️ Core Philosophy: "First, Do No Harm"

IKEMEN Lab must handle two distinct user scenarios:

| Scenario | User Profile | Our Approach |
|----------|--------------|---------------|
| **Fresh Start** | New to IKEMEN GO, empty chars/stages folders | Full automation: normalize names, organize folders, manage select.def |
| **Existing Setup** | Has working installation with content already configured | Read-only indexing first; all modifications are opt-in and reversible |

**The Golden Rule:** If a user's setup works in IKEMEN GO today, it must still work after connecting IKEMEN Lab. We add value through visibility and tooling, not by "fixing" things that aren't broken.

---

## Current Status (December 2024)

### ✅ Completed
- [x] Basic launcher UI with Launch/Stop buttons
- [x] IkemenBridge for process management via NSWorkspace
- [x] Character/stage counting and display
- [x] Drag-and-drop installation (ZIP, RAR, 7z, folders)
- [x] Auto-add to select.def with correct path detection
- [x] Portrait size validation (warns on oversized)
- [x] Homebrew dependencies (libxmp, sdl2, molten-vk, unrar)
- [x] Visual character browser with thumbnails (SFF v1/v2 portrait extraction)
- [x] Auto-detect when Ikemen GO closes (update button state)
- [x] Visual stage browser with thumbnails (SFF v1/v2 preview extraction)
- [x] Grid/list view toggle for characters and stages
- [x] Settings panel (resolution, fullscreen, etc.)
- [x] Portrait fix tool (generate/resize 160x160 portraits)
- [x] Right-click context menus for characters/stages (Reveal in Finder, Remove)
- [x] **Design System Overhaul** — Modern dark theme (zinc palette, Manrope/Montserrat/Inter fonts)
- [x] **Dashboard Page** — Overview with stats cards, drop zone, quick settings, launch button
- [x] App renamed from "MUGEN MGR" to "IKEMEN Lab"
- [x] Custom fonts installed (Montserrat-SemiBold, Manrope-Medium/Regular, Inter-Regular)
- [x] Sidebar redesign with SF Symbols, count badges, VRAM indicator
- [x] **Content Header** — Breadcrumb navigation (Home → Page) with search field
- [x] **Search** — Filter characters/stages by name/author (SQLite + header search field)

### 🔄 In Progress
- [ ] Apply design system to remaining views (Stages, Settings)
- [ ] **Unregistered Content Detection** — Show chars/stages in folders but not in select.def
  - [ ] "Unregistered" filter/tab in Character and Stage browsers
  - [ ] Batch "Register Selected" action (appends to select.def)
  - [ ] "Missing" badge for select.def entries with deleted folders

### ✅ Recently Completed
- [x] **Collections System (Phases 1-3)** — Game profiles for custom rosters:
  - Phase 1: `Collection.swift` model, `CollectionStore.swift` (JSON persistence), `SelectDefGenerator.swift`
  - Phase 2: `CollectionsSidebarSection.swift` with create/rename/delete, status indicators, count badges
  - Phase 3: `CollectionEditorView.swift` with character grid, drag-to-reorder
  - Picker sheets: `CharacterPickerSheet`, `StagePickerSheet`, `ScreenpackPickerSheet`
  - "Add to Collection" context menu in Character Browser
  - Unit tests: `CollectionModelTests`, `CollectionStoreTests`, `SelectDefGeneratorTests`
- [x] **Content Rename Tools** — Fix misnamed content in both IKEMEN Lab and IKEMEN GO:
  - Character folder rename: Context menu detects when folder name (e.g., "Intro_8") doesn't match character name ("Frank Jr.") and offers to rename
  - Stage rename dialog: Right-click → "Rename Stage…" edits the DEF file's name field directly
  - Fixed 11 stage DEF files with single-letter names (O, P, Q, T, f, x, j, v, etc.) to show real names
  - `DEFParser.extractStageName()` handles quirky DEF files with names in comments (e.g., `name = "T";"Temple Gardens"`)
- [x] **Content Detection Step in FRE** — New step 4 in First Run Experience:
  - Scans chars/, stages/, data/ folders after folder selection
  - Shows scanning state with progress spinner
  - Displays results in 3-column grid (characters, stages, screenpacks)
  - Edge case messages: empty library ("Ready to build your library!"), large library (100+ chars)
  - Background thread scanning with main thread UI updates
  - Caches results for main app use
- [x] **Screenpack Browser** — Match HTML reference design (add-ons.html):
  - List view with sections ("ACTIVE", "ALL ADD-ONS")
  - Section headers with uppercase labels
  - Grid/list view toggle now visible for Screenpacks
  - Proper section indexing and data source
- [x] **Character Grid Gradient Overlay** — Match HTML reference (generated-page-6.html):
  - `GradientOverlayView` reusable component with proper `CAGradientLayer` management
  - Bottom-to-top gradient: zinc-950 → zinc-950/20 → transparent
  - Handles cell reuse correctly via `layout()` and `updateLayer()` overrides
- [x] **First Run Experience (FRE)** — 5-step onboarding wizard:
  - Welcome screen with app branding
  - IKEMEN GO installation check (existing/download)
  - Folder selection with drag-and-drop validation
  - Content detection with scan results
  - Success confirmation with feature tips
  - Success confirmation with feature tips
- [x] **Character Browser UI Overhaul** — Match HTML reference design:
  - Grid view: Cards with gradient overlay, name/author at bottom, status dot, hover states (200ms)
  - List view: Table with columns (Icon, Name, Author, Series, Version, Date)
  - Detail panel: Always visible (420px), hero header, attributes bars, palettes, move list

### ⚠️ Known Issues
- [x] ~~Stage preview fails for stages using root-relative sprite paths~~ (fixed: now handles both `spr = stages/Bifrost.sff` and `spr = Bifrost.sff`)
- [x] ~~Dashboard card navigation incomplete~~ (fixed: NSAnimationContext completion handler issue → use CATransaction + DispatchQueue.main)
- [x] ~~All stages in IKEMEN GO are wrong~~ (fixed: Cleaned up misplaced character files, orphaned content moved to _orphaned_files/)
- [x] ~~Too many Kung Fu Man characters~~ (fixed: removed duplicate example entries from select.def)
- [x] ~~Folder rename breaks character loading~~ (fixed: `findCharacterDefEntry` now uses exact case matching; if folder name doesn't exactly match def filename, uses explicit path like `Bbhood/BBHood.def`)
- [x] ~~Stage filename sanitization breaks IKEMEN GO~~ (fixed: disabled filename sanitization for stages; .def files reference .sff by exact name, renaming breaks references)
- [x] ~~Storyboards installed as characters~~ (fixed: content detection now skips `[SceneDef]` files; `findCharacterDefEntry` also filters out storyboard .def files)
- [x] ~~Misnamed character folders (Intro_X)~~ (fixed: added context menu "Rename Folder to X" option that renames folders to match actual character name from DEF file)
- [x] ~~Single-letter stage names~~ (fixed: manually corrected DEF files + added "Rename Stage…" dialog to edit stage names in-app)
- [x] **Recently Installed shows invalid content types** (fixed: hooked up `MetadataStore` initialization and indexing in `GameWindowController.handleFREComplete` to ensure database is populated immediately after First Run Experience)

### 🛠️ Technical Debt / Refactoring
**Critical:**
- [x] Split `EmulatorBridge.swift` (2000+ lines → 489 lines) into:
  - [x] `Core/SFFParser.swift` - SFF v1/v2 parsing, PCX decoding, RLE8/LZ5 decompression
  - [x] `Core/DEFParser.swift` - Reusable .def file parsing with section support
  - [x] `Core/ImageCache.swift` - NSCache-based singleton for portraits/previews
  - [x] `Core/ContentManager.swift` - Installation, select.def management
  - [x] `Models/CharacterInfo.swift` - Character metadata struct (uses DEFParser)
  - [x] `Models/StageInfo.swift` - Stage metadata struct (uses DEFParser)
  - [x] `Shared/UIHelpers.swift` - BrowserViewMode, DesignColors, DesignFonts, BrowserLayout
- [x] DRY: Extract shared fonts/colors (DesignColors, DesignFonts in UIHelpers.swift)
- [x] DRY: Extract shared DEF file parsing logic (DEFParser.swift)
- [ ] Extract generic `ContentBrowserView<T>` - DEFERRED: Views share UIHelpers but have different item types/caching

**Medium Priority:**
- [x] Add `NSCache` for extracted portraits/previews (ImageCache.swift with 500 items / ~100MB limit)
- [x] Use `Result<T, Error>` or throws instead of nil returns (SFFError enum, extractPortraitResult/extractStagePreviewResult)
- [x] Protocol-based SFF parsing (`SFFVersionParser` protocol with SFFv1Parser/SFFv2Parser)
- [ ] Migrate to async/await from Combine publishers - DEFERRED: @Published properties work well with SwiftUI; async/await would require MainActor changes and doesn't provide clear benefit for current usage

**Nice-to-Have:**
- [x] Unit tests for SFF parsing (`SFFParserTests.swift`)
- [x] Unit tests for DEF parsing (`DEFParserTests.swift`)
- [x] Unit tests for Collections (`CollectionModelTests`, `CollectionStoreTests`, `SelectDefGeneratorTests`)
- [ ] Visualizing "unregistered" content in the UI (files found on disk but missing from select.def)
- [ ] SwiftUI migration path for new views
- [ ] Dependency injection (replace singletons)

---

## Roadmap

### 🧪 Alpha Release — "Community Preview"
**Focus:** Get early feedback from IKEMEN GO community  
**Goal:** Validate direction, discover missing features, build interest

| Task | Status | Notes |
|------|--------|-------|
| Create unsigned release build | 📋 Todo | Release config, zip the .app |
| Publish to GitHub Releases | 📋 Todo | Tag v0.1.0-alpha |
| Write README with screenshots | 📋 Todo | Installation, features, requirements |
| Enable GitHub Discussions | 📋 Todo | Feature requests, Q&A, polls |
| Create "Feature Voting" discussion | 📋 Todo | Pin a post with planned features for 👍 voting |
| Post to IKEMEN GO Discord/forums | 📋 Todo | Announce and gather feedback |
| Collect feedback → update roadmap | 📋 Todo | Prioritize based on community input |

**Community Feedback Channels:**
- **GitHub Discussions** → Feature requests, polls, Q&A
- **GitHub Issues** → Bug reports, specific problems
- **Issue reactions** → 👍/👎 voting on planned features

---

### 🚀 MVP — "The Core Pipeline"
**Focus:** Automated install + metadata foundation  
**Goal:** Make installing characters effortless, normalize chaos into clean structured data

⚠️ **Important:** These features apply to **NEW content being installed**, not existing content already in the user's library.

| Feature | Status | Notes |
|---------|--------|-------|
| Download → unzip → validate → install | ✅ Done | ZIP, RAR, 7z, folders supported |
| Fix common folder issues | ✅ Done | Auto-detect correct path structure |
| Normalize folder names + metadata | ✅ Done | **NEW content only** — sanitize names (spaces→underscores, Title_Case, preserve acronyms) |
| Auto-generate portraits (basic) | ✅ Done | Portrait fix tool (160x160) — opt-in for existing |
| Update select.def | ✅ Done | **Append only** — never reorder existing entries |
| Local metadata index (SQLite) | ✅ Done | GRDB.swift for persistent database |
| Basic search (name, author) | ✅ Done | Filter library by text (header search field) |
| Drag-and-drop feedback UI | ✅ Done | Toast notifications for success/failure |

**Why this phase matters:** This gives you the compiler core. Everything else plugs into this.

---

### 🎨 Dashboard Page — "The Command Center"
**Focus:** At-a-glance overview + quick actions  
**Goal:** Make the app feel like a proper content manager, not just a file browser

| Component | Status | Notes |
|-----------|--------|-------|
| **Overview Header** | ✅ Done | "DASHBOARD" title in sidebar |
| **Stats Cards Row** | ✅ Done | 3-column grid: Characters, Stages, Storage Used |
| ├─ Active Fighters | ✅ Done | Count from select.def |
| ├─ Installed Stages | ✅ Done | Count from select.def |
| ├─ Storage Used | ✅ Done | Calculate chars/ + stages/ folder sizes |
| └─ Launch Game | ✅ Done | Primary action button in dashboard |
| **Install Content Drop Zone** | ✅ Done | Dashed border, accepts drag-and-drop |
| **Recently Installed Table** | ✅ Done | Name, Type (Char/Stage badge), Date, Status toggle |
| **Quick Settings Panel** | ✅ Done | Fullscreen, V-Sync toggles |
| **Volume Sliders** | ✅ Done | BGM Volume, SFX Volume sliders |
| **Screenpack Promo Card** | 📋 Todo | "New Screenpack available" — see [docs/screenpack-promo-plan.md](docs/screenpack-promo-plan.md) |
| **Library Health Card** | ✅ Done | Content Validator with Scan button, expandable issues list |

**Design System (from HTML reference):**
- Color palette: Tailwind zinc (950/900/800/700/600/500/400) ✅ Implemented
- Fonts: Montserrat (headers), Manrope (body/nav), Inter (captions) ✅ Implemented
- Borders: white/5 (subtle), white/10 (hover) ✅ Implemented
- Cards: Glass panel effect (gradient from white/3% to transparent) ✅ Implemented
- Corner radius: 12px (rounded-xl) ✅ Implemented
- Sidebar: 256px width, fixed left ✅ Implemented

---

### 🧩 v1 — "The Library Era"
**Focus:** Collections + Roster Builder + Better Metadata  
**Goal:** Turn your library into a browsable, semantic system; make rosters reproducible and shareable

| Feature | Status | Notes |
|---------|--------|-------|
| Character roster arrangement | ✅ Done | Drag-to-reorder in select.def |
| Character details panel | ✅ Done | Author, version, palette count, editable name |
| Character move list viewer | ✅ Done | Parse .cmd → "↓↘→ + LP" notation |
| Local Library Manager UI | ✅ Done | Visual browser with grid/list views |
| Screenpack management | ✅ Done | Browse, activate, install, component detection |
| **Screenpack Browser UI Overhaul** | 📋 Todo | Match Character Browser design: cards with gradient overlay, hover states, detail panel |
| **Screenpack README/setup notes** | 📋 Todo | Parse readme.txt, display install instructions |
| **First-run wizard** | ✅ Done | Guide new users through initial setup |
| ├─ Welcome screen | ✅ Done | App branding, "Get Started" button |
| ├─ IKEMEN GO check | ✅ Done | "I already have it" or "Download" options |
| ├─ Folder selection | ✅ Done | Drag-and-drop or browse, validates installation |
| ├─ Version detection | ✅ Done | Auto-detect version from README.md |
| ├─ **Content detection** | ✅ Done | Scan for existing chars/stages, show summary |
| ├─ **Import mode choice** | 📋 Todo | "Index only" (read-only) vs "Full management" |
| └─ Success confirmation | ✅ Done | Feature tips, "Open Dashboard" button |
| **Collections system** | � In Progress | Game profiles that generate select.def files |
| ├─ Spec document | ✅ Done | Detailed design in `docs/collections-spec.md` |
| ├─ Phase 1: Data model | ✅ Done | `Collection.swift`, `CollectionStore.swift`, `SelectDefGenerator.swift` |
| ├─ Phase 2: Sidebar UI | ✅ Done | `CollectionsSidebarSection.swift` with create/rename/delete, status indicators |
| ├─ Phase 3: Editor | ✅ Done | `CollectionEditorView.swift`, character/stage/screenpack pickers |
| ├─ Phase 4: select.def gen | ✅ Done | Activate → generate + backup |
| ├─ Phase 5: Smart Collections | 📋 Todo | Tag-based auto-population |
| └─ Phase 6: Export/Import | 📋 Todo | `.ikemencollection` format |
| Auto-tagging (basic rules) | ✅ Done | Infer source game, style from filenames/metadata (TagDetector.swift) |
| Detect duplicates + outdated versions | 🔄 In Progress | DuplicateDetector core done; needs pre-install warning + badge display |
| Detect screenpack character limit | ✅ Done | Parse rows × columns from system.def; orange warning badge when roster exceeds slots |
| **Character cutoff indicator** | 📋 Todo | Show visual divider in Character Browser after slot limit; "X characters won't appear in-game" |
| **Existing Installation Import** | 📋 Todo | Non-destructive indexing of pre-existing setups |

### 🎨 Screenpack Handling Strategy

Screenpacks are complex — they define the entire UI theme and often have specific setup requirements:

**What screenpacks typically contain:**
```
data/MyScreenpack/
├── system.def          # Main definition (rows, columns, fonts, sounds)
├── system.sff          # Sprites for menus, select screen
├── system.snd          # UI sounds
├── fight.def           # Lifebar/HUD definition
├── fight.sff           # Lifebar sprites
├── fight.snd           # Fight sounds (round call, KO, etc.)
├── select.def          # Optional custom roster (⚠️ may override user's)
├── fightfx.air/.sff    # Hit sparks, effects
├── readme.txt          # CRITICAL: Setup instructions
└── fonts/              # Custom fonts
```

**Why screenpacks are tricky for existing setups:**
1. **May include their own select.def** — Could override user's character roster
2. **Often require specific folder structure** — `data/screenpack_name/` expected
3. **May reference absolute paths** — Breaks if installed in wrong location
4. **Font dependencies** — May require fonts in specific locations
5. **Character slot limits** — `rows × columns` defines max characters shown

**Our approach:**
| Scenario | Behavior |
|----------|----------|
| Screenpack has readme.txt | **Show in detail panel** before activation |
| Screenpack has select.def | **Warn user**: "This screenpack includes its own roster (X chars). Your current roster (Y chars) will be preserved." |
| Screenpack includes fonts | Auto-detect font/ folder, show in components list |
| Slot limit exceeded | **Warn**: "Your roster has 145 chars but this screenpack shows max 60. Consider [Large screenpack] instead." |
| Activation requested | Preview changes in "dry run" mode, backup config.json first |

**Screenpack detail panel should show:**
- Name, author, resolution (from system.def `[Info]` section)
- Components included (lifebars, select screen, etc.)
- **Character slots**: "60 slots (5×12)" parsed from `rows` × `columns`
- **README contents** (scrollable, if readme.txt exists)
- **Warnings** if slot limit < current roster size
- "Activate" button with confirmation

### �️ Collections System — "Game Profiles"

Collections are **complete game profiles** that define a playable roster. Each collection generates its own `select.def` file when activated, enabling users to maintain multiple curated experiences.

**Core Concept:**
```
Collection = Characters (ordered) + Stages + Screenpack → generates select.def
```

**Why Collections matter:**
- Users often want themed rosters: "Marvel vs Capcom", "SNK Bosses Only", "Tournament Legal"
- IKEMEN GO only reads one `select.def` at a time — Collections let users switch instantly
- Shareable: Export a collection for others to import (assumes they have the characters)

#### Collection Types

| Type | Description | Example |
|------|-------------|---------|
| **User Collection** | Manually curated by user | "My Marvel Roster", "Party Mode" |
| **Smart Collection** | Auto-populated by rules/tags | "Recently Added", "Marvel Characters", "HD Only" |
| **Default Collection** | Built-in, always exists | "All Characters" (everything in library) |

#### Data Model

```swift
struct Collection: Codable, Identifiable {
    let id: UUID
    var name: String
    var icon: String                    // SF Symbol name
    var characters: [RosterEntry]       // Ordered list with grid positions
    var stages: [StageEntry]            // Stages included in this collection
    var screenpackPath: String?         // Optional: specific screenpack for this collection
    var isSmartCollection: Bool
    var smartRules: [SmartRule]?        // For smart collections only
    var createdAt: Date
    var modifiedAt: Date
}

struct RosterEntry: Codable {
    let characterId: String             // Reference to character folder name
    var gridPosition: GridPosition?     // For manual grid layout (row, column)
    var isRandomSelect: Bool            // "randomselect" placeholder
    var isEmpty: Bool                   // Empty slot for grid spacing
}

struct GridPosition: Codable {
    var row: Int
    var column: Int
}

struct SmartRule: Codable {
    var field: String                   // "tag", "author", "dateAdded", "series"
    var operation: String               // "contains", "equals", "after", "before"
    var value: String
}
```

#### Storage Format

**JSON files** stored in app support directory:
```
~/Library/Application Support/IKEMEN Lab/
├── collections/
│   ├── default.json                   # "All Characters" collection
│   ├── {uuid}.json                    # User collections
│   └── smart/
│       ├── recently-added.json
│       ├── marvel.json
│       └── snk.json
└── exports/
    └── *.ikemencollection             # Shareable export format
```

**Why JSON (not SQLite):**
- Human-readable for debugging
- Easy to export/share (`.ikemencollection` is just JSON)
- Collections are small (just references, not content)
- Git-friendly if user wants to version control

#### Sidebar Structure

```
┌─────────────────────────────────┐
│ 📊 DASHBOARD                    │
├─────────────────────────────────┤
│ LIBRARY                         │
│   👤 Characters              127│
│   🏔️ Stages                   45│
│   🎨 Screenpacks               8│
│   🧩 Add-ons                  12│
├─────────────────────────────────┤
│ COLLECTIONS                     │
│   📁 All Characters     ● ✓  127│  ← Default, always exists
│   📁 Marvel vs Capcom   ●      52│  ← Green dot = active
│   📁 Tournament Legal   ◐      38│  ← Yellow = incomplete (missing chars)
│   📁 Party Mode                24│
│   ＋ New Collection...          │
├─────────────────────────────────┤
│ SMART COLLECTIONS               │
│   🕐 Recently Added            15│
│   🦸 Marvel                    34│
│   👊 SNK                       28│
│   🎮 Capcom                    41│
│   ⭐ Favorites                  8│
└─────────────────────────────────┘
```

**Status Indicators:**
- `●` Green dot = Currently active (this collection's select.def is loaded)
- `◐` Yellow dot = Incomplete (references characters not in library)
- No dot = Valid but not active

#### UI: Collection Editor View

When a collection is selected in sidebar:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ ← Back    Marvel vs Capcom                              [Activate] [⋯] │
├─────────────────────────────────────────────────────────────────────────┤
│ ROSTER (52 characters)                          [+ Add] [Grid View ▼]  │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ [Drag-to-reorder grid of character cards]                           │ │
│ │                                                                     │ │
│ │  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐    │ │
│ │  │Ryu │ │Ken │ │Chun│ │ ? │ │Wlvr│ │Mgnt│ │Strm│ │ ▢ │ │Cycl│    │ │
│ │  └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘    │ │
│ │    ?  = randomselect        ▢ = empty slot                          │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────┤
│ STAGES (12)                                                    [+ Add] │
│  Bifrost, Training Room, Daily Bugle, Metro City...                    │
├─────────────────────────────────────────────────────────────────────────┤
│ SCREENPACK                                                    [Change] │
│  MvC2 HD Screenpack (60 slots)                                         │
│  ⚠️ Collection has 52 chars, screenpack shows 60 — 8 empty slots       │
└─────────────────────────────────────────────────────────────────────────┘
```

**Key Interactions:**
- **Drag-to-reorder** characters in grid
- **Right-click character** → Remove from collection, Move to position...
- **[+ Add]** → Opens character picker (shows library, checkmarks already-in-collection)
- **Insert empty slot** → For grid layout control
- **Insert randomselect** → Adds "?" placeholder
- **[Activate]** → Generates select.def, sets as active, shows green dot

#### select.def Generation

When a collection is activated:

```
1. Backup current select.def → select.def.backup.{timestamp}
2. Generate new select.def from collection data:
   
   [Characters]
   Ryu/Ryu.def
   Ken/Ken.def
   Chun-Li/Chun-Li.def
   randomselect                    ; from isRandomSelect entries
   Wolverine/Wolverine.def
   Magneto/Magneto.def
   Storm/Storm.def
                                   ; empty line from isEmpty entries
   Cyclops/Cyclops.def
   
   [ExtraStages]
   stages/Bifrost/Bifrost.def
   stages/Training/Training.def
   ...
   
3. Update config.json to point to collection's screenpack (if specified)
4. Mark collection as active in UI (green dot)
```

#### Smart Collections

Auto-populated based on rules. User cannot manually add/remove — membership is computed.

| Smart Collection | Rule | Updates |
|------------------|------|---------|
| Recently Added | `dateAdded > 7 days ago` | On library change |
| Marvel | `tag contains "marvel"` | On library change |
| SNK | `tag contains "snk" OR series = "KOF"` | On library change |
| Capcom | `tag contains "capcom" OR series in [SF, Darkstalkers, MvC]` | On library change |
| HD Characters | `resolution = "HD"` | On library change |
| Favorites | `isFavorite = true` | On favorite toggle |

**Smart Collections are read-only** — they show what matches, but you can't manually add. To curate, create a User Collection and add from the Smart Collection.

#### Export/Import

**Export (`.ikemencollection`):**
```json
{
  "version": 1,
  "name": "Marvel vs Capcom",
  "exportedAt": "2026-01-07T12:00:00Z",
  "characters": [
    {"folder": "Ryu", "def": "Ryu.def"},
    {"folder": "Wolverine", "def": "Wolverine.def"},
    ...
  ],
  "stages": [
    {"folder": "Bifrost", "def": "Bifrost.def"},
    ...
  ],
  "screenpack": "MvC2_HD"
}
```

**Import behavior:**
1. Parse `.ikemencollection` file
2. Check which characters/stages exist in user's library
3. Show summary: "48 of 52 characters found, 10 of 12 stages found"
4. Create collection with found items, mark missing as "unavailable"
5. Option: "Get missing content" → shows list of missing folders

#### Implementation Phases

| Phase | Scope | Notes |
|-------|-------|-------|
| **Phase 1** | Data model + storage | `Collection.swift`, JSON read/write |
| **Phase 2** | Sidebar UI | Collection list, status indicators, create/rename/delete |
| **Phase 3** | Collection Editor | Character grid, drag-to-reorder, add/remove |
| **Phase 4** | select.def generation | Activate collection → generate + backup |
| **Phase 5** | Smart Collections | Tag-based auto-population |
| **Phase 6** | Export/Import | `.ikemencollection` format |

### �📦 Existing Installation Import Strategy

When IKEMEN Lab connects to an existing IKEMEN GO folder with content already installed:

**Phase 1: Read-Only Discovery**
| Step | Action | Notes |
|------|--------|-------|
| Scan chars/ folder | Index all .def files, extract metadata | No modifications |
| Scan stages/ folder | Index all stage .def files | No modifications |
| Parse select.def | Read current roster order, slot positions | Preserve exactly |
| Detect screenpack | Identify active screenpack, grid dimensions | For capacity warnings |
| Hash existing files | Generate checksums for duplicate detection | Compare NEW content only |
| Store "baseline" state | Snapshot of folder structure + select.def | For diff comparison |

**Phase 2: Non-Destructive Cataloging**
- Index **unregistered** content (chars/stages not in select.def) → show in "Unregistered" tab
- Detect potential issues (missing .sff, broken paths) → show as warnings, don't auto-fix
- Identify naming convention user prefers (snake_case, lowercase, etc.) → match for new installs
- Flag potential duplicates → inform user, let them decide

**Phase 3: User-Controlled Actions**
| Feature | Behavior | Safety |
|---------|----------|--------|
| Add new character | Append to select.def only | Never reorder existing |
| "Register untracked" | Add existing chars to select.def | User picks which ones |
| "Find duplicates" | Show comparison UI | User confirms removal |
| "Cleanup names" | Offer rename suggestions | Opt-in per-item, backup first |
| "Optimize roster" | Suggest reordering | Preview changes, one-click revert |

**Key Safety Rails:**
1. **Never auto-delete** — Duplicates shown for review, user must confirm
2. **Never auto-rename** — Suggest only; renaming can break .def references
3. **Never reorder select.def** — Existing roster order is sacred; only append
4. **Backup select.def** — Create `select.def.backup` before any modification
5. **"Dry run" mode** — Preview all changes before applying
6. **Undo stack** — Track recent changes, allow rollback

**Edge Cases to Handle:**
- Characters in select.def but folder deleted → Mark as "Missing" (red badge)
- Multiple .def files in same folder → Let user pick which to register
- Custom folder structure (e.g., `chars/Marvel/Cyclops/`) → Preserve paths exactly
- select.def uses relative vs absolute paths → Match existing style
- Screenpack at capacity → Warn before adding, don't silently fail

### 📊 Content Status Model

Every character/stage in IKEMEN Lab's index has a **status** derived from comparing filesystem state vs select.def:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Content Status States                       │
├──────────────┬──────────────────────────────────────────────────┤
│ Status       │ Meaning                                          │
├──────────────┼──────────────────────────────────────────────────┤
│ ✅ Active    │ In select.def AND folder exists AND files valid  │
│ 📁 Unregistered │ Folder exists BUT not in select.def           │
│ ❌ Missing   │ In select.def BUT folder/files not found         │
│ ⚠️ Broken    │ In select.def, folder exists, but .def invalid   │
│ 🔄 Duplicate │ Same character exists in multiple locations      │
└──────────────┴──────────────────────────────────────────────────┘
```

**UI Treatment:**
- **Active** → Normal display, fully functional
- **Unregistered** → Shown in separate tab/filter, "Register" button available
- **Missing** → Red badge, "Remove from roster" or "Locate folder" options
- **Broken** → Yellow badge, shows specific error, "Attempt repair" option
- **Duplicate** → Orange badge, "Compare versions" action

### 🔄 Sync Strategy

IKEMEN Lab maintains a **one-way sync** from filesystem → database:

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Filesystem     │────▶│   MetadataStore  │────▶│       UI         │
│ (source of truth)│     │    (SQLite)      │     │   (read-only)    │
└──────────────────┘     └──────────────────┘     └──────────────────┘
        │                                                  │
        │◀─────────────────────────────────────────────────│
        │            User-initiated actions only           │
        │   (Install, Remove, Register, Rename, etc.)      │
        └──────────────────────────────────────────────────┘
```

- **On app launch:** Quick scan for changes (compare file counts, modified dates)
- **On folder change:** FSEvents watcher triggers targeted re-index
- **Manual refresh:** "Rescan Library" button for full re-index
- **Never modify filesystem** unless user explicitly requests it

**Why this phase matters:** This is where your tool stops being an installer and becomes a curation engine.

---

### ⚡ v2 — "The Smart Layer"
**Focus:** Style detection + advanced previews + browser extension  
**Goal:** Add intelligence, reduce friction, make browsing MUGEN Archive feel modern

| Feature | Status | Notes |
|---------|--------|-------|
| **Add-ons Browser** | 📋 Todo | New sidebar section for misc content types |
| ├─ Scenes/Endings | 📋 Todo | Cutscenes with `[SceneDef]` (e.g., character endings) |
| ├─ Intro Movies | 📋 Todo | Game intros and attract modes |
| ├─ Sound Packs | 📋 Todo | Custom announcer voices, menu sounds |
| └─ Palettes | 📋 Todo | Additional .act palette files |
| **Smart Content Type Detection** | � In Progress | Auto-detect .def type from contents, not location |
| ├─ Character detection | ✅ Done | Has `[Files]` with cmd/cns/anim/sprite/sound keys |
| ├─ Stage detection | ✅ Done | Has `[StageInfo]` or `[BGdef]` section |
| ├─ Scene/Ending detection | ✅ Done | Has `[SceneDef]` section (excluded from stages) |
| ├─ Font detection | 📋 Todo | Has `[FNT v2]` or `[Fnt]` section |
| └─ Multi-content archives | 📋 Todo | Handle archives with char + ending + helpers (e.g., MVC_IRONFIST) |
| **Portrait Display Options** | 📋 Todo | Allow users to choose portrait sprite per character |
| ├─ Auto-select best size | ✅ Done | Prefer 9000,1 (portrait) over 9000,0 (icon), skip oversized VS screens |
| ├─ Manual override per character | 📋 Todo | Right-click → "Choose Portrait Sprite" → pick from available 9000,x |
| └─ Fallback to icon | ✅ Done | Use 9000,0 if no good portrait found |
| Animated idle stance preview | 📋 Todo | Parse .air Action 0, animate sprites with timing |
| Content validator/fixer | 📋 Todo | Path issues, missing files, encoding, auto-fix on import |
| **Pre-install validation** | 📋 Todo | Verify .def → .sff references resolve before adding to select.def |
| Style Detection Engine | 📋 Todo | POTS / MVC2 / KOF / CVS / Anime / Chibi classification |
| HD vs SD detection | 📋 Todo | Resolution-based sprite analysis |
| AI patch detection | 📋 Todo | Identify AI-enhanced characters |
| Hitbox/frame data viewer | 📋 Todo | Parse .cns/.air for frame data when available |
| Similar character suggestions | 📋 Todo | "If you like X, try Y" based on style/source |
| Browser extension | 📋 Todo | "Install to MacMugen" button on MUGEN Archive |
| Scrape metadata from web | 📋 Todo | Pull author, version, tags from download pages |
| Random roster generation | 📋 Todo | Generate random select.def from pools |


**Why this phase matters:** This is where the system becomes smart and frictionless — your signature.

---

### 🏛️ v3 — "The Ecosystem"
**Focus:** Full UX polish + accessibility + data safety  
**Goal:** Make the tool feel like a full platform with robust data management

| Feature | Status | Notes |
|---------|--------|-------|
| Stage installer pipeline | ✅ Done | Drag-and-drop for stages |
| Stage metadata + tagging | 📋 Todo | Source game, style, resolution tags |
| Portrait generator v2 | 📋 Todo | Better cropping, style presets, batch processing |
| Auto-fixer v2 | 📋 Todo | CNS patching, missing sprites, AI tweaks |
| Right-click context menus | ✅ Done | Reveal in Finder, Remove (characters + stages) |
| **Accessibility** | 📋 Todo | VoiceOver support, keyboard navigation, reduced motion |
| ├─ VoiceOver labels | 📋 Todo | Accessible labels for all UI elements |
| ├─ Keyboard navigation | 📋 Todo | Full keyboard control (Tab, Arrow keys, Enter) |
| ├─ Focus indicators | 📋 Todo | Visible focus rings for keyboard users |
| └─ Reduced motion | 📋 Todo | Respect `NSWorkspace.accessibilityDisplayShouldReduceMotion` |
| **Performance & Caching** | 📋 Todo | Optimize for large libraries (500+ characters) |
| ├─ Lazy loading | 📋 Todo | Load thumbnails on-demand in grid view |
| ├─ Background indexing | 📋 Todo | Index without blocking UI |
| └─ Memory management | 📋 Todo | Cap image cache, release off-screen resources |
| **Backup & Restore** | 📋 Todo | Protect user data |
| ├─ Auto-backup select.def | 📋 Todo | Timestamped backups before modifications |
| ├─ Backup collections | 📋 Todo | Export all collections as bundle |
| └─ Restore from backup | 📋 Todo | One-click restore of previous state |
| Light/dark mode support | 📋 Todo | Respect system appearance |
| Export/share curated sets | 📋 Todo | Export collection as shareable package |
| Netplay IP manager | 📋 Todo | Save/edit friend IPs in config.ini |

**Why this phase matters:** This is where your tool becomes the definitive MUGEN/IKEMEN manager.

---

### 🌐 v4 — "Distribution & Polish"
**Focus:** App Store readiness + localization + professional polish  
**Goal:** Ship a product users can download and trust worldwide

| Feature | Status | Notes |
|---------|--------|-------|
| Custom app icon | 📋 Todo | Professional branding |
| "Get Characters" resource links | 📋 Todo | Curated links to community sites |
| Code signing & notarization | 📋 Todo | Gatekeeper-friendly distribution |
| App Store sandboxing | 📋 Todo | Comply with App Store requirements |
| Sparkle auto-updater | 📋 Todo | For direct distribution channel |
| Crash reporting | 📋 Todo | Track and fix issues |
| Help documentation | 📋 Todo | User guide and FAQ |
| Sanitization results UI | 📋 Todo | Collapsed list showing renamed folders after install |
| **Localization** | 📋 Todo | Multi-language support |
| ├─ String externalization | 📋 Todo | Move all UI strings to Localizable.strings |
| ├─ Japanese | 📋 Todo | Primary target (large MUGEN community) |
| ├─ Spanish | 📋 Todo | Secondary target |
| └─ Portuguese | 📋 Todo | Secondary target |

**Why this phase matters:** This gets MacMugen into users' hands professionally.

---

### 🌌 v5 — "The Platform"
**Focus:** Optional long-term expansions  
**Goal:** Turn the tool into a creative + management suite with community features

| Feature | Status | Notes |
|---------|--------|-------|
| Plugin system | 💭 Future | Allow community extensions |
| Cloud sync for metadata | 💭 Future | Sync library state (not assets) across devices |
| Community-shared collections | 💭 Future | Browse/import others' curated sets |
| Advanced AI tagging | 💭 Future | ML-based style/quality classification |
| Auto-balance rosters | 💭 Future | Suggest balanced character matchups |
| Stage/music pairing suggestions | 💭 Future | Recommend music for stages |
| Play stats dashboard | 💭 Future | Parse stats.json for win rates, playtime |
| Screenshot/video capture | 💭 Future | Built-in recording |
| Tournament bracket mode | 💭 Future | Manage local tournaments |
| Character tier list editor | 💭 Future | Community-driven rankings |

**Why this phase matters:** This is where the tool becomes something the community rallies around.

---

## What We're Building vs What Exists

| Component | Ikemen GO (exists) | IKEMEN Lab (we build) |
|-----------|-------------------|---------------------|
| Fighting game engine | ✅ | — |
| MUGEN compatibility | ✅ | — |
| Rollback netplay | ✅ | — |
| macOS binary | ✅ | — |
| Mac `.app` bundle | ❌ | ✅ |
| Content manager UI | ❌ | ✅ |
| Drag-and-drop install | ❌ | ✅ |
| Native preferences | ❌ | ✅ |
| First-run wizard | ❌ | ✅ |
| **Non-destructive existing setup support** | ❌ | ✅ |
| **Content health monitoring** | ❌ | ✅ |
| Menu bar integration | ❌ | ✅ |
| App Store ready | ❌ | ✅ |
| Collections/curation | ❌ | ✅ |
| Style detection | ❌ | ✅ |
| Browser extension | ❌ | ✅ |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        IKEMEN Lab.app                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │     Swift/AppKit UI Layer                                 │  │
│  │  • Dashboard (stats, health, drop zone)                   │  │
│  │  • Content Browsers (characters, stages, screenpacks)     │  │
│  │  • Collections Manager                                    │  │
│  │  • Settings / Preferences                                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │     Core Services                                         │  │
│  │  ┌─────────────────┐  ┌─────────────────────────────────┐ │  │
│  │  │ ContentScanner  │  │ ContentManager                  │ │  │
│  │  │ • Read-only     │  │ • Install new content           │ │  │
│  │  │ • Index files   │  │ • User-initiated modifications  │ │  │
│  │  │ • Detect status │  │ • Backup before changes         │ │  │
│  │  └─────────────────┘  └─────────────────────────────────┘ │  │
│  │  ┌─────────────────┐  ┌─────────────────────────────────┐ │  │
│  │  │ MetadataStore   │  │ IkemenBridge                    │ │  │
│  │  │ • SQLite index  │  │ • Process management            │ │  │
│  │  │ • Content status│  │ • Config read/write             │ │  │
│  │  │ • Search/filter │  │ • select.def parsing            │ │  │
│  │  └─────────────────┘  └─────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│              ┌───────────────┴───────────────┐                  │
│              ▼                               ▼                  │
│  ┌────────────────────────┐    ┌────────────────────────────┐   │
│  │  Filesystem (chars/,   │    │  Ikemen_GO binary          │   │
│  │  stages/, data/)       │    │  • Runs in own window      │   │
│  │  SOURCE OF TRUTH       │    │  • We never modify its     │   │
│  │  We read; user writes  │    │    runtime state           │   │
│  └────────────────────────┘    └────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Key Architectural Principles:**
1. **Filesystem is source of truth** — Database is a cache/index, not authoritative
2. **Separate read vs write paths** — `ContentScanner` (read-only) vs `ContentManager` (user actions)
3. **Status derived, not stored** — Content status computed by comparing filesystem + select.def
4. **Defensive backups** — Any select.def modification creates timestamped backup

---

## Project Structure

```
MacMugen/
├── MacMugen.xcodeproj
├── MacMugen/
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   ├── MainWindowController.swift
│   │   └── PreferencesWindowController.swift
│   ├── Core/
│   │   ├── IkemenBridge.swift          # Launch/manage Ikemen process
│   │   ├── ContentScanner.swift        # Read-only filesystem indexing (NEW)
│   │   ├── ContentManager.swift        # User-initiated modifications
│   │   ├── ConfigManager.swift         # Read/write Ikemen configs
│   │   ├── SelectDefParser.swift       # Parse/edit select.def
│   │   ├── SFFParser.swift             # SFF v1/v2 sprite extraction
│   │   ├── DEFParser.swift             # Generic .def file parsing
│   │   ├── ImageCache.swift            # NSCache for thumbnails
│   │   ├── MetadataStore.swift         # SQLite index + content status
│   │   ├── BackupManager.swift         # Timestamped backups (NEW)
│   │   └── StyleDetector.swift         # Style classification (planned)
│   ├── Views/
│   │   ├── DashboardView.swift
│   │   ├── CharacterBrowserView.swift
│   │   ├── StageBrowserView.swift
│   │   ├── CollectionsView.swift       # (planned)
│   │   └── SettingsView.swift
│   ├── Models/
│   │   ├── CharacterInfo.swift
│   │   ├── StageInfo.swift
│   │   ├── ContentStatus.swift         # Active/Unregistered/Missing/Broken (NEW)
│   │   ├── Collection.swift            # (planned)
│   │   └── GameConfig.swift
│   ├── Shared/
│   │   └── UIHelpers.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── MainMenu.xib
├── Ikemen/                              # Bundled Ikemen GO
│   └── (Ikemen_GO binary + base files)
├── BrowserExtension/                    # (planned)
│   └── (Safari/Chrome extension)
└── docs/
    └── user-guide.md
```

---

## Success Metrics

| Phase | Success Criteria |
|-------|------------------|
| **MVP** | Can install character via drag-and-drop, search library, appears in game |
| **v1** | Existing installations indexed without modification; can create collections |
| **v2** | Style detection works, browser extension installs characters |
| **v3** | Stages have full parity with characters, can export/share sets |
| **v4** | Non-technical user can download, install, and play |
| **v5** | Community sharing ecosystem established |

---

## Resources

- **Ikemen GO Releases**: https://github.com/ikemen-engine/Ikemen-GO/releases
- **Ikemen GO Wiki**: https://github.com/ikemen-engine/Ikemen-GO/wiki
- **MUGEN Archive**: https://mugenarchive.com/
- **MUGEN Free For All**: https://mugenfreeforall.com/

---

## Why This Approach?

1. **Leverage existing work** — Ikemen GO is mature, actively maintained
2. **Focus on UX** — Our value-add is the Mac experience, not the engine
3. **Faster to ship** — Wrapper approach = playable sooner
4. **Stay current** — Can update bundled Ikemen GO as new versions release
5. **Legal clarity** — Ikemen GO is MIT licensed, clean to bundle
6. **Curation is the killer feature** — The MUGEN community has 30+ years of content; organizing it is the real value
