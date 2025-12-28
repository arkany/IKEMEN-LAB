# MacMugen — Native macOS MUGEN Experience

## Goal

Create a **Mac-native launcher and content manager** for Ikemen GO that:

* Provides a proper macOS `.app` experience (not just a bare executable)
* Makes character/stage installation drag-and-drop simple
* Handles content organization and discovery
* Wraps Ikemen GO's netplay with a friendlier UI
* Is viable for **Mac App Store distribution**

**Key insight:** Ikemen GO already exists and runs on macOS. We're not rebuilding the engine - we're building the **Mac-native UX layer** that's missing.

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

### 🔄 In Progress
- [ ] Apply design system to remaining views (Characters, Stages, Settings)

### ⚠️ Known Issues
- [x] ~~Stage preview fails for stages using root-relative sprite paths~~ (fixed: now handles both `spr = stages/Bifrost.sff` and `spr = Bifrost.sff`)
- [ ] Dashboard card navigation incomplete — Fighters/Stages card clicks fire callbacks but `selectNavItem()` not navigating

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
- [ ] Unit tests for SFF parsing
- [ ] SwiftUI migration path for new views
- [ ] Dependency injection (replace singletons)

---

## Roadmap

### 🚀 MVP — "The Core Pipeline"
**Focus:** Automated install + metadata foundation  
**Goal:** Make installing characters effortless, normalize chaos into clean structured data

| Feature | Status | Notes |
|---------|--------|-------|
| Download → unzip → validate → install | ✅ Done | ZIP, RAR, 7z, folders supported |
| Fix common folder issues | ✅ Done | Auto-detect correct path structure |
| Normalize folder names + metadata | ✅ Done | Sanitize names (spaces→underscores, Title_Case, preserve acronyms) |
| Auto-generate portraits (basic) | ✅ Done | Portrait fix tool (160x160) |
| Update select.def | ✅ Done | Auto-add with correct paths |
| Local metadata index (SQLite) | ✅ Done | GRDB.swift for persistent database |
| Basic search (name, author) | 📋 Todo | Filter library by text |
| Drag-and-drop feedback UI | 🔄 In Progress | Show success/failure in drop zone |

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
| **Recently Installed Table** | 📋 Todo | Name, Type (Char/Stage badge), Date, Status toggle |
| **Quick Settings Panel** | ✅ Done | Fullscreen, V-Sync toggles |
| **Volume Sliders** | ✅ Done | BGM Volume, SFX Volume sliders |
| **Screenpack Promo Card** | 📋 Todo | "New Screenpack available" with Install button |

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
| Collections system | 📋 Todo | Named groups of characters (e.g., "Marvel", "SNK Bosses") |
| Random roster generation | 📋 Todo | Generate random select.def from pools |
| Auto-tagging (basic rules) | 📋 Todo | Infer source game, style from filenames/metadata |
| Detect duplicates + outdated versions | 📋 Todo | Hash-based or name-based duplicate detection |
| Detect screenpack character limit | 📋 Todo | Parse `rows` × `columns` from system.def |

**Why this phase matters:** This is where your tool stops being an installer and becomes a curation engine.

---

### ⚡ v2 — "The Smart Layer"
**Focus:** Style detection + advanced previews + browser extension  
**Goal:** Add intelligence, reduce friction, make browsing MUGEN Archive feel modern

| Feature | Status | Notes |
|---------|--------|-------|
| Animated idle stance preview | 📋 Todo | Parse .air Action 0, animate sprites with timing |
| Content validator/fixer | 📋 Todo | Path issues, missing files, encoding, auto-fix on import |
| Style Detection Engine | 📋 Todo | POTS / MVC2 / KOF / CVS / Anime / Chibi classification |
| HD vs SD detection | 📋 Todo | Resolution-based sprite analysis |
| AI patch detection | 📋 Todo | Identify AI-enhanced characters |
| Hitbox/frame data viewer | 📋 Todo | Parse .cns/.air for frame data when available |
| Similar character suggestions | 📋 Todo | "If you like X, try Y" based on style/source |
| Browser extension | 📋 Todo | "Install to MacMugen" button on MUGEN Archive |
| Scrape metadata from web | 📋 Todo | Pull author, version, tags from download pages |

**Why this phase matters:** This is where the system becomes smart and frictionless — your signature.

---

### 🏛️ v3 — "The Ecosystem"
**Focus:** Full UX polish + stage integration + sharing  
**Goal:** Make the tool feel like a full platform, support stages as first-class citizens

