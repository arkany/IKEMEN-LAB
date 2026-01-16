# Safari Browser Extension Implementation Summary

## Overview

This implementation adds a Safari Web Extension to IKEMEN Lab that enables one-click installation of MUGEN characters and stages from popular MUGEN content websites. The extension scrapes metadata (author, version, description, tags) from web pages and passes it to the macOS app via a custom URL scheme.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Browser (Safari)                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              Content Script (mugenarchive.js)              │ │
│  │  • Detects download pages                                  │ │
│  │  • Injects "Install to IKEMEN Lab" button                  │ │
│  │  • Scrapes metadata (author, version, description, tags)   │ │
│  │  • Triggers ikemenlab:// URL scheme                        │ │
│  └────────────────────────────────────────────────────────────┘ │
└───────────────────────────────┬─────────────────────────────────┘
                                │ ikemenlab://install?data={payload}
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       IKEMEN Lab (macOS)                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              AppDelegate.swift (URL Handler)                │ │
│  │  • Receives URL scheme requests                            │ │
│  │  • Parses JSON payload                                     │ │
│  │  • Downloads archive file                                  │ │
│  │  • Installs content via ContentManager                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                │                                  │
│                                ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │            MetadataStore.swift (Database)                   │ │
│  │  • Stores ScrapedMetadata in SQLite                        │ │
│  │  • Links metadata to character ID                          │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                │                                  │
│                                ▼                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │       CharacterDetailsView.swift (UI Display)               │ │
│  │  • Loads scraped metadata from database                    │ │
│  │  • Displays "Source" section with URL and description      │ │
│  │  • Overrides author/version with scraped values            │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Details

### Phase 1: URL Scheme & Handler ✅

**Files Modified:**
- `IKEMEN Lab/Resources/Info.plist`
- `IKEMEN Lab/App/AppDelegate.swift`
- `IKEMEN Lab/Core/MetadataStore.swift`

**What Was Added:**

1. **URL Scheme Registration** (`Info.plist`)
   - Registered `ikemenlab://` custom URL scheme
   - Allows browser to launch IKEMEN Lab with parameters

2. **URL Handler** (`AppDelegate.swift`)
   - `application(_:open:)` method to receive URL scheme calls
   - `handleInstallRequest(from:)` to parse JSON payload
   - `downloadAndInstall(payload:)` to download and install content
   - `installDownloadedContent(at:metadata:)` to process installation

3. **Data Models** (`AppDelegate.swift`)
   - `InstallPayload` struct for URL scheme payload
   - `InstallMetadata` struct for scraped web data

4. **Database Schema** (`MetadataStore.swift`)
   - `ScrapedMetadata` struct/table for storing web-scraped data
   - Foreign key to `characters` table
   - Methods: `storeScrapedMetadata()`, `scrapedMetadata(for:)`, `deleteScrapedMetadata(for:)`

### Phase 2 & 3: Safari Extension ✅

**Files Created:**
- `IKEMEN Lab Browser Extension/Shared (Extension)/manifest.json`
- `IKEMEN Lab Browser Extension/Shared (Extension)/content-scripts/shared.js`
- `IKEMEN Lab Browser Extension/Shared (Extension)/content-scripts/button-styles.css`
- `IKEMEN Lab Browser Extension/Shared (Extension)/content-scripts/mugenarchive.js`
- `IKEMEN Lab Browser Extension/Shared (Extension)/content-scripts/mugenfreeforall.js` (stub)
- `IKEMEN Lab Browser Extension/Shared (Extension)/content-scripts/mugenguild.js` (stub)
- `IKEMEN Lab Browser Extension/Shared (Extension)/popup.html`

**What Was Added:**

1. **Extension Manifest** (`manifest.json`)
   - Manifest V3 format
   - Permissions for MUGEN content sites
   - Content scripts for automatic injection
   - Popup UI definition

2. **Shared Utilities** (`shared.js`)
   - `extractVersion()` - Parse version strings from text
   - `extractTags()` - Detect franchises and styles
   - `triggerInstall()` - Launch IKEMEN Lab via URL scheme
   - `createInstallButton()` - Generate styled button
   - Button state management (loading, success)

3. **Button Styling** (`button-styles.css`)
   - Purple gradient button design
   - Hover/active states
   - Loading animation
   - Success state styling

4. **MUGEN Archive Support** (`mugenarchive.js`)
   - Page detection logic
   - Download URL extraction
   - Metadata scraping (title, author, description)
   - Button injection and event handling

5. **Extension Popup** (`popup.html`)
   - Status display
   - Supported sites list
   - How-it-works explanation

### Phase 4: Metadata Display ✅

**Files Modified:**
- `IKEMEN Lab/UI/CharacterDetailsView.swift`

**What Was Added:**

1. **UI Components**
   - `sourceInfoHeader` - "Source" section header
   - `sourceInfoContainer` - Card containing scraped data
   - `sourceUrlLabel` - Clickable source URL
   - `scrapedDescriptionLabel` - Description from web page

2. **Layout Management**
   - Dynamic constraints to show/hide source section
   - `tagsTopConstraint` adjusts based on source info visibility

3. **Data Loading**
   - `loadScrapedMetadata(for:)` method
   - Queries database for scraped metadata
   - Shows/hides UI based on data availability
   - Overrides author/version with scraped values

## Data Flow

### Installation Flow

1. **User visits MUGEN content page** (e.g., MUGEN Archive)
2. **Content script detects download page** and injects button
3. **User clicks "Install to IKEMEN Lab"** button
4. **JavaScript scrapes metadata** from the page:
   - Character/stage name from title
   - Author from username element
   - Version from description text
   - Description from post content
   - Tags from text analysis
