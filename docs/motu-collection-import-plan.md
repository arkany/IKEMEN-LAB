# MOTU Masters Project — Import as Collection Plan

> **Source:** `/Users/davidphillips/Downloads/motu_masters_project_v2a`  
> **Analysis Date:** January 21, 2026

## Project Summary

This is a vintage WinMUGEN "fullgame" package — **Masters of the Universe** themed, created by the LightKeepers team circa 2010. It's a complete standalone MUGEN installation with:

| Component | Contents |
|-----------|----------|
| **Characters** | 2 characters: `he-man`, `skeletor` |
| **Stages** | 3 stages: `Eternia.def`, `Skeletor.def`, `he-man.def` |
| **Screenpack** | Custom "Masters Project" screenpack by LightKeepers |
| **Music/SFX** | Custom title music, credit music, stage themes |
| **Engine** | WinMUGEN (Windows-only, 2005 version) |

## Is This Feasible? **YES** ✅

This is absolutely achievable. IKEMEN GO is backwards-compatible with MUGEN content, and all the content types in this package are already supported by IKEMEN Lab.

---

## Import Strategy

### Option A: Content-Only Import (Recommended)
Import just the characters and stages into the existing IKEMEN GO library, then create a "Masters of the Universe" collection that references them.

**Pros:**
- Characters/stages become available in ALL collections
- No duplicate assets
- User can mix He-Man with other characters

**Cons:**
- Loses the custom screenpack/UI theme
- Less "authentic" fullgame experience

### Option B: Full Collection Import (New Feature Required)
Import everything including the screenpack, and create a self-contained collection that activates the custom theme.

**Pros:**
- Preserves the complete experience as intended
- "Masters Project" screenpack becomes a selectable theme

**Cons:**
- Requires screenpack installation feature (partially built)
- More complex

---

## Implementation Plan

### Phase 1: Content Import (Existing Functionality)

#### Characters
Both characters are standard MUGEN format and can be imported today:

| Character | Folder | Files | Status |
|-----------|--------|-------|--------|
| He-Man | `chars/he-man/` | `.def`, `.sff`, `.snd`, `.cmd`, `.cns`, `.ai` | ✅ Ready to import |
| Skeletor | `chars/skeletor/` | (same structure) | ✅ Ready to import |

**Action:** Drag `chars/he-man/` and `chars/skeletor/` into IKEMEN Lab → auto-detects as characters → installs to `Ikemen-GO/chars/`

#### Stages
⚠️ **Issue:** Stages are loose in `stages/` folder, not in subfolders. IKEMEN Lab expects `stages/{name}/{name}.def` structure.

| Stage | Files | Import Approach |
|-------|-------|-----------------|
| Eternia | `Eternia.def`, `Eternia.sff` | Copy both to `stages/Eternia/` |
| He-Man stage | `he-man.def`, `he-man3.sff` | Copy to `stages/He-man/`, rename SFF |
| Skeletor stage | `Skeletor.def`, `skeletor3.sff` | Copy to `stages/Skeletor_Stage/`, rename SFF |

**Enhancement Needed:** Stage import should handle loose-file stages and auto-create folder structure.

### Phase 2: Collection Creation

Once content is imported, create a new collection via the existing Collections UI:

```swift
Collection(
    name: "Masters of the Universe",
    icon: "shield.fill",  // or custom icon
    characters: [
        .character(folder: "he-man"),
        .character(folder: "skeletor")
    ],
    stages: [
        "Eternia",
        "He-man",
        "Skeletor_Stage"
    ],
    screenpackPath: "data/masters_project"  // Phase 3
)
```

### Phase 3: Screenpack Import (New Feature)

To fully support fullgame imports, we need the planned screenpack installation feature.

#### Screenpack Structure to Import

```
data/masters_project/
├── system.def          # Main theme definition
├── system.sff          # Menu sprites (title screen, select screen)
├── system.snd          # UI sounds
├── fight.def           # Lifebars/HUD
├── fight.sff           # Lifebar sprites
├── fight.snd           # Round announcer, KO sounds
├── intro.def           # Intro storyboard
├── intro.sff           # Intro sprites
├── credits.def         # Credits screen
├── credit.sff          # Credits sprites
├── fightfx.air         # Hit effects animation
├── fightfx.sff         # Hit effect sprites
├── common.snd          # Shared sounds
├── common1.cns         # Common states
└── fonts/              # Custom fonts (symlinked from font/)
    └── (from parent font/ folder)
```

