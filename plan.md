# IKEMEN Lab — Development Plan

## Overview

**IKEMEN Lab** is a Mac-native content manager for IKEMEN GO that provides drag-and-drop installation, library management, and roster curation.

## Reference Docs
- [Completed Features](docs/completed-features.md) — What's done
- [Collections Spec](docs/collections-spec.md) — Game profiles system
- [Screenpack Handling](docs/screenpack-handling.md) — Screenpack complexity
- [Existing Installation Import](docs/existing-installation-import.md) — Safety-first import strategy
- [Agent Prompts](docs/agent-prompts/) — Task specs for Copilot

---

## Core Philosophy

> **"First, Do No Harm"** — If a user's setup works in IKEMEN GO today, it must still work after connecting IKEMEN Lab.

| Scenario | Approach |
|----------|----------|
| **Fresh Start** | Full automation: normalize names, organize folders, manage select.def |
| **Existing Setup** | Read-only indexing first; all modifications are opt-in and reversible |

---

## Current Focus

### 🐛 Known Bugs
- [ ] **Collections: Character names incorrect** — Showing folder names instead of display names from DEF files
- [ ] **Collections: Stage thumbnails not loading** — All stages showing placeholder icon instead of preview images
- [ ] **Characters: "UNREGISTERED" badge is confusing** — Users think something is broken
  - Replace with section dividers: "In Roster" / "Available"
  - Only show when a collection is active
  - Add green **+** button on "Available" characters to quick-add to roster
  - Makes it clear these are just not in the current roster, not broken
  - **BUG:** Badges don't refresh when switching collections — must reload Characters view
- [ ] **Window header not draggable** — Custom header doesn't behave like standard macOS title bar
  - Make header area draggable to move window
  - Support standard title bar behaviors (double-click to zoom, etc.)

### ✅ Recently Completed (January 2026)
- [x] **Collections UI Polish**
  - [x] Removed max-height constraints on roster/stages sections
  - [x] Dynamic height calculation based on content
  - [x] Fixed nested scroll view blocking parent scroll
  - [x] Section header icon/text vertical alignment
  - [x] Hover zoom effect on character/stage thumbnails (centered scale-105)
  - [x] Delete button fixed to perfect 32×32 circle (NSView approach)
  - [x] Character details panel action buttons fixed sizing (NSView approach)
- [x] **Add Characters/Stages Sheets**
  - [x] Fixed sheet presentation (beginSheet instead of presentAsSheet)
  - [x] Fixed sheet dismissal (endSheet on parent window)
- [x] **Toast Notifications**
  - [x] Added action button support to toast system
  - [x] "Launch" button on collection activation toast

### 🔄 In Progress
- [ ] **Fullgame Import Mode** — IN PROGRESS
  - Test folder: `~/Downloads/motu_masters_project_v2a` (MOTU Masters Project)
  - **Toggle UI**: Add "Fullgame mode" checkbox to DashboardDropZone and Open Panel accessory
  - **Detection**: Scan folder for `chars/`, `stages/`, `data/system.def`, `font/`, `sound/`
  - **Content Installation**:
    - Characters: Install each subfolder in `chars/` via existing `installCharacter()`
    - Stages: Handle loose files (create subfolders), install via `installStage()`
    - Screenpack: Install `data/` contents via `installScreenpack()`
    - Fonts: Copy `font/*.fnt` to IKEMEN GO `font/`
    - Sounds: Copy `sound/*.mp3` to IKEMEN GO `sound/`
  - **Auto-Create Collection**: Parse screenpack name from `system.def` (fallback to folder name), create collection with all imported content
  - **Per-Item Duplicates**: Show per-item prompt with "Apply to remaining" option, continue batch on skip/overwrite
  - **Safety**: Backup select.def before any modification, handle partial failures gracefully
  - **Progress**: Show inline progress ("Installing 3/7...") in status label
  - **Post-Import**: Refresh character/stage browsers, show summary toast

  **Implementation Steps:**
  1. ✅ Add `fullgameImportEnabled` to AppSettings + protocol + mocks
  2. ✅ Add toggle to DashboardDropZone UI
  3. ✅ Add toggle to Open Panel accessory view
  4. ✅ Create `FullgameImporter` service with `scanFullgamePackage()` and `installFullgame()`
  5. ✅ Add `installFonts()` and `installSounds()` to FullgameImporter
  6. ✅ Add loose-stage restructuring logic
  7. ✅ Add `CollectionNameResolver` for nice naming
  8. ✅ Wire fullgame path in `handleDroppedFiles()` and Open Panel flow
  9. ✅ Implement per-item duplicate handling with "Apply to remaining"
  10. ✅ Add helper in CollectionStore to create collection from import results
  11. [ ] Add tests for detection, naming, and partial failure

