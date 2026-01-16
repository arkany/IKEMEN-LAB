/**
 * Shared utilities for IKEMEN Lab browser extension
 */

// Extract version string from text using common patterns
function extractVersion(text) {
    if (!text) return null;
    
    // Common version patterns: v1.0, Ver. 2, Version 3.5, 2024-01-15
    const patterns = [
        /v\s*(\d+\.?\d*\.?\d*)/i,
        /ver\.?\s*(\d+\.?\d*\.?\d*)/i,
        /version\s*(\d+\.?\d*\.?\d*)/i,
        /(\d{4}[-\/]\d{2}[-\/]\d{2})/,  // Date format
        /\b(\d+\.?\d+\.?\d*)\b/  // Generic numeric version
    ];
    
    for (const pattern of patterns) {
        const match = text.match(pattern);
        if (match) {
            return match[1];
        }
    }
    
    return null;
}

// Extract tags from text (fighting game franchises, styles, etc.)
function extractTags(text) {
    if (!text) return [];
    
    const lowerText = text.toLowerCase();
    const tags = new Set();
    
    // Fighting game franchises
    const franchises = [
        'street fighter', 'king of fighters', 'kof', 'fatal fury', 
        'tekken', 'mortal kombat', 'guilty gear', 'blazblue',
        'marvel', 'capcom', 'snk', 'arc system', 'namco',
        'dragon ball', 'naruto', 'one piece', 'pokemon',
        'touhou', 'melty blood', 'under night', 'samurai shodown'
    ];
    
    for (const franchise of franchises) {
        if (lowerText.includes(franchise)) {
            tags.add(franchise);
        }
    }
    
    // Sprite styles
    const styles = [
        'pots', 'mvc2', 'mvc', 'cvs', 'kof', 'anime', '3d', 'hd',
        'pixel', 'sprite', 'mugen 1.0', 'mugen 1.1', 'hi-res'
    ];
    
    for (const style of styles) {
        if (lowerText.includes(style)) {
            tags.add(style);
        }
    }
    
    return Array.from(tags);
}

// Trigger installation via custom URL scheme
async function triggerInstall(downloadUrl, metadata) {
    if (!downloadUrl) {
        console.error('IKEMEN Lab: No download URL provided');
        return;
    }
    
    console.log('IKEMEN Lab: Fetching file with credentials...');
    
    try {
        // Fetch the file with cookies (content script has access to page cookies)
        const response = await fetch(downloadUrl, {
            credentials: 'include',
            mode: 'cors'
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        // Get the blob data
        const blob = await response.blob();
        console.log('IKEMEN Lab: Downloaded', blob.size, 'bytes, type:', blob.type);
        
        // Convert to base64 data URL
        const reader = new FileReader();
        reader.onloadend = function() {
            const base64Data = reader.result.split(',')[1]; // Remove data:...;base64, prefix
            
            const payload = {
                fileData: base64Data,
                fileName: getFilenameFromUrl(downloadUrl) || 'download.zip',
                metadata: {
                    name: metadata.name || null,
                    author: metadata.author || null,
                    version: metadata.version || null,
                    description: metadata.description || null,
                    tags: metadata.tags || [],
                    sourceUrl: window.location.href,
                    scrapedAt: new Date().toISOString()
                }
            };
            
            // Encode payload as URL parameter
            const payloadJson = JSON.stringify(payload);
            const encodedPayload = encodeURIComponent(payloadJson);
            const url = `ikemenlab://install?data=${encodedPayload}`;
            
            console.log('IKEMEN Lab: Triggering installation with', blob.size, 'bytes');
            
            // Navigate to the custom URL scheme
            window.location.href = url;
        };
        reader.readAsDataURL(blob);
        
    } catch (error) {
        console.error('IKEMEN Lab: Download failed:', error);
        // Fallback: open in new tab
        alert('Download requires login. Opening download page...');
        window.open(downloadUrl, '_blank');
    }
}

// Extract filename from URL
function getFilenameFromUrl(url) {
    try {
        const urlObj = new URL(url);
        const params = urlObj.searchParams;
        // Try to get filename from URL params
        const id = params.get('id');
        if (id) {
            return id.split('-').slice(1).join('-') + '.zip';
        }
        return urlObj.pathname.split('/').pop();
    } catch (e) {
        return null;
    }
}

// Create and inject the "Install to IKEMEN Lab" button
function createInstallButton() {
    const button = document.createElement('button');
    button.className = 'ikemen-lab-install-btn';
    button.innerHTML = `
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" style="margin-right: 6px; vertical-align: middle;">
            <path d="M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0zm1 11.5V9h2.5l-3.5 4-3.5-4H7V6h2v5.5z"/>
        </svg>
        Install to IKEMEN Lab
    `;
    button.title = 'Download and install to IKEMEN Lab';
    return button;
}

// Show loading state on button
function setButtonLoading(button, isLoading) {
    if (isLoading) {
        button.disabled = true;
        button.innerHTML = `
            <span style="display: inline-block; animation: spin 1s linear infinite; margin-right: 6px;">⟳</span>
            Installing...
        `;
    } else {
        button.disabled = false;
        button.innerHTML = `
            <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" style="margin-right: 6px; vertical-align: middle;">
                <path d="M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0zm1 11.5V9h2.5l-3.5 4-3.5-4H7V6h2v5.5z"/>
            </svg>
            Install to IKEMEN Lab
        `;
    }
}

// Show success state on button
function setButtonSuccess(button) {
    button.className = 'ikemen-lab-install-btn ikemen-lab-success';
    button.innerHTML = `
        <span style="margin-right: 6px;">✓</span>
        Installed!
    `;
    
    // Reset after 3 seconds
    setTimeout(() => {
        button.className = 'ikemen-lab-install-btn';
        setButtonLoading(button, false);
    }, 3000);
}

// Sanitize text for safe display
function sanitizeText(text, maxLength = 500) {
    if (!text) return null;
    return text.trim().slice(0, maxLength);
}
