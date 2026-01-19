import Foundation
import CryptoKit

// MARK: - Duplicate Detection

/// Detects duplicate and outdated content (characters, stages, screenpacks)
/// Uses both name-based and hash-based detection for comprehensive duplicate finding
public final class DuplicateDetector {
    
    // MARK: - Duplicate Group
    
    /// A group of duplicate items
    public struct DuplicateGroup<T: Hashable & Identifiable> {
        public let items: [T]
        public let reason: DuplicateReason
        
        /// The "primary" item (usually the first alphabetically or newest version)
        public var primary: T? {
            return items.first
        }
        
        /// Items that could potentially be removed (all except primary)
        public var duplicates: [T] {
            guard let primary = primary else { return items }
            return items.filter { $0.id != primary.id }
        }
        
        public init(items: [T], reason: DuplicateReason) {
            self.items = items
            self.reason = reason
        }
    }
    
    /// Reason why items are considered duplicates
    public enum DuplicateReason: String {
        case exactNameMatch = "Exact name match"
        case similarName = "Similar name"
        case contentHash = "Identical content (hash match)"
        case defFileHash = "Identical DEF file"
    }
    
    // MARK: - Version Info
    
    /// Version information extracted from content
    public struct VersionInfo {
        public let version: String?
        public let date: String?
        public let parsedDate: Date?
        
        /// Whether this version info is newer than another
        public func isNewerThan(_ other: VersionInfo) -> Bool? {
            // First try comparing parsed dates
            if let thisDate = parsedDate, let otherDate = other.parsedDate {
                return thisDate > otherDate
            }
            
            // Fall back to version string comparison if available
            if let thisVersion = version, let otherVersion = other.version {
                return compareVersionStrings(thisVersion, otherVersion) > 0
            }
            
            return nil
        }
        
        /// Compare two version strings (e.g., "1.0", "1.1", "2.0")
        private func compareVersionStrings(_ v1: String, _ v2: String) -> Int {
            let components1 = v1.split(separator: ".").compactMap { Int($0) }
            let components2 = v2.split(separator: ".").compactMap { Int($0) }
            
            let maxLength = max(components1.count, components2.count)
            
            for i in 0..<maxLength {
                let c1 = i < components1.count ? components1[i] : 0
                let c2 = i < components2.count ? components2[i] : 0
                
                if c1 != c2 {
                    return c1 - c2
                }
            }
            
            return 0
        }
    }
    
    /// An outdated version with information about what it's outdated compared to
    public struct OutdatedItem<T> {
        public let item: T
        public let newerItem: T
        public let itemVersion: VersionInfo
        public let newerVersion: VersionInfo
    }
    
    // MARK: - Character Duplicate Detection
    
    /// Find duplicate characters using name and hash-based detection
    public static func findDuplicateCharacters(_ characters: [CharacterInfo]) -> [DuplicateGroup<CharacterInfo>] {
        var groups: [DuplicateGroup<CharacterInfo>] = []
        var processed = Set<String>()
        
        // 1. Exact name matches
        let nameGroups = Dictionary(grouping: characters) { char in
            normalizedName(char.displayName)
        }
        
        for (name, items) in nameGroups where items.count > 1 && !name.isEmpty {
            let authorGroups = Dictionary(grouping: items) { char in
                normalizedAuthorKey(char.author)
            }
            
            for (_, authorItems) in authorGroups where authorItems.count > 1 {
                let group = DuplicateGroup(items: authorItems, reason: .exactNameMatch)
                groups.append(group)
                authorItems.forEach { processed.insert($0.id) }
            }
        }
        
        // 2. Similar name detection (Levenshtein distance)
        let unprocessed = characters.filter { !processed.contains($0.id) }
        let similarGroups = findSimilarNames(unprocessed.map { ($0.id, $0.displayName) })
        
        for similarIds in similarGroups {
            let items = characters.filter { similarIds.contains($0.id) }
            if items.count > 1 && authorsCompatible(items) {
                let group = DuplicateGroup(items: items, reason: .similarName)
                groups.append(group)
                items.forEach { processed.insert($0.id) }
            }
        }
        
        // 3. DEF file hash matching (characters with identical definition files)
        let unprocessedForHash = characters.filter { !processed.contains($0.id) }
        let hashGroups = Dictionary(grouping: unprocessedForHash) { char in
            computeFileHash(char.defFile)
        }
        
        for (hash, items) in hashGroups where items.count > 1 && hash != nil {
            let group = DuplicateGroup(items: items, reason: .defFileHash)
            groups.append(group)
        }
        
        return groups
    }
    
