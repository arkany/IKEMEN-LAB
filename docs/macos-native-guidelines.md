# macOS Native Development Guidelines

Living reference for building a Mac-native emulator app. Covers AppKit patterns, Metal rendering, sandbox compliance, input handling, and accessibility.

---

## UI Framework: AppKit

### Why AppKit Over SwiftUI

| Consideration | AppKit | SwiftUI |
|---------------|--------|---------|
| Fullscreen handling | Mature, well-documented | Inconsistent behavior |
| Game loop integration | CVDisplayLink works seamlessly | Requires workarounds |
| Input latency | Direct event handling | Extra abstraction layer |
| macOS version support | 10.13+ | 11.0+ for full features |
| Community resources | Decades of examples | Fewer emulator examples |

**Recommendation**: Use AppKit for the main window and game rendering. SwiftUI can be used for preferences/settings panels if desired (via `NSHostingController`).

### Key AppKit Classes

```
NSApplication          → App lifecycle
NSWindow              → Main game window
NSWindowController    → Window management
NSViewController      → View hierarchy
NSView                → Custom rendering view
NSMenu / NSMenuItem   → Menu bar integration
NSOpenPanel           → File selection (sandboxed)
NSSavePanel           → File export (sandboxed)
```

### Window Configuration

```swift
// Recommended window setup for emulation
window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
window.collectionBehavior = [.fullScreenPrimary, .managed]
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
window.backgroundColor = .black

// Retina-aware backing
window.contentView?.wantsLayer = true
window.contentView?.layer?.contentsScale = window.backingScaleFactor
```

### Fullscreen Best Practices

- Use native fullscreen (`NSWindow.toggleFullScreen(_:)`) not custom
- Handle `NSWindowDelegate` methods:
  - `windowWillEnterFullScreen(_:)`
  - `windowDidEnterFullScreen(_:)`
  - `windowWillExitFullScreen(_:)`
  - `windowDidExitFullScreen(_:)`
- Pause emulation during fullscreen transition (avoid frame drops)
- Remember fullscreen state in preferences

---

## Metal Rendering

### Setup

```swift
// Metal device and layer
let device = MTLCreateSystemDefaultDevice()!
let metalLayer = CAMetalLayer()
metalLayer.device = device
metalLayer.pixelFormat = .bgra8Unorm
metalLayer.framebufferOnly = true
metalLayer.displaySyncEnabled = true  // VSync
view.layer = metalLayer
```

### Frame Timing with CVDisplayLink

```swift
var displayLink: CVDisplayLink?

func setupDisplayLink() {
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
    CVDisplayLinkSetOutputCallback(displayLink!, { (_, _, _, _, _, userInfo) -> CVReturn in
        let renderer = Unmanaged<Renderer>.fromOpaque(userInfo!).takeUnretainedValue()
        renderer.renderFrame()
        return kCVReturnSuccess
    }, Unmanaged.passUnretained(self).toOpaque())
    CVDisplayLinkStart(displayLink!)
}
```

### Latency Optimization

| Technique | Impact |
|-----------|--------|
| Triple buffering | Smooths frame delivery, adds ~1 frame latency |
| Double buffering | Lower latency, potential tearing |
| `displaySyncEnabled = true` | Prevents tearing, may add latency |
| Prefer `presentDrawable(_:)` | Use after command buffer commit |

**Target**: <16ms input-to-display at 60Hz

### BGFX Integration

MAME's BGFX backend supports Metal natively:

```
# Build MAME with Metal backend
make SUBTARGET=mame OSD=sdl USE_BGFX=1 BGFX_BACKEND=metal
```

BGFX abstracts shaders—write once, run on Metal/Vulkan/OpenGL.

---

## Sandbox & Entitlements

### Required Entitlements

```xml
<!-- App.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
</dict>
</plist>
```

### Security-Scoped Bookmarks

Persist file access across launches:

```swift
// Save bookmark when user selects file
func saveBookmark(for url: URL) throws {
    let bookmarkData = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    UserDefaults.standard.set(bookmarkData, forKey: "romFolder")
}

// Restore access on launch
func restoreBookmark() -> URL? {
    guard let data = UserDefaults.standard.data(forKey: "romFolder") else { return nil }
    var isStale = false
    let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
    _ = url?.startAccessingSecurityScopedResource()
    return url
}
```

### File Access Patterns

| Action | API | Sandboxed? |
|--------|-----|------------|
| User opens file | `NSOpenPanel` | ✓ |
| User saves file | `NSSavePanel` | ✓ |
| Drag-and-drop | `NSView` drag APIs | ✓ (temporary) |
| App storage | `FileManager.default.urls(for: .applicationSupportDirectory)` | ✓ |
| Arbitrary path | Direct `URL` access | ✗ Denied |

---

## Input Handling

### Game Controller Framework

```swift
import GameController

func setupControllers() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(controllerConnected),
        name: .GCControllerDidConnect,
        object: nil
    )
    
    // Discover existing controllers
    GCController.controllers().forEach { setupController($0) }
}

func setupController(_ controller: GCController) {
    controller.extendedGamepad?.valueChangedHandler = { gamepad, element in
        // Handle input with minimal latency
        if element == gamepad.buttonA {
            self.emulator.pressButton(.a, pressed: gamepad.buttonA.isPressed)
        }
    }
}
```

### Keyboard Input

