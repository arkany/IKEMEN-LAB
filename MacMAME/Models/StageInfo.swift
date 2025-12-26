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
    
    public init(defFile: URL) {
        self.defFile = defFile
        self.id = defFile.deletingPathExtension().lastPathComponent
        
        // Parse .def file using shared parser
        let parsed = DEFParser.parse(url: defFile)
        
        // Get name - prefer displayname for stages
        let parsedName = parsed?.displayName ?? parsed?.name ?? defFile.deletingPathExtension().lastPathComponent
        
        self.name = parsedName
        self.author = parsed?.author ?? "Unknown"
        
        // Get camera bounds from [Camera] section
        let bounds = parsed?.cameraBounds ?? (left: -150, right: 150)
        self.boundLeft = bounds.left
        self.boundRight = bounds.right
        
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
        } else {
            self.sffFile = nil
        }
    }
}
