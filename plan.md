# Native macOS MAME App — Phased Project Plan

## Goal

Create a **native macOS arcade emulator experience** built on MAME that:

* Feels *Mac-first*, not a port
* Uses drag-and-drop for ROM/library management
* Is legally and technically viable for **Mac App Store distribution**
* Can be developed incrementally without boiling the ocean

---

## Guiding Principles

* **Preservation first**: stay aligned with upstream MAME goals and licensing
* **Mac-native UX**: AppKit/SwiftUI conventions over cross-platform lowest-common-denominator UI
* **Incremental wins**: each phase should produce something runnable
* **Legal by design**: no bundled ROMs, clear user ownership boundaries

---

## Phase 0 — Research & Constraints (Short but Critical)

**Outcome:** Clear architectural and legal guardrails before writing real code.

### Research Tasks (Completed)

* Reviewed:
  * MAME license structure (GPL-2.0 + BSD-3-Clause files)
  * Apple App Store emulator precedents (Delta, PPSSPP, OpenEmu patterns)
  * Sandbox + entitlement constraints on macOS
  * Metal vs OpenGL on macOS (Metal required for App Store; OpenGL deprecated)
  * BIOS/firmware management UI patterns in existing emulators
  * Save state storage in sandboxed environments
  * Benchmarking & latency profiling approaches

### Architectural Decisions

**Core Wrapper Strategy: Modular Framework Approach (Delta-inspired)**

* Create `MAMECore.framework` wrapping MAME's C core
* Establish middleware interface abstracting CPU/GPU backends (similar to DeltaCore)
* Fork MAME's build system to generate macOS framework target
* Embed framework in app (no subprocess spawning—lower latency, simpler sandboxing)
* Benefits: Reusable, testable, isolation from app lifecycle, future-proof for alternative backends

**Graphics Rendering: Metal-Only (App Store Mandatory)**

* Metal is required; OpenGL deprecated/removed from App Store apps
* Use MAME's existing BGFX backend to abstract Metal shaders
* Document Metal rendering bridge for arcade effects (scanlines, blur, CRT simulation)
* Achieves <16ms frame latency at 60Hz on Apple Silicon

**BIOS/Firmware Management: Preferences-Driven with URL Search**

* Create Preferences → "Firmware & BIOS" panel with file selection dialog
* Allow users to add custom URLs; app searches and manages downloads within sandbox
* Error messaging: show missing ROM set with SHA1, link to mamedev.org documentation
* No direct download links (avoids piracy liability; users source responsibly)

**Save State Storage: Sandboxed with Optional iCloud Sync (Phase 5)**

* Store in `~/Library/Application Support/[BundleID]/SaveStates/[GameName]/`
* Per-game state organization: `slot-1.state`, `slot-2.state`, etc.
* Manual export via NSSavePanel (App Store safe)
* Plan optional iCloud sync via `NSUbiquitousKeyValueStore` (metadata only) for Phase 5
* State metadata: timestamp, screenshot preview, emulator version

**UI Framework: AppKit (Recommended over SwiftUI)**

* Better macOS conventions for fullscreen handling (critical for emulation)
* Mature gamepad/input APIs via IOKit bridge
* More predictable performance for resource-intensive rendering
* Established patterns for menu bar integration

**Benchmarking & Latency Profiling: Built-In for Phase 2**

* Use MAME's native benchmark mode (`mame -b`) for regression testing in CI
* Use macOS CVDisplayLink for frame-to-frame timing measurement
* Target: <16ms input-to-display latency at 60Hz (1 frame overhead)
* Developer overlay (hidden by default) showing frame count & latency metrics
* Expose profiling data via Lua interface for custom performance validation

### Terminology

* Avoid "ROMs" in UI → use "Game Files" or "Cartridges"
* Refer to emulation cores as "Emulators" or "Systems" (Arcade, NES, SNES, etc.)

**Deliverables**

* `docs/constraints.md` — Technical & legal constraints summary
* `docs/legal-notes.md` — MAME licensing deep-dive, App Store policy review, BIOS liability scoping
* `docs/macos-native-guidelines.md` — AppKit patterns, Metal rendering best practices, sandbox entitlements, accessibility baseline
* `docs/architecture.md` — Framework wrapper design, Metal bridge specification, middleware interface contract

---

## Phase 1 — Minimal macOS Shell (Proof of Life)

**Outcome:** A native macOS app that launches and runs MAME in some form.

### Scope

* Create a macOS app project in Xcode
* No custom UI polish yet
* Focus on:

  * Launching MAME
  * Displaying video output
  * Handling basic input

### Tasks

* Clone upstream MAME
* Build MAME for macOS (CLI or library)
* Wrap it with:

  * App lifecycle
  * Window creation
  * Fullscreen handling
* Hardcode a single test game path (local dev only)

**Deliverables**

* Runnable `.app`
* `README.md` with build steps
* `scripts/build-mame-macos.sh`

---

## Phase 2 — Mac-Native Windowing & Input

**Outcome:** It *feels* like a Mac app, even if it's ugly.

### Improvements

* Proper macOS fullscreen behavior
* Retina scaling handled correctly
* Gamepad + keyboard mapping via macOS APIs
* Menu bar integration:

  * Quit
  * Pause
  * Reset
  * Toggle fullscreen

### Benchmarking & Latency

* Integrate CVDisplayLink-based frame timing measurement
* Developer overlay for frame count & latency metrics (hidden by default)
* Target: <16ms input-to-display latency at 60Hz

