# Browser Extension — Agent Prompt

## Overview

Create a Safari/Chrome browser extension that adds an "Install to IKEMEN Lab" button on MUGEN content download pages, enabling one-click installation and metadata scraping.

## Goals

1. **Friction-free installation** — Click button → content downloads → IKEMEN Lab opens → install begins
2. **Metadata capture** — Scrape author, version, description, tags from page before download
3. **Cross-browser support** — Safari (primary, for Mac users) + Chrome (secondary)

## Target Sites

| Site | Priority | URL Pattern |
|------|----------|-------------|
| MUGEN Archive | High | `mugenarchive.com/forums/*` |
| MUGEN Free For All | Medium | `mugenfreeforall.com/*` |
| The Mugen Fighters Guild | Medium | `mugenguild.com/*` |
| OneDrive/MediaFire/MEGA | Low | Various hosting patterns |

## Architecture

```
Browser Extension
├── manifest.json          # Extension config (v3 for Chrome, Safari conversion)
├── content-scripts/
│   ├── mugenarchive.js   # Site-specific scraper
│   ├── mugenfreeforall.js
│   └── mugenguild.js
├── background.js          # Service worker for download handling
├── popup/
│   ├── popup.html        # Settings/status UI
│   └── popup.js
└── shared/
    └── metadata.js        # Common metadata parsing
```

## Content Script Behavior

### 1. Page Detection
```javascript
// mugenarchive.js - inject on download thread pages
const isDownloadPage = () => {
  return document.querySelector('.download-button') !== null ||
         window.location.href.includes('/forums/downloads/');
};
```

### 2. Button Injection
```javascript
const injectButton = () => {
  const downloadBtn = document.querySelector('.download-button');
  if (!downloadBtn) return;
  
  const ikemenBtn = document.createElement('button');
  ikemenBtn.className = 'ikemen-lab-install';
  ikemenBtn.innerHTML = '🎮 Install to IKEMEN Lab';
  ikemenBtn.onclick = handleInstall;
  
  downloadBtn.parentNode.insertBefore(ikemenBtn, downloadBtn.nextSibling);
};
```

### 3. Metadata Scraping
```javascript
const scrapeMetadata = () => {
  return {
    name: document.querySelector('.thread-title')?.textContent?.trim(),
    author: document.querySelector('.author-name')?.textContent?.trim(),
    version: extractVersion(document.body.textContent), // regex for "v1.0", "Ver. 2", etc.
    description: document.querySelector('.post-content')?.textContent?.slice(0, 500),
    tags: extractTags(document.body.textContent), // "Marvel", "KOF", "POTS style", etc.
    sourceUrl: window.location.href,
    scrapedAt: new Date().toISOString()
  };
};
```

## Communication with IKEMEN Lab

### Option A: Custom URL Scheme (Recommended)
```javascript
// Register ikemenlab:// URL scheme in macOS app
const triggerInstall = (downloadUrl, metadata) => {
  const payload = encodeURIComponent(JSON.stringify({ downloadUrl, metadata }));
  window.location.href = `ikemenlab://install?data=${payload}`;
};
```

**macOS App Changes Required:**
- Register `ikemenlab://` URL scheme in Info.plist
- Handle `application(_:open:)` in AppDelegate
- Parse payload, initiate download, show install confirmation

### Option B: Native Messaging (More Complex)
- Requires native messaging host binary
- More reliable but harder to set up
- Better for large payloads

## Safari Extension Specifics

Safari Web Extensions use the same WebExtension APIs but need:
1. Xcode project wrapper
2. App Extension target
3. Containing app (can be minimal)
4. Code signing with Apple Developer account

```
IKEMEN Lab Browser Helper.app/
├── Contents/
│   ├── MacOS/
│   │   └── IKEMEN Lab Browser Helper
│   ├── Resources/
│   │   └── Extension.appex/
│   │       └── (WebExtension bundle)
│   └── Info.plist
```

## Metadata Storage

When extension sends metadata, IKEMEN Lab stores it:

