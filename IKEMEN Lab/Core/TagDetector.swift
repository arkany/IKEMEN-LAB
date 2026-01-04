import Foundation

// MARK: - Tag Detector

/// Detects tags from character/stage metadata using pattern matching
class TagDetector {
    static let shared = TagDetector()
    
    private init() {}
    
    // MARK: - Regex Patterns
    
    /// Compiled regex for "sf" word boundary (excludes "sfx")
    private static let sfRegex = try! NSRegularExpression(pattern: "\\bsf\\b(?!x)", options: [])
    
    /// Compiled regex for "mk" followed by number
    private static let mkRegex = try! NSRegularExpression(pattern: "\\bmk\\s*\\d", options: [])
    
    // MARK: - Pattern Definitions
    
    /// Street Fighter character names
    private let streetFighterCharacters = [
        "ryu", "ken", "chun-li", "guile", "zangief", "dhalsim",
        "blanka", "e.honda", "vega", "sagat", "m.bison", "balrog",
        "cammy", "fei long", "dee jay", "t.hawk", "akuma", "sakura"
    ]
    
    /// Source Game patterns - pattern to tag mapping
    private let sourceGamePatterns: [(pattern: String, tag: String)] = [
        // KOF
        ("kof", "KOF"),
        ("king of fighters", "KOF"),
        
        // MVC
        ("mvc", "MVC"),
        ("marvel vs capcom", "MVC"),
        
        // CVS
        ("cvs", "CVS"),
        ("capcom vs snk", "CVS"),
        
        // Street Fighter (but not sfx)
        ("street fighter", "Street Fighter"),
        ("sf", "Street Fighter"),  // Will be handled specially
        
        // Guilty Gear
        ("guilty gear", "Guilty Gear"),
        ("guiltygear", "Guilty Gear"),
        ("ggxx", "Guilty Gear"),
        ("ggxrd", "Guilty Gear"),
        
        // Melty Blood
        ("melty", "Melty Blood"),
        ("mbaa", "Melty Blood"),
        
        // JoJo
        ("jojo", "JoJo"),
        ("hftf", "JoJo"),
        
        // Dragon Ball
        ("dbz", "Dragon Ball"),
        ("dragon ball", "Dragon Ball"),
        ("dragonball", "Dragon Ball"),
        
        // Naruto
        ("naruto", "Naruto"),
        
        // BlazBlue
        ("blazblue", "BlazBlue"),
        ("bbcf", "BlazBlue"),
        ("bbcp", "BlazBlue"),
        
        // Tekken
        ("tekken", "Tekken"),
        
        // Mortal Kombat
        ("mortal kombat", "Mortal Kombat"),
        
        // Fatal Fury
        ("fatal fury", "Fatal Fury"),
        ("garou", "Fatal Fury"),
        ("motw", "Fatal Fury"),
        
        // Samurai Shodown
        ("samurai shodown", "Samurai Shodown"),
        ("samsho", "Samurai Shodown"),
        
        // Darkstalkers
        ("darkstalkers", "Darkstalkers"),
        ("vampire savior", "Darkstalkers"),
    ]
    
    /// Franchise patterns - pattern to tag mapping
    private let franchisePatterns: [(pattern: String, tag: String)] = [
        // Marvel
        ("marvel", "Marvel"),
        ("x-men", "Marvel"),
        ("xmen", "Marvel"),
        ("avengers", "Marvel"),
        ("cyclops", "Marvel"),
        ("wolverine", "Marvel"),
        ("magneto", "Marvel"),
        ("storm", "Marvel"),
        ("spider-man", "Marvel"),
        ("spiderman", "Marvel"),
        
        // DC
        ("dc", "DC"),
        ("batman", "DC"),
        ("superman", "DC"),
        ("justice league", "DC"),
        
        // Capcom
        ("capcom", "Capcom"),
        ("ryu", "Capcom"),
        ("chun-li", "Capcom"),
        ("akuma", "Capcom"),
        
        // SNK
        ("snk", "SNK"),
        ("kyo", "SNK"),
        ("iori", "SNK"),
        ("terry", "SNK"),
        
        // Disney
        ("disney", "Disney"),
        
        // Anime
        ("anime", "Anime"),
    ]
    
