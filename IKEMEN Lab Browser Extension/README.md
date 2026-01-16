# IKEMEN Lab Browser Extension

Safari Web Extension for one-click installation of MUGEN characters and stages to IKEMEN Lab.

## Features

- 🎮 One-click installation from MUGEN content sites
- 📦 Automatic metadata scraping (author, version, description)
- 🏷️ Tag detection (franchises, styles, etc.)
- 🔗 Direct integration with IKEMEN Lab via custom URL scheme

## Supported Sites

- ✅ **MUGEN Archive** - Full support
- ⏳ **MUGEN Free For All** - Coming soon
- ⏳ **MUGEN Fighters Guild** - Coming soon

## Installation (Safari)

### Prerequisites
- macOS 11.0 or later
- Safari 14.0 or later
- IKEMEN Lab installed

### Building & Installing

1. Open the main IKEMEN Lab Xcode project
2. Select the "IKEMEN Lab Browser Extension" scheme
3. Build and run (⌘R)
4. Safari will open with the extension available
5. Enable the extension in Safari Preferences > Extensions

### Manual Installation

1. Build the extension target in Xcode
2. Locate the built `.app` in DerivedData
3. Copy to Applications folder
4. Open Safari > Preferences > Extensions
5. Enable "IKEMEN Lab Installer"

## How It Works

### URL Scheme Communication

The extension communicates with the macOS app via the `ikemenlab://` custom URL scheme:

```
ikemenlab://install?data={urlEncodedJson}
```

**Payload structure:**
```json
{
  "downloadUrl": "https://example.com/character.zip",
  "metadata": {
    "name": "Character Name",
    "author": "Creator Name",
    "version": "1.0",
    "description": "Character description...",
    "tags": ["street fighter", "mvc2", "hd"],
    "sourceUrl": "https://example.com/thread/12345",
    "scrapedAt": "2024-01-15T10:30:00Z"
  }
}
```

### Content Script Flow

1. **Page Detection** - Check if current page is a download page
2. **Button Injection** - Insert "Install to IKEMEN Lab" button
3. **Metadata Scraping** - Extract character info from page
4. **URL Trigger** - Launch IKEMEN Lab with download payload

### Metadata Storage

Scraped metadata is stored in IKEMEN Lab's SQLite database (`scraped_metadata` table) and displayed in the character details panel.

## Development

### File Structure

```
IKEMEN Lab Browser Extension/
├── Shared (Extension)/
│   ├── manifest.json              # Extension manifest
│   ├── popup.html                 # Extension popup UI
│   └── content-scripts/
│       ├── shared.js              # Shared utilities
│       ├── button-styles.css     # Button styles
│       ├── mugenarchive.js       # MUGEN Archive scraper
│       ├── mugenfreeforall.js    # MFFA scraper (TODO)
│       └── mugenguild.js         # Guild scraper (TODO)
```

### Adding New Site Support

1. Create a new content script: `content-scripts/sitename.js`
2. Implement site-specific selectors:
   - `isDownloadPage()` - Detect if page has downloadable content
   - `findDownloadUrl()` - Extract download link
   - `scrapeMetadata()` - Parse page for author, version, etc.
3. Add content script to `manifest.json`
4. Test on the target site

### Debugging

1. Open Safari Web Inspector (Develop menu)
2. Check console for `IKEMEN Lab:` prefixed logs
3. Inspect network requests for download URLs
4. Verify URL scheme triggers in macOS Console.app

## Privacy & Permissions

The extension requires:
- **Host permissions** - Access to MUGEN content sites for button injection
- **Tabs** - Open IKEMEN Lab via custom URL scheme

**No data is collected or transmitted** to external servers. All scraped metadata is sent directly to your local IKEMEN Lab installation.

## Troubleshooting

### Button doesn't appear
- Check if page is a download/content page
- Open Safari Web Inspector and check console for errors
- Verify extension is enabled in Safari Preferences

### IKEMEN Lab doesn't open
- Verify IKEMEN Lab is installed
- Check that the `ikemenlab://` URL scheme is registered
- Open Console.app and filter for "IKEMEN Lab" to see error messages

### Download fails
- Check download URL is accessible
- Verify IKEMEN GO working directory is configured
- Look for error alerts from IKEMEN Lab

## Future Enhancements

- [ ] Support for more MUGEN sites
- [ ] Batch download from search results
- [ ] Update detection for installed content
- [ ] Chrome/Firefox extension ports
- [ ] Native messaging for better reliability

## License

GPL-2.0 - Same as IKEMEN Lab

## Contributing

Contributions welcome! To add support for a new site:

1. Analyze the site's page structure
2. Implement a content script with proper selectors
3. Test thoroughly on various pages
4. Submit a pull request

See the `mugenarchive.js` implementation as a reference.