```swift
override func keyDown(with event: NSEvent) {
    guard !event.isARepeat else { return }
    let keyCode = event.keyCode
    emulator.keyDown(keyCode)
}

override func keyUp(with event: NSEvent) {
    let keyCode = event.keyCode
    emulator.keyUp(keyCode)
}

// Prevent beeping on unhandled keys
override var acceptsFirstResponder: Bool { true }
```

### Input Mapping Storage

```swift
struct InputMapping: Codable {
    var keyboard: [UInt16: EmulatorButton]  // keyCode → button
    var gamepad: [String: EmulatorButton]    // element name → button
}

// Store per-game or global
let mappingURL = appSupportURL.appendingPathComponent("input-mapping.json")
```

---

## Accessibility

### Minimum Requirements

- [ ] VoiceOver announces game title when selected
- [ ] Keyboard-only navigation for library
- [ ] High contrast support (respect system setting)
- [ ] Reduce motion support (disable animations)

### Implementation

```swift
// Make library list accessible
libraryTableView.setAccessibilityLabel("Game Library")

// Announce game selection
func tableViewSelectionDidChange(_ notification: Notification) {
    if let game = selectedGame {
        NSAccessibility.post(element: tableView, notification: .announcementRequested, 
                            userInfo: [.announcement: "Selected \(game.title)"])
    }
}
```

### System Preferences Respect

```swift
// Check reduce motion
if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
    // Disable transition animations
}

// Check high contrast
if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
    // Use high contrast colors
}
```

---

## Menu Bar Integration

### Standard Menu Items

```swift
// File menu
let fileMenu = NSMenu(title: "File")
fileMenu.addItem(withTitle: "Open Game...", action: #selector(openGame), keyEquivalent: "o")
fileMenu.addItem(withTitle: "Add Games to Library...", action: #selector(addGames), keyEquivalent: "")
fileMenu.addItem(.separator())
fileMenu.addItem(withTitle: "Close", action: #selector(close), keyEquivalent: "w")

// Emulation menu (custom)
let emulationMenu = NSMenu(title: "Emulation")
emulationMenu.addItem(withTitle: "Pause", action: #selector(togglePause), keyEquivalent: "p")
emulationMenu.addItem(withTitle: "Reset", action: #selector(resetGame), keyEquivalent: "r")
emulationMenu.addItem(.separator())
emulationMenu.addItem(withTitle: "Save State", action: #selector(saveState), keyEquivalent: "s")
emulationMenu.addItem(withTitle: "Load State", action: #selector(loadState), keyEquivalent: "l")

// View menu
let viewMenu = NSMenu(title: "View")
viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(toggleFullScreen), keyEquivalent: "f")
viewMenu.addItem(withTitle: "Actual Size", action: #selector(actualSize), keyEquivalent: "1")
viewMenu.addItem(withTitle: "Double Size", action: #selector(doubleSize), keyEquivalent: "2")
```

### Dynamic Menu State

```swift
override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    switch menuItem.action {
    case #selector(togglePause):
        menuItem.title = isPaused ? "Resume" : "Pause"
        return isGameRunning
    case #selector(saveState), #selector(loadState):
        return isGameRunning
    default:
        return true
    }
}
```

---

## Performance Profiling

### Built-in Metrics

```swift
class PerformanceMonitor {
    var frameCount = 0
    var lastFrameTime: CFAbsoluteTime = 0
    var fps: Double = 0
    var frameTimeMs: Double = 0
    
    func recordFrame() {
        let now = CFAbsoluteTimeGetCurrent()
        frameTimeMs = (now - lastFrameTime) * 1000
        lastFrameTime = now
        frameCount += 1
        
        // Calculate FPS every second
        // ...
    }
}
```

### Developer Overlay

```swift
// Toggle with Cmd+Shift+D (debug builds only)
#if DEBUG
func drawOverlay(in context: CGContext) {
    let text = String(format: "FPS: %.1f | Frame: %.2fms", fps, frameTimeMs)
    // Draw semi-transparent background
    // Draw text
}
#endif
```

### MetricKit Integration

```swift
import MetricKit

class MetricsManager: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        // Log to analytics (opt-in only)
    }
    
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Crash and hang diagnostics
    }
}
```

---

## Code Organization

```
MacMAME/
├── App/
│   ├── AppDelegate.swift
│   ├── MainMenu.xib
│   └── Info.plist
├── Core/
│   ├── MAMECore.framework/      # Wrapped MAME
│   └── EmulatorBridge.swift     # Swift ↔ C interface
├── Views/
│   ├── GameWindow.swift
│   ├── MetalView.swift
│   └── LibraryViewController.swift
├── Input/
│   ├── InputManager.swift
│   └── InputMapping.swift
├── Library/
│   ├── GameLibrary.swift
│   ├── GameMetadata.swift
│   └── LibraryStorage.swift
├── Preferences/
│   ├── PreferencesWindow.swift
│   ├── FirmwarePanel.swift
│   └── InputPanel.swift
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

---

## Testing Strategy

### Unit Tests

- Input mapping serialization
- Library metadata parsing
- Bookmark persistence
- Settings validation

### UI Tests

- Launch and quit
- Open file dialog
- Fullscreen toggle
- Menu item state

### Performance Tests

- Frame timing consistency
- Memory usage under load
- Cold launch time

### Manual Testing Checklist

- [ ] Apple Silicon Mac
- [ ] Intel Mac
- [ ] Multiple displays
- [ ] Various controllers (Xbox, PS5, 8BitDo)
- [ ] Accessibility (VoiceOver)
- [ ] Low power mode
