import Foundation

// MARK: - SmartCollectionEvaluator

/// Evaluates smart collection filter rules to determine which content matches
class SmartCollectionEvaluator {
    
    private let metadataStore = MetadataStore.shared
    
    // MARK: - Public API
    
    /// Evaluate a collection's rules and return matching content
    /// - Parameter collection: The smart collection to evaluate
    /// - Returns: A tuple of matching character folders and stage folders
    func evaluate(_ collection: Collection) -> (characters: [String], stages: [String]) {
        guard collection.isSmartCollection else {
            return ([], [])
        }
        
        let rules = collection.smartRules ?? []
        let ruleOperator = collection.smartRuleOperator ?? .all
        let includeCharacters = collection.includeCharacters ?? true
        let includeStages = collection.includeStages ?? true
        
        var matchingCharacters: [String] = []
        var matchingStages: [String] = []
        
        // Evaluate characters
        if includeCharacters {
            let characters = (try? metadataStore.allCharacters()) ?? []
            matchingCharacters = characters
                .filter { character in
                    evaluateRules(rules, for: character, operator: ruleOperator)
                }
                .map { $0.id }
        }
        
        // Evaluate stages
        if includeStages {
            let stages = (try? metadataStore.allStages()) ?? []
            matchingStages = stages
                .filter { stage in
                    evaluateRules(rules, for: stage, operator: ruleOperator)
                }
                .map { $0.id }
        }
        
        return (matchingCharacters, matchingStages)
    }
    
    // MARK: - Private Helpers
    
    /// Evaluate rules for a character
    private func evaluateRules(_ rules: [FilterRule], for character: CharacterRecord, operator ruleOperator: RuleOperator) -> Bool {
        // Empty rules match all
        guard !rules.isEmpty else { return true }
        
        let results = rules.map { rule in
            evaluateRule(rule, for: character)
        }
        
        switch ruleOperator {
        case .all:
            return results.allSatisfy { $0 }
        case .any:
            return results.contains(true)
        }
    }
    
    /// Evaluate rules for a stage
    private func evaluateRules(_ rules: [FilterRule], for stage: StageRecord, operator ruleOperator: RuleOperator) -> Bool {
        // Empty rules match all
        guard !rules.isEmpty else { return true }
        
        let results = rules.map { rule in
            evaluateRule(rule, for: stage)
        }
        
        switch ruleOperator {
        case .all:
            return results.allSatisfy { $0 }
        case .any:
            return results.contains(true)
        }
    }
    
    /// Evaluate a single rule for a character
    private func evaluateRule(_ rule: FilterRule, for character: CharacterRecord) -> Bool {
        switch rule.field {
        case .name:
            return evaluateStringField(character.name, rule: rule)
        case .author:
            return evaluateStringField(character.author, rule: rule)
        case .tag:
            // Dynamically compute inferred tags using TagDetector (don't rely on stale DB data)
            let inferredTags = TagDetector.shared.detectTags(
                folderName: character.id,
                displayName: character.name,
                author: character.author
            )
            let customTags = (try? metadataStore.customTags(for: character.id)) ?? []
            
            // Combine all tags, removing duplicates
            var allTagsSet = Set<String>()
            for tag in inferredTags + customTags {
                allTagsSet.insert(tag.lowercased())
            }
            let allTags = allTagsSet.joined(separator: ",")
            return evaluateTagField(allTags, rule: rule)
        case .installedAt:
            return evaluateDateField(character.installedAt, rule: rule)
        case .sourceGame:
            return evaluateOptionalStringField(character.sourceGame, rule: rule)
        case .isHD:
            return evaluateBoolField(character.isHD, rule: rule)
        case .hasAI:
            return evaluateBoolField(character.hasAI, rule: rule)
        case .style:
            return evaluateOptionalStringField(character.style, rule: rule)
        case .totalWidth, .hasMusic, .resolution:
            // Stage-specific fields don't apply to characters
            return false
        }
    }
    
