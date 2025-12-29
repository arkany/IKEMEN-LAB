import Foundation

// MARK: - DEF File Parser

/// Reusable parser for MUGEN/Ikemen .def files
/// Handles INI-style key=value parsing with section tracking
public struct DEFParser {
    
    /// Parsed result from a DEF file
    public struct ParseResult {
        /// All key-value pairs, keyed by lowercased key name
        public let values: [String: String]
        
        /// Section-specific values, keyed by "[section]" then lowercased key
        public let sectionValues: [String: [String: String]]
        
        /// Get a value, optionally from a specific section
        public func value(for key: String, inSection section: String? = nil) -> String? {
            let loweredKey = key.lowercased()
            if let section = section {
                return sectionValues[section.lowercased()]?[loweredKey]
            }
            return values[loweredKey]
        }
        
        /// Get an integer value
        public func intValue(for key: String, inSection section: String? = nil, default defaultValue: Int = 0) -> Int {
            guard let stringValue = value(for: key, inSection: section) else { return defaultValue }
            return Int(stringValue) ?? defaultValue
        }
        
        /// Convenience accessors for common fields
        public var name: String? { value(for: "name") }
        public var displayName: String? { value(for: "displayname") }
        public var author: String? { value(for: "author") }
        public var versionDate: String? { value(for: "versiondate") }
        public var sprite: String? { value(for: "sprite") ?? value(for: "spr") }
    }
    
    /// Parse a DEF file from a URL
    public static func parse(url: URL) -> ParseResult? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return parse(content: content)
    }
    
    /// Parse DEF file content string
    public static func parse(content: String) -> ParseResult {
        var values: [String: String] = [:]
        var sectionValues: [String: [String: String]] = [:]
        var currentSection: String? = nil
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix(";") {
                continue
            }
            
            // Check for section header [SectionName]
            if trimmed.hasPrefix("[") && trimmed.contains("]") {
                if let endIndex = trimmed.firstIndex(of: "]") {
                    let sectionName = String(trimmed[trimmed.index(after: trimmed.startIndex)..<endIndex])
                    currentSection = sectionName.lowercased()
                    if sectionValues[currentSection!] == nil {
                        sectionValues[currentSection!] = [:]
                    }
                }
                continue
            }
            
            // Parse key = value
            guard let equalsIndex = trimmed.firstIndex(of: "=") else { continue }
            
            let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces).lowercased()
            var value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
            
            // Remove inline comments (after semicolon)
            if let commentIndex = value.firstIndex(of: ";") {
                value = String(value[..<commentIndex]).trimmingCharacters(in: .whitespaces)
            }
            
            // Remove surrounding quotes
            value = value.replacingOccurrences(of: "\"", with: "")
            
            // Store in appropriate location
            if let section = currentSection {
                sectionValues[section]?[key] = value
            }
            
            // Also store in flat values (last occurrence wins for duplicates)
            values[key] = value
        }
        
        return ParseResult(values: values, sectionValues: sectionValues)
    }
}

// MARK: - Convenience Extensions

extension DEFParser.ParseResult {
    
    /// Get camera bounds from [Camera] section (for stages)
    public var cameraBounds: (left: Int, right: Int) {
        let left = intValue(for: "boundleft", inSection: "camera", default: -150)
        let right = intValue(for: "boundright", inSection: "camera", default: 150)
        return (left, right)
    }
    
    /// Get the sprite/sff file reference
    public var spriteFile: String? {
        // Try "sprite" first (characters), then "spr" (stages)
        // But exclude "spriteno" which is a different key
        if let sprite = value(for: "sprite") {
            return sprite
        }
        // For stages, look in bgdef section or root
        if let spr = value(for: "spr", inSection: "bgdef") ?? value(for: "spr") {
            return spr
        }
        return nil
    }
    
    /// Get the effective display name (prefers name over displayname for characters)
    public var effectiveName: String? {
        // For characters, "name" is usually more descriptive
        // For stages, "displayname" is preferred if available
        return name ?? displayName
    }
    
    /// Get the CNS file reference (for characters)
    public var cnsFile: String? {
        return value(for: "cns")
    }
    
    /// Get the CMD file reference (for characters)
    public var cmdFile: String? {
        return value(for: "cmd")
    }
}

// MARK: - CNS Parser

/// Parser for character .cns files to extract stats and gameplay data
public struct CNSParser {
    
    /// Character stats from CNS [Data] section
    public struct CharacterStats {
        public let life: Int       // Max health (default 1000)
        public let attack: Int     // Damage multiplier % (default 100)
        public let defence: Int    // Defense multiplier % (default 100)
        public let power: Int      // Max power meter (default 3000)
        public let airJuggle: Int  // Juggle points (default 15)
        public let fallDefenceUp: Int // Fall defense boost % (default 50)
        
        /// Reasonable max values for UI display
        public static let maxLife = 2000
        public static let maxAttack = 200
        public static let maxDefence = 200
        public static let maxPower = 5000
    }
    
    /// Parse CNS file from URL
    public static func parseStats(from url: URL) -> CharacterStats? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return parseStats(content: content)
    }
    
    /// Parse CNS content string for stats
    public static func parseStats(content: String) -> CharacterStats {
        // Use DEFParser since CNS uses same INI-like format
        let parsed = DEFParser.parse(content: content)
        
        // Extract values from [Data] section
        let life = parsed.intValue(for: "life", inSection: "data", default: 1000)
        let attack = parsed.intValue(for: "attack", inSection: "data", default: 100)
        let defence = parsed.intValue(for: "defence", inSection: "data", default: 100)
        let power = parsed.intValue(for: "power", inSection: "data", default: 3000)
        let airJuggle = parsed.intValue(for: "airjuggle", inSection: "data", default: 15)
        let fallDefenceUp = parsed.intValue(for: "fall.defence_up", inSection: "data", default: 50)
        
        return CharacterStats(
            life: life,
            attack: attack,
            defence: defence,
            power: power,
            airJuggle: airJuggle,
            fallDefenceUp: fallDefenceUp
        )
    }
    
    /// Get stats for a character by finding and parsing their CNS file
    public static func getStats(for characterDirectory: URL, defFile: URL) -> CharacterStats {
        // Parse DEF file to get CNS reference
        guard let defContent = try? String(contentsOf: defFile, encoding: .utf8) else {
            return CharacterStats(life: 1000, attack: 100, defence: 100, power: 3000, airJuggle: 15, fallDefenceUp: 50)
        }
        
        let defParsed = DEFParser.parse(content: defContent)
        
        // Get CNS file path from [Files] section or root
        let cnsPath = defParsed.value(for: "cns", inSection: "files") ?? defParsed.value(for: "cns")
        
        guard let cnsFileName = cnsPath else {
            return CharacterStats(life: 1000, attack: 100, defence: 100, power: 3000, airJuggle: 15, fallDefenceUp: 50)
        }
        
        // Resolve CNS file path relative to character directory
        let cnsFile = characterDirectory.appendingPathComponent(cnsFileName)
        
        return parseStats(from: cnsFile) ?? CharacterStats(life: 1000, attack: 100, defence: 100, power: 3000, airJuggle: 15, fallDefenceUp: 50)
    }
}
