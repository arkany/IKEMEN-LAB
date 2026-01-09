import XCTest
@testable import IKEMEN_Lab

/// Tests for Phase 4: Activation and Validation logic
final class CollectionsPhase4Tests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create a temp directory for test files
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Mock IKEMEN structure
        try? FileManager.default.createDirectory(at: tempDirectory.appendingPathComponent("chars/Ryu"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: tempDirectory.appendingPathComponent("chars/Ken"), withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Validation Tests
    
    func testValidateCollectionReturnsEmptyIfAllCharactersExist() {
        // Given
        var collection = Collection(name: "Valid Collection")
        collection.characters = [
            .character(folder: "Ryu"),
            .character(folder: "Ken")
        ]
        
        // When
        let missing = SelectDefGenerator.validateCollection(collection, ikemenPath: tempDirectory)
        
        // Then
        XCTAssertTrue(missing.isEmpty, "Should report no missing characters")
    }
    
    func testValidateCollectionDetectsMissingCharacters() {
        // Given
        var collection = Collection(name: "Invalid Collection")
        collection.characters = [
            .character(folder: "Ryu"),
            .character(folder: "Akuma") // Does not exist
        ]
        
        // When
        let missing = SelectDefGenerator.validateCollection(collection, ikemenPath: tempDirectory)
        
        // Then
        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing.first, "Akuma")
    }
    
    func testValidateCollectionIgnoresRandomSelectAndEmptySlots() {
        // Given
        var collection = Collection(name: "Mixed Collection")
        collection.characters = [
            .character(folder: "Ryu"),
            .randomSelect(),
            .emptySlot(),
            .character(folder: "MissingChar")
        ]
        
        // When
        let missing = SelectDefGenerator.validateCollection(collection, ikemenPath: tempDirectory)
        
        // Then
        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing.first, "MissingChar")
    }
    
    // MARK: - Integration Flow Logic
    
    func testIsActivePropertyEncodesCorrectly() throws {
        // Given
        var collection = Collection(name: "Active Collection")
        collection.isActive = true
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(collection)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Collection.self, from: data)
        
        // Then
        XCTAssertTrue(decoded.isActive)
    }
    
    func testSelectDefGenerationWithBackup() {
        // Given
        let dataDir = tempDirectory.appendingPathComponent("data")
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        
        let selectDef = dataDir.appendingPathComponent("select.def")
        try? "Original Content".write(to: selectDef, atomically: true, encoding: .utf8)
        
        let collection = Collection(name: "Test")
        
        // When
        let result = SelectDefGenerator.writeSelectDef(for: collection, ikemenPath: tempDirectory)
        
        // Then
        // 1. Check result is success
        switch result {
        case .success(let url):
            XCTAssertEqual(url.lastPathComponent, "select.def")
        case .failure(let error):
            XCTFail("Generation failed: \(error)")
        }
        
        // 2. Check backup was created
        let files = try? FileManager.default.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil)
        let backups = files?.filter { $0.lastPathComponent.contains("select.def.backup") }
        XCTAssertEqual(backups?.count, 1)
        
        // 3. Check generation content
        let newContent = try? String(contentsOf: selectDef)
        XCTAssertTrue(newContent?.contains("; Collection: Test") ?? false)
    }
}