    /// Evaluate a single rule for a stage
    private func evaluateRule(_ rule: FilterRule, for stage: StageRecord) -> Bool {
        switch rule.field {
        case .name:
            return evaluateStringField(stage.name, rule: rule)
        case .author:
            return evaluateStringField(stage.author, rule: rule)
        case .installedAt:
            return evaluateDateField(stage.installedAt, rule: rule)
        case .sourceGame:
            return evaluateOptionalStringField(stage.sourceGame, rule: rule)
        case .resolution:
            return evaluateOptionalStringField(stage.resolution, rule: rule)
        case .tag, .isHD, .hasAI, .style, .totalWidth, .hasMusic:
            // Character-specific or unsupported fields
            return false
        }
    }
    
    // MARK: - Field Evaluators
    
    /// Evaluate a string field
    private func evaluateStringField(_ fieldValue: String, rule: FilterRule) -> Bool {
        let value = rule.value
        
        switch rule.comparison {
        case .equals:
            return fieldValue.lowercased() == value.lowercased()
        case .notEquals:
            return fieldValue.lowercased() != value.lowercased()
        case .contains:
            return fieldValue.lowercased().contains(value.lowercased())
        case .notContains:
            return !fieldValue.lowercased().contains(value.lowercased())
        case .isEmpty:
            return fieldValue.isEmpty
        case .isNotEmpty:
            return !fieldValue.isEmpty
        case .greaterThan, .lessThan, .withinDays:
            return false
        }
    }
    
    /// Evaluate an optional string field
    private func evaluateOptionalStringField(_ fieldValue: String?, rule: FilterRule) -> Bool {
        switch rule.comparison {
        case .isEmpty:
            return fieldValue == nil || fieldValue?.isEmpty == true
        case .isNotEmpty:
            return fieldValue != nil && fieldValue?.isEmpty == false
        default:
            guard let fieldValue = fieldValue else { return false }
            return evaluateStringField(fieldValue, rule: rule)
        }
    }
    
    /// Evaluate a tag field (comma-separated tags)
    private func evaluateTagField(_ tagsString: String?, rule: FilterRule) -> Bool {
        let characterTags = tagsString?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? []
        
        // The rule value can be a single tag or comma-separated list of tags to search for
        let searchTags = rule.value.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        
        // Empty search tags = no match
        guard !searchTags.isEmpty else {
            switch rule.comparison {
            case .isEmpty:
                return characterTags.isEmpty
            case .isNotEmpty:
                return !characterTags.isEmpty
            default:
                return false
            }
        }
        
        switch rule.comparison {
        case .contains:
            // Match if character has ANY of the search tags
            return searchTags.contains { searchTag in
                characterTags.contains(searchTag)
            }
        case .notContains:
            // Match if character has NONE of the search tags
            return !searchTags.contains { searchTag in
                characterTags.contains(searchTag)
            }
        case .isEmpty:
            return characterTags.isEmpty
        case .isNotEmpty:
            return !characterTags.isEmpty
        case .equals, .notEquals, .greaterThan, .lessThan, .withinDays:
            return false
        }
    }
    
    /// Evaluate a boolean field
    private func evaluateBoolField(_ fieldValue: Bool?, rule: FilterRule) -> Bool {
        switch rule.comparison {
        case .equals:
            let expectedValue = rule.value.lowercased() == "true"
            return fieldValue == expectedValue
        case .notEquals:
            let expectedValue = rule.value.lowercased() == "true"
            return fieldValue != expectedValue
        case .isEmpty:
            return fieldValue == nil
        case .isNotEmpty:
            return fieldValue != nil
        case .contains, .notContains, .greaterThan, .lessThan, .withinDays:
            return false
        }
    }
    
    /// Evaluate a date field
    private func evaluateDateField(_ fieldValue: Date, rule: FilterRule) -> Bool {
        switch rule.comparison {
        case .withinDays:
            guard let days = Int(rule.value) else { return false }
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return fieldValue >= cutoffDate
        case .greaterThan:
            // Parse ISO8601 date string
            guard let compareDate = ISO8601DateFormatter().date(from: rule.value) else { return false }
            return fieldValue > compareDate
        case .lessThan:
            // Parse ISO8601 date string
            guard let compareDate = ISO8601DateFormatter().date(from: rule.value) else { return false }
            return fieldValue < compareDate
        case .equals, .notEquals, .contains, .notContains, .isEmpty, .isNotEmpty:
            return false
        }
    }
}
