import SwiftUI
import AppKit

// MARK: - SwiftUI Hosting Infrastructure

/// Wraps a SwiftUI view for use in AppKit
/// This allows embedding SwiftUI views inside existing NSViewController-based views
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
    
    /// Update the root view when state changes
    func updateRootView(_ rootView: Content) {
        hostingController?.rootView = rootView
    }
}

// MARK: - AppKit Hosting Protocol

/// Protocol for SwiftUI views that can be hosted in AppKit
/// Provides a convenient way to convert SwiftUI views to NSView
protocol AppKitHostable: View {
    associatedtype HostView: NSView
    func makeHostView() -> HostView
}

extension AppKitHostable {
    /// Default implementation creates a hosting view
    func makeHostView() -> SwiftUIHostingView<Self> {
        SwiftUIHostingView(rootView: self)
    }
}

// MARK: - View Controller Helpers

extension NSViewController {
    /// Embed a SwiftUI view as a child view controller
    /// This properly manages the view controller hierarchy
    func embedSwiftUIView<Content: View>(_ view: Content, in containerView: NSView) {
        let hostingController = NSHostingController(rootView: view)
        addChild(hostingController)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }
}