    /// Find outdated character versions
    public static func findOutdatedCharacters(_ characters: [CharacterInfo]) -> [OutdatedItem<CharacterInfo>] {
        var outdated: [OutdatedItem<CharacterInfo>] = []
        
        // Group characters by similar name
        let nameGroups = Dictionary(grouping: characters) { char in
            normalizedName(char.displayName)
        }
        
        for (_, items) in nameGroups where items.count > 1 {
            // Extract version info for each character
            let versioned = items.compactMap { char -> (CharacterInfo, VersionInfo)? in
                guard let version = extractVersionInfo(fromCharacter: char) else { return nil }
                return (char, version)
            }
            
            // Find the newest version
            guard let newest = versioned.max(by: { v1, v2 in
                v1.1.isNewerThan(v2.1) == false
            }) else { continue }
            
            // All others are outdated
            for (char, version) in versioned {
                if char.id != newest.0.id,
                   let isNewer = version.isNewerThan(newest.1),
                   !isNewer {
                    let item = OutdatedItem(
                        item: char,
                        newerItem: newest.0,
                        itemVersion: version,
                        newerVersion: newest.1
                    )
                    outdated.append(item)
                }
            }
        }
        
        return outdated
    }
    
    // MARK: - Stage Duplicate Detection
    
    /// Find duplicate stages using name and hash-based detection
    public static func findDuplicateStages(_ stages: [StageInfo]) -> [DuplicateGroup<StageInfo>] {
        var groups: [DuplicateGroup<StageInfo>] = []
        var processed = Set<String>()
        
        // 1. Exact name matches
        let nameGroups = Dictionary(grouping: stages) { stage in
            stage.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        for (name, items) in nameGroups where items.count > 1 && !name.isEmpty {
            let group = DuplicateGroup(items: items, reason: .exactNameMatch)
            groups.append(group)
            items.forEach { processed.insert($0.id) }
        }
        
        // 2. Similar name detection
        let unprocessed = stages.filter { !processed.contains($0.id) }
        let similarGroups = findSimilarNames(unprocessed.map { ($0.id, $0.name) })
        
        for similarIds in similarGroups {
            let items = stages.filter { similarIds.contains($0.id) }
            if items.count > 1 {
                let group = DuplicateGroup(items: items, reason: .similarName)
                groups.append(group)
                items.forEach { processed.insert($0.id) }
            }
        }
        
        // 3. DEF file hash matching
        let unprocessedForHash = stages.filter { !processed.contains($0.id) }
        let hashGroups = Dictionary(grouping: unprocessedForHash) { stage in
            computeFileHash(stage.defFile)
        }
        
        for (hash, items) in hashGroups where items.count > 1 && hash != nil {
            let group = DuplicateGroup(items: items, reason: .defFileHash)
            groups.append(group)
        }
        
        return groups
    }
    
    /// Find outdated stage versions
    public static func findOutdatedStages(_ stages: [StageInfo]) -> [OutdatedItem<StageInfo>] {
        var outdated: [OutdatedItem<StageInfo>] = []
        
        // Group stages by similar name
        let nameGroups = Dictionary(grouping: stages) { stage in
            normalizedName(stage.name)
        }
        
        for (_, items) in nameGroups where items.count > 1 {
            // Compare modification dates to find the newest
            let sorted = items.sorted { s1, s2 in
                guard let d1 = s1.modificationDate, let d2 = s2.modificationDate else {
                    return false
                }
                return d1 > d2
            }
            
            guard let newest = sorted.first, newest.modificationDate != nil else { continue }
            
            // All others are outdated
            for stage in sorted.dropFirst() {
                if let newestDate = newest.modificationDate,
                   let stageDate = stage.modificationDate,
                   stageDate < newestDate {
                    let newestVersion = VersionInfo(
                        version: nil,
                        date: formatDate(newestDate),
                        parsedDate: newestDate
                    )
                    let stageVersion = VersionInfo(
                        version: nil,
                        date: formatDate(stageDate),
                        parsedDate: stageDate
                    )
                    
                    let item = OutdatedItem(
                        item: stage,
                        newerItem: newest,
                        itemVersion: stageVersion,
                        newerVersion: newestVersion
                    )
                    outdated.append(item)
                }
            }
        }
        
        return outdated
    }
    
    // MARK: - Screenpack Duplicate Detection
    
    /// Find duplicate screenpacks using name and hash-based detection
    public static func findDuplicateScreenpacks(_ screenpacks: [ScreenpackInfo]) -> [DuplicateGroup<ScreenpackInfo>] {
        var groups: [DuplicateGroup<ScreenpackInfo>] = []
        var processed = Set<String>()
        
        // 1. Exact name matches
        let nameGroups = Dictionary(grouping: screenpacks) { sp in
            sp.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        for (name, items) in nameGroups where items.count > 1 && !name.isEmpty {
            let group = DuplicateGroup(items: items, reason: .exactNameMatch)
            groups.append(group)
            items.forEach { processed.insert($0.id) }
        }
        
        // 2. Similar name detection
        let unprocessed = screenpacks.filter { !processed.contains($0.id) }
        let similarGroups = findSimilarNames(unprocessed.map { ($0.id, $0.name) })
        
        for similarIds in similarGroups {
            let items = screenpacks.filter { similarIds.contains($0.id) }
            if items.count > 1 {
                let group = DuplicateGroup(items: items, reason: .similarName)
                groups.append(group)
                items.forEach { processed.insert($0.id) }
            }
        }
        
        // 3. DEF file hash matching
        let unprocessedForHash = screenpacks.filter { !processed.contains($0.id) }
        let hashGroups = Dictionary(grouping: unprocessedForHash) { sp in
            computeFileHash(sp.defFile)
        }
        
        for (hash, items) in hashGroups where items.count > 1 && hash != nil {
            let group = DuplicateGroup(items: items, reason: .defFileHash)
            groups.append(group)
        }
        
        return groups
    }
    
    // MARK: - Helper Methods
    
    /// Compute SHA-256 hash of a file
    private static func computeFileHash(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Find groups of similar names using Levenshtein distance
    /// Returns arrays of IDs that have similar names
    private static func findSimilarNames(_ items: [(id: String, name: String)]) -> [[String]] {
        var groups: [[String]] = []
        var processed = Set<String>()
        
        for i in 0..<items.count {
            guard !processed.contains(items[i].id) else { continue }
            
            var group = [items[i].id]
            let name1 = normalizedName(items[i].name)
            
            for j in (i+1)..<items.count {
                guard !processed.contains(items[j].id) else { continue }
                
                let name2 = normalizedName(items[j].name)
                let distance = levenshteinDistance(name1, name2)
                let maxLength = max(name1.count, name2.count)
                
                // Consider similar if distance is less than 20% of the longer name
                // and at least one name is longer than 5 characters
                if maxLength > 5 && Double(distance) / Double(maxLength) < 0.2 {
                    group.append(items[j].id)
                }
            }
            
            if group.count > 1 {
                groups.append(group)
                group.forEach { processed.insert($0) }
            }
        }
        
        return groups
    }

    private static func normalizedAuthorKey(_ author: String) -> String? {
        let normalized = author.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { return nil }
        if normalized == "unknown" || normalized == "n/a" || normalized == "na" {
            return nil
        }
        return normalized
    }

    private static func authorsCompatible(_ items: [CharacterInfo]) -> Bool {
        let authorKeys = Set(items.compactMap { normalizedAuthorKey($0.author) })
        return authorKeys.count <= 1
    }
    
    /// Normalize a name for comparison (remove version numbers, special chars, etc.)
    private static func normalizedName(_ name: String) -> String {
        var normalized = name.lowercased()
        
        // Remove version indicators
        let versionPatterns = [
            "v\\d+\\.\\d+",
            "v\\d+",
            "ver\\d+",
            "version\\d+",
            "_\\d+\\.\\d+",
            "_\\d+$"
        ]
        
        for pattern in versionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(normalized.startIndex..., in: normalized)
                normalized = regex.stringByReplacingMatches(in: normalized, range: range, withTemplate: "")
            }
        }
        
        // Remove special characters
        normalized = normalized.replacingOccurrences(of: "_", with: " ")
        normalized = normalized.replacingOccurrences(of: "-", with: " ")
        
        // Collapse multiple spaces
        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Calculate Levenshtein distance between two strings
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if s1Array[i-1] == s2Array[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
    
    /// Extract version information from a character
    private static func extractVersionInfo(fromCharacter char: CharacterInfo) -> VersionInfo? {
        // Try to parse versiondate field
        let dateString = char.versionDate
        
        // Common date formats in MUGEN content
        let dateFormatters = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "yyyy/MM/dd",
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "dd-MM-yyyy"
        ]
        
        var parsedDate: Date? = nil
        if !dateString.isEmpty {
            for format in dateFormatters {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    parsedDate = date
                    break
                }
            }
        }
        
        // Try to extract version number from name or versiondate
        var version: String? = nil
        let versionPattern = #"v?(\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: versionPattern, options: [.caseInsensitive]) {
            let text = "\(char.displayName) \(dateString)"
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let range = Range(match.range(at: 1), in: text) {
                version = String(text[range])
            }
        }
        
        guard parsedDate != nil || version != nil else { return nil }
        
        return VersionInfo(
            version: version,
            date: dateString,
            parsedDate: parsedDate
        )
    }
    
    /// Format a date as a string
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
