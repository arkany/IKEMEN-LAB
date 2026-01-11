import Foundation
import AppKit

// MARK: - Screenpack Components

/// Components that can be included in a screenpack
public struct ScreenpackComponents: OptionSet, Hashable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let titleScreen = ScreenpackComponents(rawValue: 1 << 0)
    public static let selectScreen = ScreenpackComponents(rawValue: 1 << 1)
    public static let vsScreen = ScreenpackComponents(rawValue: 1 << 2)
    public static let fightScreen = ScreenpackComponents(rawValue: 1 << 3)  // Lifebars
    public static let continueScreen = ScreenpackComponents(rawValue: 1 << 4)
    public static let victoryScreen = ScreenpackComponents(rawValue: 1 << 5)
    public static let optionsScreen = ScreenpackComponents(rawValue: 1 << 6)
    public static let storyboard = ScreenpackComponents(rawValue: 1 << 7)
    
    /// Human-readable names for display
    public var componentNames: [String] {
        var names: [String] = []
        if contains(.titleScreen) { names.append("Title Screen") }
        if contains(.selectScreen) { names.append("Select Screen") }
        if contains(.vsScreen) { names.append("VS Screen") }
        if contains(.fightScreen) { names.append("Lifebars") }
        if contains(.continueScreen) { names.append("Continue Screen") }
        if contains(.victoryScreen) { names.append("Victory Screen") }
        if contains(.optionsScreen) { names.append("Options Screen") }
        if contains(.storyboard) { names.append("Storyboard") }
        return names
    }
}

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
    public let components: ScreenpackComponents  // What's included
    public let selectRows: Int       // Character select grid rows
    public let selectColumns: Int    // Character select grid columns
    
    /// Whether this screenpack is currently active in Ikemen GO
    public var isActive: Bool = false
    
    /// Maximum character slots in the select screen (rows × columns)
    public var characterSlots: Int {
        return selectRows * selectColumns
    }
    
    /// Character limit string for display (e.g., "546 slots (14×39)")
    public var characterLimitString: String {
        if selectRows > 0 && selectColumns > 0 {
            return "\(characterSlots) slots (\(selectRows)×\(selectColumns))"
        }
        return "Unknown"
    }
    
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
    
    /// Component summary for display (e.g., "Lifebars, Select Screen, Title")
    public var componentSummary: String {
        let names = components.componentNames
        if names.isEmpty { return "Standard Screenpack" }
        return names.joined(separator: ", ")
    }
    
    /// Primary type of this screenpack for categorization
    /// Returns "Lifebar" if it only contains fight screen, "Storyboard" if primarily story content,
    /// otherwise "Screenpack" for full/mixed packs
    public var primaryType: String {
        // If only lifebars (fight screen), categorize as Lifebar
        if components == .fightScreen {
            return "Lifebar"
        }
        // If primarily storyboard content
        if components == .storyboard {
            return "Storyboard"
        }
        // If has storyboard plus intro elements only
        if components.isSubset(of: [.storyboard, .titleScreen]) && components.contains(.storyboard) {
            return "Storyboard"
        }
        // Full or mixed screenpack
        return "Screenpack"
    }
    
    /// Short description for list view subtitle
    public var shortDescription: String {
        switch primaryType {
        case "Lifebar":
            if let coord = localcoord {
                return coord.width >= 1280 ? "HD lifebar set" : "Classic lifebar set"
            }
            return "Custom lifebar set"
        case "Storyboard":
            return "Animated storyboard"
        default:
            if let coord = localcoord {
                return coord.width >= 1280 ? "HD screenpack" : "Standard screenpack"
            }
            return "Custom screenpack"
        }
    }
    
    public init(defFile: URL, isActive: Bool = false) {
        self.defFile = defFile
        self.isActive = isActive
        
        // ID is the folder name containing the screenpack
        let folderName = defFile.deletingLastPathComponent().lastPathComponent
        self.id = folderName
        
        // Parse system.def file
        let parsed = DEFParser.parse(url: defFile)
        let defContent = (DEFParser.readFileContent(from: defFile)?.lowercased()) ?? ""
        
        // Get name from [Info] section or filename
        let parsedName = parsed?.value(for: "name", inSection: "info") 
            ?? parsed?.name 
            ?? folderName.replacingOccurrences(of: "_", with: " ").capitalized
        
        self.name = parsedName
        self.author = parsed?.value(for: "author", inSection: "info") ?? parsed?.author ?? "Unknown"
        
        // Detect which components are included
        var detectedComponents: ScreenpackComponents = []
        
        // Check for component references in [Files] section or by file existence
        let folder = defFile.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        // Title screen
        if defContent.contains("[title info]") || defContent.contains("title =") ||
           fileManager.fileExists(atPath: folder.appendingPathComponent("title.def").path) {
            detectedComponents.insert(.titleScreen)
        }
        
        // Select screen  
        if defContent.contains("[select info]") || defContent.contains("select =") ||
           fileManager.fileExists(atPath: folder.appendingPathComponent("select.def").path) {
            detectedComponents.insert(.selectScreen)
        }
        
        // VS screen
        if defContent.contains("[vs screen]") || defContent.contains("vs =") ||
           fileManager.fileExists(atPath: folder.appendingPathComponent("vs.def").path) {
            detectedComponents.insert(.vsScreen)
        }
        
        // Fight screen (lifebars)
        if defContent.contains("fight =") || 
           fileManager.fileExists(atPath: folder.appendingPathComponent("fight.def").path) {
            detectedComponents.insert(.fightScreen)
        }
        
        // Continue screen
        if defContent.contains("[continue screen]") || defContent.contains("continue =") ||
           fileManager.fileExists(atPath: folder.appendingPathComponent("continue.def").path) {
            detectedComponents.insert(.continueScreen)
        }
        
        // Victory screen
        if defContent.contains("[victory screen]") || defContent.contains("victory =") ||
           fileManager.fileExists(atPath: folder.appendingPathComponent("victory.def").path) {
            detectedComponents.insert(.victoryScreen)
        }
        
        // Options screen
        if defContent.contains("[option info]") || defContent.contains("options =") {
            detectedComponents.insert(.optionsScreen)
        }
        
        // Storyboard
        if defContent.contains("storyboard") ||
           fileManager.fileExists(atPath: folder.appendingPathComponent("intro.def").path) {
            detectedComponents.insert(.storyboard)
        }
        
        self.components = detectedComponents
        
        // Get sprite file reference - typically "spr" in [Files] section
        if let sprName = parsed?.value(for: "spr", inSection: "files") {
            self.sffFile = folder.appendingPathComponent(sprName)
        } else if let sprite = parsed?.sprite {
            self.sffFile = folder.appendingPathComponent(sprite)
        } else {
            // Look for common screenpack sprite names
            let commonNames = ["system.sff", "screenpack.sff", "\(folderName).sff"]
            var foundSff: URL? = nil
            for name in commonNames {
                let sffPath = folder.appendingPathComponent(name)
                if fileManager.fileExists(atPath: sffPath.path) {
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
        
        // Get character select grid size from [Select Info] section
        // Format: rows = 14 ; columns = 39
        if let rowsStr = parsed?.value(for: "rows", inSection: "select info"),
           let rows = Int(rowsStr.trimmingCharacters(in: .whitespaces)) {
            self.selectRows = rows
        } else {
            self.selectRows = 0
        }
        
        if let colsStr = parsed?.value(for: "columns", inSection: "select info"),
           let cols = Int(colsStr.trimmingCharacters(in: .whitespaces)) {
            self.selectColumns = cols
        } else {
            self.selectColumns = 0
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
