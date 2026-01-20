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

### 🔄 In Progress
- [ ] Screenpack Browser UI overhaul (match Character Browser design)

### 📋 Up Next
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
