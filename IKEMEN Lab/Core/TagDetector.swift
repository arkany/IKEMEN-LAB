import Foundation

// MARK: - Tag Detector

/// Detects tags from character/stage metadata using pattern matching
class TagDetector {
    static let shared = TagDetector()
    
    private init() {}
    
    // MARK: - Regex Cache
    
    /// Cache of compiled regex patterns for word boundary matching
    private var regexCache: [String: NSRegularExpression] = [:]
    private let regexLock = NSLock()
    
    /// Get or create a regex for word boundary matching
    private func wordBoundaryRegex(for pattern: String) -> NSRegularExpression? {
        regexLock.lock()
        defer { regexLock.unlock() }
        
        if let cached = regexCache[pattern] {
            return cached
        }
        
        // Escape special regex characters in pattern, then wrap with word boundaries
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        guard let regex = try? NSRegularExpression(pattern: "\\b\(escaped)\\b", options: .caseInsensitive) else {
            return nil
        }
        regexCache[pattern] = regex
        return regex
    }
    
    /// Check if a word (with boundaries) exists in text
    private func containsWord(_ word: String, in text: String) -> Bool {
        guard let regex = wordBoundaryRegex(for: word) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    // MARK: - Special Regex Patterns
    
    /// Compiled regex for "sf" word boundary (excludes "sfx")
    private static let sfRegex: NSRegularExpression? = {
        return try? NSRegularExpression(pattern: "\\bsf\\b(?!x)", options: .caseInsensitive)
    }()
    
    /// Compiled regex for "mk" followed by number (mk1, mk2, mk3, etc.)
    private static let mkRegex: NSRegularExpression? = {
        return try? NSRegularExpression(pattern: "\\bmk\\s*\\d", options: .caseInsensitive)
    }()
    
    // MARK: - Pattern Definitions
    
    /// Street Fighter character names (require word boundary matching)
    private let streetFighterCharacters = [
        "ryu", "ken", "chun-li", "chun li", "guile", "zangief", "dhalsim",
        "blanka", "e.honda", "e honda", "vega", "sagat", "m.bison", "m bison", "balrog",
        "cammy", "fei long", "dee jay", "t.hawk", "t hawk", "akuma", "sakura",
        "dan", "rose", "gen", "rolento", "sodom", "birdie", "adon", "cody", "guy"
    ]
    
    /// Source Game patterns - pattern to tag mapping
    /// Patterns marked with useWordBoundary=true require exact word matching
    private let sourceGamePatterns: [(pattern: String, tag: String, useWordBoundary: Bool)] = [
        // KOF - word boundary to avoid "strikofist" false positives
        ("kof", "KOF", true),
        ("king of fighters", "KOF", false),
        
        // MVC - word boundary needed
        ("mvc", "MVC", true),
        ("marvel vs capcom", "MVC", false),
        
        // CVS - word boundary needed
        ("cvs", "CVS", true),
        ("capcom vs snk", "CVS", false),
        
        // Street Fighter (but not sfx) - handled specially via sfRegex
        ("street fighter", "Street Fighter", false),
        
        // Guilty Gear - multi-word is safe
        ("guilty gear", "Guilty Gear", false),
        ("guiltygear", "Guilty Gear", false),
        ("ggxx", "Guilty Gear", true),
        ("ggxrd", "Guilty Gear", true),
        ("ggst", "Guilty Gear", true),
        
        // Melty Blood
        ("melty blood", "Melty Blood", false),
        ("melty", "Melty Blood", true),
        ("mbaa", "Melty Blood", true),
        
        // JoJo
        ("jojo", "JoJo", true),
        ("hftf", "JoJo", true),
        
        // Dragon Ball
        ("dbz", "Dragon Ball", true),
        ("dragon ball", "Dragon Ball", false),
        ("dragonball", "Dragon Ball", false),
        
        // Naruto - word boundary to avoid partial matches
        ("naruto", "Naruto", true),
        
        // BlazBlue
        ("blazblue", "BlazBlue", false),
        ("bbcf", "BlazBlue", true),
        ("bbcp", "BlazBlue", true),
        
        // Tekken
        ("tekken", "Tekken", true),
        
        // Mortal Kombat - multi-word is safe
        ("mortal kombat", "Mortal Kombat", false),
        
        // Fatal Fury
        ("fatal fury", "Fatal Fury", false),
        ("garou", "Fatal Fury", true),
        ("motw", "Fatal Fury", true),
        
        // Samurai Shodown
        ("samurai shodown", "Samurai Shodown", false),
        ("samsho", "Samurai Shodown", true),
        
        // Darkstalkers
        ("darkstalkers", "Darkstalkers", false),
        ("vampire savior", "Darkstalkers", false),
    ]
    
    /// Franchise patterns - pattern to tag mapping
    /// Note: Removed overly broad patterns like "dc", "storm" that cause false positives
    private let franchisePatterns: [(pattern: String, tag: String, useWordBoundary: Bool)] = [
        // Marvel - specific character names need word boundaries
        ("marvel", "Marvel", true),
        ("x-men", "Marvel", false),
        ("xmen", "Marvel", true),
        ("avengers", "Marvel", true),
        ("cyclops", "Marvel", true),
        ("wolverine", "Marvel", true),
        ("magneto", "Marvel", true),
        ("spider-man", "Marvel", false),
        ("spiderman", "Marvel", true),
        ("iron man", "Marvel", false),
        ("ironman", "Marvel", true),
        ("captain america", "Marvel", false),
        ("hulk", "Marvel", true),
        ("thor", "Marvel", true),
        ("deadpool", "Marvel", true),
        ("venom", "Marvel", true),
        
        // DC - require specific character names, not just "dc" (too many false positives)
        ("batman", "DC", true),
        ("superman", "DC", true),
        ("wonder woman", "DC", false),
        ("justice league", "DC", false),
        ("joker", "DC", true),
        ("harley quinn", "DC", false),
        ("green lantern", "DC", false),
        ("flash", "DC", true),
        ("aquaman", "DC", true),
        
        // SNK - word boundary needed
        ("snk", "SNK", true),
        ("kyo kusanagi", "SNK", false),
        ("iori yagami", "SNK", false),
        ("terry bogard", "SNK", false),
        
        // Capcom - word boundary
        ("capcom", "Capcom", true),
        
        // Disney - word boundary
        ("disney", "Disney", true),
        ("kingdom hearts", "Disney", false),
        
        // Anime (generic) - word boundary
        ("anime", "Anime", true),
    ]
    
    /// Style patterns - pattern to tag mapping with special handling
    /// matchAuthor: true = check author with word boundary
    /// matchAuthor: false = check folder/author with contains (multi-word patterns)
    private let stylePatterns: [(pattern: String, tag: String, matchAuthor: Bool)] = [
        // POTS Style - check author with word boundary
        ("pots", "POTS Style", true),
        
        // Infinite Style - check author with word boundary
        ("infinite", "Infinite Style", true),
        
        // CVS Style - multi-word patterns safe with contains
        ("cvs style", "CVS Style", false),
        ("cvs2 style", "CVS Style", false),
        
        // MVC Style - multi-word patterns safe with contains  
        ("mvc style", "MVC Style", false),
        ("mvc2 style", "MVC Style", false),
    ]
    
    /// Quality/Type patterns - two categories:
    /// 1. Exact patterns (multi-word or with delimiters) - safe with contains
    /// 2. Word patterns - require word boundary matching
    private let qualityExactPatterns: [(pattern: String, tag: String)] = [
        // AI Enhanced - patterns with delimiters/multi-word are safe
        ("ai enhanced", "AI Enhanced"),
        ("ai patch", "AI Enhanced"),
        (" ai ", "AI Enhanced"),  // Space-padded
        ("_ai_", "AI Enhanced"),  // Underscore-padded
        ("_ai", "AI Enhanced"),   // Trailing underscore (end of folder name)
        ("ai_", "AI Enhanced"),   // Leading underscore (start of suffix)
        ("-ai-", "AI Enhanced"),  // Hyphen-padded
        ("-ai", "AI Enhanced"),   // Hyphen suffix
        ("boss ai", "AI Enhanced"),
        
        // HD - patterns with delimiters are safe
        (" hd", "HD"),
        ("_hd", "HD"),
        ("-hd", "HD"),
        ("hd ", "HD"),
        ("hi-res", "HD"),
        ("hires", "HD"),
        ("high res", "HD"),
        ("high-res", "HD"),
        
        // Hi-Res (MUGEN 1.0)
        ("mugen1", "Hi-Res"),
        ("mugen 1.0", "Hi-Res"),
        ("mugen1.0", "Hi-Res"),
        
        // Lo-Res (WinMUGEN)
        ("winmugen", "Lo-Res"),
    ]
    
    /// Quality patterns that need word boundary matching
    private let qualityWordPatterns: [(pattern: String, tag: String)] = [
        // Edit - word boundary to avoid "credited", "edited"
        ("edit", "Edit"),
        ("arranged", "Edit"),
        
        // Beta - word boundary to avoid "alphabet"
        ("beta", "Beta"),
        ("wip", "Beta"),
        
        // CPU - word boundary to avoid partial matches
        ("cpu", "AI Enhanced"),
    ]
    
    // MARK: - Public Methods
    
    /// Infer tags from a CharacterInfo
    func detectTags(for character: CharacterInfo) -> [String] {
        var tags: Set<String> = []
        
        // Gather sources to check (case-insensitive)
        let folderName = character.directory.lastPathComponent.lowercased()
        let displayName = character.displayName.lowercased()
        let author = character.author.lowercased()
        
        // Combined search text for general pattern matching
        let searchText = [folderName, displayName, author].joined(separator: " ")
        
        // Detect source games
        for (pattern, tag, useWordBoundary) in sourceGamePatterns {
            if useWordBoundary {
                if containsWord(pattern, in: searchText) {
                    tags.insert(tag)
                }
            } else if searchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Special handling for "sf" - only match if not "sfx"
        let range = NSRange(searchText.startIndex..., in: searchText)
        if let regex = TagDetector.sfRegex,
           regex.firstMatch(in: searchText, options: [], range: range) != nil {
            tags.insert("Street Fighter")
        }
        
        // Detect franchises
        for (pattern, tag, useWordBoundary) in franchisePatterns {
            if useWordBoundary {
                if containsWord(pattern, in: searchText) {
                    tags.insert(tag)
                }
            } else if searchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Detect styles with special handling
        for (pattern, tag, matchAuthor) in stylePatterns {
            if matchAuthor {
                // Check author specifically for style patterns (POTS, Infinite)
                // Use word boundary to avoid false positives
                if containsWord(pattern, in: author) {
                    tags.insert(tag)
                }
            } else {
                // Check folder or author for style patterns (CVS Style, MVC Style)
                if folderName.contains(pattern) || author.contains(pattern) {
                    tags.insert(tag)
                }
            }
        }
        
        // Special case: Street Fighter characters (also add Capcom franchise)
        for sfCharacter in streetFighterCharacters {
            if containsWord(sfCharacter, in: searchText) {
                tags.insert("Street Fighter")
                tags.insert("Capcom")
                break
            }
        }
        
        // Detect quality/type - check folder name AND author
        let qualitySearchText = folderName + " " + author
        
        // Exact patterns (multi-word or with delimiters) - safe with contains
        for (pattern, tag) in qualityExactPatterns {
            if qualitySearchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Word patterns - require word boundary matching
        for (pattern, tag) in qualityWordPatterns {
            if containsWord(pattern, in: qualitySearchText) {
                tags.insert(tag)
            }
        }
        
        // Special case: Mortal Kombat with mk followed by number
        if let regex = TagDetector.mkRegex,
           regex.firstMatch(in: searchText, options: [], range: range) != nil {
            tags.insert("Mortal Kombat")
        }
        
        // Special case: Multi-Palette detection
        if hasMultiplePalettes(in: character.directory) {
            tags.insert("Multi-Palette")
        }
        
        // Return unique tags, sorted alphabetically
        return Array(tags).sorted()
    }
    
    /// Infer tags from a StageInfo
    func detectTags(for stage: StageInfo) -> [String] {
        var tags: Set<String> = []
        
        // Gather sources to check (case-insensitive)
        let fileName = stage.defFile.deletingPathExtension().lastPathComponent.lowercased()
        let stageName = stage.name.lowercased()
        let author = stage.author.lowercased()
        
        // Combined search text for general pattern matching
        let searchText = [fileName, stageName, author].joined(separator: " ")
        
        // Detect source games
        for (pattern, tag, useWordBoundary) in sourceGamePatterns {
            if useWordBoundary {
                if containsWord(pattern, in: searchText) {
                    tags.insert(tag)
                }
            } else if searchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Special handling for "sf" - only match if not "sfx"
        let range = NSRange(searchText.startIndex..., in: searchText)
        if let regex = TagDetector.sfRegex,
           regex.firstMatch(in: searchText, options: [], range: range) != nil {
            tags.insert("Street Fighter")
        }
        
        // Detect franchises
        for (pattern, tag, useWordBoundary) in franchisePatterns {
            if useWordBoundary {
                if containsWord(pattern, in: searchText) {
                    tags.insert(tag)
                }
            } else if searchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Detect quality/type - check filename AND author
        let qualitySearchText = fileName + " " + author
        
        // Exact patterns (multi-word or with delimiters) - safe with contains
        for (pattern, tag) in qualityExactPatterns {
            if qualitySearchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Word patterns - require word boundary matching
        for (pattern, tag) in qualityWordPatterns {
            if containsWord(pattern, in: qualitySearchText) {
                tags.insert(tag)
            }
        }
        
        // Special case: Mortal Kombat with mk followed by number
        if let regex = TagDetector.mkRegex,
           regex.firstMatch(in: searchText, options: [], range: range) != nil {
            tags.insert("Mortal Kombat")
        }
        
        // Return unique tags, sorted alphabetically
        return Array(tags).sorted()
    }
    
    // MARK: - Private Helpers
    
    /// Check if a character directory has multiple palette (.act) files
    private func hasMultiplePalettes(in directory: URL) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        
        let paletteFiles = contents.filter { $0.pathExtension.lowercased() == "act" }
        return paletteFiles.count > 1
    }
}
