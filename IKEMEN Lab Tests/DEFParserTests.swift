import XCTest
@testable import IKEMEN_Lab

/// Tests for DEFParser parsing accuracy
final class DEFParserTests: XCTestCase {
    
    // MARK: - Basic Parsing Tests
    
    func testParseSimpleKeyValue() {
        // Given
        let content = """
        name = Ryu
        author = Capcom
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertEqual(result.name, "Ryu")
        XCTAssertEqual(result.author, "Capcom")
    }
    
    func testParseWithWhitespace() {
        // Given
        let content = """
          name   =   Ryu with Spaces  
        author=NoSpaces
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertEqual(result.name, "Ryu with Spaces")
        XCTAssertEqual(result.author, "NoSpaces")
    }
    
    func testParseWithQuotedValues() {
        // Given
        let content = """
        name = "Street Fighter Ryu"
        displayname = "Ryu"
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertEqual(result.name, "Street Fighter Ryu")
        XCTAssertEqual(result.displayName, "Ryu")
    }
    
    func testParseIgnoresComments() {
        // Given
        let content = """
        ; This is a comment
        name = Ryu
        ; Another comment
        author = Capcom ; inline comment
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertEqual(result.name, "Ryu")
        XCTAssertEqual(result.author, "Capcom")
    }
    
    func testParseIgnoresEmptyLines() {
        // Given
        let content = """
        name = Ryu
        
        
        author = Capcom
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertEqual(result.name, "Ryu")
        XCTAssertEqual(result.author, "Capcom")
    }
    
    // MARK: - Section Parsing Tests
    
    func testParseSections() {
        // Given
        let content = """
        [Info]
        name = Ryu
        author = Capcom
        
        [Files]
        sprite = ryu.sff
        cmd = ryu.cmd
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertEqual(result.value(for: "name", inSection: "info"), "Ryu")
        XCTAssertEqual(result.value(for: "author", inSection: "info"), "Capcom")
        XCTAssertEqual(result.value(for: "sprite", inSection: "files"), "ryu.sff")
        XCTAssertEqual(result.value(for: "cmd", inSection: "files"), "ryu.cmd")
    }
    
    func testParseSectionsCaseInsensitive() {
        // Given
        let content = """
        [INFO]
        Name = Ryu
        AUTHOR = Capcom
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertEqual(result.value(for: "name", inSection: "info"), "Ryu")
        XCTAssertEqual(result.value(for: "author", inSection: "INFO"), "Capcom")
    }
    
    func testParseFlatValuesContainAllKeys() {
        // Given
        let content = """
        [Info]
        name = Ryu
        
        [Files]
        sprite = ryu.sff
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then - Flat values should contain keys from all sections
        XCTAssertEqual(result.values["name"], "Ryu")
        XCTAssertEqual(result.values["sprite"], "ryu.sff")
    }
    
    // MARK: - Convenience Accessor Tests
    
    func testIntValue() {
        // Given
        let content = """
        life = 1000
        attack = 100
        invalid = abc
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertEqual(result.intValue(for: "life"), 1000)
        XCTAssertEqual(result.intValue(for: "attack"), 100)
        XCTAssertEqual(result.intValue(for: "invalid"), 0)  // Default for non-numeric
        XCTAssertEqual(result.intValue(for: "missing", default: 500), 500)
    }
    
    func testSpriteFileAccessor() {
        // Given - Character style
        let charContent = """
        [Files]
        sprite = ryu.sff
        """
        
        // When
        let charResult = DEFParser.parse(content: charContent)
        
        // Then
        XCTAssertEqual(charResult.spriteFile, "ryu.sff")
        
        // Given - Stage style
        let stageContent = """
        [BGdef]
        spr = stage.sff
        """
        
        // When
        let stageResult = DEFParser.parse(content: stageContent)
        
        // Then
        XCTAssertEqual(stageResult.spriteFile, "stage.sff")
    }
    
    func testEffectiveName() {
        // Given - Has both name and displayname
        let content1 = """
        name = Internal Name
        displayname = Display Name
        """
        
        // When
        let result1 = DEFParser.parse(content: content1)
        
        // Then - name takes precedence
        XCTAssertEqual(result1.effectiveName, "Internal Name")
        
        // Given - Only displayname
        let content2 = """
        displayname = Only Display
        """
        
        // When
        let result2 = DEFParser.parse(content: content2)
        
        // Then
        XCTAssertEqual(result2.effectiveName, "Only Display")
    }
    
    // MARK: - Content Type Detection Tests
    
    func testIsValidCharacterDefFile() throws {
        // Given - Valid character def
        let charContent = """
        [Info]
        name = Ryu
        
        [Files]
        cmd = ryu.cmd
        cns = ryu.cns
        sprite = ryu.sff
        """
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let charURL = tempDir.appendingPathComponent("ryu.def")
        try charContent.write(to: charURL, atomically: true, encoding: .utf8)
        
        // Then
        XCTAssertTrue(DEFParser.isValidCharacterDefFile(charURL))
    }
    
    func testIsStoryboardDefFileExcluded() throws {
        // Given - Storyboard def (should NOT be a valid character)
        let storyContent = """
        [SceneDef]
        name = Intro
        """
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let storyURL = tempDir.appendingPathComponent("intro.def")
        try storyContent.write(to: storyURL, atomically: true, encoding: .utf8)
        
        // Then
        XCTAssertFalse(DEFParser.isValidCharacterDefFile(storyURL))
        XCTAssertTrue(DEFParser.isStoryboardDefFile(storyURL))
    }
    
    func testIsValidStageDefFile() throws {
        // Given - Valid stage def
        let stageContent = """
        [StageInfo]
        name = Training Stage
        
        [BGdef]
        spr = training.sff
        """
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let stageURL = tempDir.appendingPathComponent("training.def")
        try stageContent.write(to: stageURL, atomically: true, encoding: .utf8)
        
        // Then
        XCTAssertTrue(DEFParser.isValidStageDefFile(stageURL))
        XCTAssertFalse(DEFParser.isValidCharacterDefFile(stageURL))
    }
    
    func testFontDefFileExcluded() throws {
        // Given - Font def
        let fontContent = """
        [Fnt]
        type = bitmap
        """
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let fontURL = tempDir.appendingPathComponent("font.def")
        try fontContent.write(to: fontURL, atomically: true, encoding: .utf8)
        
        // Then
        XCTAssertFalse(DEFParser.isValidCharacterDefFile(fontURL))
        XCTAssertFalse(DEFParser.isValidStageDefFile(fontURL))
    }
    
    // MARK: - Edge Cases
    
    func testParseEmptyContent() {
        // Given
        let content = ""
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertTrue(result.values.isEmpty)
        XCTAssertTrue(result.sectionValues.isEmpty)
    }
    
    func testParseOnlyComments() {
        // Given
        let content = """
        ; Comment 1
        ; Comment 2
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then
        XCTAssertTrue(result.values.isEmpty)
    }
    
    func testParseLineWithNoEquals() {
        // Given
        let content = """
        name = Ryu
        this line has no equals sign
        author = Capcom
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then - Should skip invalid line and continue
        XCTAssertEqual(result.name, "Ryu")
        XCTAssertEqual(result.author, "Capcom")
    }
    
    func testParseDuplicateKeysLastWins() {
        // Given
        let content = """
        name = First
        name = Second
        """
        
        // When
        let result = DEFParser.parse(content: content)
        
        // Then - Last value wins
        XCTAssertEqual(result.name, "Second")
    }
}
