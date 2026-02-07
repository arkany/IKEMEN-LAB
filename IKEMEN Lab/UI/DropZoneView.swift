import Cocoa

// MARK: - Drop Zone View

/// A view with dashed borders and drag-and-drop support for installing content files.
/// Accepts archive files (.zip, .rar, .7z) and folders.
class DropZoneView: NSView {
    
    var onFilesDropped: (([URL]) -> Void)?
    
    private var isDragging = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var label: NSTextField!
    private var sublineLabel: NSTextField!
    private var dashedBorderLayer: CAShapeLayer?
    
    private var borderColor: NSColor = NSColor(red: 0xfd/255.0, green: 0x4e/255.0, blue: 0x5b/255.0, alpha: 1.0)
    private var textColor: NSColor = NSColor(red: 0x7a/255.0, green: 0x84/255.0, blue: 0x8f/255.0, alpha: 1.0)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create dashed border using a shape layer
        let dashedBorder = CAShapeLayer()
        dashedBorder.strokeColor = borderColor.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [12, 8]
        dashedBorder.lineWidth = 4
        layer?.addSublayer(dashedBorder)
        self.dashedBorderLayer = dashedBorder
        
        // Register for drag types
        registerForDraggedTypes([.fileURL])
        
        // Cream text color per Figma
        let creamColor = NSColor(red: 0xff/255.0, green: 0xf0/255.0, blue: 0xe5/255.0, alpha: 1.0)
        
        // Main label - Montserrat header style
        label = NSTextField(labelWithString: "Drop characters or\nstages here")
        label.font = DesignFonts.header(size: 20)
        label.textColor = creamColor
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        // Subline label - body style
        sublineLabel = NSTextField(labelWithString: "(.zip, .rar, .7z or folder)")
        sublineLabel.font = DesignFonts.body(size: 14)
        sublineLabel.textColor = creamColor
        sublineLabel.alignment = .center
        sublineLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sublineLabel)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -12),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            
            sublineLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sublineLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
        ])
    }
    
    override func layout() {
        super.layout()
        
        // Update dashed border path to match bounds
        let path = CGPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), cornerWidth: 16, cornerHeight: 16, transform: nil)
        dashedBorderLayer?.path = path
        dashedBorderLayer?.frame = bounds
    }
    
    func applyFigmaStyle(borderColor: NSColor, textColor: NSColor, font: NSFont) {
        self.borderColor = borderColor
        self.textColor = textColor
        
        dashedBorderLayer?.strokeColor = borderColor.cgColor
        // Keep cream color for text per Figma
        let creamColor = NSColor(red: 0xff/255.0, green: 0xf0/255.0, blue: 0xe5/255.0, alpha: 1.0)
        label.textColor = creamColor
        label.font = DesignFonts.header(size: 20)
        sublineLabel.textColor = creamColor
        sublineLabel.font = DesignFonts.body(size: 14)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if isDragging {
            dashedBorderLayer?.strokeColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.4, alpha: 1.0).cgColor
            layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.3, blue: 0.2, alpha: 0.2).cgColor
        } else {
            dashedBorderLayer?.strokeColor = borderColor.cgColor
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    // MARK: - Drag & Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasValidFiles(sender) {
            isDragging = true
            return .copy
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return hasValidFiles(sender) ? .copy : []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return hasValidFiles(sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return false
        }
        
        let archiveExts = ["zip", "rar", "7z"]
        let validURLs = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            if archiveExts.contains(ext) { return true }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                return isDirectory.boolValue
            }
            return false
        }
        
        if !validURLs.isEmpty {
            onFilesDropped?(validURLs)
            return true
        }
        
        return false
    }
    
    private func hasValidFiles(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return false
        }
        
        let archiveExts = ["zip", "rar", "7z"]
        return urls.contains { url in
            let ext = url.pathExtension.lowercased()
            if archiveExts.contains(ext) { return true }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                return isDirectory.boolValue
            }
            return false
        }
    }
}
