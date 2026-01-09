# PNG Stage Creator — Learnings & Technical Notes

This document captures the technical learnings from implementing the PNG-to-Stage generator feature in IKEMEN Lab.

## Overview

The PNG Stage Creator allows users to generate a complete IKEMEN GO stage package from a single PNG background image. The feature creates:
- An SFF v2 sprite file containing the background image and a thumbnail
- A `.def` stage definition file with proper camera, player, and background configuration

## Key Files

- [StageGenerator.swift](../IKEMEN%20Lab/Core/StageGenerator.swift) — Orchestrates stage generation
- [SFFWriter.swift](../IKEMEN%20Lab/Core/SFFWriter.swift) — Writes SFF v2 format files
- [GameWindowController.swift](../IKEMEN%20Lab/App/GameWindowController.swift) — UI integration

---

## SFF v2 File Format Learnings

### Header Structure (68 bytes)

The SFF v2 header is more complex than v1. Key offsets:

| Offset | Size | Field |
|--------|------|-------|
| 0 | 12 | Signature: `ElecbyteSpr\0` |
| 12 | 4 | Version (v2.01 = `0x00, 0x01, 0x00, 0x02`) |
| 36 | 4 | Sprite list offset |
| 40 | 4 | Sprite count |
| 44 | 4 | Palette list offset |
| 48 | 4 | Palette count |
| 52 | 4 | Ldata (literal data) offset |
| 56 | 4 | Ldata length |
| 60 | 4 | Tdata offset |
| 64 | 4 | Tdata length |

### Sprite Node Structure (28 bytes each)

```
[0-1]   Group number (UInt16)
[2-3]   Image number (UInt16)
[4-5]   Width (UInt16)
[6-7]   Height (UInt16)
[8-9]   X axis offset (Int16)
[10-11] Y axis offset (Int16)
[12-13] Linked index (0xFFFF = not linked)
[14]    Format (11 = PNG24, 12 = PNG32)
[15]    Color depth (32 for PNG32)
[16-19] Data offset in ldata
[20-23] Data length
[24-25] Palette index (0 for PNG)
[26-27] Flags (0 = uses ldata)
```

### PNG Embedding

PNG images can be embedded directly in SFF v2 files:
- Format byte = 12 (PNG32 with alpha) or 11 (PNG24 without alpha)
- PNG data is stored in the ldata section
- Each sprite's PNG data is preceded by a 4-byte "uncompressed size" header (typically ignored for PNG)

### Palette Requirements

Even for PNG-only SFF files, **at least one dummy palette node is required**:
- Group 0, Item 0, with 1 color
- 4 bytes of RGBA data (can be transparent black: `0x00000000`)

---

## Stage DEF File Learnings

### Coordinate System

IKEMEN GO uses a **localcoord** system. For HD stages:
```ini
[StageInfo]
localcoord = 1280, 720  ; HD widescreen
```

### Critical Parameters

#### zoffset — Floor Position
The most important parameter for character placement:
```
zoffset = imgHeight - 75
```
- Determines where characters' feet touch the ground
- Higher value = characters appear lower on screen
- The `-75` offset accounts for the typical floor margin

#### Camera Bounds
How far the camera can pan based on image size:
```swift
let cameraPanX = max(0, (imgWidth - screenWidth) / 2)
let boundLeft = -cameraPanX
let boundRight = cameraPanX
```

#### Player Movement Bounds
Limit where players can walk (prevents walking off visible background):
```swift
let leftbound = -imgWidth / 2 + 50   // Leave margin
let rightbound = imgWidth / 2 - 50
```

### Background Positioning

To center a background image larger than the screen:
```swift
let bgStartX = -imgWidth / 2
let bgStartY = -(imgHeight - screenHeight)  // Bottom-align with screen
```

### Thumbnail Sprite for Stage Select

IKEMEN GO expects a thumbnail sprite at **group 9000, image 1**:
```ini
[Begin Action 9000]
9000,1, 0,0, -1

[StageInfo]
portraitscale = 4  ; Scale factor for thumbnail
```

The thumbnail should be a wide aspect ratio (we use 240×100 pixels).

---

## Image Processing Learnings

### Thumbnail Generation Strategy

For stage select thumbnails:
1. Calculate target aspect ratio (240:100 = 2.4:1)
2. Crop to match target aspect ratio from image center
3. For stage images, bias crop toward top (where interesting content usually is)
4. Scale to target dimensions

```swift
// Bias toward top of image where action usually is
let yOffset = originalSize.height - newHeight - (originalSize.height * 0.1)
```

### PNG Encoding in AppKit

Converting NSImage to PNG data:
```swift
guard let tiffData = nsImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    throw SFFWriteError.pngEncodingFailed
}
```

### Size Validation

We enforce limits to prevent crashes/performance issues:
- **Minimum**: 320×240 (too small looks bad)
- **Maximum**: 4096×4096 (IKEMEN GO may have issues with larger)

---

## Lessons Learned

### 1. SFF v2 Requires Proper Byte Alignment

The header offsets must be exact. The sprite list must start at offset 68 (after the full header), not earlier.

### 2. Dummy Palette is Mandatory

Even with PNG sprites that don't use palettes, IKEMEN GO expects at least one palette entry in the palette table. Without it, the file may not load.

### 3. PNG Data Needs Length Prefix

Each PNG sprite in ldata needs a 4-byte header containing the uncompressed pixel data size. While IKEMEN GO seems to ignore this for PNG format, it's part of the format spec:
```swift
let uncompressedSize = UInt32(sprite.width) * UInt32(sprite.height) * 4
data.append(littleEndian: uncompressedSize)
data.append(sprite.pngData)
```

### 4. localcoord Affects Everything

The `localcoord` setting in the DEF file affects how all coordinates are interpreted. Mixing coordinate systems causes positioning bugs. Stick with 1280×720 for HD stages.

### 5. zoffset is Tricky

Getting characters to stand at the right height requires careful calculation. The formula `imgHeight - 75` works for most cases, but ideally this should be user-configurable for fine-tuning.

### 6. Thumbnail Aspect Ratio Matters

The stage select screen expects wide thumbnails. A square or tall thumbnail will look wrong. The 240×100 size (2.4:1 aspect) matches existing working stages.

### 7. Feature Flag for Experimental Features

We hide the feature behind a settings toggle (`enablePNGStageCreation`) because:
- The feature is experimental
- Generated stages may need manual DEF file tweaking
- Prevents accidental stage creation

---

## Future Improvements

### User-Facing
- [ ] Preview dialog showing generated stage before saving
- [ ] Manual zoffset/floor position slider
- [ ] BGM file picker integration
- [ ] Multiple background layer support
- [ ] Animated background support (multiple frames)

### Technical
- [ ] Support tiled/repeating backgrounds properly
- [ ] Parallax layer generation from multiple images
- [ ] Stage template system (preset DEF configurations)
- [ ] Validation against actual IKEMEN GO loading

---

## References

- [Elecbyte SFF v2 Specification](http://www.elecbyte.com/mugendocs-11b1/sff.html) (original docs)
- IKEMEN GO source code for SFF parsing
- Working reference: `stages/stage0-720/` in default IKEMEN GO installation
