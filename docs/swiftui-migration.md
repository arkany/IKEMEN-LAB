# SwiftUI Migration Guide

This document provides guidelines for introducing SwiftUI views into IKEMEN Lab's existing AppKit codebase.

## Overview

IKEMEN Lab uses a **gradual migration** approach:
- **Existing AppKit code stays unchanged** — No rewrites of working views
- **New features use SwiftUI** — Simpler, faster development for new UIs
- **Both coexist** — SwiftUI views can be embedded in AppKit windows

## Infrastructure

### Core Files

1. **SwiftUIBridge.swift** — Embedding infrastructure
   - `SwiftUIHostingView<Content>` — Wraps SwiftUI views for AppKit
   - `AppKitHostable` protocol — Convenience for conversion
   - `NSViewController.embedSwiftUIView()` — Helper for view controllers

2. **DesignSystem.swift** — SwiftUI design tokens
   - Color extensions matching AppKit `DesignColors`
   - Font extensions matching AppKit `DesignFonts`
   - View modifiers for cards, inputs, buttons

3. **AppState.swift** — Shared reactive state
   - Syncs with `IkemenBridge` (EmulatorBridge)
   - Observable properties for characters, stages, etc.
   - Convenience methods for common operations

## When to Use SwiftUI

### ✅ Good Candidates

- **Settings panels** — Forms with pickers, toggles, sliders
- **About window** — Static content, simple layout
- **Dialogs/sheets** — Modal forms, confirmations
- **Collection editor** — Form-based with validation
- **Simple list views** — Static or lightly interactive data
- **New feature views** — Anything starting from scratch

### ❌ Not Yet Recommended

- **CharacterBrowserView** — Complex `NSCollectionView` with custom layouts
- **Dashboard** — Complex multi-section layout with animations
- **Any view needing drag-and-drop** — AppKit's drag-drop is more mature
- **Views with heavy `NSView` customization** — Custom drawing, complex gestures

## How to Use

### 1. Create a SwiftUI View

```swift
import SwiftUI

struct MyNewView: View, AppKitHostable {
    @StateObject private var appState = AppState.shared
    
    var body: some View {
        VStack {
            Text("My View")
                .font(.header(size: 24))
                .foregroundColor(.textPrimary)
        }
        .padding()
        .background(Color.background)
    }
}
```

### 2. Embed in AppKit Window

#### Option A: In an NSView

```swift
class MyViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let swiftUIView = MyNewView()
        let hostingView = SwiftUIHostingView(rootView: swiftUIView)
        
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
```

#### Option B: As a Child View Controller

```swift
class MyViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let swiftUIView = MyNewView()
        embedSwiftUIView(swiftUIView, in: view)
    }
}
```

#### Option C: In a Window

```swift
func showAboutWindow() {
    let aboutView = AboutView()
    let hostingController = NSHostingController(rootView: aboutView)
    
    let window = NSWindow(contentViewController: hostingController)
    window.title = "About IKEMEN Lab"
    window.styleMask = [.titled, .closable]
    window.center()
    window.makeKeyAndOrderFront(nil)
}
```

### 3. Use AppState for Data

```swift
struct CharacterListView: View {
    @StateObject private var appState = AppState.shared
    
    var body: some View {
        List(appState.characters) { character in
            Text(character.displayName)
        }
    }
}
```

## Design System Usage

### Colors

Use the SwiftUI color extensions that match AppKit:

```swift
.background(Color.cardBackground)
.foregroundColor(.textPrimary)
.overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderSubtle))
```

### Fonts

Use the custom font extensions:

```swift
.font(.header(size: 24))  // Montserrat-SemiBold
.font(.body(size: 14))    // Manrope-Medium
.font(.caption(size: 12)) // Inter-Regular
```

### View Modifiers

Use the pre-built modifiers:

```swift
VStack { ... }
    .cardStyle()  // Card background + border
    
TextField("Name", text: $name)
    .inputStyle()  // Input background + border
    
Button("Save") { ... }
    .buttonStyle(PrimaryButtonStyle())
```

## Testing SwiftUI Views

### Unit Tests

SwiftUI views are challenging to unit test directly. Focus on testing:
- **ViewModels** — Extract business logic to testable objects
- **Data transformations** — Test pure functions
- **AppState methods** — Test state mutations

### Manual Testing

Use Xcode Previews for rapid iteration:

```swift
#if DEBUG
struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView()
            .frame(width: 400, height: 300)
    }
}
#endif
```

## Accessing AppKit Services from SwiftUI

### Singletons

All major services are singletons accessible from SwiftUI:

```swift
// Characters, stages, engine state
AppState.shared.characters

// IKEMEN GO operations
IkemenBridge.shared.launchGame()

// Metadata database
MetadataStore.shared.updateCharacter(...)

// Image caching
ImageCache.shared.getImage(for: url)

// Settings
AppSettings.shared.ikemenPath
```

### Notifications

Subscribe to AppKit notifications:

```swift
.onReceive(NotificationCenter.default.publisher(for: .contentChanged)) { _ in
    // Refresh data
}
```

## Migration Strategy

### Phase 1: New Features Only
- All new dialogs/sheets use SwiftUI
- All new settings panels use SwiftUI
- Existing views remain AppKit

### Phase 2: Low-Risk Replacements
- About window → SwiftUI
- Simple settings panels → SwiftUI
- Toast notifications → SwiftUI (maybe)

### Phase 3: Complex Views (Future)
- Consider SwiftUI for complex views only if:
  - SwiftUI gains feature parity (drag-drop, collection views)
  - Performance is proven
  - Team has strong SwiftUI expertise

## Known Limitations

1. **No NSCollectionView equivalent** — SwiftUI's `LazyVGrid` is different
2. **Drag-and-drop** — AppKit's APIs are more mature
3. **Custom drawing** — AppKit's `CALayer` is more flexible
4. **Window management** — AppKit has finer control
5. **Menu bar** — AppKit required for custom menu items

## Examples

See `IKEMEN Lab/UI/SwiftUI/AboutView.swift` for a complete reference implementation.

## Questions?

- Check existing SwiftUI views in `IKEMEN Lab/UI/SwiftUI/`
- Review `SwiftUIBridge.swift` for integration patterns
- Ask in team chat or open a discussion

---

**Remember:** Don't rewrite working code. Use SwiftUI for new features where it shines.
