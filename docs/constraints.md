# Technical & Legal Constraints

This document captures the guardrails for developing a native macOS MAME application suitable for Mac App Store distribution.

---

## Technical Constraints

### Graphics API

| Constraint | Detail |
|------------|--------|
| **Metal required** | OpenGL is deprecated on macOS (since 10.14) and prohibited in App Store apps |
| **BGFX abstraction** | Use MAME's existing BGFX backend with Metal renderer |
| **Retina support** | Must handle 2x/3x scaling via `NSWindow` backing scale factor |
| **Frame latency target** | <16ms input-to-display at 60Hz (1 frame overhead max) |

### Sandbox & Entitlements

| Entitlement | Required | Purpose |
|-------------|----------|---------|
| `com.apple.security.app-sandbox` | ✓ | App Store mandatory |
| `com.apple.security.files.user-selected.read-write` | ✓ | User file access via dialogs |
| `com.apple.security.files.bookmarks.app-scope` | ✓ | Remember file access across launches |
| `com.apple.developer.icloud-container-identifiers` | Optional | iCloud metadata sync |
| `com.apple.security.device.audio-input` | ✗ | Not needed |
| `com.apple.security.network.client` | Optional | For user-configured URL downloads |

### File System Access

- **Sandboxed storage**: `~/Library/Application Support/[BundleID]/`
- **User files**: Only via `NSOpenPanel` / `NSSavePanel` (security-scoped bookmarks)
- **No arbitrary filesystem scanning**: Cannot enumerate `/Users/*/Downloads/` etc.
- **Drag-and-drop**: Grants temporary access; must copy to sandboxed storage for persistence

### Input Handling

- **Game Controller framework**: Primary API for gamepad support (MFi, DualShock, Xbox)
- **IOKit**: Low-level fallback for non-standard controllers
- **Keyboard**: Standard `NSEvent` key handling
- **No raw HID without justification**: App Review may reject

### Architecture

- **Universal Binary**: Must support both Apple Silicon (arm64) and Intel (x86_64)
- **Minimum deployment**: macOS 12.0 (Monterey) recommended for Metal 3 baseline
- **No JIT compilation**: App Store prohibits `mmap` with `PROT_EXEC` for writable memory
- **No dynamic code loading**: Cannot `dlopen` unsigned code

---

## Legal Constraints

### MAME Licensing

| Component | License | Implication |
|-----------|---------|-------------|
| MAME core | GPL-2.0 | Derivative works must be GPL-2.0; source must be available |
| Some drivers | BSD-3-Clause | More permissive; check individual files |
| Artwork/samples | Various | Do NOT bundle; user-supplied only |

**Key requirement**: If distributing a binary that links MAME, source code must be made available under GPL-2.0.

### App Store Policy (Post-April 2024)

Apple's updated guidelines now permit emulators:

> "Apps may offer software that... runs a virtualized operating system and emulator software"

**Conditions**:
- No bundled ROMs or copyrighted game content
- No links to ROM download sites
- Clear that users provide their own legally-obtained game files
- App must not facilitate piracy

### BIOS/Firmware Liability

- **Never bundle** system BIOS files (e.g., NeoGeo BIOS, CPS3 firmware)
- **Never link** to BIOS download sites
- **Acceptable**: Link to official documentation (mamedev.org) explaining what's needed
- **Acceptable**: Show SHA1 hashes so users can verify they have correct files

### Terminology (UI Copy)

| Avoid | Use Instead |
|-------|-------------|
| ROMs | Game Files, Cartridges |
| BIOS | System Files, Firmware |
| Dump | Backup, Archive |
| Piracy, Illegal | (don't mention at all) |

---

## App Store Review Risks

| Risk | Mitigation |
|------|------------|
| Perceived piracy facilitation | Clear onboarding: "Add your own legally-obtained game files" |
| GPL compliance | Open-source the macOS shell; provide source download link |
| Sandbox escape attempts | Audit all file access; use only security-scoped bookmarks |
| Performance/crashes | Test extensively on Intel and Apple Silicon |

---

## References

- [MAME License](https://github.com/mamedev/mame/blob/master/COPYING)
- [Apple App Store Review Guidelines §4.7](https://developer.apple.com/app-store/review/guidelines/#design)
- [App Sandbox Design Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
- [Game Controller Framework](https://developer.apple.com/documentation/gamecontroller)
