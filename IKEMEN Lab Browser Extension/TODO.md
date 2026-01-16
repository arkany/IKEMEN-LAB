# IKEMEN Lab Browser Extension TODO

## Performance Optimizations

### MetadataStore Query Optimization
- [ ] Add `mostRecentlyInstalledCharacter()` method that uses SQL "ORDER BY installedAt DESC LIMIT 1" instead of loading all characters
- [ ] Update AppDelegate.swift to use the new optimized method in browser extension install flow

This optimization is important to avoid loading all characters into memory just to find the most recent one, especially as the character library grows.
