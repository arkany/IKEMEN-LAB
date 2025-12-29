# Architecture

Technical architecture for the macOS MAME application, including the modular framework approach, Metal rendering bridge, and middleware interface contract.

---

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      macOS App Shell                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   AppKit    │  │   Library   │  │    Preferences      │  │
│  │   Windows   │  │   Manager   │  │    & Settings       │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│  ┌──────┴────────────────┴─────────────────────┴──────────┐  │
│  │                  EmulatorBridge                         │  │
│  │            (Swift ↔ C Interface Layer)                  │  │
│  └─────────────────────────┬───────────────────────────────┘  │
└────────────────────────────┼────────────────────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────┐
│                    MAMECore.framework                       │
│  ┌─────────────┐  ┌───────┴───────┐  ┌─────────────────┐   │
│  │   MAME      │  │   Middleware  │  │   BGFX/Metal    │   │
│  │   Core      │◄─┤   Interface   ├─►│   Renderer      │   │
│  │   (C/C++)   │  │               │  │                 │   │
│  └─────────────┘  └───────────────┘  └─────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## MAMECore.framework

### Purpose

Encapsulate MAME's emulation engine as a reusable, testable macOS framework that:
- Isolates MAME's C/C++ code from Swift app lifecycle
- Provides clean C interface for Swift interop
- Handles Metal rendering internally
- Manages audio output via Core Audio

### Framework Structure

```
MAMECore.framework/
├── Headers/
│   └── MAMECore.h              # Public C interface
├── Modules/
│   └── module.modulemap        # Swift module map
├── Resources/
│   ├── Info.plist
│   └── shaders/                # BGFX Metal shaders
└── MAMECore                    # Binary (universal: arm64 + x86_64)
```

### Build Configuration

Modify MAME's makefile to produce a framework:

```makefile
# Custom target for macOS framework
framework: $(MAME_TARGET)
	mkdir -p MAMECore.framework/Headers
	mkdir -p MAMECore.framework/Modules
	cp src/osd/mac/MAMECore.h MAMECore.framework/Headers/
	cp build/MAMECore MAMECore.framework/
	# ... (code signing, Info.plist, etc.)
```

---

## Middleware Interface

### C Header (MAMECore.h)

```c
#ifndef MAMECORE_H
#define MAMECORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to emulator instance
typedef struct MAMEInstance* MAMEInstanceRef;

// Lifecycle
MAMEInstanceRef mame_create(void);
void mame_destroy(MAMEInstanceRef instance);

// Configuration
typedef struct {
    const char* romPath;
    const char* biosPath;
    const char* savePath;
    int sampleRate;
    bool skipBiosCheck;
} MAMEConfig;

int mame_configure(MAMEInstanceRef instance, MAMEConfig config);

// Game loading
int mame_load_game(MAMEInstanceRef instance, const char* romName);
void mame_unload_game(MAMEInstanceRef instance);
bool mame_is_game_loaded(MAMEInstanceRef instance);

// Emulation control
void mame_run_frame(MAMEInstanceRef instance);
void mame_pause(MAMEInstanceRef instance);
void mame_resume(MAMEInstanceRef instance);
void mame_reset(MAMEInstanceRef instance);
bool mame_is_paused(MAMEInstanceRef instance);

// Input
typedef enum {
    MAME_INPUT_UP = 0,
    MAME_INPUT_DOWN,
    MAME_INPUT_LEFT,
    MAME_INPUT_RIGHT,
    MAME_INPUT_BUTTON1,
    MAME_INPUT_BUTTON2,
    MAME_INPUT_BUTTON3,
    MAME_INPUT_BUTTON4,
    MAME_INPUT_BUTTON5,
    MAME_INPUT_BUTTON6,
    MAME_INPUT_COIN1,
    MAME_INPUT_START1,
    // ... extend as needed
} MAMEInput;

void mame_set_input(MAMEInstanceRef instance, int player, MAMEInput input, bool pressed);

// Video output
typedef struct {
    void* metalTexture;         // id<MTLTexture>
    int width;
    int height;
    double aspectRatio;
} MAMEVideoFrame;

MAMEVideoFrame mame_get_video_frame(MAMEInstanceRef instance);

// Audio output
typedef struct {
    int16_t* samples;
    int sampleCount;
    int channels;
} MAMEAudioBuffer;

MAMEAudioBuffer mame_get_audio_buffer(MAMEInstanceRef instance);

// Save states
int mame_save_state(MAMEInstanceRef instance, const char* path);
int mame_load_state(MAMEInstanceRef instance, const char* path);

// Error handling
const char* mame_get_last_error(MAMEInstanceRef instance);

// Game info
typedef struct {
    const char* name;
    const char* description;
    const char* manufacturer;
    const char* year;
    int screenWidth;
    int screenHeight;
    double refreshRate;
} MAMEGameInfo;

MAMEGameInfo mame_get_game_info(MAMEInstanceRef instance);

// Performance metrics
typedef struct {
    double fps;
    double frameTimeMs;
    double emulationSpeed;      // 1.0 = 100%
} MAMEPerformance;

MAMEPerformance mame_get_performance(MAMEInstanceRef instance);

#ifdef __cplusplus
}
#endif

#endif // MAMECORE_H
```