### Key Decision

* Decide how much MAME UI is exposed vs hidden

  * Prefer hiding internal MAME menus where possible

**Deliverables**

* Stable fullscreen gameplay
* Documented input mapping layer
* Latency profiling infrastructure

---

## Phase 3 — Drag-and-Drop Library MVP

**Outcome:** The "aha" moment for users.

### UX Concept

* User drags a game file onto:

  * App icon **or**
  * Main window
* App:

  * Copies file into sandboxed storage
  * Indexes it
  * Displays it in a simple library list/grid

### Implementation Notes

* Use macOS drag-and-drop APIs
* Maintain:

  * App-managed storage
  * Metadata cache (SQLite or JSON initially)
* No auto-download or scraping in v1

**Deliverables**

* Drag-and-drop support
* Basic Library UI
* Persistent game list between launches

---

## Phase 4 — Polished Mac UX + Save State Management (Still No Scope Creep)

**Outcome:** Something you'd proudly demo.

### Enhancements

* Game artwork placeholders
* "Recently Played" tracking
* **Save State Management**:
  * Per-game save slots (1–5, auto-indexed)
  * Save/load UI accessible in-game (keyboard shortcuts + menu bar)
  * State metadata display (timestamp, screenshot preview)
  * Auto-backup of previous state before overwrite
  * Clear state version/compatibility warnings (e.g., "saved on v0.250, current v0.251")
* **Firmware/BIOS Management Panel**:
  * Preferences → "Firmware & BIOS" with file browser
  * Add/remove firmware files via NSSavePanel
  * Display required vs optional system files with clear status indicators
  * Error states with SHA1 hash mismatches
* Per-game settings:
  * Controls (button remapping, dead zones, force feedback options)
  * Video options (scaling, effects, aspect ratio)
* Clear error states (missing ROM set, unsupported files, incompatible BIOS versions)

### UX Tone

* Friendly
* Non-technical
* Never references piracy
* Helpful & guiding (e.g., "Game Files hold your ROM collection; manage it like any other app data")

**Deliverables**

* Refined UI with save state UI and management panels
* Firmware/BIOS management panel
* State metadata architecture (JSON schema for state manifest)
* UX copy pass (all user-facing text reviewed for tone)
* Screenshots suitable for App Store submission

---

## Phase 5 — App Store Compliance, Cloud Sync & Packaging

**Outcome:** Ready to submit (even if you don't yet).

### Legal & Policy Checklist

* ✓ No bundled ROMs
* ✓ No direct download links to ROM sites (users add own sources)
* ✓ Explicit user responsibility language (onboarding, help docs)
* ✓ App sandbox enabled (all file access via sandboxed storage or file dialogs)
* ✓ Hardened runtime (entitlements minimized, no code injection)
* ✓ Notarization (build via automated notarization pipeline)
* ✓ Entitlements audit (only request: file I/O, gamepad, audio, graphics)

### Cloud & Sync Features

* **Optional iCloud Sync for Save State Metadata** (via `NSUbiquitousKeyValueStore`)
  * Syncs only state manifest (timestamps, screenshot previews), not large state files
  * Version history tracking (restore save from previous day/week)
  * Conflict resolution: device timestamp + hash comparison
  * User opt-in only (checkbox in Preferences → "Cloud Sync")
* **Manual Export of Save States** (user-initiated, not automatic)
  * NSSavePanel for explicit user control over export destination
  * Export format: ZIP with state files + metadata JSON
  * App Store safe: zero surprise uploads

### Store Strategy: Unified Codebase, Build-Time Variants

**App Store Build** (Entitlements: Sandbox + iCloud Container)

* Strict sandbox enforcement
* All ROMs/firmware via drag-and-drop or file dialogs
* iCloud metadata sync enabled
* Safer, friction-free distribution

**Direct Download Build** (Entitlements: Sandbox + File Access)

* Same codebase, different entitlements
* Users can optionally enable broader file access
* Local filesystem browsing (if not on App Store)
* Same metadata sync (optional iCloud)

**Deliverables**

* App Store–ready build with iCloud metadata sync
* Direct download build variant (entitlements file)
* `App Store Review Notes.md` (addressing potential reviewer concerns: no piracy facilitation, legality reasoning, open-source approach)
* Clear "How to Add Your Games" onboarding screen
* Privacy Policy & Terms of Use templates (for App Store submission)

---

## Phase 6 — Community & Sustainability (Optional but Smart)

**Outcome:** Project doesn't die after v1.

* Stay close to upstream MAME
* Document contribution guidelines
* Decide:

  * Fully open source fork
  * Or thin Mac shell + upstream core
* Optional:

  * Telemetry (opt-in)
  * Crash reporting

---

## What This Is *Not* (Intentionally)

* ❌ A ROM marketplace
* ❌ A PvP/netplay platform (initially)
* ❌ A reskinned Windows port
* ❌ A one-shot rewrite of MAME

---

## Why This Project Is Worth Doing

* MAME has never had a **great Mac-native experience**
* Apple Silicon Macs are perfect for emulation
* Apple's emulator policy has materially shifted
* Drag-and-drop + Mac UX is an unsolved niche here

---

## Next Concrete Step (Do This First)

1. Create repo ✓
2. Add this file as `plan.md` ✓
3. Start Phase 0 docs
4. Get *anything* running on macOS, no matter how ugly

Momentum beats perfection.
