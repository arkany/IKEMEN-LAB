import Foundation
import AppKit

/// Generates complete Ikemen GO stage packages from PNG images
/// Creates both the SFF sprite file and the .def stage definition file
public final class StageGenerator {
    
    // MARK: - Errors
    
    public enum StageGenerationError: LocalizedError {
        case imageLoadFailed(URL)
        case invalidImageSize(width: Int, height: Int)
        case imageTooLarge(width: Int, height: Int)
        case directoryCreationFailed(String)
        case sffWriteFailed(String)
        case defWriteFailed(String)
        case featureDisabled
        
        public var errorDescription: String? {
            switch self {
            case .imageLoadFailed(let url):
                return "Failed to load image: \(url.lastPathComponent)"
            case .invalidImageSize(let width, let height):
                return "Image too small (\(width)x\(height)). Minimum size is 320x240 pixels."
            case .imageTooLarge(let width, let height):
                return "Image too large (\(width)x\(height)). Maximum recommended size is 4096x4096 pixels."
            case .directoryCreationFailed(let detail):
                return "Failed to create stage directory: \(detail)"
            case .sffWriteFailed(let detail):
                return "Failed to create sprite file: \(detail)"
            case .defWriteFailed(let detail):
                return "Failed to create definition file: \(detail)"
            case .featureDisabled:
                return "PNG stage creation is disabled in settings"
            }
        }
    }
    
    // MARK: - Stage Options
    
    /// Configuration options for stage generation
    public struct StageOptions {
        /// Display name for the stage
        public var name: String
        
        /// Author name
        public var author: String
        
        /// Camera left bound (negative = wider view to left)
        public var boundLeft: Int
        
        /// Camera right bound (positive = wider view to right)
        public var boundRight: Int
        
        /// Zoom level (1.0 = normal, higher = zoomed out)
        public var zoomOut: Double
        
        /// Floor level (Y position where characters stand)
        public var floorLevel: Int
        
        /// Whether to tile the background horizontally
        public var tileHorizontal: Bool
        
        /// Background music file (optional)
        public var bgmFile: String?
        
        public init(
            name: String,
            author: String = "MacMugen",
            boundLeft: Int = -150,
            boundRight: Int = 150,
            zoomOut: Double = 1.0,
            floorLevel: Int = 0,
            tileHorizontal: Bool = false,
            bgmFile: String? = nil
        ) {
            self.name = name
            self.author = author
            self.boundLeft = boundLeft
            self.boundRight = boundRight
            self.zoomOut = zoomOut
            self.floorLevel = floorLevel
            self.tileHorizontal = tileHorizontal
            self.bgmFile = bgmFile
        }
        
        /// Create options with defaults from AppSettings
        public static func withDefaults(name: String) -> StageOptions {
            let settings = AppSettings.shared
            return StageOptions(
                name: name,
                author: "MacMugen",
                boundLeft: settings.defaultStageBoundLeft,
                boundRight: settings.defaultStageBoundRight,
                zoomOut: settings.defaultStageZoom
            )
        }
    }
    
    // MARK: - Generation Result
    
    /// Result of successful stage generation
    public struct GeneratedStage {
        /// URL to the generated .def file
        public let defFile: URL
        
        /// URL to the generated .sff file
        public let sffFile: URL
        
        /// URL to the stage directory
        public let stageDirectory: URL
        
        /// The stage name used
        public let stageName: String
    }
    
    // MARK: - Public API
    
