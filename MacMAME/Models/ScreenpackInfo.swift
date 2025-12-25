import Foundation
import AppKit

// MARK: - Screenpack Info

/// Screenpack metadata parsed from system.def files
/// A screenpack defines the visual theme for menus, character select, fight UI, etc.
public struct ScreenpackInfo: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let author: String
    public let defFile: URL          // system.def path
    public let sffFile: URL?         // Sprite file for preview
    public let localcoord: (width: Int, height: Int)?  // Native resolution
    
    /// Whether this screenpack is currently active in Ikemen GO
    public var isActive: Bool = false
    
    /// Load preview image from screenpack SFF
    /// Typically uses sprite group 0 or a title screen element
    public func loadPreviewImage() -> NSImage? {
        guard let sff = sffFile else { return nil }
        return SFFParser.extractStagePreview(from: sff)
    }
    
    /// Resolution string for display (e.g., "1280x720")
    public var resolutionString: String {
        if let coord = localcoord {
            return "\(coord.width)x\(coord.height)"
        }
        return "Unknown"
    }
    
    public init(defFile: URL, isActive: Bool = false) {
        self.defFile = defFile
        self.isActive = isActive
        
        // ID is the folder name containing the screenpack
        let folderName = defFile.deletingLastPathComponent().lastPathComponent
        self.id = folderName
        
        // Parse system.def file
        let parsed = DEFParser.parse(url: defFile)
        
        // Get name from [Info] section or filename
        let parsedName = parsed?.value(for: "name", inSection: "info") 
            ?? parsed?.name 
            ?? folderName.replacingOccurrences(of: "_", with: " ").capitalized
        
        self.name = parsedName
        self.author = parsed?.value(for: "author", inSection: "info") ?? parsed?.author ?? "Unknown"
        
        // Get sprite file reference - typically "spr" in [Files] section
        if let sprName = parsed?.value(for: "spr", inSection: "files") {
            self.sffFile = defFile.deletingLastPathComponent().appendingPathComponent(sprName)
        } else if let sprite = parsed?.sprite {
            self.sffFile = defFile.deletingLastPathComponent().appendingPathComponent(sprite)
        } else {
            // Look for common screenpack sprite names
            let folder = defFile.deletingLastPathComponent()
            let commonNames = ["system.sff", "screenpack.sff", "\(folderName).sff"]
            var foundSff: URL? = nil
            for name in commonNames {
                let sffPath = folder.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: sffPath.path) {
                    foundSff = sffPath
                    break
                }
            }
            self.sffFile = foundSff
        }
        
        // Get native resolution from [Info] section
        if let coordStr = parsed?.value(for: "localcoord", inSection: "info") {
            let parts = coordStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, let width = Int(parts[0]), let height = Int(parts[1]) {
                self.localcoord = (width, height)
            } else {
                self.localcoord = nil
            }
        } else {
            self.localcoord = nil
        }
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ScreenpackInfo, rhs: ScreenpackInfo) -> Bool {
        lhs.id == rhs.id
    }
}
