# TODO - Future Improvements

## Performance Optimizations

### MetadataStore Query Optimization
- [ ] Add `mostRecentlyInstalledCharacter()` method to MetadataStore
- [ ] Use SQL `ORDER BY installedAt DESC LIMIT 1` instead of loading all characters
- [ ] Benefits: O(1) query vs O(n) memory sort, especially for large character rosters

**Current Code (AppDelegate.swift:169-170):**
```swift
if let recentCharacters = try? MetadataStore.shared.allCharacters(),
   let newestCharacter = recentCharacters.sorted(by: { $0.installedAt > $1.installedAt }).first {
```

**Suggested:**
```swift
// Add to MetadataStore.swift
public func mostRecentlyInstalledCharacter() throws -> CharacterRecord? {
    try dbQueue?.read { db in
        try CharacterRecord
            .order(Column("installedAt").desc)
            .limit(1)
            .fetchOne(db)
    }
}

// Use in AppDelegate.swift
if let newestCharacter = try? MetadataStore.shared.mostRecentlyInstalledCharacter() {
```

## Data Model Improvements

### Tags as Array Property
- [ ] Refactor ScrapedMetadata to keep tags as `[String]` array
- [ ] Add computed property for comma-separated string for database
- [ ] Decouple data model from storage format

**Current Code (MetadataStore.swift:66-75):**
```swift
public init(..., tags: [String]?, ...) {
    self.tags = tags?.joined(separator: ",")
}
```

**Suggested:**
```swift
public struct ScrapedMetadata: Codable, FetchableRecord, PersistableRecord {
    public var characterId: String
    // ... other fields
    private var _tags: String?  // Database storage
    
    public var tags: [String] {
        get { _tags?.split(separator: ",").map(String.init) ?? [] }
        set { _tags = newValue.isEmpty ? nil : newValue.joined(separator: ",") }
    }
    
    enum CodingKeys: String, CodingKey {
        case _tags = "tags"
        // ... other cases
    }
}
```

## Error Handling

### Metadata Storage Errors
- [ ] Add proper error handling for metadata storage failures
- [ ] Log errors for debugging
- [ ] Optionally notify user if metadata fails to save (character still installed)

**Current Code (AppDelegate.swift:184):**
```swift
try? MetadataStore.shared.storeScrapedMetadata(scrapedMetadata)
```

**Suggested:**
```swift
do {
    try MetadataStore.shared.storeScrapedMetadata(scrapedMetadata)
} catch {
    NSLog("Failed to store scraped metadata: \(error)")
    // Character is already installed, just metadata failed
    // Could show a non-critical warning notification
}
```

## Extension Enhancements

### Multi-Site Support
- [ ] Implement MUGEN Free For All scraping logic
- [ ] Implement MUGEN Fighters Guild scraping logic
- [ ] Add generic scraper as fallback for unknown sites

### Metadata Accuracy
- [ ] Improve version detection regex patterns
- [ ] Expand tag recognition for more franchises/styles
- [ ] Add character name disambiguation (e.g., "Ryu SF2" vs "Ryu SFV")

### User Experience
- [ ] Add progress indicator in extension popup
- [ ] Show recently installed characters in popup
- [ ] Add settings: auto-install, notification preferences
- [ ] Support batch downloads from search results

### Error Recovery
- [ ] Retry failed downloads
- [ ] Resume interrupted downloads
- [ ] Better error messages for different failure types

## Testing
- [ ] Unit tests for metadata extraction functions
- [ ] Integration tests for URL scheme handling
- [ ] UI tests for character details display
- [ ] Test with various archive formats (.zip, .rar, .7z)

## Documentation
- [ ] Video tutorial for extension setup
- [ ] Screenshots for each step
- [ ] Troubleshooting FAQ
- [ ] Site-specific scraping documentation for contributors

## Priority

**High Priority (Next Release):**
- Performance optimization for character query
- Better error handling for metadata storage

**Medium Priority:**
- Tags as array property refactor
- MUGEN Free For All support

**Low Priority:**
- Batch downloads
- Advanced settings

## Notes

All current functionality works correctly. These improvements are for performance, maintainability, and enhanced features. The existing implementation is production-ready and follows the "make it work, make it right, make it fast" principle - we're at "make it work" and these TODOs are for "make it right" and "make it fast".
