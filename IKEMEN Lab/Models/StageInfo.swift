import Foundation
import AppKit

// MARK: - Stage Info

/// Stage metadata parsed from .def files
public struct StageInfo: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let author: String
    public let defFile: URL
    public let sffFile: URL?       // Sprite file for preview extraction
    public let boundLeft: Int      // Camera left bound (negative = wider stage)
    public let boundRight: Int     // Camera right bound (positive = wider stage)
    public var isDisabled: Bool    // Whether stage is commented out in select.def
    public let hasBGM: Bool        // Whether stage has background music defined
    public let modificationDate: Date?  // File modification date
    
    /// The .def filename for display
    public var defFileName: String {
        return defFile.lastPathComponent
    }
    
    /// Total horizontal camera range (larger = wider stage)
    public var totalWidth: Int {
        return boundRight - boundLeft
    }
    
    /// Whether this is a "wide" stage (>400 total width)
    public var isWideStage: Bool {
        return totalWidth > 400
    }
    
    /// Human-readable size category
    public var sizeCategory: String {
        if totalWidth <= 300 {
            return "Standard"
        } else if totalWidth <= 600 {
            return "Wide"
        } else {
            return "Extra Wide"
        }
    }
    
    /// Load preview image from stage SFF (background sprite)
    public func loadPreviewImage() -> NSImage? {
        guard let sff = sffFile else { return nil }
        return SFFParser.extractStagePreview(from: sff)
    }
    
    /// Automatically inferred tags based on file name, stage name, and author
    public var inferredTags: [String] {
        return TagDetector.shared.detectTags(for: self)
    }
    
    public init(defFile: URL, isDisabled: Bool = false) {
        self.defFile = defFile
        self.id = defFile.deletingPathExtension().lastPathComponent
        self.isDisabled = isDisabled
        
        // Get file modification date
        if let attrs = try? FileManager.default.attributesOfItem(atPath: defFile.path),
           let modDate = attrs[.modificationDate] as? Date {
            self.modificationDate = modDate
        } else {
            self.modificationDate = nil
        }
        
        // Parse .def file using shared parser
        let parsed = DEFParser.parse(url: defFile)
        
        // Get name - use special extractor that handles commented names
        // Some stage files have format: name = "O";"Avalon" where real name is in comment
        let extractedName = DEFParser.extractStageName(from: defFile)
        let fallbackName = defFile.deletingPathExtension().lastPathComponent
        
        // Use extracted name if valid, otherwise fall back to filename
        if let name = extractedName, !name.isEmpty, name.count > 2 {
            self.name = name
        } else {
            // Name is too short or missing - use cleaned-up filename
            self.name = fallbackName
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
        }
        
        self.author = parsed?.author ?? "Unknown"
        
        // Get camera bounds from [Camera] section
        let bounds = parsed?.cameraBounds ?? (left: -150, right: 150)
        self.boundLeft = bounds.left
        self.boundRight = bounds.right
        
        // Check if stage has background music defined
        self.hasBGM = parsed?.hasBGM ?? false
        
        // Get sprite file reference
        if let sprName = parsed?.spriteFile {
            // Normalize path separators (Windows backslashes to forward slashes)
            let normalizedPath = sprName.replacingOccurrences(of: "\\", with: "/")
            
            // Check if it's a root-relative path (e.g., "stages/Bifrost.sff")
            // vs a file-relative path (e.g., "Bifrost.sff")
            if normalizedPath.contains("/") {
                // Root-relative path - resolve from Ikemen GO working directory
                // Go up from stages/ folder to root, then append the path
                let rootDir = defFile.deletingLastPathComponent().deletingLastPathComponent()
                self.sffFile = rootDir.appendingPathComponent(normalizedPath)
            } else {
                // File-relative path - resolve from same directory as .def
                self.sffFile = defFile.deletingLastPathComponent().appendingPathComponent(normalizedPath)
            }
            
            // Debug: check if file exists
            if let sff = self.sffFile, !FileManager.default.fileExists(atPath: sff.path) {
                print("[StageInfo] WARNING: SFF not found: \(sff.path)")
            }
        } else {
            self.sffFile = nil
            print("[StageInfo] WARNING: No spriteFile for \(defFile.lastPathComponent)")
        }
    }
}
