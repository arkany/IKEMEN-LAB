# IKEMEN Lab Browser Extension TODO

## Performance Optimizations

### MetadataStore Query Optimization
- [x] Add `mostRecentlyInstalledCharacter()` method that uses SQL "ORDER BY installedAt DESC LIMIT 1" instead of loading all characters
- [x] Update AppDelegate.swift with comments and example usage for browser extension install flow

This optimization is important to avoid loading all characters into memory just to find the most recent one, especially as the character library grows.

## Implementation Details

The new `mostRecentlyInstalledCharacter()` method:
- Added to `MetadataStoreProtocol` in `Services.swift`
- Implemented in `MetadataStore.swift` using efficient GRDB query with `.order().limit(1)`
- Mock implementation added to `MockServices.swift` for testing
- AppDelegate.swift includes TODO comment with example usage for future browser extension integration

## Next Steps

When implementing the browser extension:
1. Register `ikemenlab://` URL scheme in Info.plist
2. Implement `application(_:open:)` in AppDelegate
3. Use `MetadataStore.shared.mostRecentlyInstalledCharacter()` after installation to show user the newly installed character
