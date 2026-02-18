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

### 🐛 Known Bugs (Backlog)
- [ ] **Smart Collections: Tag matching inconsistent** — Some characters with detected tags not matching in smart collection rules
- [ ] **Collections: Character names incorrect** — Showing folder names instead of display names from DEF files
- [ ] **Collections: Stage thumbnails not loading** — Some stages showing placeholder icon
- [ ] **Characters: "UNREGISTERED" badge UX** — Replace with "In Roster" / "Available" section dividers
- [x] **Window header not draggable** — Custom header doesn't behave like standard macOS title bar

### 📋 Up Next (Post-1.0)
- [ ] **Drag & Drop to Collections** — Drag characters from Characters view onto a Collection in sidebar
- [ ] **Bulk Add to Collection** — Multi-select characters, right-click "Add to Collection"
- [ ] Screenpack Browser UI overhaul (match Character Browser design)
- [ ] Existing installation import
- [ ] Add-ons Browser

---

## Roadmap

### 🧪 Alpha Release ✅
All alpha tasks complete!

### 🎉 v0.5.0
| Feature | Status |
|---------|--------|
| **Light/Dark Theme** | ✅ Done |
| **Custom Tags System** | ✅ Done |
| **Browser Extension** | ✅ Done |
| **Unregistered Content Detection** | ✅ Done |
| **Character Cutoff Indicator** | ✅ Done |
| **First-Run Experience** | ✅ Done |
| **Duplicate Detection** | ✅ Done |
| **Update Checker** | ✅ Done |

### 🎉 v1.0.0 — Current Release
| Feature | Status |
|---------|--------|
| **Collections System (Phases 1-4)** | ✅ Done |
| ├─ Collection CRUD with JSON persistence | ✅ Done |
| ├─ Collection editor with character grid, drag-to-reorder | ✅ Done |
| ├─ Picker sheets for characters, stages, screenpacks | ✅ Done |
| ├─ Activate collection → generate select.def + backup | ✅ Done |
| └─ "Add to Collection" context menu | ✅ Done |
| **Smart Collections UI** | ✅ Done |
| ├─ Rule builder with field/comparison/value inputs | ✅ Done |
| ├─ Author field autocomplete from database | ✅ Done |
| ├─ Boolean toggles for Is HD / Has AI fields | ✅ Done |
| └─ Tag input with autocomplete suggestions | ✅ Done |
| **Fullgame Import Mode** | ✅ Done |
| ├─ Auto-create collection from MUGEN/IKEMEN packages | ✅ Done |
| ├─ Per-item duplicate handling with "Apply to remaining" | ✅ Done |
| └─ Tracks fonts/sounds owned by collection | ✅ Done |
| **Screenpack Activation** | ✅ Done |
| └─ Activating collection sets screenpack in config.ini | ✅ Done |
| **Collections UI Polish** | ✅ Done |
| ├─ Dynamic height, hover effects, delete buttons | ✅ Done |
| └─ Sheet presentation/dismissal fixes | ✅ Done |
| **Toast Notifications** | ✅ Done |
| └─ Action button support ("Launch" on activation) | ✅ Done |
| **Code Quality** | ✅ Done |
| ├─ ContentManager split (god object → focused services) | ✅ Done |
| ├─ GameWindowController split (3250 → 2392 lines, 9 files) | ✅ Done |
| ├─ DashboardView split (2833 → 1449 lines, 6 files) | ✅ Done |
| ├─ Error handling refactor (Result types, typed errors) | ✅ Done |
| ├─ IkemenConfigManager (eliminates hardcoded paths) | ✅ Done |
| └─ Dependency injection infrastructure | ✅ Done |

### 🧩 v1.1 — Polish & Fixes
| Feature | Status |
|---------|--------|
| **Screenpack Browser Overhaul** | 📋 Todo |
| ├─ Match Character Browser design | 📋 Todo |
| └─ README/setup notes display | 📋 Todo |
| Existing installation import | 📋 Todo |
| Drag & Drop to Collections | 📋 Todo |
| Bulk Add to Collection | 📋 Todo |
| Smart Collections tag matching fix | 📋 Todo |

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

### Resolved ✅
- [x] Split ContentManager god object into focused services
- [x] Split GameWindowController (3,250 → 2,392 lines, 9 new files)
- [x] Split DashboardView (2,833 → 1,449 lines, 6 new files)
- [x] Error handling refactor (Result types, typed errors)
- [x] IkemenConfigManager (eliminates hardcoded config paths)
- [x] Dependency injection infrastructure

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