5. **Extension constructs payload**:
   ```json
   {
     "downloadUrl": "https://...",
     "metadata": {
       "name": "Ryu",
       "author": "Balthazar",
       "version": "2.0",
       "description": "...",
       "tags": ["street fighter", "mvc2"],
       "sourceUrl": "https://...",
       "scrapedAt": "2024-01-15T10:30:00Z"
     }
   }
   ```
6. **Browser navigates to** `ikemenlab://install?data={encodedPayload}`
7. **macOS launches IKEMEN Lab** and calls `application(_:open:)`
8. **AppDelegate parses payload** and starts download
9. **ContentManager installs** character to `chars/` directory
10. **MetadataStore saves** scraped metadata to database
11. **User sees notification** "Installed character: Ryu"
12. **Character appears** in character browser

### Display Flow

1. **User selects character** in IKEMEN Lab
2. **CharacterDetailsView loads** character info
3. **`loadScrapedMetadata(for:)`** queries database
4. **If metadata found**:
   - Show "Source" section
   - Display source URL (e.g., "🔗 mugenarchive.com")
   - Display description
   - Override author/version in quick stats
5. **If no metadata**:
   - Hide "Source" section
   - Show only .def file data

## Site-Specific Scraping

### MUGEN Archive (Implemented)

**URL Pattern:** `https://mugenarchive.com/forums/*`

**Selectors:**
- Title: `.p-title-value`, `.thread-title`, `h1`
- Author: `.username`, `.author-name`, `.p-author .username`
- Description: `.message-body`, `.post-content`, `.messageText`

**Download URL:**
- `.attachment a[href*=".zip"]`
- Links to MediaFire, MEGA, Google Drive

### MUGEN Free For All (Stub)

**URL Pattern:** `https://mugenfreeforall.com/*`

**Status:** Placeholder implemented, needs site analysis

### MUGEN Fighters Guild (Stub)

**URL Pattern:** `https://mugenguild.com/*`

**Status:** Placeholder implemented, needs site analysis

## Database Schema

### scraped_metadata Table

```sql
CREATE TABLE scraped_metadata (
  characterId TEXT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  name TEXT,
  author TEXT,
  version TEXT,
  description TEXT,
  tags TEXT,  -- comma-separated
  sourceUrl TEXT NOT NULL,
  scrapedAt DATETIME NOT NULL
);

CREATE INDEX idx_scraped_metadata_characterId ON scraped_metadata(characterId);
```

## Security Considerations

1. **Sandboxing**: Extension runs in Safari's sandbox
2. **Limited Permissions**: Only accesses specified MUGEN sites
3. **URL Validation**: AppDelegate validates download URLs
4. **Safe Installation**: ContentManager validates archives before extraction
5. **No External Servers**: All data stays local (browser → app → database)

## Testing Strategy

See `TESTING.md` for comprehensive testing guide.

**Key Test Cases:**
1. URL scheme registration and handling
2. Button injection on download pages
3. Metadata scraping accuracy
4. Download and installation flow
5. Database storage and retrieval
6. UI display of scraped metadata
7. Error handling (network, invalid URLs, etc.)

## Known Limitations

1. **Safari-only**: Requires Safari Web Extension framework
2. **macOS-only**: Custom URL scheme is macOS-specific
3. **Single-site support**: Only MUGEN Archive fully implemented
4. **No Xcode target**: Extension files created but not integrated into Xcode project
5. **Manual icon setup**: Extension icons need to be generated from app icon

## Future Enhancements

### Short-term (v1.1)
- [ ] Add MUGEN Free For All support
- [ ] Add MUGEN Fighters Guild support
- [ ] Improve version string parsing
- [ ] Better tag detection accuracy
- [ ] Click on source URL to open in browser

### Medium-term (v1.5)
- [ ] Batch downloads from search results
- [ ] Download queue management
- [ ] Progress tracking in extension popup
- [ ] User preferences (auto-install, notifications)
- [ ] Update detection for installed content

### Long-term (v2.0)
- [ ] Chrome/Firefox extensions (requires Native Messaging)
- [ ] Cloud sync of scraped metadata
- [ ] Community ratings/reviews integration
- [ ] Automatic character screenshots/previews
- [ ] AI-powered character recommendations

## Developer Notes

### Adding New Site Support

To add support for a new MUGEN content site:

1. Create `content-scripts/sitename.js`:
   ```javascript
   (function() {
     'use strict';
     
     function isDownloadPage() { /* ... */ }
     function findDownloadUrl() { /* ... */ }
     function scrapeMetadata() { /* ... */ }
     function injectButton() { /* ... */ }
     
     init();
   })();
   ```

2. Update `manifest.json`:
   ```json
   {
     "matches": ["https://sitename.com/*"],
     "js": ["content-scripts/shared.js", "content-scripts/sitename.js"],
     "css": ["content-scripts/button-styles.css"]
   }
   ```

3. Test on various page types on the site
4. Refine selectors based on site structure

### Debugging Tips

1. **Extension Console**: Safari → Develop → Web Extension Background Content
2. **App Logs**: Console.app → Filter: "IKEMEN Lab"
3. **Database Queries**: `sqlite3 ikemenlab.sqlite`
4. **URL Scheme Test**: `open "ikemenlab://install?data=..."`

## License

GPL-2.0 (same as IKEMEN Lab)

## Contributing

Contributions welcome! Key areas for contribution:
- Additional site support
- Improved metadata extraction
- Better error handling
- UI/UX enhancements
- Testing and bug reports

See main README.md for contribution guidelines.
