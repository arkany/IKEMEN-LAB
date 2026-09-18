import XCTest
@testable import IKEMEN_Lab

/// Tests for the camera arithmetic behind generated stages.
///
/// The values asserted here are cross-checked against two real stages that are
/// known to work — Elecbyte's `stage0-720` and JoeStar's `CF3GRAVE` — and
/// against MUGEN Stage Studio, which derives the same geometry from the
/// opposite axis convention and arrives at the same rectangle.
final class StageGeometryTests: XCTestCase {

    private let screenWidth = 1280
    private let screenHeight = 720

    // MARK: - Backdrop placement

    /// The generator mounts the backdrop flush with the bottom of the frame, so
    /// its top edge is the only thing the vertical camera values care about.
    func testBackdropTopIsNegativeForATallBackdrop() {
        // A 1024-tall backdrop in a 720-tall frame hangs 304 units above it.
        XCTAssertEqual(
            StageGenerator.StageGeometry.backdropTop(imageHeight: 1024, screenHeight: screenHeight),
            -304
        )
    }

    func testBackdropTopIsZeroWhenTheArtworkExactlyFillsTheFrame() {
        XCTAssertEqual(
            StageGenerator.StageGeometry.backdropTop(imageHeight: 720, screenHeight: screenHeight),
            0
        )
    }

    // MARK: - zoffset

    /// The regression this file exists for. `zoffset` is a screen coordinate,
    /// so it must land inside the frame. The previous implementation returned
    /// `imageHeight - 75`, which for a 1024-tall backdrop was 949 — 229 units
    /// below the bottom of a 720-tall frame, putting characters off-screen.
    func testZoffsetLandsInsideTheFrame() {
        for imageHeight in [720, 1024, 1050, 1440, 2048] {
            let z = StageGenerator.StageGeometry.zoffset(
                imageHeight: imageHeight,
                screenHeight: screenHeight
            )
            XCTAssertGreaterThan(z, 0, "zoffset above the top of the frame for \(imageHeight)px")
            XCTAssertLessThanOrEqual(
                z, screenHeight,
                "zoffset below the bottom of the frame for a \(imageHeight)px backdrop"
            )
        }
    }

    func testZoffsetForTheCommonGeneratedSize() {
        // 1536x1024 is what image models tend to emit. Ground at 88% of the
        // artwork = row 901; the artwork's top is at -304; 901 - 304 = 597.
        XCTAssertEqual(
            StageGenerator.StageGeometry.zoffset(imageHeight: 1024, screenHeight: screenHeight),
            597
        )
    }

    /// An explicit ground line is converted from artwork space to screen space
    /// rather than used as-is.
    func testExplicitFloorIsConvertedToScreenSpace() {
        // CF3GRAVE: 1800x1050 artwork with its ground line 924 rows down.
        // 924 - (1050 - 720) = 594, which is the zoffset that stage ships.
        XCTAssertEqual(
            StageGenerator.StageGeometry.zoffset(
                imageHeight: 1050,
                screenHeight: screenHeight,
                floorInImage: 924
            ),
            594
        )
    }

    func testMovingTheFloorLineMovesZoffsetByTheSameAmount() {
        let a = StageGenerator.StageGeometry.zoffset(
            imageHeight: 1024, screenHeight: screenHeight, floorInImage: 900
        )
        let b = StageGenerator.StageGeometry.zoffset(
            imageHeight: 1024, screenHeight: screenHeight, floorInImage: 800
        )
        XCTAssertEqual(a - b, 100)
    }

    func testFloorLineCannotBeDraggedPastTheBottomOfTheArtwork() {
        let z = StageGenerator.StageGeometry.zoffset(
            imageHeight: 1024, screenHeight: screenHeight, floorInImage: 99_999
        )
        XCTAssertEqual(z, screenHeight, "clamped to the bottom edge of the frame")
    }

    // MARK: - zoomout normalisation

    /// `zoomout` is a divisor on the viewport, so values above 1 are not
    /// meaningful. They used to be written straight into the DEF.
    func testZoomOutIsClampedToSaneValues() {
        XCTAssertEqual(StageGenerator.StageGeometry.normalizedZoomOut(1.0), 1.0)
        XCTAssertEqual(StageGenerator.StageGeometry.normalizedZoomOut(0.75), 0.75)
        XCTAssertEqual(StageGenerator.StageGeometry.normalizedZoomOut(1.5), 1.0)
        XCTAssertEqual(StageGenerator.StageGeometry.normalizedZoomOut(0.0), 1.0)
        XCTAssertEqual(StageGenerator.StageGeometry.normalizedZoomOut(-2.0), 1.0)
    }

    // MARK: - Horizontal bounds

    func testHorizontalBoundMatchesTheClassicFormulaWithoutZoom() {
        // CF3GRAVE ships boundright = 260 for an 1800-wide backdrop.
        XCTAssertEqual(
            StageGenerator.StageGeometry.horizontalBound(
                imageWidth: 1800, screenWidth: screenWidth, zoomOut: 1.0
            ),
            260
        )
        XCTAssertEqual(
            StageGenerator.StageGeometry.horizontalBound(
                imageWidth: 1536, screenWidth: screenWidth, zoomOut: 1.0
            ),
            128
        )
    }