    /// Style patterns - pattern to tag mapping with special handling
    private let stylePatterns: [(pattern: String, tag: String, matchAuthor: Bool)] = [
        // POTS Style
        ("pots", "POTS Style", true),
        ("pots style", "POTS Style", false),
        
        // Infinite Style
        ("infinite", "Infinite Style", true),
        
        // CVS Style - check author OR folder
        ("cvs", "CVS Style", false),
        
        // MVC Style - check folder for mvc2 OR author for mvc
        ("mvc2", "MVC Style", false),
    ]
    
    /// MVC Style author patterns (checked separately to avoid false positives)
    private let mvcStyleAuthors = ["mvc"]
    
    /// Quality/Type patterns - pattern to tag mapping
    private let qualityPatterns: [(pattern: String, tag: String)] = [
        // AI Enhanced
        ("ai", "AI Enhanced"),
        ("cpu", "AI Enhanced"),
        ("boss", "AI Enhanced"),
        
        // Edit
        ("edit", "Edit"),
        ("arranged", "Edit"),
        
        // Beta
        ("beta", "Beta"),
        ("wip", "Beta"),
        
        // HD
        ("hd", "HD"),
        ("hi-res", "HD"),
        ("hires", "HD"),
        
        // Hi-Res (MUGEN 1.0) - more specific patterns
        ("mugen1", "Hi-Res"),
        ("mugen 1.0", "Hi-Res"),
        ("mugen1.0", "Hi-Res"),
        
        // Lo-Res (WinMUGEN)
        ("winmugen", "Lo-Res"),
        ("wm", "Lo-Res"),
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
        for (pattern, tag) in sourceGamePatterns {
            // Special handling for "sf" - only match if not "sfx"
            if pattern == "sf" {
                let range = NSRange(searchText.startIndex..., in: searchText)
                if TagDetector.sfRegex.firstMatch(in: searchText, options: [], range: range) != nil {
                    tags.insert(tag)
                }
            } else if searchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Detect franchises
        for (pattern, tag) in franchisePatterns {
            if searchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Detect styles with special handling
        for (pattern, tag, matchAuthor) in stylePatterns {
            if matchAuthor {
                // Check author specifically for style patterns (POTS, Infinite)
                if author.contains(pattern) {
                    tags.insert(tag)
                }
            } else {
                // Check folder or author for style patterns (CVS Style, MVC Style)
                if folderName.contains(pattern) || author.contains(pattern) {
                    tags.insert(tag)
                }
            }
        }
        
        // MVC Style for author containing "mvc" (separate check to avoid false positives with folder names)
        for mvcPattern in mvcStyleAuthors {
            if author.contains(mvcPattern) {
                tags.insert("MVC Style")
            }
        }
        
        // Special case: Street Fighter characters
        for character in streetFighterCharacters {
            if searchText.contains(character) {
                tags.insert("Street Fighter")
                break
            }
        }
        
        // Detect quality/type
        for (pattern, tag) in qualityPatterns {
            if folderName.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Special case: Mortal Kombat with mk followed by number
        let range = NSRange(searchText.startIndex..., in: searchText)
        if TagDetector.mkRegex.firstMatch(in: searchText, options: [], range: range) != nil {
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
        for (pattern, tag) in sourceGamePatterns {
            // Special handling for "sf" - only match if not "sfx"
            if pattern == "sf" {
                let range = NSRange(searchText.startIndex..., in: searchText)
                if TagDetector.sfRegex.firstMatch(in: searchText, options: [], range: range) != nil {
                    tags.insert(tag)
                }
            } else if searchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Detect franchises
        for (pattern, tag) in franchisePatterns {
            if searchText.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Detect quality/type (stages typically don't have style patterns)
        // Only check filename for consistency with character detection
        for (pattern, tag) in qualityPatterns {
            if fileName.contains(pattern) {
                tags.insert(tag)
            }
        }
        
        // Special case: Mortal Kombat with mk followed by number
        let range = NSRange(searchText.startIndex..., in: searchText)
        if TagDetector.mkRegex.firstMatch(in: searchText, options: [], range: range) != nil {
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
