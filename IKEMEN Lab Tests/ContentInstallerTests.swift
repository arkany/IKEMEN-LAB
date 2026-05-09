import XCTest
@testable import IKEMEN_Lab

/// Tests for ContentInstaller helpers that don't require real archive
/// extraction. We focus on:
///   * findCharacterDefEntry (path resolution logic)
///   * validateCharacterPortrait (warning generation)
///   * redirectScreenpackToGlobalSelectDef (system.def rewriting)
///   * redirectAllScreenpacksToGlobalSelectDef (folder scanning)
///   * installContentFolder content-type detection (character vs stage vs screenpack)
///
/// Archive extraction (zip/rar/7z/ace) and full installCharacter / installStage
/// flows are not exercised here because they invoke external binaries
/// (`ditto`, `unrar`, etc.) and singletons (MetadataStore, ImageCache) that
/// aren't trivially mockable in unit tests.
final class ContentInstallerTests: XCTestCase {

    var workingDir: URL!

    override func setUp() {
        super.setUp()
        workingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContentInstallerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: workingDir)
        workingDir = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Create a folder containing a character-style def file (with [Files] +
    /// .cmd/.cns/.air references).
    @discardableResult
    private func makeCharacterFolder(named folderName: String, defName: String? = nil) throws -> URL {
        let folder = workingDir.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let defFile = folder.appendingPathComponent("\(defName ?? folderName).def")
        let contents = """
        [Info]
        name = \(folderName)
        author = Test
        [Files]
        cmd = \(folderName).cmd
        cns = \(folderName).cns
        air = \(folderName).air
        sprite = \(folderName).sff
        """
        try contents.write(to: defFile, atomically: true, encoding: .utf8)
        return folder
    }

    // MARK: - findCharacterDefEntry

    func testFindCharacterDefEntryReturnsBareNameForExactCaseMatch() throws {
        let folder = try makeCharacterFolder(named: "kfm")
        let entry = ContentInstaller.shared.findCharacterDefEntry(charName: "kfm", in: folder)
        XCTAssertEqual(entry, "kfm",
                       "Folder/folder.def with exact case match should produce bare-name entry")
    }

    func testFindCharacterDefEntryReturnsExplicitPathForMismatchedCase() throws {
        // Folder is "Bbhood" but def is "BBHood.def".
        let folder = workingDir.appendingPathComponent("Bbhood")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let defFile = folder.appendingPathComponent("BBHood.def")
        let contents = """
        [Info]
        name = BBHood
        [Files]
        cmd = bbhood.cmd
        cns = bbhood.cns
        air = bbhood.air
        """
        try contents.write(to: defFile, atomically: true, encoding: .utf8)

        let entry = ContentInstaller.shared.findCharacterDefEntry(charName: "Bbhood", in: folder)
        XCTAssertEqual(entry, "Bbhood/BBHood.def")
    }

    func testFindCharacterDefEntrySkipsStoryboardDefs() throws {
        let folder = workingDir.appendingPathComponent("Hero")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Storyboard-style def
        let intro = folder.appendingPathComponent("intro.def")
        try "[SceneDef]\nspr = intro.sff\n".write(to: intro, atomically: true, encoding: .utf8)
        // Real character def
        let charDef = folder.appendingPathComponent("Hero.def")
        try """
        [Info]
        name = Hero
        [Files]
        cmd = hero.cmd
        """.write(to: charDef, atomically: true, encoding: .utf8)

        let entry = ContentInstaller.shared.findCharacterDefEntry(charName: "Hero", in: folder)
        XCTAssertEqual(entry, "Hero", "Storyboard intro.def should be ignored when picking entry")
    }

    func testFindCharacterDefEntryFallsBackToFolderNameWhenEmpty() throws {
        let folder = workingDir.appendingPathComponent("Empty")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let entry = ContentInstaller.shared.findCharacterDefEntry(charName: "Empty", in: folder)
        XCTAssertEqual(entry, "Empty")
    }

    // MARK: - validateCharacterPortrait

    func testValidateCharacterPortraitWarnsWhenNoSff() throws {
        let folder = try makeCharacterFolder(named: "kfm")
        let warnings = ContentInstaller.shared.validateCharacterPortrait(in: folder)
        XCTAssertTrue(warnings.contains("No sprite file found"))
    }

    func testValidateCharacterPortraitReturnsEmptyForUnreadableSff() throws {
        // An empty .sff file isn't valid SFFv1, so dimension check returns nil
        // and no large/missing-portrait warning is emitted. The test covers the
        // "unreadable but present" branch.
        let folder = try makeCharacterFolder(named: "kfm")
        let sff = folder.appendingPathComponent("kfm.sff")
        try Data().write(to: sff)

        let warnings = ContentInstaller.shared.validateCharacterPortrait(in: folder)
        XCTAssertFalse(warnings.contains("No sprite file found"))
        // No portrait dimensions parseable from empty file → no extra warning.
        XCTAssertTrue(warnings.isEmpty)
    }

    // MARK: - redirectScreenpackToGlobalSelectDef

    func testRedirectScreenpackRewritesSelectDefReference() throws {
        let folder = workingDir.appendingPathComponent("MyPack")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let systemDef = folder.appendingPathComponent("system.def")
        try """
        [Info]
        name = MyPack
        [Files]
        select = select.def
        fight = fight.def
        """.write(to: systemDef, atomically: true, encoding: .utf8)

        ContentInstaller.shared.redirectScreenpackToGlobalSelectDef(screenpackPath: folder)

        let content = try String(contentsOf: systemDef, encoding: .utf8)
        XCTAssertTrue(content.contains("../select.def"),
                      "system.def should now reference the global select.def via relative path")
        // The original "select = select.def" line should be replaced with the
        // relative-path form. Verify there's no remaining occurrence of
        // "= select.def" without the "../" prefix.
        XCTAssertFalse(content.contains("= select.def"),
                       "Original local select.def reference should be replaced")
    }

    func testRedirectScreenpackIsNoopWhenSystemDefMissing() throws {
        let folder = workingDir.appendingPathComponent("EmptyPack")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // Should not throw or modify anything.
        ContentInstaller.shared.redirectScreenpackToGlobalSelectDef(screenpackPath: folder)

        let systemDef = folder.appendingPathComponent("system.def")
        XCTAssertFalse(FileManager.default.fileExists(atPath: systemDef.path))
    }

    func testRedirectAllScreenpacksOnlyTouchesPacksWithLocalSelectDef() throws {
        let dataDir = workingDir.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        // Pack A: has local select.def → should be redirected.
        let packA = dataDir.appendingPathComponent("PackA")
        try FileManager.default.createDirectory(at: packA, withIntermediateDirectories: true)
        try """
        [Info]
        name = PackA
        [Files]
        select = select.def
        """.write(to: packA.appendingPathComponent("system.def"), atomically: true, encoding: .utf8)
        try "[Characters]\n".write(to: packA.appendingPathComponent("select.def"), atomically: true, encoding: .utf8)

        // Pack B: no local select.def → should NOT be redirected.
        let packB = dataDir.appendingPathComponent("PackB")
        try FileManager.default.createDirectory(at: packB, withIntermediateDirectories: true)
        try """
        [Info]
        name = PackB
        [Files]
        select = select.def
        """.write(to: packB.appendingPathComponent("system.def"), atomically: true, encoding: .utf8)

        let count = ContentInstaller.shared.redirectAllScreenpacksToGlobalSelectDef(in: workingDir)
        XCTAssertEqual(count, 1)

        let packAContent = try String(contentsOf: packA.appendingPathComponent("system.def"), encoding: .utf8)
        XCTAssertTrue(packAContent.contains("../select.def"))

        let packBContent = try String(contentsOf: packB.appendingPathComponent("system.def"), encoding: .utf8)
        XCTAssertFalse(packBContent.contains("../select.def"))
    }

    // MARK: - installContentFolder dispatching

    /// installContentFolder dispatches to installScreenpack for a folder
    /// containing a screenpack-style system.def. installScreenpack is safe to
    /// run because it only touches files (no MetadataStore call).
    func testInstallContentFolderDispatchesToScreenpack() throws {
        // Set up working dir with data/
        let dataDir = workingDir.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        // Source screenpack lives outside the working dir to avoid copying onto self.
        let sourceRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContentInstallerTests-src-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceRoot) }

