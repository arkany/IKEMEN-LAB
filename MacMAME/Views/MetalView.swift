import Cocoa
import Metal
import MetalKit
import QuartzCore

/// Metal-backed view for rendering emulator frames
/// Uses CVDisplayLink for precise frame timing
class MetalView: NSView {
    
    // MARK: - Metal Objects
    
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var metalLayer: CAMetalLayer!
    private var pipelineState: MTLRenderPipelineState?
    
    // MARK: - Display Link
    
    private var displayLink: CVDisplayLink?
    private var isRendering: Bool = false
    private var isInTransition: Bool = false
    
    // MARK: - Emulator
    
    weak var emulatorBridge: EmulatorBridge?
    
    // MARK: - Performance Metrics
    
    #if DEBUG
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFAbsoluteTime = 0
    private var currentFPS: Double = 0
    #endif
    
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
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
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
        
        // Create render pipeline
        setupRenderPipeline()
        
        // Setup display link
        setupDisplayLink()
    }
    
    private func setupRenderPipeline() {
        // For now, use a simple passthrough shader
        // This will be replaced with proper texture blitting when MAME integration happens
        
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };
        
        vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
            // Full-screen quad
            float2 positions[4] = {
                float2(-1, -1),
                float2( 1, -1),
                float2(-1,  1),
                float2( 1,  1)
            };
            
            float2 texCoords[4] = {
                float2(0, 1),
                float2(1, 1),
                float2(0, 0),
                float2(1, 0)
            };
            
            VertexOut out;
            out.position = float4(positions[vertexID], 0, 1);
            out.texCoord = texCoords[vertexID];
            return out;
        }
        
        fragment float4 fragment_main(VertexOut in [[stage_in]],
                                      texture2d<float> texture [[texture(0)]]) {
            constexpr sampler s(filter::nearest);
            return texture.sample(s, in.texCoord);
        }
        
        // Placeholder fragment shader (shows test pattern when no texture)
        fragment float4 fragment_placeholder(VertexOut in [[stage_in]]) {
            // Classic test pattern - colored bars
            float x = in.texCoord.x;
            
            if (x < 0.125) return float4(1, 1, 1, 1);      // White
            if (x < 0.250) return float4(1, 1, 0, 1);      // Yellow
            if (x < 0.375) return float4(0, 1, 1, 1);      // Cyan
            if (x < 0.500) return float4(0, 1, 0, 1);      // Green
            if (x < 0.625) return float4(1, 0, 1, 1);      // Magenta
            if (x < 0.750) return float4(1, 0, 0, 1);      // Red
            if (x < 0.875) return float4(0, 0, 1, 1);      // Blue
            return float4(0, 0, 0, 1);                      // Black
        }
        """
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            let vertexFunction = library.makeFunction(name: "vertex_main")
            let fragmentFunction = library.makeFunction(name: "fragment_placeholder")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = metalLayer.pixelFormat
            
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline: \(error)")
        }
    }
    
    // MARK: - Display Link
    
    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        guard let displayLink = displayLink else { return }
        
        let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, userInfo) -> CVReturn in
            let view = Unmanaged<MetalView>.fromOpaque(userInfo!).takeUnretainedValue()
            view.renderFrame()
            return kCVReturnSuccess
        }
        
        CVDisplayLinkSetOutputCallback(displayLink, callback, Unmanaged.passUnretained(self).toOpaque())
    }
    
    // MARK: - Rendering Control
    
    func startRendering() {
        guard let displayLink = displayLink, !isRendering else { return }
        isRendering = true
        CVDisplayLinkStart(displayLink)
    }
    
    func stopRendering() {
        guard let displayLink = displayLink, isRendering else { return }
        isRendering = false
        CVDisplayLinkStop(displayLink)
    }
    
    func pauseForTransition() {
        isInTransition = true
    }
    
    func resumeFromTransition() {
        isInTransition = false
    }
    
    // MARK: - Frame Rendering
    
    private func renderFrame() {
        guard !isInTransition else { return }
        
        autoreleasepool {
            guard let drawable = metalLayer.nextDrawable(),
                  let pipelineState = pipelineState,
                  let commandBuffer = commandQueue.makeCommandBuffer() else {
                return
            }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
            
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            renderEncoder.setRenderPipelineState(pipelineState)
            
            // TODO: When emulator is integrated, get frame texture from emulatorBridge
            // For now, draw the test pattern
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
            #if DEBUG
            updateFPSCounter()
            #endif
        }
    }
    
    // MARK: - Performance Monitoring
    
    #if DEBUG
    private func updateFPSCounter() {
        frameCount += 1
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastFPSUpdate
        
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastFPSUpdate = now
            
            // FPS is available via currentFPS property for overlay display
            // Uncomment below for console logging:
            // print(String(format: "FPS: %.1f", currentFPS))
        }
    }
    #endif
    
    // MARK: - View Lifecycle
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if window != nil {
            // Update display link to match current display
            if let displayLink = displayLink,
               let screen = window?.screen,
               let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                CVDisplayLinkSetCurrentCGDisplay(displayLink, displayID)
            }
            
            // Update layer scale
            metalLayer.contentsScale = window?.backingScaleFactor ?? 2.0
        }
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer.drawableSize = convertToBacking(bounds).size
    }
    
    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        metalLayer.drawableSize = convertToBacking(bounds).size
    }
    
    // MARK: - Input Handling
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        emulatorBridge?.keyDown(keyCode: event.keyCode)
    }
    
    override func keyUp(with event: NSEvent) {
        emulatorBridge?.keyUp(keyCode: event.keyCode)
    }
}