### 📋 Up Next
- [ ] **Drag & Drop to Collections** — Drag characters from Characters view onto a Collection in sidebar
- [ ] **Bulk Add to Collection** — Multi-select characters, right-click "Add to Collection" (respects selection count)
- [ ] **Smart Collections** — Auto-populated collections based on tags (e.g., "All Marvel characters")
- [ ] Screenpack Browser UI overhaul (match Character Browser design)
- [ ] Existing installation import
- [ ] Add-ons Browser

---

## Roadmap

### 🧪 Alpha Release ✅
All alpha tasks complete!

### 🎉 v0.5.0 — Current Release
| Feature | Status |
|---------|--------|
| **Light/Dark Theme** | ✅ Done |
| ├─ Full theme support across all views | ✅ Done |
| └─ Theme toggle in Settings | ✅ Done |
| **Custom Tags System** | ✅ Done |
| ├─ Add/edit/delete custom tags | ✅ Done |
| ├─ Recent tags dropdown | ✅ Done |
| ├─ Case-insensitive matching | ✅ Done |
| ├─ Tag search integration | ✅ Done |
| ├─ Grid card tag badges | ✅ Done |
| └─ Bulk tag assignment | ✅ Done |
| **Browser Extension** | ✅ Done |
| ├─ Safari extension bundled | ✅ Done |
| ├─ One-click install from MUGEN Archive | ✅ Done |
| ├─ Metadata scraping | ✅ Done |
| └─ Dashboard CTA for extension | ✅ Done |
| **Unregistered Content Detection** | ✅ Done |
| ├─ Visual badges in browsers | ✅ Done |
| └─ Filter by registration status | ✅ Done |
| **Character Cutoff Indicator** | ✅ Done |
| └─ Shows when roster exceeds screenpack slots | ✅ Done |
| **First-Run Experience** | ✅ Done |
| └─ Import mode choice | ✅ Done |
| **Duplicate Detection** | ✅ Done |
| ├─ Pre-install warning | ✅ Done |
| ├─ Badge display in browser | ✅ Done |
| └─ Metadata-based detection | ✅ Done |
| **Update Checker** | ✅ Done |
| └─ Custom About window | ✅ Done |

### 🧩 v1 — Collections & Curation
| Feature | Status |
|---------|--------|
| **Screenpack Browser Overhaul** | 📋 Todo |
| ├─ Match Character Browser design | 📋 Todo |
| └─ README/setup notes display | 📋 Todo |
| Existing installation import | 📋 Todo |

### ⚡ v2 — Smart Features
| Feature | Status |
|---------|--------|
| **Add-ons Browser** | 📋 Todo |
| ├─ Lifebars | 📋 Todo |
| ├─ Storyboards | 📋 Todo |
| ├─ Scenes/Endings | 📋 Todo |
| ├─ Intro Movies | 📋 Todo |
| ├─ Sound Packs | 📋 Todo |
| └─ Palettes | 📋 Todo |
| **Portrait Display Options** | 📋 Todo |
| └─ Manual override per character | 📋 Todo |
| Animated idle stance preview | 📋 Todo |
| Content validator/fixer | 📋 Todo |
| Pre-install validation | 📋 Todo |
| DEF file editor in character detail | 📋 Todo |
| **Style Detection Engine** | 📋 Todo |
| ├─ POTS/MVC2/KOF/CVS classification | 📋 Todo |
| ├─ HD vs SD detection | 📋 Todo |
| └─ AI patch detection | 📋 Todo |
| Hitbox/frame data viewer | 📋 Todo |
| Similar character suggestions | 📋 Todo |
| **Browser Extension Expansion** | 📋 Todo |
| ├─ Chrome/Edge/Opera (.crx) | 📋 Todo |
| ├─ Firefox (.xpi) | 📋 Todo |
| └─ Update detection (aspirational) | 💭 Future |

