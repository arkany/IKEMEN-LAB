# Testing the Safari Browser Extension

## Prerequisites

1. macOS 11.0+ with Safari 14.0+
2. IKEMEN Lab installed and configured with a working directory
3. Xcode 13.0+ for building the extension

## Building & Testing Without Xcode Target (Manual Testing)

Since creating an Xcode target requires GUI interaction, you can test the extension's core functionality manually:

### 1. Test URL Scheme Handling

First, verify that the `ikemenlab://` URL scheme is registered:

```bash
# Check if URL scheme is registered
open -a "IKEMEN Lab" "ikemenlab://install?data=%7B%22downloadUrl%22%3A%22https%3A%2F%2Fexample.com%2Fcharacter.zip%22%2C%22metadata%22%3A%7B%22name%22%3A%22Test%20Character%22%2C%22author%22%3A%22Test%20Author%22%2C%22version%22%3A%221.0%22%2C%22description%22%3A%22A%20test%20character%22%2C%22tags%22%3A%5B%22street%20fighter%22%2C%22mvc2%22%5D%2C%22sourceUrl%22%3A%22https%3A%2F%2Fexample.com%2Fthread%2F123%22%2C%22scrapedAt%22%3A%222024-01-15T10%3A30%3A00Z%22%7D%7D"
```

If the URL scheme works, IKEMEN Lab should:
1. Open (if not already running)
2. Show a notification about downloading
3. Attempt to download from the URL (will fail for this test URL)

### 2. Test with Real Download URL

For a real test, you need a valid download URL. Example test payload:

```javascript
// Construct this in browser console on a MUGEN page
const payload = {
  downloadUrl: "https://actual-download-url.zip",
  metadata: {
    name: "Ryu",
    author: "Balthazar",
    version: "2.0",
    description: "Street Fighter character with authentic moves",
    tags: ["street fighter", "capcom", "mvc2"],
    sourceUrl: window.location.href,
    scrapedAt: new Date().toISOString()
  }
};

const payloadJson = JSON.stringify(payload);
const encodedPayload = encodeURIComponent(payloadJson);
const url = `ikemenlab://install?data=${encodedPayload}`;

// Open IKEMEN Lab with the payload
window.location.href = url;
```

### 3. Test Content Script Locally

Open Safari and use the Web Inspector console on a MUGEN Archive page:

```javascript
// Load the shared utilities
var script1 = document.createElement('script');
script1.src = 'file:///path/to/IKEMEN Lab Browser Extension/Shared (Extension)/content-scripts/shared.js';
document.head.appendChild(script1);

// Load the MUGEN Archive script
var script2 = document.createElement('script');
script2.src = 'file:///path/to/IKEMEN Lab Browser Extension/Shared (Extension)/content-scripts/mugenarchive.js';
document.head.appendChild(script2);

// Load the CSS
var link = document.createElement('link');
link.rel = 'stylesheet';
link.href = 'file:///path/to/IKEMEN Lab Browser Extension/Shared (Extension)/content-scripts/button-styles.css';
document.head.appendChild(link);
```

Note: Safari may block `file://` URLs due to security restrictions.

## Setting Up as Safari Web Extension (Requires Xcode)

To create a proper Safari Web Extension target in Xcode:

### Step 1: Create Safari Extension Project

1. Open `IKEMEN Lab.xcodeproj` in Xcode
2. File → New → Target
3. Select "Safari Extension" template
4. Name: "IKEMEN Lab Browser Extension"
5. Uncheck "Include content blocker"
6. Choose Swift as language

### Step 2: Configure Extension Bundle

1. Copy contents of `IKEMEN Lab Browser Extension/Shared (Extension)/` to the new target's `Resources/` folder
2. Add files to the target in Xcode
3. Update `Info.plist` with bundle identifier: `com.ikemenlab.safari-extension`

### Step 3: Configure Entitlements

Add to the extension's entitlements file:
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

### Step 4: Build & Test

1. Build the extension target (⌘B)
2. Run the extension target (⌘R)
3. Safari will launch with the extension enabled
4. Enable it in Safari → Preferences → Extensions

