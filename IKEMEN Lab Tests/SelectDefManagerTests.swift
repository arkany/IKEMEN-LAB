import XCTest
@testable import IKEMEN_Lab

/// Tests for SelectDefManager parsing, reordering, and enable/disable behaviour.
/// Note: Tests focus on file mutation logic. Methods that move files to Trash
/// (removeStage, removeCharacter) and notify the app (NotificationCenter,
/// MetadataStore) are intentionally not exercised here — they have side effects
/// outside the temp directory.
final class SelectDefManagerTests: XCTestCase {

    var workingDir: URL!
    var dataDir: URL!
    var selectDefPath: URL!

    override func setUp() {
        super.setUp()
        workingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SelectDefManagerTests-\(UUID().uuidString)")
        dataDir = workingDir.appendingPathComponent("data")
        selectDefPath = dataDir.appendingPathComponent("select.def")
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: workingDir)
        workingDir = nil
        dataDir = nil
        selectDefPath = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func writeSelectDef(_ contents: String) {
        try? contents.write(to: selectDefPath, atomically: true, encoding: .utf8)
    }

    private func readSelectDef() -> String {
        return (try? String(contentsOf: selectDefPath, encoding: .utf8)) ?? ""
    }

    /// Build a CharacterInfo for a synthetic character on disk under `chars/<folder>/`.
    private func makeCharacter(folder: String, defName: String? = nil) throws -> CharacterInfo {
        let charsDir = workingDir.appendingPathComponent("chars")
        let charDir = charsDir.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: charDir, withIntermediateDirectories: true)
        let defFile = charDir.appendingPathComponent(defName ?? "\(folder).def")
        try "[Info]\nname = \(folder)\nauthor = Test\n".write(to: defFile, atomically: true, encoding: .utf8)
        return CharacterInfo(directory: charDir, defFile: defFile)
    }

    /// Build a StageInfo for a synthetic stage on disk under `stages/<name>.def`.
    private func makeStage(name: String, inSubfolder: Bool = false) throws -> StageInfo {
        let stagesDir = workingDir.appendingPathComponent("stages")
        try FileManager.default.createDirectory(at: stagesDir, withIntermediateDirectories: true)
        let defFile: URL
        if inSubfolder {
            let sub = stagesDir.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            defFile = sub.appendingPathComponent("\(name).def")
        } else {
            defFile = stagesDir.appendingPathComponent("\(name).def")
        }
        try "[StageInfo]\nname = \(name)\n".write(to: defFile, atomically: true, encoding: .utf8)
        return StageInfo(defFile: defFile)
    }

    // MARK: - readCharacterOrder

    func testReadCharacterOrderReturnsCharactersInSectionOrder() {
        writeSelectDef("""
        [Characters]
        Ryu
        Ken
        Akuma
        [ExtraStages]
        stages/Training.def
        """)

        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        XCTAssertEqual(order, ["Ryu", "Ken", "Akuma"])
    }

    func testReadCharacterOrderSkipsCommentsAndEmptyEntries() {
        writeSelectDef("""
        ; Top-level comment
        [Characters]
        ; this is commented

        Ryu
        empty
        Ken
        """)

        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        XCTAssertEqual(order, ["Ryu", "Ken"])
    }

    func testReadCharacterOrderHandlesPathSeparators() {
        writeSelectDef("""
        [Characters]
        kfm/kfm.def
        chars/Ryu/Ryu.def
        Ken\\Ken.def
        """)

        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        XCTAssertEqual(order, ["kfm", "chars", "Ken"])
    }

    func testReadCharacterOrderReturnsEmptyForMissingFile() {
        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        XCTAssertEqual(order, [])
    }

    func testReadCharacterOrderStripsStageAssignments() {
        writeSelectDef("""
        [Characters]
        Ryu, stages/Training.def, order=1
        Ken, random, order=1
        """)

        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        XCTAssertEqual(order, ["Ryu", "Ken"])
    }

    // MARK: - reorderCharacters

    func testReorderCharactersRewritesSectionInGivenOrder() throws {
        writeSelectDef("""
        [Characters]
        Ken
        Ryu
        Akuma
        [ExtraStages]
        stages/Training.def
        """)

        try SelectDefManager.shared.reorderCharacters(["Ryu", "Ken", "Akuma"], in: workingDir)

        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        XCTAssertEqual(order, ["Ryu", "Ken", "Akuma"])
    }

    func testReorderCharactersAppendsMissingCharactersAtEnd() throws {
        writeSelectDef("""
        [Characters]
        Ken
        Ryu
        Akuma
        Sagat
        """)

        try SelectDefManager.shared.reorderCharacters(["Akuma", "Ryu"], in: workingDir)

        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        XCTAssertEqual(order, ["Akuma", "Ryu", "Ken", "Sagat"])
    }

    func testReorderCharactersThrowsWhenSelectDefMissing() {
        XCTAssertThrowsError(
            try SelectDefManager.shared.reorderCharacters(["A"], in: workingDir)
        )
    }

    // MARK: - addStageToSelectDef

    func testAddStageInsertsIntoExtraStagesSection() throws {
        writeSelectDef("""
        [Characters]
        Ryu
        [ExtraStages]
        stages/Training.def
        """)

        try SelectDefManager.shared.addStageToSelectDef("Bifrost", in: workingDir)

        let content = readSelectDef()
        XCTAssertTrue(content.contains("stages/Bifrost.def"))
        XCTAssertTrue(content.contains("stages/Training.def"))
    }

    func testAddStageIsIdempotent() throws {
        writeSelectDef("""
        [Characters]
        [ExtraStages]
        stages/Bifrost.def
        """)

        try SelectDefManager.shared.addStageToSelectDef("Bifrost", in: workingDir)

        let content = readSelectDef()
        let occurrences = content.components(separatedBy: "stages/Bifrost.def").count - 1
        XCTAssertEqual(occurrences, 1, "Stage should not be added a second time")
    }

    // MARK: - addCharacterToSelectDefFile

    func testAddCharacterToSelectDefFileInsertsAfterCharactersHeader() throws {
        writeSelectDef("""
        [Characters]
        Ryu
        [ExtraStages]
        """)

        try SelectDefManager.shared.addCharacterToSelectDefFile("Ken", selectDefPath: selectDefPath)

        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        // New entry appears at the top of the section.
        XCTAssertEqual(order.first, "Ken")
        XCTAssertTrue(order.contains("Ryu"))
    }

    func testAddCharacterToSelectDefFileSkipsDuplicates() throws {
        writeSelectDef("""
        [Characters]
        Ryu
        [ExtraStages]
        """)

        try SelectDefManager.shared.addCharacterToSelectDefFile("Ryu", selectDefPath: selectDefPath)

        let content = readSelectDef()
        let occurrences = content.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces) == "Ryu" }
            .count
        XCTAssertEqual(occurrences, 1, "Duplicate entry should not be added")
    }

    func testAddCharacterToSelectDefFileSkipsDuplicatesCaseInsensitively() throws {
        writeSelectDef("""
        [Characters]
        Ryu
        [ExtraStages]
        """)

        try SelectDefManager.shared.addCharacterToSelectDefFile("ryu/ryu.def", selectDefPath: selectDefPath)

        let content = readSelectDef()
        XCTAssertFalse(content.contains("ryu/ryu.def"),
                       "Existing case-insensitive match should prevent duplicate insertion")
    }

    // MARK: - disable / enable stage

    func testDisableStageCommentsOutMatchingLine() throws {
        let stage = try makeStage(name: "Bifrost")
        writeSelectDef("""
        [Characters]
        Ryu
        [ExtraStages]
        stages/Bifrost.def
        stages/Training.def
        """)

        let modified = try SelectDefManager.shared.disableStage(stage, in: workingDir)
        XCTAssertTrue(modified)

        let content = readSelectDef()
        XCTAssertTrue(content.contains(";stages/Bifrost.def"))
        XCTAssertTrue(content.contains("stages/Training.def"))
        XCTAssertTrue(SelectDefManager.shared.isStageDisabled(stage, in: workingDir))
    }

    func testEnableStageUncommentsLine() throws {
        let stage = try makeStage(name: "Bifrost")
        writeSelectDef("""
        [Characters]
        Ryu
        [ExtraStages]
        ;stages/Bifrost.def
        stages/Training.def
        """)

        XCTAssertTrue(SelectDefManager.shared.isStageDisabled(stage, in: workingDir))

        let modified = try SelectDefManager.shared.enableStage(stage, in: workingDir)
        XCTAssertTrue(modified)
        XCTAssertFalse(SelectDefManager.shared.isStageDisabled(stage, in: workingDir))

        let content = readSelectDef()
        XCTAssertTrue(content.contains("stages/Bifrost.def"))
        XCTAssertFalse(content.contains(";stages/Bifrost.def"))
    }

    // MARK: - disable / enable character

    func testDisableCharacterCommentsOutLineInCharactersSection() throws {
        let character = try makeCharacter(folder: "Ken")
        writeSelectDef("""
        [Characters]
        Ryu
        Ken
        [ExtraStages]
        Ken
        """)

        let modified = try SelectDefManager.shared.disableCharacter(character, in: workingDir)
        XCTAssertTrue(modified)

        let content = readSelectDef()
        // The first Ken line in [Characters] should be commented; the second
        // Ken under [ExtraStages] should be untouched.
        let lines = content.components(separatedBy: "\n")
        let charactersIndex = lines.firstIndex(where: { $0.contains("[Characters]") }) ?? 0
        let stagesIndex = lines.firstIndex(where: { $0.contains("[ExtraStages]") }) ?? lines.count
        let charactersSlice = lines[charactersIndex..<stagesIndex]
        let stagesSlice = lines[stagesIndex..<lines.count]

        XCTAssertTrue(charactersSlice.contains(where: { $0.contains(";") && $0.contains("Ken") }))
        XCTAssertTrue(stagesSlice.contains(where: { $0.trimmingCharacters(in: .whitespaces) == "Ken" }))
    }

    func testEnableCharacterUncommentsLine() throws {
        let character = try makeCharacter(folder: "Ken")
        writeSelectDef("""
        [Characters]
        Ryu
        ;Ken
        [ExtraStages]
        """)

        XCTAssertTrue(SelectDefManager.shared.isCharacterDisabled(character, in: workingDir))

        let modified = try SelectDefManager.shared.enableCharacter(character, in: workingDir)
        XCTAssertTrue(modified)
        XCTAssertFalse(SelectDefManager.shared.isCharacterDisabled(character, in: workingDir))
    }

    func testDisableCharacterReturnsFalseWhenAlreadyDisabled() throws {
        let character = try makeCharacter(folder: "Ken")
        writeSelectDef("""
        [Characters]
        Ryu
        ;Ken
        [ExtraStages]
        """)

        let modified = try SelectDefManager.shared.disableCharacter(character, in: workingDir)
        XCTAssertFalse(modified, "Already-commented entry should not be re-disabled")
    }

    // MARK: - Edge cases

    func testReadCharacterOrderHandlesMalformedHeaders() {
        // Bracketed text mid-file but missing closing bracket — should not flip section.
        writeSelectDef("""
        [Characters]
        Ryu
        [Malformed
        Ken
        """)

        let order = SelectDefManager.shared.readCharacterOrder(from: workingDir)
        // The malformed line ("[Malformed") doesn't close so it's treated as content.
        XCTAssertTrue(order.contains("Ryu"))
        XCTAssertTrue(order.contains("Ken"))
    }
}
