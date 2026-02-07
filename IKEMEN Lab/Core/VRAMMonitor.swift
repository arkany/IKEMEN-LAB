import Cocoa
import Metal

/// Monitors GPU VRAM usage via Metal and reports back via a closure.
/// Self-scheduling: once started, polls every 2 seconds until the owner is deallocated.
final class VRAMMonitor {
    
    /// Called on the main thread with (percentage: Double, formattedText: String)
    var onUpdate: ((Double, String) -> Void)?
    
    private var isRunning = false
    
    /// Start periodic VRAM monitoring. Calls `onUpdate` every 2 seconds.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        poll()
    }
    
    /// Stop monitoring.
    func stop() {
        isRunning = false
    }
    
    private func poll() {
        guard isRunning else { return }
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            onUpdate?(0, "N/A")
            return
        }
        
        let recommendedWorkingSet = device.recommendedMaxWorkingSetSize
        let currentAllocated = device.currentAllocatedSize
        
        let percentage: Double
        if recommendedWorkingSet > 0 {
            percentage = Double(currentAllocated) / Double(recommendedWorkingSet) * 100.0
        } else {
            percentage = 0
        }
        
        let percentText = String(format: "%.0f%%", min(percentage, 100))
        onUpdate?(min(percentage, 100), percentText)
        
        // Schedule next update
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.poll()
        }
    }
}
