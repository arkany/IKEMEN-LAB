# IKEMEN Lab

A **Mac-native Content Management System (CMS)** for the MUGEN community.

IKEMEN Lab transforms how you interact with [IKEMEN GO](https://github.com/ikemen-engine/Ikemen-GO), the open-source fighting game engine. Instead of manually editing text files like `select.def`, IKEMEN Lab provides a visual, searchable database for your characters, stages, and screenpacks.

Use it to build, organize, and curate your fighting game roster with the ease of a modern photo or music library.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

> ⚠️ **Alpha Release** — This project is in early development. Feedback welcome!

---

## ✨ Features

### Library Organization
- **Visual Database** — Browse your collection with rich thumbnails extracted directly from sprite files (SFF)
- **Collections System** — Create curations like "Marvel vs. Capcom 2" or "Street Fighter III" and switch between them instantly
- **Smart Filtering** — Instantly find content by name, author, or status
- **Toggle Content** — Enable or disable characters/stages without deleting files

### Content Ingestion
- **Drag-and-Drop Import** — Install characters (ZIP/RAR/7z) and stages by dragging them onto the app
- **Duplicate Detection** — Automatically identifies duplicate content and prompts for resolution
- **Auto-Sanitization** — Cleans filenames to ensure compatibility with the engine
- **Format Support** — Handles standard MUGEN/IKEMEN folder structures automatically

### Asset Management
- **Metadata Inspector** — View detailed stats: author, version date, palette count, and local file paths
- **Move List Viewer** — Native parsing of `.cmd` files to display move lists (↓↘→ + LP)
- **Select Screen Editor** — Drag and drop to rearrange your roster order visually
- **Stage Size Indicators** — Automatically detects Standard, Wide, or Extra Wide stages

### Dashboard
- **Asset Overview** — Track library growth with beautiful statistics graphs
- **Storage Monitoring** — Keep an eye on VRAM keys and disk usage
- **One-Click Launch** — Boot IKEMEN GO directly from the CMS with your active configuration

---

## 📸 Screenshots

<!-- TODO: Add screenshots -->
<img width="1528" height="944" alt="image" src="https://github.com/user-attachments/assets/512e8ef8-7843-44ca-aca9-62332db89dbd" />
<img width="1528" height="944" alt="image" src="https://github.com/user-attachments/assets/4c542d66-870e-4b1a-92f1-b889510d33f8" />
<img width="1528" height="944" alt="image" src="https://github.com/user-attachments/assets/701c5609-da2d-435d-ab43-f6358ce24c24" />


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

### Importing Assets
1. Download characters/stages from communities like [MUGEN Archive](https://mugenarchive.com)
2. Drag the ZIP/RAR file directly onto IKEMEN Lab
3. The CMS extracts, validates, and indexes the content into your library

### Curating your Roster
- **Grid/List View** — Toggle between visual grid or detailed list layouts
- **Context Actions** — Right-click any asset to Reveal in Finder, Toggle Status, or Uninstall
- **Collections** — Use the sidebar to create new game profiles (rosters)

### Launching
- Click **Launch Game** on the Dashboard or use ⌘L to start the engine with your currently active collection.

---

## 🗺️ Roadmap
You can help us decide! Add your request in Issues or Discussions.

### Upcoming Features
- 🎬 **Animated Previews** — View idle animations directly in the browser
- 🏷️ **Auto-tagging** — Detect source game (e.g. "CvS2", "MvC") and fighting style
- 🌐 **Web Import** — Browser extension for one-click installation
- 📡 **Remote Management** — Manage headless IKEMEN instances

**Vote on features!** Head to [Discussions](../../discussions) to upvote the features you want most.

---

## 🛠️ Building from Source

```bash
# Clone the repo
git clone https://github.com/yourname/ikemen-lab.git
cd ikemen-lab

# Open in Xcode
open "IKEMEN Lab.xcodeproj"

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