## Testing the Complete Flow

### Test Case 1: MUGEN Archive Download

1. Visit a MUGEN Archive character download page
2. Look for the "Install to IKEMEN Lab" button
3. Click the button
4. IKEMEN Lab should open and start downloading
5. After installation, check the character in IKEMEN Lab
6. View character details to see the scraped metadata

### Test Case 2: Metadata Display

1. Install a character via the extension
2. Open IKEMEN Lab
3. Navigate to Characters tab
4. Select the character you just installed
5. Check the "Source" section in the details panel
6. Verify:
   - Source URL is displayed
   - Description is shown
   - Author/version from web override .def values

### Test Case 3: Error Handling

Test various error scenarios:

1. **Invalid URL**: Click button with no download URL
   - Should show error notification
   
2. **Network failure**: Disconnect internet and try downloading
   - Should show download failed error
   
3. **Invalid archive**: Use a non-zip URL
   - Should show installation error

## Manual Testing Checklist

- [ ] URL scheme opens IKEMEN Lab
- [ ] Download notifications appear
- [ ] Download completes successfully
- [ ] Character installs to chars/ folder
- [ ] Character appears in character browser
- [ ] Scraped metadata is stored in database
- [ ] Source section displays in character details
- [ ] Author/version values override .def data
- [ ] Button styling matches design
- [ ] Button states work (loading, success)
- [ ] Extension popup displays correctly
- [ ] Console logs show proper debugging info

## Debugging Tips

### Check URL Scheme Registration

```bash
# List registered URL schemes for IKEMEN Lab
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump | grep -A 5 "ikemenlab"
```

### Check Database for Scraped Metadata

```bash
# Navigate to IKEMEN GO directory
cd ~/path/to/ikemen-go

# Query scraped metadata
sqlite3 ikemenlab.sqlite "SELECT * FROM scraped_metadata;"
```

### View App Logs

```bash
# Monitor IKEMEN Lab logs
log stream --predicate 'process == "IKEMEN Lab"' --level debug
```

### Debug Extension Console

1. Safari → Develop → Web Extension Background Content
2. Select "IKEMEN Lab Installer"
3. View console logs from content scripts

## Common Issues

### Button Doesn't Appear

**Causes:**
- Extension not enabled in Safari
- Page doesn't match URL patterns in manifest
- JavaScript error in content script

**Debug:**
- Open Web Inspector console
- Check for error messages
- Verify URL matches manifest patterns

### IKEMEN Lab Doesn't Open

**Causes:**
- URL scheme not registered
- IKEMEN Lab not in Applications folder
- Payload encoding error

**Debug:**
- Test URL scheme manually (see above)
- Rebuild IKEMEN Lab to register URL scheme
- Check Console.app for system errors

### Download Fails

**Causes:**
- Invalid download URL
- Network connectivity issue
- Unsupported archive format

**Debug:**
- Verify URL in browser
- Check Console.app logs
- Test with a simple .zip file

### Metadata Not Displayed

**Causes:**
- Database not initialized
- Metadata not scraped correctly
- Character ID mismatch

**Debug:**
- Check database query (see above)
- Verify character ID matches folder name
- Check for SQL errors in logs

## Performance Testing

Test with various scenarios:

1. **Large files**: 50MB+ character archives
2. **Slow connections**: Throttled network
3. **Multiple installs**: Queue 5+ downloads
4. **Duplicate installs**: Re-install same character

## Browser Compatibility Notes

The extension is designed for Safari but uses standard WebExtensions API (Manifest V3). The core functionality (button injection, metadata scraping, URL triggering) should work across browsers with minimal changes.

For Chrome/Firefox support:
1. Replace URL scheme with Native Messaging
2. Adjust manifest.json for browser-specific features
3. Test on each platform separately

## Next Steps After Testing

Once basic functionality is verified:

1. Add support for more MUGEN sites
2. Improve metadata extraction accuracy
3. Add batch download capabilities
4. Implement update detection
5. Add user preferences (auto-install, notifications, etc.)
