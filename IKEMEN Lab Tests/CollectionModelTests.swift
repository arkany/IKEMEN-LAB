import XCTest
@testable import IKEMEN_Lab

/// Tests for Collection and RosterEntry model Codable conformance
final class CollectionModelTests: XCTestCase {
    
    // MARK: - Collection Codable Tests
    
    func testCollectionEncodesAndDecodesCorrectly() throws {
        // Given
        var collection = Collection(name: "Marvel vs Capcom", icon: "star.fill")
        collection.characters = [
            .character(folder: "Ryu", def: "Ryu.def"),
            .character(folder: "Wolverine"),
            .randomSelect(),
            .emptySlot()
        ]
        collection.stages = ["Training", "Bifrost"]
        collection.screenpackPath = "data/MvC2"
        collection.isDefault = false
        
        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(collection)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Collection.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.id, collection.id)
        XCTAssertEqual(decoded.name, "Marvel vs Capcom")
        XCTAssertEqual(decoded.icon, "star.fill")
        XCTAssertEqual(decoded.characters.count, 4)
        XCTAssertEqual(decoded.stages, ["Training", "Bifrost"])
        XCTAssertEqual(decoded.screenpackPath, "data/MvC2")
        XCTAssertEqual(decoded.isDefault, false)
    }
    
    func testCollectionWithEmptyArraysEncodesCorrectly() throws {
        // Given
        let collection = Collection(name: "Empty Collection")
        
        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(collection)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Collection.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.name, "Empty Collection")
        XCTAssertTrue(decoded.characters.isEmpty)
        XCTAssertTrue(decoded.stages.isEmpty)
        XCTAssertNil(decoded.screenpackPath)
    }
    
    func testCollectionDefaultValues() {
        // When
        let collection = Collection(name: "Test")
        
        // Then
        XCTAssertEqual(collection.icon, "folder.fill")
        XCTAssertTrue(collection.characters.isEmpty)
        XCTAssertTrue(collection.stages.isEmpty)
        XCTAssertNil(collection.screenpackPath)
        XCTAssertFalse(collection.isDefault)
    }
    
    func testCollectionPreservesUUIDAfterRoundtrip() throws {
        // Given
        let originalId = UUID()
        let collection = Collection(id: originalId, name: "Test")
        
        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(collection)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Collection.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.id, originalId)
    }
    
    func testCollectionDatesPreservedAfterRoundtrip() throws {
        // Given
        let collection = Collection(name: "Test")
        let originalCreated = collection.createdAt
        let originalModified = collection.modifiedAt
        
        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(collection)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Collection.self, from: data)
        
        // Then - ISO8601 loses sub-second precision, so compare to within 1 second
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, originalCreated.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(decoded.modifiedAt.timeIntervalSince1970, originalModified.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - RosterEntry Tests
    
    func testRosterEntryCharacterFactory() {
        // When
        let entry = RosterEntry.character(folder: "Ryu", def: "Ryu_MvC.def")
        
        // Then
        XCTAssertEqual(entry.entryType, .character)
        XCTAssertEqual(entry.characterFolder, "Ryu")
        XCTAssertEqual(entry.defFile, "Ryu_MvC.def")
        XCTAssertNil(entry.gridPosition)
    }
    
    func testRosterEntryCharacterFactoryWithoutDef() {
        // When
        let entry = RosterEntry.character(folder: "Ken")
        
        // Then
        XCTAssertEqual(entry.entryType, .character)
        XCTAssertEqual(entry.characterFolder, "Ken")
        XCTAssertNil(entry.defFile)
    }
    
    func testRosterEntryRandomSelectFactory() {
        // When
        let entry = RosterEntry.randomSelect()
        
        // Then
        XCTAssertEqual(entry.entryType, .randomSelect)
        XCTAssertNil(entry.characterFolder)
        XCTAssertNil(entry.defFile)
        XCTAssertNil(entry.gridPosition)
    }
    
    func testRosterEntryEmptySlotFactory() {
        // When
        let entry = RosterEntry.emptySlot()
        
        // Then
        XCTAssertEqual(entry.entryType, .emptySlot)
        XCTAssertNil(entry.characterFolder)
        XCTAssertNil(entry.defFile)
        XCTAssertNil(entry.gridPosition)
    }
    
    func testRosterEntryEncodesAndDecodesCorrectly() throws {
        // Given
        let entries: [RosterEntry] = [
            .character(folder: "Ryu", def: "Ryu.def"),
            .randomSelect(),
            .emptySlot()
        ]
        
        // When
        let data = try JSONEncoder().encode(entries)
        let decoded = try JSONDecoder().decode([RosterEntry].self, from: data)
        
        // Then
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].entryType, .character)
        XCTAssertEqual(decoded[0].characterFolder, "Ryu")
        XCTAssertEqual(decoded[1].entryType, .randomSelect)
        XCTAssertEqual(decoded[2].entryType, .emptySlot)
    }
    
    func testRosterEntryTypeRawValues() {
        // Ensure raw values match expected strings for JSON compatibility
        XCTAssertEqual(RosterEntry.RosterEntryType.character.rawValue, "character")
        XCTAssertEqual(RosterEntry.RosterEntryType.randomSelect.rawValue, "randomSelect")
        XCTAssertEqual(RosterEntry.RosterEntryType.emptySlot.rawValue, "emptySlot")
    }
    
    // MARK: - GridPosition Tests
    
    func testGridPositionEquality() {
        let pos1 = GridPosition(row: 1, column: 2)
        let pos2 = GridPosition(row: 1, column: 2)
        let pos3 = GridPosition(row: 2, column: 1)
        
        XCTAssertEqual(pos1, pos2)
        XCTAssertNotEqual(pos1, pos3)
    }
    
    func testGridPositionEncodesAndDecodes() throws {
        // Given
        let position = GridPosition(row: 5, column: 10)
        
        // When
        let data = try JSONEncoder().encode(position)
        let decoded = try JSONDecoder().decode(GridPosition.self, from: data)
        
        // Then
        XCTAssertEqual(decoded.row, 5)
        XCTAssertEqual(decoded.column, 10)
    }
}