### Swift Bridge (EmulatorBridge.swift)

```swift
import Foundation
import MAMECore

/// Swift wrapper around MAMECore C interface
class EmulatorBridge {
    private var instance: MAMEInstanceRef?
    
    init() {
        instance = mame_create()
    }
    
    deinit {
        if let instance = instance {
            mame_destroy(instance)
        }
    }
    
    func configure(romPath: URL, biosPath: URL, savePath: URL) throws {
        var config = MAMEConfig()
        config.romPath = romPath.path.cString(using: .utf8)
        config.biosPath = biosPath.path.cString(using: .utf8)
        config.savePath = savePath.path.cString(using: .utf8)
        config.sampleRate = 48000
        config.skipBiosCheck = false
        
        let result = mame_configure(instance, config)
        if result != 0 {
            throw EmulatorError.configurationFailed(mame_get_last_error(instance))
        }
    }
    
    func loadGame(named romName: String) throws {
        let result = mame_load_game(instance, romName)
        if result != 0 {
            throw EmulatorError.loadFailed(mame_get_last_error(instance))
        }
    }
    
    func runFrame() {
        mame_run_frame(instance)
    }
    
    func setInput(player: Int, input: MAMEInput, pressed: Bool) {
        mame_set_input(instance, Int32(player), input, pressed)
    }
    
    var videoFrame: MAMEVideoFrame {
        mame_get_video_frame(instance)
    }
    
    var performance: MAMEPerformance {
        mame_get_performance(instance)
    }
    
    // ... additional methods
}

enum EmulatorError: Error {
    case configurationFailed(String?)
    case loadFailed(String?)
    case saveStateFailed(String?)
}
```

---

## Metal Rendering Bridge

### Overview

MAME renders frames to a texture. The macOS app displays that texture in a `CAMetalLayer`.

```
MAME Core                    Metal Layer
    │                            │
    ▼                            │
┌─────────┐                      │
│ BGFX    │──── MTLTexture ─────►│
│ Metal   │                      │
│ Backend │                      │
└─────────┘                      ▼
                           ┌──────────┐
                           │ Display  │
                           └──────────┘
```

### Texture Sharing

```swift
// Create shared texture for MAME to render into
func createSharedTexture(width: Int, height: Int) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm,
        width: width,
        height: height,
        mipmapped: false
    )
    descriptor.usage = [.shaderRead, .renderTarget]
    descriptor.storageMode = .shared  // CPU + GPU access
    
    return device.makeTexture(descriptor: descriptor)!
}

// Pass texture pointer to MAME core
mame_set_render_target(instance, Unmanaged.passUnretained(texture).toOpaque())
```

### Frame Presentation

```swift
func renderFrame() {
    // 1. MAME renders to shared texture (called from core)
    emulator.runFrame()
    
    // 2. Get drawable from Metal layer
    guard let drawable = metalLayer.nextDrawable() else { return }
    
    // 3. Blit MAME texture to drawable
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    
    blitEncoder.copy(from: mameTexture, to: drawable.texture)
    blitEncoder.endEncoding()
    
    // 4. Present
    commandBuffer.present(drawable)
    commandBuffer.commit()
}
```

---

## Audio Pipeline

### Core Audio Integration

```swift
import AudioToolbox

class AudioManager {
    private var audioUnit: AudioComponentInstance?
    private let sampleRate: Double = 48000
    private var audioBuffer: RingBuffer<Int16>
    
    func setupAudioUnit() {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_DefaultOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        
        let component = AudioComponentFindNext(nil, &desc)!
        AudioComponentInstanceNew(component, &audioUnit)
        
        // Configure format (stereo, 16-bit, 48kHz)
        var format = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        AudioUnitSetProperty(audioUnit!, kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Input, 0, &format, UInt32(MemoryLayout.size(ofValue: format)))
        
        // Set render callback
        var callbackStruct = AURenderCallbackStruct(
            inputProc: audioCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        AudioUnitSetProperty(audioUnit!, kAudioUnitProperty_SetRenderCallback,
                            kAudioUnitScope_Input, 0, &callbackStruct, UInt32(MemoryLayout.size(ofValue: callbackStruct)))
        
        AudioUnitInitialize(audioUnit!)
        AudioOutputUnitStart(audioUnit!)
    }
    
    func queueAudio(from emulator: EmulatorBridge) {
        let buffer = emulator.audioBuffer
        audioBuffer.write(buffer.samples, count: buffer.sampleCount)
    }
}

// Render callback
private func audioCallback(/* ... */) -> OSStatus {
    let manager = Unmanaged<AudioManager>.fromOpaque(inRefCon).takeUnretainedValue()
    manager.audioBuffer.read(into: ioData, frameCount: inNumberFrames)
    return noErr
}
```

---

## Save State Architecture

### File Format

```
SaveStates/
└── pacman/
    ├── slot-1.state           # Binary state data
    ├── slot-1.meta.json       # Metadata
    ├── slot-1.preview.png     # Screenshot
    ├── slot-2.state
    ├── slot-2.meta.json
    └── slot-2.preview.png
```