    /// Generate a complete stage package from a PNG image
    /// - Parameters:
    ///   - pngURL: URL to the source PNG image
    ///   - stagesDirectory: The Ikemen GO stages directory
    ///   - options: Configuration options for the stage
    /// - Returns: Result containing the generated stage info or an error
    public static func generate(
        from pngURL: URL,
        in stagesDirectory: URL,
        options: StageOptions
    ) -> Result<GeneratedStage, StageGenerationError> {
        // Check if feature is enabled
        guard AppSettings.shared.enablePNGStageCreation else {
            return .failure(.featureDisabled)
        }
        
        // Load the image
        guard let image = NSImage(contentsOf: pngURL) else {
            return .failure(.imageLoadFailed(pngURL))
        }
        
        // Validate image size
        let size = image.size
        let width = Int(size.width)
        let height = Int(size.height)
        
        guard width >= 320 && height >= 240 else {
            return .failure(.invalidImageSize(width: width, height: height))
        }
        
        // Warn about very large images (Ikemen GO may have performance issues)
        if width > 4096 || height > 4096 {
            return .failure(.imageTooLarge(width: width, height: height))
        }
        
        // Create a safe directory name from the stage name
        let safeName = options.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        let stageDir = stagesDirectory.appendingPathComponent(safeName)
        
        // Create stage directory
        do {
            try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        } catch {
            return .failure(.directoryCreationFailed(error.localizedDescription))
        }
        
        // Generate SFF file
        let sffFile = stageDir.appendingPathComponent("\(safeName).sff")
        let sffResult = SFFWriter.writeStageBackground(image: image, to: sffFile)
        
        switch sffResult {
        case .failure(let error):
            return .failure(.sffWriteFailed(error.localizedDescription))
        case .success:
            break
        }
        
        // Generate .def file
        let defFile = stageDir.appendingPathComponent("\(safeName).def")
        let defContent = generateDEFContent(options: options, sffFileName: "\(safeName).sff", imageSize: size)
        
        do {
            try defContent.write(to: defFile, atomically: true, encoding: .utf8)
        } catch {
            return .failure(.defWriteFailed(error.localizedDescription))
        }
        
        return .success(GeneratedStage(
            defFile: defFile,
            sffFile: sffFile,
            stageDirectory: stageDir,
            stageName: options.name
        ))
    }
    
    /// Generate a stage from an image object
    /// - Parameters:
    ///   - image: The source image
    ///   - stagesDirectory: The Ikemen GO stages directory
    ///   - options: Configuration options for the stage
    /// - Returns: Result containing the generated stage info or an error
    public static func generate(
        from image: NSImage,
        in stagesDirectory: URL,
        options: StageOptions
    ) -> Result<GeneratedStage, StageGenerationError> {
        // Check if feature is enabled
        guard AppSettings.shared.enablePNGStageCreation else {
            return .failure(.featureDisabled)
        }
        
        // Validate image size
        let size = image.size
        let width = Int(size.width)
        let height = Int(size.height)
        
        guard width >= 320 && height >= 240 else {
            return .failure(.invalidImageSize(width: width, height: height))
        }
        
        // Warn about very large images (Ikemen GO may have performance issues)
        if width > 4096 || height > 4096 {
            return .failure(.imageTooLarge(width: width, height: height))
        }
        
        // Create a safe directory name from the stage name
        let safeName = options.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        
        let stageDir = stagesDirectory.appendingPathComponent(safeName)
        
        // Create stage directory
        do {
            try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        } catch {
            return .failure(.directoryCreationFailed(error.localizedDescription))
        }
        
        // Generate SFF file
        let sffFile = stageDir.appendingPathComponent("\(safeName).sff")
        let sffResult = SFFWriter.writeStageBackground(image: image, to: sffFile)
        
        switch sffResult {
        case .failure(let error):
            return .failure(.sffWriteFailed(error.localizedDescription))
        case .success:
            break
        }
        
        // Generate .def file
        let defFile = stageDir.appendingPathComponent("\(safeName).def")
        let defContent = generateDEFContent(options: options, sffFileName: "\(safeName).sff", imageSize: size)
        
        do {
            try defContent.write(to: defFile, atomically: true, encoding: .utf8)
        } catch {
            return .failure(.defWriteFailed(error.localizedDescription))
        }
        
        return .success(GeneratedStage(
            defFile: defFile,
            sffFile: sffFile,
            stageDirectory: stageDir,
            stageName: options.name
        ))
    }
    
    // MARK: - DEF File Generation
    
