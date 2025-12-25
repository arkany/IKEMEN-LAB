import Foundation
import AppKit

// MARK: - Character Info

/// Character metadata parsed from .def files
public struct CharacterInfo: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let displayName: String
    public let author: String
    public let versionDate: String
    public let spriteFile: String?
    public let directory: URL
    public let defFile: URL
    
    public init(directory: URL, defFile: URL) {
        self.directory = directory
        self.defFile = defFile
        self.id = directory.lastPathComponent
        
        // Parse .def file using shared parser
        let parsed = DEFParser.parse(url: defFile)
        
        let parsedName = parsed?.name ?? directory.lastPathComponent
        let parsedDisplayName = parsed?.displayName ?? parsedName
        
        self.name = parsedName
        // Prefer "name" over "displayname" as it's usually more descriptive
        self.displayName = parsedName.isEmpty ? parsedDisplayName : parsedName
        self.author = parsed?.author ?? "Unknown"
        self.versionDate = parsed?.versionDate ?? ""
        self.spriteFile = parsed?.spriteFile
    }
    
    /// Get the portrait image for this character
    /// Looks for portrait.png first, then extracts from SFF file
    public func getPortraitImage() -> NSImage? {
        let fileManager = FileManager.default
        
        // First check for portrait.png in character directory
        let portraitPng = directory.appendingPathComponent("portrait.png")
        if fileManager.fileExists(atPath: portraitPng.path),
           let image = NSImage(contentsOf: portraitPng) {
            return image
        }
        
        // Check for any .png file that might be a portrait
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in contents where file.pathExtension.lowercased() == "png" {
                let name = file.deletingPathExtension().lastPathComponent.lowercased()
                if name.contains("portrait") || name.contains("select") {
                    if let image = NSImage(contentsOf: file) {
                        return image
                    }
                }
            }
        }
        
        // Try to extract from SFF file - use the one specified in DEF if available
        if let spriteFileName = spriteFile {
            let sffFile = directory.appendingPathComponent(spriteFileName)
            if fileManager.fileExists(atPath: sffFile.path) {
                return SFFParser.extractPortrait(from: sffFile)
            }
        }
        
        // Fallback: look for any SFF file with same name as DEF or folder
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let sffFiles = contents.filter { $0.pathExtension.lowercased() == "sff" }
            let defName = defFile.deletingPathExtension().lastPathComponent.lowercased()
            let dirName = directory.lastPathComponent.lowercased()
            
            // Prefer SFF with same name as DEF or directory
            let preferredSff = sffFiles.first { sff in
                let sffName = sff.deletingPathExtension().lastPathComponent.lowercased()
                return sffName == defName || sffName == dirName
            }
            
            if let sffFile = preferredSff ?? sffFiles.first {
                return SFFParser.extractPortrait(from: sffFile)
            }
        }
        
        return nil
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: CharacterInfo, rhs: CharacterInfo) -> Bool {
        lhs.id == rhs.id
    }
}
