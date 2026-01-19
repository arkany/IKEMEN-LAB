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
- [ ] Unregistered content visualization (see [agent prompt](docs/agent-prompts/unregistered-content-visualization.md))

### 📋 Up Next
- [ ] Smart Collections (tag-based auto-population)
- [ ] Collection export/import (`.ikemencollection` format)
- [ ] Screenpack Browser UI overhaul (match Character Browser design)

---

## Roadmap

### 🧪 Alpha Release ✅
All alpha tasks complete! Currently at **v0.2.0** on GitHub Releases.

### 🧩 v1 — Collections & Curation
| Feature | Status |
|---------|--------|
| **Collections System** | 🔄 In Progress |
| ├─ Phase 5: Smart Collections | 📋 Todo |
| └─ Phase 6: Export/Import | 📋 Todo |
| **Screenpack Browser Overhaul** | 📋 Todo |
| ├─ Match Character Browser design | 📋 Todo |
| └─ README/setup notes display | 📋 Todo |
| **First-Run Experience** | ✅ Done |
| └─ Import mode choice | ✅ Done |
| **Tagging UI** | ✅ Done |
| ├─ Detail panel tags section | ✅ Done |
| ├─ Grid card tag badges | ✅ Done |
| ├─ Tag search integration | ✅ Done |
| ├─ Custom tag creation | ✅ Done |
| ├─ Tag editing/deletion | ✅ Done |
| └─ Bulk tag assignment | ✅ Done |
| **Duplicate Detection** | ✅ Done |
| ├─ Pre-install warning | ✅ Done |
| └─ Badge display in browser | ✅ Done |
| Character cutoff indicator | 📋 Todo |
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
| **Browser Extension** | ✅ Done |
| ├─ "Install to IKEMEN Lab" button | ✅ Done |
| ├─ Scrape metadata from web | ✅ Done |
| ├─ Dashboard CTA for extension | 📋 Todo |
| ├─ Multi-browser packaging | 📋 Todo |
| │  ├─ Safari (Xcode target) | ✅ Done |
| │  ├─ Chrome/Edge/Opera (.crx) | 📋 Todo |
| │  └─ Firefox (.xpi) | 📋 Todo |
| └─ Update detection (aspirational) | 💭 Future |
| Random roster generation | 📋 Todo |

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
| Light/dark mode support | 📋 Todo |
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
