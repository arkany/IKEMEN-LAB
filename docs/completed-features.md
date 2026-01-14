# IKEMEN Lab — Completed Features

This document tracks all completed features and resolved issues for historical reference.

---

## Core Features ✅

### Launcher & Process Management
- Basic launcher UI with Launch/Stop buttons
- IkemenBridge for process management via NSWorkspace
- Auto-detect when Ikemen GO closes (update button state)
- Character/stage counting and display

### Content Installation
- Drag-and-drop installation (ZIP, RAR, 7z, folders)
- Auto-add to select.def with correct path detection
- Portrait size validation (warns on oversized)
- Homebrew dependencies (libxmp, sdl2, molten-vk, unrar)
- Toast notifications for success/failure
- Normalize folder names for NEW content (spaces→underscores, Title_Case)

### Visual Browsers
- Character browser with thumbnails (SFF v1/v2 portrait extraction)
- Stage browser with thumbnails (SFF v1/v2 preview extraction)
- Grid/list view toggle for characters and stages
- Character details panel (author, version, palette count, editable name)
- Character move list viewer (parse .cmd → "↓↘→ + LP" notation)
- Screenpack browser with sections ("ACTIVE", "ALL ADD-ONS")

### Design System
- Modern dark theme (zinc palette)
- Custom fonts (Montserrat-SemiBold, Manrope-Medium/Regular, Inter-Regular)
- Glass panel card effects
- Sidebar with SF Symbols, count badges, VRAM indicator
- Content header with breadcrumb navigation
- Character grid gradient overlay (zinc-950 → transparent)

### Dashboard
- Stats cards (Characters, Stages, Storage Used)
- Install content drop zone
- Recently installed table
- Quick settings (Fullscreen, V-Sync)
- Volume sliders (BGM, SFX)
- Library health card with Content Validator
- Launch Game button

### Settings
- Resolution picker
- Fullscreen, VSync, Borderless toggles
- Volume controls
- Experimental features toggle
- Image cache clearing

### Search & Metadata
- SQLite metadata index (GRDB.swift)
- Search by name, author
- Search by inferred tags (Marvel, KOF, etc.)
- Auto-tagging via TagDetector.swift

### Collections System (Phases 1-4)
- `Collection.swift` model with JSON persistence
- `CollectionStore.swift` for CRUD operations
- `SelectDefGenerator.swift` for select.def generation
- `CollectionsSidebarSection.swift` with create/rename/delete
- `CollectionEditorView.swift` with character grid, drag-to-reorder
- Picker sheets: Character, Stage, Screenpack
- "Add to Collection" context menu
- Activate collection → generate select.def + backup
- Unit tests: CollectionModelTests, CollectionStoreTests, SelectDefGeneratorTests

### Tagging UI
- Tags displayed as pill badges in CharacterDetailsView
- Flow layout wrapping for multiple tags
- Tag-based search in MetadataStore
- Up to 3 tag badges on character grid cards

### First Run Experience (FRE)
- Welcome screen with app branding
- IKEMEN GO installation check
- Folder selection with drag-and-drop validation
- Content detection with scan results
- Success confirmation with feature tips

### Context Menus & Tools
- Right-click: Reveal in Finder, Remove
- Character folder rename (match DEF name)
- Stage rename dialog (edit DEF name field)
- Portrait fix tool (160x160)

### Content Detection
- Character detection (has `[Files]` with cmd/cns/anim keys)
- Stage detection (has `[StageInfo]` or `[BGdef]`)
- Scene/Ending detection (has `[SceneDef]`)
- Screenpack character limit detection (rows × columns)
- Character cutoff indicator in browser

### Duplicate Detection
- DuplicateDetector core implementation
- (UI integration in progress)

---

## Resolved Issues ✅

| Issue | Resolution |
|-------|------------|
| Stage preview fails for root-relative sprite paths | Now handles both `spr = stages/X.sff` and `spr = X.sff` |
| Dashboard card navigation incomplete | Fixed NSAnimationContext → use CATransaction + DispatchQueue.main |
| All stages in IKEMEN GO wrong | Cleaned up misplaced files, moved orphaned to _orphaned_files/ |
| Too many Kung Fu Man characters | Removed duplicate example entries from select.def |
| Folder rename breaks character loading | `findCharacterDefEntry` uses exact case matching |
| Stage filename sanitization breaks IKEMEN GO | Disabled sanitization; .def references .sff by exact name |
| Storyboards installed as characters | Content detection skips `[SceneDef]` files |
| Misnamed character folders (Intro_X) | Added "Rename Folder to X" context menu option |
| Single-letter stage names | Manual DEF fixes + "Rename Stage…" dialog |
| Recently Installed shows invalid types | MetadataStore initialized in handleFREComplete |

---

## Technical Debt Resolved ✅

### Code Refactoring
- Split `EmulatorBridge.swift` (2000+ lines → 489 lines):
  - `Core/SFFParser.swift` - SFF v1/v2 parsing, PCX decoding, RLE8/LZ5 decompression
  - `Core/DEFParser.swift` - Reusable .def file parsing with section support
  - `Core/ImageCache.swift` - NSCache-based singleton (500 items / ~100MB)
  - `Core/ContentManager.swift` - Installation, select.def management
  - `Models/CharacterInfo.swift` - Character metadata struct
  - `Models/StageInfo.swift` - Stage metadata struct
  - `Shared/UIHelpers.swift` - DesignColors, DesignFonts, BrowserLayout

### Architecture Improvements
- DRY: Shared fonts/colors in UIHelpers.swift
- DRY: Shared DEF parsing in DEFParser.swift
- `Result<T, Error>` and throws instead of nil returns
- Protocol-based SFF parsing (`SFFVersionParser` protocol)
- Unit tests for SFF, DEF, and Collections

---

## Unit Tests ✅

- `SFFParserTests.swift` - SFF v1/v2 parsing
- `DEFParserTests.swift` - DEF file parsing
- `CollectionModelTests.swift` - Collection data model
- `CollectionStoreTests.swift` - JSON persistence
- `SelectDefGeneratorTests.swift` - select.def generation
