# IKEMEN Lab

A **Mac-native content manager** for [IKEMEN GO](https://github.com/ikemen-engine/Ikemen-GO) — the open-source fighting game engine compatible with MUGEN content.

IKEMEN Lab makes it easy to install, organize, and manage your characters, stages, and screenpacks without touching config files.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

> ⚠️ **Alpha Release** — This project is in early development. Feedback welcome!

---

## ✨ Features

### Content Management
- **Drag-and-drop installation** — Drop ZIP, RAR, 7z, or folders to install characters and stages
- **Visual browser** — Grid and list views with thumbnails extracted from SFF sprite files
- **Search & filter** — Find content by name or author
- **Enable/disable toggle** — Temporarily disable characters or stages without removing them

### Character Tools
- **Details panel** — View author, version, palette count, and more
- **Move list viewer** — Parsed command notation (↓↘→ + LP)
- **Roster arrangement** — Drag to reorder characters in select.def
- **Portrait extraction** — SFF v1 and v2 support

### Stage Browser
- **Preview thumbnails** — Extracted from stage sprite files
- **Size indicators** — See stage width categories (Standard/Wide/Extra Wide)

### Dashboard
- **Quick stats** — Character count, stage count, storage used
- **Drop zone** — Install content right from the dashboard
- **Launch button** — Start IKEMEN GO with one click

---

## 📸 Screenshots

<!-- TODO: Add screenshots -->
*Coming soon*

---

## 📋 Requirements

- **macOS 12.0** (Monterey) or later
- **IKEMEN GO** installed separately — [Download from GitHub](https://github.com/ikemen-engine/Ikemen-GO/releases)

---

## 🚀 Installation

1. Download the latest release from [Releases](../../releases)
2. Unzip and drag **IKEMEN Lab.app** to your Applications folder
3. **First launch:** Right-click → Open → "Open Anyway" (required for unsigned apps)
4. Point to your IKEMEN GO installation when prompted

---

## 🎮 Usage

### Installing Content
1. Download characters/stages from sites like [MUGEN Archive](https://mugenarchive.com)
2. Drag the ZIP/RAR file onto IKEMEN Lab
3. Content is automatically extracted, validated, and added to select.def

### Managing Content
- **Grid/List toggle** — Switch views with the toolbar button
- **Right-click menu** — Reveal in Finder, Enable/Disable, Remove
- **Details panel** — Click a character to see metadata and move list

### Launching the Game
- Click **Launch Game** on the Dashboard or use ⌘L

---

## 🗺️ Roadmap

See [plan.md](plan.md) for the full roadmap.

### Upcoming Features
- 📁 **Collections** — Group characters (e.g., "Marvel", "SNK Bosses")
- 🔍 **Duplicate detection** — Find and manage duplicates
- 🎬 **Animated previews** — See idle stance animations
- 🏷️ **Auto-tagging** — Detect source game, style, resolution
- 🌐 **Browser extension** — One-click install from MUGEN Archive

**Vote on features!** Head to [Discussions](../../discussions) to upvote the features you want most.

---

## 🛠️ Building from Source

```bash
# Clone the repo
git clone https://github.com/yourname/ikemen-lab.git
cd ikemen-lab

# Open in Xcode
open MacMAME.xcodeproj

# Build and run (⌘R)
```

Requires Xcode 15+ and macOS 12.0+.

---

## 🤝 Contributing

This is an early alpha — feedback and contributions are welcome!

- **Bug reports** → [Open an Issue](../../issues)
- **Feature requests** → [Start a Discussion](../../discussions)
- **Pull requests** → Fork, branch, and submit

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- [IKEMEN GO](https://github.com/ikemen-engine/Ikemen-GO) — The engine that makes this all possible
- [MUGEN](https://elecbyte.com/) — The original fighting game engine
- The MUGEN/IKEMEN community for decades of amazing content

---

**IKEMEN Lab is not affiliated with Elecbyte or the IKEMEN GO project.**
