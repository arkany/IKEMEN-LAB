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
        
        /// `[Camera] zoomout` — the smallest scale the camera may reach.
        ///
        /// This is a divisor on the viewport, so **lower means further out**:
        /// 0.75 shows `1 / 0.75` of the normal area. 1.0 disables zoom-out.
        /// Values above 1 are meaningless and get clamped.
        ///
        /// A zoom-enabled stage needs a bigger backdrop — see
        /// `StageGeometry.minimumImageSize`.
        public var zoomOut: Double
        
        /// Where the ground sits in the *artwork*, in pixels from the top of
        /// the image. 0 means derive it from `StageGeometry.defaultFloorRatio`.
        ///
        /// This is an artwork coordinate, not a screen one; `StageGeometry`
        /// converts it. It has to be per-image because a backdrop's horizon is
        /// wherever it happens to be drawn.
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
    
    // MARK: - Stage Geometry

    /// The camera arithmetic, kept pure so it can be unit-tested without
    /// touching AppKit or the filesystem.
    ///
    /// ## Screen space
    ///
    /// Everything here is measured in `localcoord` units, in the space a
    /// `[BG ] start` is expressed in:
    ///
    /// - `y = 0` is the **top edge of the viewport**, not the floor.
    /// - `y = screenHeight` is the bottom edge.
    ///
    /// A `[BG ]` element places the sprite's *axis point* at its `start`. This
    /// generator writes sprites with axis `(0, 0)` and
    /// `start = (-imgWidth/2, -(imgHeight - screenHeight))`, which mounts the
    /// backdrop centred horizontally with its bottom edge flush against the
    /// bottom of the screen. So its top edge lands at
    /// `-(imgHeight - screenHeight)`, and that value — not the image height —
    /// is what the camera values are measured against.
    public enum StageGeometry {
        /// Where the ground sits in the artwork, as a fraction of image height,
        /// when the caller hasn't said. A backdrop's horizon is wherever the
        /// artist (or the image model) happened to put it, so this is only a
        /// starting point.
        public static let defaultFloorRatio: Double = 0.88

        /// Top edge of the backdrop in screen space, for a backdrop mounted
        /// flush with the bottom of the viewport. Negative when the artwork is
        /// taller than the screen, which is the usual case.
        public static func backdropTop(imageHeight: Int, screenHeight: Int) -> Int {
            -(imageHeight - screenHeight)
        }

        /// The `[StageInfo] zoffset` — where characters' feet land, measured
        /// from the top of the screen.
        ///
        /// This is a *screen* coordinate, so it has to be derived from where
        /// the backdrop was mounted. The previous implementation used
        /// `imageHeight - 75`, which is a coordinate in the *artwork*: for a
        /// 1024-tall backdrop it produced 949, some 229 units below the bottom
        /// of a 720-tall viewport, putting characters off-screen entirely.
        ///
        /// - Parameters:
        ///   - floorInImage: the ground line in artwork pixels from the top of
        ///     the image. Pass `nil` to fall back to `defaultFloorRatio`.
        public static func zoffset(
            imageHeight: Int,
            screenHeight: Int,
            floorInImage: Int? = nil
        ) -> Int {
            let top = backdropTop(imageHeight: imageHeight, screenHeight: screenHeight)
            let floor: Int
            if let given = floorInImage, given > 0 {
                floor = min(given, imageHeight)
            } else {
                floor = Int((Double(imageHeight) * defaultFloorRatio).rounded())
            }
            return top + floor
        }

        /// `zoomout` is a *divisor* on the viewport: at 0.75 the camera pulls
        /// back to show `1 / 0.75` of the normal area. Values above 1 are not
        /// meaningful, so they are clamped rather than written through.
        public static func normalizedZoomOut(_ zoomOut: Double) -> Double {
            guard zoomOut.isFinite, zoomOut > 0 else { return 1.0 }
            return min(zoomOut, 1.0)
        }

        /// How far the camera may travel left/right before the edge of the
        /// backdrop comes into view.
        ///
        /// Zooming out widens the visible area, so the slack between the
        /// artwork and the frame shrinks. Computing this against `screenWidth`
        /// while also writing a `zoomout` below 1 — which is what the previous
        /// implementation did — lets the camera scroll past the artwork the
        /// moment the stage zooms out.
        public static func horizontalBound(
            imageWidth: Int,
            screenWidth: Int,
            zoomOut: Double
        ) -> Int {
            let visibleWidth = Double(screenWidth) / normalizedZoomOut(zoomOut)
            let slack = (Double(imageWidth) - visibleWidth) / 2
            return max(0, Int(slack.rounded(.down)))
        }

        /// How far the camera may rise, as a negative number. Zero when the
        /// backdrop is no taller than the frame.
        ///
        /// Zoom-out grows the frame around the camera, so half the extra height
        /// eats into the headroom above.
        public static func boundHigh(
            imageHeight: Int,
            screenHeight: Int,
            zoomOut: Double
        ) -> Int {
            let visibleHeight = Double(screenHeight) / normalizedZoomOut(zoomOut)
            let extraHeight = max(0, visibleHeight - Double(screenHeight))
            let top = backdropTop(imageHeight: imageHeight, screenHeight: screenHeight)
            let headroom = Double(-top) - extraHeight / 2
            return -max(0, Int(headroom.rounded(.down)))
        }

        /// Smallest backdrop that still fills the frame at full zoom-out.
        /// Anything smaller shows past the artwork as soon as the camera pulls
        /// back.
        public static func minimumImageSize(
            screenWidth: Int,
            screenHeight: Int,
            zoomOut: Double
        ) -> (width: Int, height: Int) {
            let z = normalizedZoomOut(zoomOut)
            return (
                Int((Double(screenWidth) / z).rounded(.up)),
                Int((Double(screenHeight) / z).rounded(.up))
            )
        }
    }

    // MARK: - DEF File Generation

    private static func generateDEFContent(options: StageOptions, sffFileName: String, imageSize: NSSize) -> String {
        // HD stage format: 1280x720 localcoord for widescreen
        let screenWidth = 1280
        let screenHeight = 720

        let imgWidth = Int(imageSize.width)
        let imgHeight = Int(imageSize.height)

        // Values above 1 are not meaningful for zoomout, and every bound below
        // is computed against this same number, so clamp once here.
        let zoomOut = StageGeometry.normalizedZoomOut(options.zoomOut)

        // Floor position on screen, derived from where the ground sits in the
        // artwork rather than assumed to be a fixed distance from its bottom.
        let zoffset = StageGeometry.zoffset(
            imageHeight: imgHeight,
            screenHeight: screenHeight,
            floorInImage: options.floorLevel > 0 ? options.floorLevel : nil
        )

        // Camera bounds. Both account for zoomout: pulling the camera back
        // enlarges the visible area, which shrinks the slack the camera has to
        // move in before an edge of the backdrop shows.
        let cameraPanX = StageGeometry.horizontalBound(
            imageWidth: imgWidth,
            screenWidth: screenWidth,
            zoomOut: zoomOut
        )
        let boundLeft = -cameraPanX
        let boundRight = cameraPanX

        let boundhigh = StageGeometry.boundHigh(
            imageHeight: imgHeight,
            screenHeight: screenHeight,
            zoomOut: zoomOut
        )

        // Player movement bounds - limit to where the background exists
        let leftbound = -imgWidth / 2 + 50  // Leave some margin
        let rightbound = imgWidth / 2 - 50
        
        // Player start positions
        let p1startx = -150
        let p2startx = 150
        
        // Tile settings
        let tileX = options.tileHorizontal ? 1 : 0
        
        var content = """
        ; Stage generated by MacMugen
        ; Created from PNG image (\(imgWidth)x\(imgHeight))
        
        [Info]
        name = "\(options.name)"
        displayname = "\(options.name)"
        author = "\(options.author)"
        
        [Camera]
        startx = 0
        starty = 0
        boundleft = \(boundLeft)
        boundright = \(boundRight)
        boundhigh = \(boundhigh)
        boundlow = 0
        tension = 50
        tensionhigh = 0
        tensionlow = 0
        verticalfollow = 0.8
        floortension = 20
        overdrawhigh = 0
        overdrawlow = 0
        cuthigh = 0
        cutlow = 0
        zoomout = \(String(format: "%.2f", zoomOut))
        zoomin = 1.0
        
        [PlayerInfo]
        p1startx = \(p1startx)
        p1starty = 0
        p1facing = 1
        p2startx = \(p2startx)
        p2starty = 0
        p2facing = -1
        leftbound = \(leftbound)
        rightbound = \(rightbound)
        
        [Scaling]
        topz = 0
        botz = 50
        topscale = 1
        botscale = 1.2
        
        [Bound]
        screenleft = 15
        screenright = 15
        
        [StageInfo]
        zoffset = \(zoffset)
        zoffsetlink = 0
        autoturn = 1
        resetBG = 1
        localcoord = \(screenWidth), \(screenHeight)
        xscale = 1
        yscale = 1
        portraitscale = 4
        
        [Shadow]
        intensity = 96
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
        
        // Calculate BG start position to center the image
        // For an image larger than screen, center it horizontally and position floor at zoffset
        let bgStartX = -imgWidth / 2
        let bgStartY = -(imgHeight - screenHeight)  // Position so bottom aligns with screen bottom
        
        content += """
        
        [BGdef]
        spr = \(sffFileName)
        debugbg = 0
        
        ; Thumbnail animation for stage select
        [Begin Action 9000]
        9000,1, 0,0, -1
        
        [BG Main]
        type = normal
        spriteno = 0, 0
        layerno = 0
        start = \(bgStartX), \(bgStartY)
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
