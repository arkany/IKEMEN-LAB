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
}
