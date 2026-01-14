# Task: Establish SwiftUI Migration Path for New Views

## Context
IKEMEN Lab is built with AppKit (NSViewController, NSView, NSCollectionView). We want to enable SwiftUI for NEW views while keeping existing AppKit code working. This is a gradual migration, not a rewrite.

## Objective
Set up infrastructure to use SwiftUI for new views, hosted within the existing AppKit window structure.

## Technical Requirements

### 1. Create SwiftUI Hosting Infrastructure
Create: `IKEMEN Lab/Shared/SwiftUIBridge.swift`

```swift
import SwiftUI
import AppKit

/// Wraps a SwiftUI view for use in AppKit
class SwiftUIHostingView<Content: View>: NSView {
    private var hostingController: NSHostingController<Content>?
    
    init(rootView: Content) {
        super.init(frame: .zero)
        setupHosting(rootView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupHosting(_ rootView: Content) {
        let hostingController = NSHostingController(rootView: rootView)
        self.hostingController = hostingController
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    func updateRootView(_ rootView: Content) {
        hostingController?.rootView = rootView
    }
}

/// Protocol for AppKit-compatible SwiftUI views
protocol AppKitHostable: View {
    associatedtype HostView: NSView
    func makeHostView() -> HostView
}

extension AppKitHostable {
    func makeHostView() -> SwiftUIHostingView<Self> {
        SwiftUIHostingView(rootView: self)
    }
}
```

### 2. Create Design System for SwiftUI
Create: `IKEMEN Lab/Shared/DesignSystem.swift`

Bridge existing DesignColors/DesignFonts to SwiftUI:

```swift
import SwiftUI

// MARK: - SwiftUI Color Extensions
extension Color {
    static let zinc50 = Color(nsColor: DesignColors.zinc50)
    static let zinc100 = Color(nsColor: DesignColors.zinc100)
    // ... etc for all zinc colors
    
    static let textPrimary = Color(nsColor: DesignColors.textPrimary)
    static let textSecondary = Color(nsColor: DesignColors.textSecondary)
    static let cardBackground = Color(nsColor: DesignColors.cardBackground)
    static let borderSubtle = Color(nsColor: DesignColors.borderSubtle)
    static let accentBlue = Color(nsColor: DesignColors.accentBlue)
}

// MARK: - SwiftUI Font Extensions
extension Font {
    static func header(size: CGFloat) -> Font {
        Font.custom("Montserrat-Bold", size: size)
    }
    
    static func body(size: CGFloat) -> Font {
        Font.custom("Manrope-Medium", size: size)
    }
    
    static func caption(size: CGFloat) -> Font {
        Font.custom("Inter-Regular", size: size)
    }
}

// MARK: - Common View Modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderSubtle, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

### 3. Create Example SwiftUI View
Create: `IKEMEN Lab/UI/SwiftUI/AboutView.swift`

Simple example that could replace AboutWindowController:

```swift
import SwiftUI

struct AboutView: View, AppKitHostable {
    @State private var updateStatus: String = "Checking..."
    
    var body: some View {
        VStack(spacing: 24) {
            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
            
            // App Name & Version
            Text("IKEMEN Lab")
                .font(.header(size: 24))
                .foregroundColor(.textPrimary)
            
            Text("Version \(Bundle.main.appVersion)")
                .font(.body(size: 14))
                .foregroundColor(.textSecondary)
            
            // Update Status
            Text(updateStatus)
                .font(.caption(size: 12))
                .foregroundColor(.textSecondary)
            
            Spacer()
        }
        .padding(32)
        .frame(width: 300, height: 400)
        .background(Color.zinc900)
        .onAppear {
            checkForUpdates()
        }
    }
    
    private func checkForUpdates() {
        // Use existing UpdateChecker
    }
}

// Bundle extension for version
extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
```

### 4. Integration Pattern for GameWindowController
Show how to add SwiftUI views to the existing AppKit structure:

```swift
// In GameWindowController.swift
private func showSwiftUIView<V: View>(_ view: V) {
    let hostingView = SwiftUIHostingView(rootView: view)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    mainAreaView.addSubview(hostingView)
    
    NSLayoutConstraint.activate([
        hostingView.topAnchor.constraint(equalTo: contentHeaderView.bottomAnchor, constant: 16),
        hostingView.leadingAnchor.constraint(equalTo: mainAreaView.leadingAnchor, constant: 24),
        hostingView.trailingAnchor.constraint(equalTo: mainAreaView.trailingAnchor, constant: -24),
        hostingView.bottomAnchor.constraint(equalTo: mainAreaView.bottomAnchor, constant: -24),
    ])
}
```

### 5. Observable Object for Shared State
Create: `IKEMEN Lab/Shared/AppState.swift`

```swift
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var characters: [CharacterInfo] = []
    @Published var stages: [StageInfo] = []
    @Published var selectedCharacter: CharacterInfo?
    @Published var ikemenPath: URL?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Sync with EmulatorBridge
        EmulatorBridge.shared.$characters
            .receive(on: DispatchQueue.main)
            .assign(to: &$characters)
    }
}
```

## Files to Create
1. `IKEMEN Lab/Shared/SwiftUIBridge.swift` - Hosting infrastructure
2. `IKEMEN Lab/Shared/DesignSystem.swift` - SwiftUI design tokens
3. `IKEMEN Lab/Shared/AppState.swift` - Observable state object
4. `IKEMEN Lab/UI/SwiftUI/` - Directory for new SwiftUI views

## Files to Modify
1. `IKEMEN Lab.xcodeproj` - Ensure SwiftUI framework is linked

## Migration Guidelines Document
Create: `docs/swiftui-migration.md`

Document:
- When to use SwiftUI vs AppKit
- How to access singletons from SwiftUI
- Design system usage
- Testing SwiftUI views
- Known limitations (no NSCollectionView equivalent, etc.)

## Recommended First SwiftUI Views
1. Settings view (simple form layout)
2. About window (static content)
3. Collection editor (forms + pickers)
4. New dialogs/sheets

## NOT Recommended for SwiftUI Yet
1. CharacterBrowserView (complex NSCollectionView)
2. Dashboard (complex layout)
3. Any view needing drag-and-drop
