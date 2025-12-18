# MacMAME

A native macOS arcade emulator built on [MAME](https://www.mamedev.org/), designed to feel like a first-class Mac application.

> ⚠️ **Early Development** — This project is in Phase 0 (Research & Constraints). Not yet functional.

## Goals

- **Mac-native UX**: Drag-and-drop library management, native fullscreen, menu bar integration
- **App Store viable**: Sandboxed, hardened, legally compliant
- **Preservation-focused**: Built on MAME for accuracy and compatibility

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| 0 | ✅ Complete | Research & Constraints |
| 1 | ✅ Complete | Minimal macOS Shell |
| 2 | 🔲 Not started | Mac-Native Windowing & Input |
| 3 | 🔲 Not started | Drag-and-Drop Library |
| 4 | 🔲 Not started | Polished UX + Save States |
| 5 | 🔲 Not started | App Store Compliance |
| 6 | 🔲 Not started | Community & Sustainability |

See [plan.md](plan.md) for the full roadmap.

## Architecture

```
┌─────────────────────────────────────┐
│         macOS App Shell             │
│   (AppKit, Swift, Metal rendering)  │
└──────────────┬──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│         MAMECore.framework          │
│   (MAME wrapped as macOS framework) │
└─────────────────────────────────────┘
```

Key decisions:
- **Modular framework approach** (inspired by Delta emulator)
- **Metal-only rendering** (required for App Store)
- **AppKit over SwiftUI** (better for game rendering)

See [docs/architecture.md](docs/architecture.md) for details.

## Documentation

- [plan.md](plan.md) — Project roadmap
- [docs/constraints.md](docs/constraints.md) — Technical & legal constraints
- [docs/legal-notes.md](docs/legal-notes.md) — Licensing and App Store policy
- [docs/macos-native-guidelines.md](docs/macos-native-guidelines.md) — macOS development patterns
- [docs/architecture.md](docs/architecture.md) — Technical architecture

## Requirements

- macOS 12.0+ (Monterey)
- Xcode 15+
- Apple Silicon or Intel Mac

## Building

> 🚧 Build instructions will be added in Phase 1

```bash
# Clone with submodules
git clone --recursive https://github.com/yourname/macmame.git

# Build MAME core (coming soon)
./scripts/build-mame-macos.sh

# Open Xcode project (coming soon)
open MacMAME.xcodeproj
```

## Legal

### Game Files

This application does **not** include any game files. You must provide your own legally-obtained game files.

### MAME License

MAME is licensed under [GPL-2.0](https://github.com/mamedev/mame/blob/master/COPYING). This project complies with GPL-2.0 requirements:
- Full source code is available
- License notices are preserved
- Modifications are documented

### Trademarks

"MAME" is a trademark of the MAME team. This project is not affiliated with or endorsed by the MAME team.

## Contributing

Contributions welcome! Please read the project plan and documentation before submitting PRs.

## License

GPL-2.0 — See [LICENSE](LICENSE) for details.