        let pack = sourceRoot.appendingPathComponent("CoolPack")
        try FileManager.default.createDirectory(at: pack, withIntermediateDirectories: true)
        try """
        [Info]
        name = CoolPack
        [Files]
        select = select.def
        fight = fight.def
        [Title Info]
        bgmusic =
        """.write(to: pack.appendingPathComponent("system.def"), atomically: true, encoding: .utf8)

        let result = try ContentInstaller.shared.installContentFolder(from: pack, to: workingDir)
        XCTAssertTrue(result.lowercased().contains("screenpack"),
                      "Result message should indicate a screenpack install: \(result)")

        let installed = dataDir.appendingPathComponent("CoolPack/system.def")
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.path))
    }

    func testInstallScreenpackThrowsOnDuplicateWithoutOverwrite() throws {
        let dataDir = workingDir.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let sourceRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContentInstallerTests-src-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceRoot) }

        let pack = sourceRoot.appendingPathComponent("DupPack")
        try FileManager.default.createDirectory(at: pack, withIntermediateDirectories: true)
        try """
        [Info]
        name = DupPack
        [Files]
        select = select.def
        [Title Info]
        bgmusic =
        """.write(to: pack.appendingPathComponent("system.def"), atomically: true, encoding: .utf8)

        // First install succeeds.
        _ = try ContentInstaller.shared.installScreenpack(from: pack, to: workingDir)

        // Second install without overwrite should throw duplicateContent.
        XCTAssertThrowsError(try ContentInstaller.shared.installScreenpack(from: pack, to: workingDir)) { error in
            guard case IkemenError.duplicateContent(let name) = error else {
                XCTFail("Expected duplicateContent error, got \(error)")
                return
            }
            XCTAssertEqual(name, "DupPack")
        }
    }

    func testInstallScreenpackWithOverwriteReplacesExisting() throws {
        let dataDir = workingDir.appendingPathComponent("data")
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let sourceRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContentInstallerTests-src-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceRoot) }

        let pack = sourceRoot.appendingPathComponent("OverPack")
        try FileManager.default.createDirectory(at: pack, withIntermediateDirectories: true)
        try """
        [Info]
        name = OverPack
        [Files]
        select = select.def
        [Title Info]
        """.write(to: pack.appendingPathComponent("system.def"), atomically: true, encoding: .utf8)

        // First install
        _ = try ContentInstaller.shared.installScreenpack(from: pack, to: workingDir)

        // Modify source so we can verify overwrite happened
        let marker = pack.appendingPathComponent("marker.txt")
        try "v2".write(to: marker, atomically: true, encoding: .utf8)

        let result = try ContentInstaller.shared.installScreenpack(from: pack, to: workingDir, overwrite: true)
        XCTAssertTrue(result.lowercased().contains("updated"))

        let installedMarker = dataDir.appendingPathComponent("OverPack/marker.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: installedMarker.path))
    }

    // MARK: - installContentFolder error path

    func testInstallContentFolderThrowsForUnrecognisedFolder() throws {
        let folder = workingDir.appendingPathComponent("Mystery")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Just a readme — no .def, no recognisable content.
        try "hello".write(to: folder.appendingPathComponent("README.txt"),
                          atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try ContentInstaller.shared.installContentFolder(from: folder, to: workingDir)
        )
    }
}