| Feature | Status | Notes |
|---------|--------|-------|
| Stage installer pipeline | ✅ Done | Drag-and-drop for stages |
| Stage metadata + tagging | 📋 Todo | Source game, style, resolution tags |
| Stage collections | 📋 Todo | Named groups of stages |
| Stage roster pools | 📋 Todo | Random stage selection per match |
| Portrait generator v2 | 📋 Todo | Better cropping, style presets, batch processing |
| Auto-fixer v2 | 📋 Todo | CNS patching, missing sprites, AI tweaks |
| Right-click context menus | ✅ Done | Reveal in Finder, Remove (characters + stages) |
| Light/dark mode support | 📋 Todo | Respect system appearance |
| Export/share curated sets | 📋 Todo | Export collection as shareable package |
| Netplay IP manager | 📋 Todo | Save/edit friend IPs in config.ini |

**Why this phase matters:** This is where your tool becomes the definitive MUGEN/IKEMEN manager.

---

### 🌐 v4 — "Distribution & Polish"
**Focus:** App Store readiness + professional polish  
**Goal:** Ship a product users can download and trust

| Feature | Status | Notes |
|---------|--------|-------|
| Bundle Ikemen GO inside .app | 📋 Todo | Self-contained distribution |
| Custom app icon | 📋 Todo | Professional branding |
| First-run wizard | 📋 Todo | Guide new users through setup |
| "Get Characters" resource links | 📋 Todo | Curated links to community sites |
| Code signing & notarization | 📋 Todo | Gatekeeper-friendly distribution |
| App Store sandboxing | 📋 Todo | Comply with App Store requirements |
| Sparkle auto-updater | 📋 Todo | For direct distribution channel |
| Crash reporting | 📋 Todo | Track and fix issues |
| Help documentation | 📋 Todo | User guide and FAQ |
| Sanitization results UI | 📋 Todo | Collapsed list showing renamed folders after install |

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

| Component | Ikemen GO (exists) | MacMugen (we build) |
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
| Menu bar integration | ❌ | ✅ |
| App Store ready | ❌ | ✅ |
| Collections/curation | ❌ | ✅ |
| Style detection | ❌ | ✅ |
| Browser extension | ❌ | ✅ |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│              MacMugen.app                   │
│  ┌───────────────────────────────────────┐  │
│  │     Swift/AppKit UI Layer             │  │
│  │  • Content Browser                    │  │
│  │  • Preferences                        │  │
│  │  • Collections Manager                │  │
│  │  • Netplay Lobby                      │  │
│  └───────────────────────────────────────┘  │
│                    │                        │
│                    ▼                        │
│  ┌───────────────────────────────────────┐  │
│  │     Core Services                     │  │
│  │  • IkemenBridge (process mgmt)        │  │
│  │  • ContentManager (install/organize)  │  │
│  │  • MetadataStore (SQLite index)       │  │
│  │  • StyleDetector (classification)     │  │
│  └───────────────────────────────────────┘  │
│                    │                        │
│                    ▼                        │
│  ┌───────────────────────────────────────┐  │
│  │  Ikemen_GO (bundled binary)           │  │
│  │  • Runs in own OpenGL window          │  │
│  │  • Reads chars/, stages/, data/       │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

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
│   │   ├── IkemenBridge.swift          # Launch/manage Ikemen
│   │   ├── ContentManager.swift        # Chars/stages management
│   │   ├── ConfigManager.swift         # Read/write Ikemen configs
│   │   ├── SelectDefParser.swift       # Parse/edit select.def
│   │   ├── SFFParser.swift             # SFF v1/v2 sprite extraction
│   │   ├── DEFParser.swift             # Generic .def file parsing
│   │   ├── ImageCache.swift            # NSCache for thumbnails
│   │   ├── MetadataStore.swift         # SQLite database (planned)
│   │   └── StyleDetector.swift         # Style classification (planned)
│   ├── Views/
│   │   ├── ContentBrowserView.swift
│   │   ├── CharacterGridView.swift
│   │   ├── StageListView.swift
│   │   ├── CollectionsView.swift       # (planned)
│   │   └── NetplayView.swift
│   ├── Models/
│   │   ├── CharacterInfo.swift
│   │   ├── StageInfo.swift
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
| **v1** | Can create collections, generate random rosters, detect duplicates |
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