```swift
// In MetadataStore.swift
struct ScrapedMetadata: Codable {
    let name: String
    let author: String?
    let version: String?
    let description: String?
    let tags: [String]
    let sourceUrl: String
    let scrapedAt: Date
}

func storeScrapedMetadata(_ metadata: ScrapedMetadata, for characterId: String) {
    // Store in SQLite alongside character record
    // Use when displaying character details
}
```

## Update Detection (Aspirational)

The extension could potentially detect updates by:
1. Storing `sourceUrl` + `version` when installing
2. Periodically checking if page content changed
3. Comparing version strings

**Challenges:**
- No standard versioning ("v1.0" vs "Ver. 2" vs "2024-01-15")
- Pages may change without version bump
- Rate limiting / being blocked by sites
- Privacy concerns with background checking

**Recommendation:** Start without update detection. Add later if there's demand and a viable approach emerges.

## Implementation Phases

### Phase 1: Safari Extension Skeleton
- [ ] Create Xcode Safari Web Extension project
- [ ] Basic manifest.json with permissions
- [ ] Content script that logs on MUGEN Archive pages
- [ ] Popup with extension status

### Phase 2: Button Injection
- [ ] Detect download pages on MUGEN Archive
- [ ] Inject styled "Install to IKEMEN Lab" button
- [ ] Button click → log download URL

### Phase 3: URL Scheme Integration
- [ ] Register `ikemenlab://` in main app
- [ ] Handle URL in AppDelegate
- [ ] Extension triggers URL with download link
- [ ] App downloads and installs content

### Phase 4: Metadata Scraping
- [ ] Scrape author, version, description from page
- [ ] Pass metadata alongside download URL
- [ ] Store metadata in MetadataStore
- [ ] Display scraped metadata in character details

### Phase 5: Multi-Site Support
- [ ] Add content script for MUGEN Free For All
- [ ] Add content script for MUGEN Fighters Guild
- [ ] Site-specific scraping patterns

### Phase 6: Chrome Extension (Optional)
- [ ] Port to Chrome Web Store
- [ ] Native messaging host for macOS
- [ ] Cross-browser testing

## UI/UX Considerations

### Button Styling
- Match site's button style where possible
- Clear IKEMEN Lab branding (icon + text)
- Loading state while preparing install
- Success/error feedback

### Popup UI
- Show connection status to IKEMEN Lab
- List of recent installs via extension
- Settings: enable/disable per-site
- Link to open IKEMEN Lab

## Security Considerations

1. **Content Security Policy** — Sites may block inline scripts
2. **Download validation** — App should validate downloaded files
3. **URL scheme hijacking** — Validate payload source
4. **Permission scope** — Request minimal permissions

## Files to Create/Modify

### New Files
```
IKEMEN Lab Browser Extension/
├── IKEMEN Lab Browser Extension.xcodeproj
├── Shared (Extension)/
│   ├── manifest.json
│   ├── content.js
│   ├── background.js
│   └── popup/
├── macOS (App)/
│   └── AppDelegate.swift  # Minimal containing app
└── macOS (Extension)/
    └── SafariWebExtensionHandler.swift
```

### Modified Files
- `IKEMEN Lab/App/AppDelegate.swift` — Add URL scheme handler
- `IKEMEN Lab/Info.plist` — Register `ikemenlab://` scheme
- `IKEMEN Lab/Core/ContentManager.swift` — Accept metadata from extension
- `IKEMEN Lab/Core/MetadataStore.swift` — Store scraped metadata

## Success Criteria

1. ✅ Extension installs in Safari without errors
2. ✅ Button appears on MUGEN Archive download pages
3. ✅ Clicking button opens IKEMEN Lab with download queued
4. ✅ Metadata (author, version) appears in character details
5. ✅ Works for at least 3 major MUGEN sites

## Out of Scope (v1)

- Chrome extension (defer to Phase 6)
- Automatic update checking
- Batch downloads from search results
- Account integration with MUGEN sites
- Download queue management in extension

## Resources

- [Safari Web Extensions Guide](https://developer.apple.com/documentation/safariservices/safari_web_extensions)
- [WebExtensions API](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions)
- [Custom URL Schemes](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
