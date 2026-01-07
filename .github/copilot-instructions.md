# IKEMEN Lab — Copilot Instructions

## Project Overview

IKEMEN Lab is a **macOS-native content manager** for IKEMEN GO (a MUGEN-compatible fighting game engine). It's built with Swift/AppKit, not SwiftUI.

## Key Architecture

- **UI Layer**: AppKit with NSViewController, NSCollectionView, NSTableView
- **Data Layer**: GRDB.swift (SQLite) for metadata, JSON for Collections
- **Core Services**: EmulatorBridge, ContentManager, MetadataStore, SFFParser, DEFParser
- **Design System**: Dark theme with zinc palette, Montserrat/Manrope/Inter fonts (see UIHelpers.swift)

## File Locations

| Purpose | Location |
|---------|----------|
| Models | `IKEMEN Lab/Models/` |
| Core services | `IKEMEN Lab/Core/` |
| Views | `IKEMEN Lab/UI/` |
| Shared utilities | `IKEMEN Lab/Shared/UIHelpers.swift` |
| Design colors/fonts | `DesignColors`, `DesignFonts` in UIHelpers.swift |

## Coding Conventions

1. **Use existing patterns** — Look at CharacterBrowserView.swift for UI patterns, CharacterInfo.swift for models
2. **AppKit, not SwiftUI** — All views use NSView, NSViewController
3. **Singletons for services** — EmulatorBridge.shared, ImageCache.shared, MetadataStore.shared
4. **Design tokens** — Use `DesignColors.zinc950`, `DesignFonts.bodyMedium`, etc.
5. **Error handling** — Use `Result<T, Error>` or throwing functions

## Implementation Specs

Detailed specs for major features are in `/docs/`:

- `docs/collections-spec.md` — Collections system (game profiles → select.def)
- `docs/architecture.md` — Overall architecture
- `docs/constraints.md` — Technical constraints

## IKEMEN GO Context

- **select.def** — Defines which characters/stages appear in game (we generate this)
- **chars/** — Character folders with .def, .sff, .snd, .cmd, .cns files
- **stages/** — Stage folders with .def, .sff files
- **SFF** — Sprite file format (v1 and v2), parsed by SFFParser.swift
- **DEF** — Definition files (INI-like), parsed by DEFParser.swift

## Safety Rules

1. **Never auto-delete user content** — Always require confirmation
2. **Backup select.def** — Before any modification, create timestamped backup
3. **Filesystem is source of truth** — Database is just a cache
4. **Preserve existing setups** — "First, do no harm" philosophy