### Metadata Schema

```json
{
    "version": 1,
    "gameId": "pacman",
    "mameVersion": "0.261",
    "timestamp": "2024-12-18T10:30:00Z",
    "playTime": 3600,
    "screenshotPath": "slot-1.preview.png",
    "sha256": "abc123..."
}
```

### Save/Load Flow

```swift
struct SaveStateManager {
    let basePath: URL
    
    func save(slot: Int, emulator: EmulatorBridge, screenshot: NSImage?) throws {
        let gameId = emulator.gameInfo.name
        let stateURL = basePath.appendingPathComponent("\(gameId)/slot-\(slot).state")
        
        // 1. Save emulator state
        try emulator.saveState(to: stateURL)
        
        // 2. Capture screenshot
        if let screenshot = screenshot {
            let previewURL = stateURL.deletingPathExtension().appendingPathExtension("preview.png")
            try screenshot.pngData()?.write(to: previewURL)
        }
        
        // 3. Write metadata
        let meta = SaveStateMetadata(
            version: 1,
            gameId: gameId,
            mameVersion: emulator.mameVersion,
            timestamp: Date(),
            playTime: emulator.playTime,
            sha256: sha256(of: stateURL)
        )
        let metaURL = stateURL.deletingPathExtension().appendingPathExtension("meta.json")
        try JSONEncoder().encode(meta).write(to: metaURL)
    }
    
    func load(slot: Int, emulator: EmulatorBridge) throws {
        let gameId = emulator.gameInfo.name
        let stateURL = basePath.appendingPathComponent("\(gameId)/slot-\(slot).state")
        
        // Validate metadata compatibility
        let metaURL = stateURL.deletingPathExtension().appendingPathExtension("meta.json")
        let meta = try JSONDecoder().decode(SaveStateMetadata.self, from: Data(contentsOf: metaURL))
        
        if meta.mameVersion != emulator.mameVersion {
            // Warn user about potential incompatibility
        }
        
        try emulator.loadState(from: stateURL)
    }
}
```

---

## Error Handling Strategy

### Error Categories

| Category | Example | User Message |
|----------|---------|--------------|
| Missing ROM | File not found | "Game file not found. Add it to your library." |
| Missing BIOS | neogeo.zip needed | "This game requires system files. See Help → System Files." |
| Corrupt state | SHA mismatch | "Save file is damaged. Try an earlier save." |
| Performance | <50% speed | "Performance warning. Try closing other apps." |

### Error Propagation

```swift
enum MAMEError: LocalizedError {
    case romNotFound(String)
    case biosRequired(String)
    case saveStateCorrupt
    case saveStateIncompatible(savedVersion: String, currentVersion: String)
    
    var errorDescription: String? {
        switch self {
        case .romNotFound(let name):
            return "Game file '\(name)' not found"
        case .biosRequired(let bios):
            return "System file '\(bios)' is required"
        case .saveStateCorrupt:
            return "Save file is damaged"
        case .saveStateIncompatible(let saved, let current):
            return "Save was created with version \(saved), current is \(current)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .romNotFound:
            return "Drag the game file onto the app to add it to your library."
        case .biosRequired:
            return "Add the required system file in Preferences → Firmware & BIOS."
        case .saveStateCorrupt, .saveStateIncompatible:
            return "Try loading a different save slot."
        }
    }
}
```

---

## Testing Strategy

### Unit Test Targets

```swift
// MAMECoreTests
func testCreateDestroy() {
    let instance = mame_create()
    XCTAssertNotNil(instance)
    mame_destroy(instance)
}

func testConfigureValidPaths() {
    let instance = mame_create()
    var config = MAMEConfig()
    config.romPath = "/valid/path"
    XCTAssertEqual(mame_configure(instance, config), 0)
}

func testInputMapping() {
    let instance = mame_create()
    mame_set_input(instance, 0, MAME_INPUT_UP, true)
    // Verify internal state
}
```

### Integration Tests

```swift
// EmulatorBridgeTests
func testLoadAndRunGame() async throws {
    let bridge = EmulatorBridge()
    try bridge.configure(romPath: testRomPath, biosPath: testBiosPath, savePath: tempPath)
    try bridge.loadGame(named: "pacman")
    
    // Run 60 frames (1 second at 60fps)
    for _ in 0..<60 {
        bridge.runFrame()
    }
    
    XCTAssertEqual(bridge.performance.emulationSpeed, 1.0, accuracy: 0.1)
}
```

---

## Build Pipeline

### Xcode Scheme Configuration

```
IKEMEN Lab.xcodeproj/
├── IKEMEN Lab (App target)
│   └── Build Phases:
│       ├── Compile Swift
│       └── Copy Resources
└── IKEMEN LabTests (Test target)
```

### CI/CD (GitHub Actions)

```yaml
name: Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Build MAME Core
        run: ./scripts/build-mame-macos.sh
      - name: Build App
        run: xcodebuild -scheme "IKEMEN Lab" -configuration Release
      - name: Run Tests
        run: xcodebuild test -scheme "IKEMEN Lab"
```
