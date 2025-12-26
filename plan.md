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

### 🔄 In Progress
- [ ] Drag-and-drop feedback UI - show success/failure message inside the drop zone area (needs design)

### 📋 Planned
- [x] Screenpack management (browse, activate, install, component detection)
- [x] Character roster arrangement (drag-to-reorder in select.def)
- [x] Character details panel (author, version, palette count, editable name)
- [x] Character move list viewer (parse .cmd file for commands like `~D, DF, F, x` → "↓↘→ + LP")
- [ ] Animated idle stance in character details (parse .air Action 0, extract sprites from .sff, animate with timing)
- [ ] Light/dark mode support
- [ ] Detect screenpack character limit (parse `rows` × `columns` from system.def, e.g., MMMBE = 14×39 = 546 slots)
- [ ] Content validator/fixer for imported chars & stages:
  - Path issues: root-relative vs file-relative, Windows backslashes, case sensitivity
  - Missing files: sprite/sound references that don't exist
  - Portrait problems: wrong size, missing 9000,0 sprite
  - Encoding issues: Shift-JIS, Latin-1, BOM markers
  - Auto-fix safe issues on import, report others
- [ ] Netplay IP manager (save/edit friend IPs in config.ini `[Netplay]` section - game handles actual connection)
- [ ] Bundle Ikemen GO inside the .app for distribution
- [ ] App Store preparation (sandbox, signing)

### 🐛 Known Issues
- [x] ~~Stage preview fails for stages using root-relative sprite paths~~ (fixed: now handles both `spr = stages/Bifrost.sff` and `spr = Bifrost.sff`)

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

---

## Architecture

```
┌─────────────────────────────────────────────┐
│              MacMugen.app                   │
│  ┌───────────────────────────────────────┐  │
│  │     Swift/AppKit UI Layer             │  │
│  │  • Content Browser                    │  │
│  │  • Preferences                        │  │
│  │  • Netplay Lobby                      │  │
│  └───────────────────────────────────────┘  │
│                    │                        │
│                    ▼                        │
│  ┌───────────────────────────────────────┐  │
│  │     IkemenBridge.swift                │  │
│  │  • Launch/manage Ikemen process       │  │
│  │  • Pass configuration                 │  │
│  │  • Monitor status                     │  │
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

## Phase 0 — Setup & Research ✅ (Mostly Complete)

### Completed
- [x] Xcode project structure  
- [x] Basic AppKit shell (window, menu bar)
- [x] Metal rendering foundation (may not need for wrapper approach)

### Remaining  
- [ ] Download and test Ikemen GO macOS build
- [ ] Understand Ikemen GO's config files (mugen.cfg, select.def)
- [ ] Document command-line arguments if any
- [ ] Determine best way to bundle and launch

---

## Phase 1 — Minimal Wrapper (Proof of Life)

**Outcome:** MacMugen.app launches Ikemen GO and it just works.

### Tasks
- [ ] Download Ikemen GO macOS release
- [ ] Bundle Ikemen_GO binary inside MacMugen.app
- [ ] Create `IkemenBridge.swift` to launch subprocess
- [ ] Handle process lifecycle (launch, quit, crash)
- [ ] Set working directory to content folder
- [ ] Basic "Launch Game" button in UI

### Deliverables
- MacMugen.app that launches Ikemen GO
- User can play if they manually add characters

---

## Phase 2 — Content Management

**Outcome:** Easy drag-and-drop character/stage installation.

### Features
- [ ] Content directory setup (~/Library/Application Support/MacMugen/)
- [ ] Drag-and-drop `.zip` installation for characters
- [ ] Drag-and-drop `.zip` installation for stages  
- [ ] Character browser with thumbnails (parse .sff for portrait)
- [ ] Stage browser with previews
- [ ] Automatic `select.def` generation/editing
- [ ] Enable/disable characters without deleting
- [ ] Delete characters with confirmation

### Content Structure
```
~/Library/Application Support/MacMugen/
├── chars/           # Character folders
├── stages/          # Stage folders  
├── data/            # Ikemen config (we manage select.def)
├── font/            # Fonts
└── sound/           # Sound effects
```

### Deliverables
- Content browser window
- Functional drag-and-drop installation
- Characters appear in game after install

---

## Phase 3 — Preferences & Configuration  

**Outcome:** Native macOS preferences for game settings.

### Features
- [ ] Video settings (resolution, fullscreen, vsync)
- [ ] Audio settings (volume levels)
- [ ] Input/controller configuration
- [ ] Content paths configuration
- [ ] Write settings to Ikemen's config files
- [ ] Keyboard shortcut customization

### Deliverables
- Preferences window (⌘,)
- Settings persist and apply to Ikemen GO

---

## Phase 4 — Netplay UI

**Outcome:** Friendly interface for managing netplay connection info.

### Features
- [ ] Manage saved IP addresses in config.ini `[Netplay]` section
- [ ] Add/edit/delete friend IPs with nicknames (`IP.FriendName = 192.168.1.100`)
- [ ] Configure listen port (default: 7500)
- [ ] Toggle rollback vs delay netcode (`RollbackNetcode = 0/1`)
- [ ] Display local IP for sharing with friends

### Notes
- Ikemen GO handles actual connections through its in-game Network menu
- We just pre-configure the IP list so friends appear in the connection menu
- Config location: `save/config.ini` under `[Netplay]`
- Rollback netcode uses GGPO (experimental but better for online play)

### Deliverables
- Netplay settings panel in MacMugen preferences
- Saved IPs appear in Ikemen GO's connection menu

---

## Phase 5 — Polish & Distribution

**Outcome:** Ready for users (and potentially App Store).

### Features
- [ ] Custom app icon
- [ ] First-run experience / setup wizard
- [ ] "Get Characters" links to community resources
- [ ] Sparkle auto-updater (for direct distribution)
- [ ] Proper code signing and notarization
- [ ] Sandboxing (if targeting App Store)
- [ ] Crash reporting
- [ ] Help documentation

### Distribution Options
1. **Direct download** (DMG) — Easier, full flexibility
2. **App Store** — Wider reach, sandboxing constraints

### Deliverables
- Signed, notarized MacMugen.app
- Website/landing page
- User documentation

---

## Phase 6 — Nice-to-Haves (Future)

- [ ] Character favorites and ratings
- [ ] Play stats dashboard (parse `save/stats.json`):
  - Top winning characters (from `clearcount`)
  - Arcade mode rankings & high scores
  - Total playtime per mode
  - Win/loss records
- [ ] Screenshot capture
- [ ] Video recording
- [ ] Twitch/streaming integration
- [ ] Tournament bracket mode
- [ ] Character tier list editor
- [ ] Hitbox visualization toggle

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
│   │   └── SelectDefParser.swift       # Parse/edit select.def
│   ├── Views/
│   │   ├── ContentBrowserView.swift
│   │   ├── CharacterGridView.swift
│   │   ├── StageListView.swift
│   │   └── NetplayView.swift
│   ├── Models/
│   │   ├── Character.swift
│   │   ├── Stage.swift
│   │   └── GameConfig.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── MainMenu.xib
├── Ikemen/                              # Bundled Ikemen GO
│   └── (Ikemen_GO binary + base files)
└── docs/
    └── user-guide.md
```

---

## Success Metrics

1. **Phase 1**: App launches Ikemen GO successfully
2. **Phase 2**: Can install a character via drag-and-drop, appears in game
3. **Phase 3**: Can change resolution in preferences, applies to game
4. **Phase 4**: Can host/join netplay match through UI
5. **Phase 5**: Non-technical user can download, install, and play

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