### 🏛️ v3 — Polish & Safety
| Feature | Status |
|---------|--------|
| Stage metadata + tagging | 📋 Todo |
| Portrait generator v2 | 📋 Todo |
| Auto-fixer v2 | 📋 Todo |
| **Accessibility** | 📋 Todo |
| ├─ VoiceOver labels | 📋 Todo |
| ├─ Keyboard navigation | 📋 Todo |
| ├─ Focus indicators | 📋 Todo |
| └─ Reduced motion support | 📋 Todo |
| **Performance & Caching** | 📋 Todo |
| ├─ Lazy loading thumbnails | 📋 Todo |
| ├─ Background indexing | 📋 Todo |
| └─ Memory management | 📋 Todo |
| **Backup & Restore** | 📋 Todo |
| ├─ Auto-backup select.def | 📋 Todo |
| ├─ Backup collections | 📋 Todo |
| └─ Restore from backup | 📋 Todo |
| Export/share curated sets | 📋 Todo |
| Netplay IP manager | 📋 Todo |

### 🌐 v4 — Distribution
| Feature | Status |
|---------|--------|
| Custom app icon | 📋 Todo |
| "Get Characters" resource links | 📋 Todo |
| Code signing & notarization | 📋 Todo |
| App Store sandboxing | 📋 Todo |
| Sparkle auto-updater | 📋 Todo |
| Crash reporting | 📋 Todo |
| Help documentation | 📋 Todo |
| Sanitization results UI | 📋 Todo |
| **Localization** | 📋 Todo |
| ├─ String externalization | 📋 Todo |
| ├─ Japanese | 📋 Todo |
| ├─ Spanish | 📋 Todo |
| └─ Portuguese | 📋 Todo |

### 🌌 v5 — Future Ideas
| Feature | Status |
|---------|--------|
| Smart Collections (tag-based auto-population) | 💭 Future |
| Collection export/import | 💭 Future |
| Plugin system | 💭 Future |
| Cloud sync for metadata | 💭 Future |
| Community-shared collections | 💭 Future |
| Advanced AI tagging | 💭 Future |
| Auto-balance rosters | 💭 Future |
| Stage/music pairing suggestions | 💭 Future |
| Play stats dashboard | 💭 Future |
| Screenshot/video capture | 💭 Future |
| Tournament bracket mode | 💭 Future |
| Character tier list editor | 💭 Future |

---

## Technical Debt

### Deferred
- [ ] Extract generic `ContentBrowserView<T>` — Views share UIHelpers but have different item types
- [ ] Migrate to async/await — @Published works well; no clear benefit currently

### Nice-to-Have
- [ ] SwiftUI migration path (see [agent prompt](docs/agent-prompts/swiftui-migration-path.md))
- [ ] Dependency injection (see [agent prompt](docs/agent-prompts/dependency-injection.md))

---

## Architecture

```
IKEMEN Lab.app
├── UI Layer (Swift/AppKit)
│   ├── Dashboard, Browsers, Collections, Settings
│   └── Design System (DesignColors, DesignFonts)
├── Core Services
│   ├── EmulatorBridge — Process management
│   ├── ContentManager — Installation, select.def
│   ├── MetadataStore — SQLite index (GRDB)
│   ├── SFFParser — Sprite extraction
│   ├── DEFParser — Config parsing
│   ├── ImageCache — Thumbnail caching
│   └── CollectionStore — JSON persistence
└── Filesystem (source of truth)
    └── chars/, stages/, data/
```

**Principles:**
1. Filesystem is source of truth — database is a cache
2. Never modify filesystem without explicit user action
3. Backup select.def before any modification

---

## Resources

- [Ikemen GO Releases](https://github.com/ikemen-engine/Ikemen-GO/releases)
- [Ikemen GO Wiki](https://github.com/ikemen-engine/Ikemen-GO/wiki)
- [MUGEN Archive](https://mugenarchive.com/)
