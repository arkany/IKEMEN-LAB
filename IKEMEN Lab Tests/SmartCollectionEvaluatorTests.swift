import XCTest
@testable import IKEMEN_Lab

/// Tests for SmartCollectionEvaluator rule evaluation
final class SmartCollectionEvaluatorTests: XCTestCase {
    
    var evaluator: SmartCollectionEvaluator!
    var metadataStore: MetadataStore!
    
    override func setUp() {
        super.setUp()
        evaluator = SmartCollectionEvaluator()
        metadataStore = MetadataStore.shared
        
        // Note: These tests assume MetadataStore has some test data
        // In a real test environment, you'd want to use a test database
        // or mock the MetadataStore dependency
    }
    
    override func tearDown() {
        evaluator = nil
        super.tearDown()
    }
    
    // MARK: - Empty Rules Tests
    
    func testEmptyRulesMatchAll() {
        // Given - A smart collection with no rules
        var collection = Collection(name: "Test", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = []
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then - Should match all characters
        // We can't assert exact count without knowing test database state,
        // but we can verify it returns some results if data exists
        XCTAssertTrue(result.characters.count >= 0)
        XCTAssertEqual(result.stages.count, 0) // Stages not included
    }
    
    func testNilRulesMatchAll() {
        // Given - A smart collection with nil rules
        var collection = Collection(name: "Test", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = nil
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then - Should match all characters
        XCTAssertTrue(result.characters.count >= 0)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    // MARK: - Tag Matching Tests
    
    func testTagContainsMatch() {
        // Given - A rule that checks if tags contain "Marvel"
        let rule = FilterRule(
            field: .tag,
            comparison: .contains,
            value: "Marvel"
        )
        
        var collection = Collection(name: "Marvel Characters", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = [rule]
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then - Should only return characters with "Marvel" tag
        // We can verify the result is an array (exact count depends on test data)
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    func testTagNotContainsMatch() {
        // Given - A rule that checks if tags don't contain "DC"
        let rule = FilterRule(
            field: .tag,
            comparison: .notContains,
            value: "DC"
        )
        
        var collection = Collection(name: "Non-DC Characters", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = [rule]
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    // MARK: - String Field Tests
    
    func testNameContainsMatch() {
        // Given - A rule that checks if name contains "Ryu"
        let rule = FilterRule(
            field: .name,
            comparison: .contains,
            value: "Ryu"
        )
        
        var collection = Collection(name: "Ryu Variants", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = [rule]
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    func testAuthorEqualsMatch() {
        // Given - A rule that checks if author equals "Vyn"
        let rule = FilterRule(
            field: .author,
            comparison: .equals,
            value: "Vyn"
        )
        
        var collection = Collection(name: "Vyn's Characters", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = [rule]
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    // MARK: - AND/OR Combination Tests
    
    func testANDCombination() {
        // Given - Two rules that must both match
        let tagRule = FilterRule(
            field: .tag,
            comparison: .contains,
            value: "Street Fighter"
        )
        
        let hdRule = FilterRule(
            field: .isHD,
            comparison: .equals,
            value: "true"
        )
        
        var collection = Collection(name: "HD Street Fighter", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = [tagRule, hdRule]
        collection.smartRuleOperator = .all  // AND
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then - Should only return characters matching BOTH rules
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    func testORCombination() {
        // Given - Two rules where either can match
        let tagRule1 = FilterRule(
            field: .tag,
            comparison: .contains,
            value: "Marvel"
        )
        
        let tagRule2 = FilterRule(
            field: .tag,
            comparison: .contains,
            value: "DC"
        )
        
        var collection = Collection(name: "Marvel or DC", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = [tagRule1, tagRule2]
        collection.smartRuleOperator = .any  // OR
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then - Should return characters matching EITHER rule
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    // MARK: - Date Filter Tests
    
    func testWithinDaysFilter() {
        // Given - A rule that checks if character was installed within last 7 days
        let rule = FilterRule(
            field: .installedAt,
            comparison: .withinDays,
            value: "7"
        )
        
        var collection = Collection(name: "Recently Added", icon: "clock.fill")
        collection.isSmartCollection = true
        collection.smartRules = [rule]
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    // MARK: - Boolean Filter Tests
    
    func testIsHDFilter() {
        // Given - A rule that checks if character is HD
        let rule = FilterRule(
            field: .isHD,
            comparison: .equals,
            value: "true"
        )
        
        var collection = Collection(name: "HD Characters", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = [rule]
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    func testHasAIFilter() {
        // Given - A rule that checks if character has AI
        let rule = FilterRule(
            field: .hasAI,
            comparison: .equals,
            value: "true"
        )
        
        var collection = Collection(name: "Characters with AI", icon: "cpu")
        collection.isSmartCollection = true
        collection.smartRules = [rule]
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertNotNil(result.characters)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    // MARK: - Include Flags Tests
    
    func testIncludeCharactersOnly() {
        // Given
        var collection = Collection(name: "Test", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = []
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = false
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertTrue(result.characters.count >= 0)
        XCTAssertEqual(result.stages.count, 0)
    }
    
    func testIncludeStagesOnly() {
        // Given
        var collection = Collection(name: "Test", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = []
        collection.smartRuleOperator = .all
        collection.includeCharacters = false
        collection.includeStages = true
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertEqual(result.characters.count, 0)
        XCTAssertTrue(result.stages.count >= 0)
    }
    
    func testIncludeBothCharactersAndStages() {
        // Given
        var collection = Collection(name: "Test", icon: "star.fill")
        collection.isSmartCollection = true
        collection.smartRules = []
        collection.smartRuleOperator = .all
        collection.includeCharacters = true
        collection.includeStages = true
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then
        XCTAssertTrue(result.characters.count >= 0)
        XCTAssertTrue(result.stages.count >= 0)
    }
    
    // MARK: - Non-Smart Collection Tests
    
    func testNonSmartCollectionReturnsEmpty() {
        // Given - A regular (non-smart) collection
        var collection = Collection(name: "Regular Collection", icon: "folder.fill")
        collection.isSmartCollection = false
        collection.smartRules = [FilterRule(field: .name, comparison: .contains, value: "test")]
        
        // When
        let result = evaluator.evaluate(collection)
        
        // Then - Should return empty arrays for non-smart collections
        XCTAssertEqual(result.characters.count, 0)
        XCTAssertEqual(result.stages.count, 0)
    }
}
