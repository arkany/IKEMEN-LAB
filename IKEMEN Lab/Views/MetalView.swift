import Cocoa
import Metal
import MetalKit
import QuartzCore

/// Metal-backed view for rendering
/// Currently minimal - Ikemen GO handles its own rendering
/// Kept for future potential use (character previews, etc.)
class MetalView: NSView {
    
    // MARK: - Metal Objects
    
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var metalLayer: CAMetalLayer!
    
    // MARK: - Display Link
    
    private var displayLink: CVDisplayLink?
    private var isRendering: Bool = false
    private var isInTransition: Bool = false
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMetal()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
    }
    
    deinit {
        stopRendering()
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        // Get default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Failed to create Metal command queue")
            return
        }
        self.commandQueue = commandQueue
        
        // Configure layer
        wantsLayer = true
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.displaySyncEnabled = true
        metalLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        layer = metalLayer
        
        // Set initial drawable size
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }
    
    // MARK: - View Lifecycle
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }
    
    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        updateDrawableSize()
    }
    
    private func updateDrawableSize() {
        guard metalLayer != nil else { return }
        
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }
    
    // MARK: - Rendering Control
    
    func startRendering() {
        // Minimal implementation - kept for API compatibility
        isRendering = true
    }
    
    func stopRendering() {
        isRendering = false
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
    
    func pauseForTransition() {
        isInTransition = true
    }
    
    func resumeFromTransition() {
        isInTransition = false
    }
}