#### IKEMEN GO Compatibility Notes

1. **Path References:** MUGEN uses `font/f-4x6.fnt`, IKEMEN GO looks in `data/` first. May need path adjustment in `system.def`.

2. **Music Paths:** Source uses `sound/main_00.mp3`, should work if `sound/` folder is copied.

3. **Resolution:** Old MUGEN was 320x240. IKEMEN GO auto-upscales but may look pixelated.

---

## New Add-On Types Required

To import fullgame packages like this as complete collections, IKEMEN Lab needs:

### 1. Screenpack Installation
**Status:** Documented in [screenpack-handling.md](screenpack-handling.md), not implemented

**Required:**
- Detect screenpack structure (`system.def` presence)
- Copy to `data/{screenpack_name}/`
- Parse resolution, slot count, author info
- Allow activation per-collection

### 2. Music/Sound Import
**Status:** Not implemented

**Required:**
- Copy `sound/` folder contents
- Stage music is already handled in stage `.def` files
- Screenpack music (`title.bgm`, `select.bgm`) needs path resolution

### 3. Font Import
**Status:** Not implemented

**Required:**
- Copy `font/` folder to `data/` or `font/`
- IKEMEN GO typically uses `data/` for fonts
- Validate `.fnt` files exist

### 4. Fullgame Package Import (Bundle All Above)
**Status:** Not implemented

**New workflow:**
```
User drags fullgame folder → IKEMEN Lab detects:
  ✓ 2 characters found
  ✓ 3 stages found
  ✓ 1 screenpack found (Masters Project)
  ✓ Custom fonts found
  
[Import as Collection] button →
  Creates "Masters of the Universe" collection
  Imports all characters
  Imports all stages (with folder restructure)
  Imports screenpack
  Associates screenpack with collection
```

---

## Implementation Roadmap

### Immediate (Use Today with Manual Steps)
1. Manually copy `chars/he-man/` → `Ikemen-GO/chars/he-man/`
2. Manually copy `chars/skeletor/` → `Ikemen-GO/chars/skeletor/`
3. Create stage folders and copy stage files
4. Use IKEMEN Lab to create "Masters of the Universe" collection
5. Add characters and stages to collection
6. (Optional) Manually copy screenpack to `data/masters_project/`

### Short-term (Feature Additions)
1. **Loose stage file import** — Auto-create folder structure for stages without subfolders
2. **Batch folder import** — Drag a folder containing multiple chars/stages
3. **Screenpack detection** — Identify screenpacks in imported content

### Medium-term (Fullgame Support)
1. **Screenpack installation UI** — Browse, preview, install screenpacks
2. **Collection-screenpack binding** — Each collection can specify a screenpack
3. **Fullgame detection** — Recognize complete MUGEN packages
4. **One-click fullgame import** — Extract all content, create collection

---

## Technical Considerations

### MUGEN → IKEMEN GO Compatibility

| Feature | WinMUGEN (Source) | IKEMEN GO | Notes |
|---------|-------------------|-----------|-------|
| Character format | .def/.sff/.cmd/.cns | ✅ Same | Full compatibility |
| Stage format | .def/.sff | ✅ Same | May need path fixes |
| Screenpack | system.def/sff | ⚠️ Mostly | Some extensions differ |
| SFF version | v1 | ✅ v1 + v2 | IKEMEN supports both |
| Resolution | 320x240 | ✅ Any | Auto-scales |
| AI format | .ai | ✅ + .zss | Legacy .ai works |

### Potential Issues

1. **Case sensitivity:** macOS is case-insensitive, but paths in `.def` files may have case mismatches. The source has `stages/Heman.def` vs actual file `stages/he-man.def` — needs fixing.

2. **Path separator:** MUGEN uses backslashes, IKEMEN GO on macOS needs forward slashes.

3. **Sound formats:** Old `.mp3` files should work, but quality may vary.

---

## Conclusion

**Yes, this is absolutely possible.** The core content (characters + stages) can be imported TODAY using existing IKEMEN Lab functionality with minor manual adjustments.

To support **one-click fullgame import** with screenpack theming, we need to implement:
1. Screenpack installation (highest priority)
2. Loose-file stage restructuring
3. Fullgame package detection & batch import

This would be a compelling feature for users who want to run classic "fullgames" like this MOTU package as complete, themed experiences.