    private static func generateDEFContent(options: StageOptions, sffFileName: String, imageSize: NSSize) -> String {
        // Calculate reasonable values based on image size
        let scaleFactor = 640.0 / imageSize.width  // Normalize to 640 width
        let scaledHeight = Int(imageSize.height * scaleFactor)
        // For a simple PNG background:
        // - The sprite should be centered horizontally (start X = 0 means center)
        // - The Y position should place the bottom of the image at the floor level
        // - Delta 1,1 means the background moves with the camera (static relative to stage)
        
        // Calculate Y start: In Mugen/Ikemen, positive Y is down
        // The floor is at Y=0 for characters, so we want the bottom of the image there
        // start Y should be negative (image drawn above the origin point)
        let bgY = Int(-imageSize.height) + 240  // Position so floor area is visible
        
        // Tile settings
        let tileX = options.tileHorizontal ? 1 : 0
        
        // Calculate proper bounds based on image width
        // For a centered image wider than 640, allow camera to pan
        let halfWidth = Int(imageSize.width) / 2
        let boundLeft = min(options.boundLeft, -(halfWidth - 320))
        let boundRight = max(options.boundRight, halfWidth - 320)
        
        var content = """
        ; Stage generated by MacMugen
        ; Created from PNG image
        
        [Info]
        name = "\(options.name)"
        displayname = "\(options.name)"
        author = "\(options.author)"
        
        [Camera]
        startx = 0
        starty = 0
        boundleft = \(boundLeft)
        boundright = \(boundRight)
        boundhigh = -25
        boundlow = 0
        tension = 50
        tensionhigh = 0
        tensionlow = 0
        verticalfollow = 0.2
        floortension = 0
        overdrawhigh = 0
        overdrawlow = 0
        cuthigh = 0
        cutlow = 0
        zoomout = \(String(format: "%.1f", options.zoomOut))
        zoomin = 1.0
        
        [PlayerInfo]
        p1startx = -70
        p1starty = 0
        p1facing = 1
        p2startx = 70
        p2starty = 0
        p2facing = -1
        leftbound = \(boundLeft - 50)
        rightbound = \(boundRight + 50)
        
        [Scaling]
        topz = 0
        botz = 50
        topscale = 1
        botscale = 1.2
        
        [Bound]
        screenleft = 15
        screenright = 15
        
        [StageInfo]
        zoffset = 0
        zoffsetlink = 0
        autoturn = 1
        resetBG = 1
        localcoord = 640, 480
        xscale = 1
        yscale = 1
        
        [Shadow]
        intensity = 64
        color = 0,0,0
        yscale = 0.3
        fade.range = 0, 0
        reflect = 0
        
        [Reflection]
        intensity = 0
        
        [Music]
        
        """
        
        // Add BGM if specified
        if let bgm = options.bgmFile {
            content += """
            bgmusic = \(bgm)
            bgmvolume = 100
            bgmloopstart = 0
            bgmloopend = 0
            
            """
        }
        
        content += """
        
        [BGdef]
        spr = \(sffFileName)
        debugbg = 0
        
        [BG Main]
        type = normal
        spriteno = 0, 0
        layerno = 0
        start = 0, \(bgY)
        delta = 1, 1
        mask = 0
        tile = \(tileX), 0
        tilespacing = 0, 0
        
        """
        
        return content
    }
    
    // MARK: - Select.def Registration
    
    /// Register a stage in select.def so it appears in Ikemen GO
    /// - Parameters:
    ///   - stagePath: Path to the stage .def file relative to the stages directory (e.g., "MyStage/MyStage.def")
    ///   - dataDirectory: The Ikemen GO data directory containing select.def
    /// - Returns: true if registration succeeded, false otherwise
    @discardableResult
    public static func registerStageInSelectDef(stagePath: String, dataDirectory: URL) -> Bool {
        let selectDefURL = dataDirectory.appendingPathComponent("select.def")
        
        guard FileManager.default.fileExists(atPath: selectDefURL.path) else {
            print("select.def not found at \(selectDefURL.path)")
            return false
        }
        
        do {
            var content = try String(contentsOf: selectDefURL, encoding: .utf8)
            
            // Check if stage is already registered
            let stageEntry = "stages/\(stagePath)"
            if content.contains(stageEntry) {
                print("Stage already registered: \(stageEntry)")
                return true
            }
            
            // Find [ExtraStages] section and add the stage after it
            if let range = content.range(of: "[ExtraStages]") {
                // Find the end of the line containing [ExtraStages]
                let searchStart = range.upperBound
                if let lineEnd = content[searchStart...].firstIndex(of: "\n") {
                    // Insert after the [ExtraStages] line
                    let insertionPoint = content.index(after: lineEnd)
                    content.insert(contentsOf: stageEntry + "\n", at: insertionPoint)
                    
                    try content.write(to: selectDefURL, atomically: true, encoding: .utf8)
                    print("Registered stage: \(stageEntry)")
                    return true
                }
            }
            
            print("Could not find [ExtraStages] section in select.def")
            return false
        } catch {
            print("Failed to update select.def: \(error)")
            return false
        }
    }
}