    /// The other regression. Writing `zoomout` while computing bounds against
    /// the un-zoomed frame lets the camera travel past the artwork as soon as
    /// the stage pulls back.
    func testZoomingOutShrinksTheHorizontalBound() {
        let noZoom = StageGenerator.StageGeometry.horizontalBound(
            imageWidth: 1800, screenWidth: screenWidth, zoomOut: 1.0
        )
        let zoomed = StageGenerator.StageGeometry.horizontalBound(
            imageWidth: 1800, screenWidth: screenWidth, zoomOut: 0.75
        )
        // Visible width becomes 1280 / 0.75 = 1706.67, leaving (1800 - 1706.67) / 2.
        XCTAssertEqual(noZoom, 260)
        XCTAssertEqual(zoomed, 46)
        XCTAssertLessThan(zoomed, noZoom)
    }

    func testBoundIsZeroWhenTheBackdropCannotEvenFillTheZoomedFrame() {
        // 1536 wide against a 1706-wide zoomed frame: no room to scroll at all.
        XCTAssertEqual(
            StageGenerator.StageGeometry.horizontalBound(
                imageWidth: 1536, screenWidth: screenWidth, zoomOut: 0.75
            ),
            0
        )
    }

    func testHorizontalBoundNeverGoesNegative() {
        XCTAssertEqual(
            StageGenerator.StageGeometry.horizontalBound(
                imageWidth: 640, screenWidth: screenWidth, zoomOut: 1.0
            ),
            0
        )
    }

    // MARK: - Vertical bound

    func testBoundHighTracksTheTopOfTheArtwork() {
        XCTAssertEqual(
            StageGenerator.StageGeometry.boundHigh(
                imageHeight: 1024, screenHeight: screenHeight, zoomOut: 1.0
            ),
            -304
        )
    }

    func testZoomingOutShrinksTheVerticalBound() {
        let noZoom = StageGenerator.StageGeometry.boundHigh(
            imageHeight: 1024, screenHeight: screenHeight, zoomOut: 1.0
        )
        let zoomed = StageGenerator.StageGeometry.boundHigh(
            imageHeight: 1024, screenHeight: screenHeight, zoomOut: 0.75
        )
        // Visible height 960, so 240 extra; half of it eats into the headroom.
        XCTAssertEqual(zoomed, -184)
        XCTAssertGreaterThan(zoomed, noZoom, "less headroom when zoomed out")
    }

    func testBoundHighIsZeroWhenThereIsNoHeadroom() {
        XCTAssertEqual(
            StageGenerator.StageGeometry.boundHigh(
                imageHeight: 720, screenHeight: screenHeight, zoomOut: 1.0
            ),
            0
        )
    }

    /// Whatever the inputs, the camera must not be allowed above the artwork.
    func testBoundHighNeverExceedsTheArtwork() {
        for imageHeight in [720, 900, 1024, 1440, 2048] {
            for zoomOut in [1.0, 0.9, 0.75, 0.6] {
                let top = StageGenerator.StageGeometry.backdropTop(
                    imageHeight: imageHeight, screenHeight: screenHeight
                )
                let high = StageGenerator.StageGeometry.boundHigh(
                    imageHeight: imageHeight, screenHeight: screenHeight, zoomOut: zoomOut
                )
                XCTAssertGreaterThanOrEqual(
                    high, top,
                    "boundhigh \(high) scrolls past artwork top \(top) at \(imageHeight)px / \(zoomOut)"
                )
                XCTAssertLessThanOrEqual(high, 0, "boundhigh is never positive")
            }
        }
    }

    // MARK: - Minimum backdrop

    func testMinimumImageSizeAccountsForZoom() {
        let none = StageGenerator.StageGeometry.minimumImageSize(
            screenWidth: screenWidth, screenHeight: screenHeight, zoomOut: 1.0
        )
        XCTAssertEqual(none.width, 1280)
        XCTAssertEqual(none.height, 720)

        let zoomed = StageGenerator.StageGeometry.minimumImageSize(
            screenWidth: screenWidth, screenHeight: screenHeight, zoomOut: 0.75
        )
        XCTAssertEqual(zoomed.width, 1707)
        XCTAssertEqual(zoomed.height, 960)
    }

    /// A backdrop at the stated minimum must actually produce usable bounds,
    /// otherwise the number is advice nobody can act on.
    func testABackdropAtTheMinimumProducesNonNegativeBounds() {
        for zoomOut in [1.0, 0.9, 0.75, 0.6] {
            let min = StageGenerator.StageGeometry.minimumImageSize(
                screenWidth: screenWidth, screenHeight: screenHeight, zoomOut: zoomOut
            )
            XCTAssertGreaterThanOrEqual(
                StageGenerator.StageGeometry.horizontalBound(
                    imageWidth: min.width, screenWidth: screenWidth, zoomOut: zoomOut
                ),
                0
            )
        }
    }
}
