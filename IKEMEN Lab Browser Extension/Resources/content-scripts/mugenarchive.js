/**
 * MUGEN Archive content script
 * Detects download pages and injects "Install to IKEMEN Lab" button
 */

(function() {
    'use strict';
    
    console.log('IKEMEN Lab: Initializing MUGEN Archive script');
    
    // Check if this is a download/content page
    function isDownloadPage() {
        // Look for download links or buttons
        const hasDownloadButton = document.querySelector('.download-button') !== null ||
                                   document.querySelector('a[href*="download"]') !== null ||
                                   document.querySelector('.attachment') !== null;
        
        // Check URL patterns
        const url = window.location.href.toLowerCase();
        const isRelevantUrl = url.includes('/forums/downloads') ||
                              url.includes('/forums/threads') ||
                              url.includes('downloads.php') ||
                              url.includes('mugenarchive.com');
        
        return hasDownloadButton || isRelevantUrl;
    }
    
    // Find download URL on the page
    function findDownloadUrl() {
        // Try various selectors for download links - prioritize the actual download button
        const selectors = [
            'a.newcontent_textcontrol[href*="act=down"]',
            'a[href*="act=down"]',
            'a.download-button',
            '.attachment a[href*=".zip"]',
            '.attachment a[href*=".rar"]',
            '.attachment a[href*=".7z"]',
            'a[href*="mediafire"]',
            'a[href*="mega.nz"]',
            'a[href*="drive.google"]'
        ];
        
        for (const selector of selectors) {
            const link = document.querySelector(selector);
            if (link && link.href) {
                return link.href;
            }
        }
        
        return null;
    }
    
    // Scrape metadata from the page
    function scrapeMetadata() {
        const metadata = {
            name: null,
            author: null,
            version: null,
            description: null,
            tags: []
        };
        
        // Try to get title/name
        const titleElement = document.querySelector('.p-title-value') ||
                            document.querySelector('.thread-title') ||
                            document.querySelector('h1');
        if (titleElement) {
            metadata.name = sanitizeText(titleElement.textContent);
        }
        
        // Try to get author
        const authorElement = document.querySelector('.username') ||
                             document.querySelector('.author-name') ||
                             document.querySelector('.p-author .username');
        if (authorElement) {
            metadata.author = sanitizeText(authorElement.textContent, 100);
        }
        
        // Try to get description from first post
        const descriptionElement = document.querySelector('.message-body') ||
                                   document.querySelector('.post-content') ||
                                   document.querySelector('.messageText');
        if (descriptionElement) {
            metadata.description = sanitizeText(descriptionElement.textContent, 500);
            
            // Extract version from description
            metadata.version = extractVersion(metadata.description);
            
            // Extract tags from description
            metadata.tags = extractTags(metadata.description);
        }
        
        return metadata;
    }
    
    // Inject the install button
    function injectButton() {
        // Check if button already exists
        if (document.querySelector('.ikemen-lab-install-btn')) {
            console.log('IKEMEN Lab: Button already exists');
            return;
        }
        
        const downloadUrl = findDownloadUrl();
        if (!downloadUrl) {
            console.log('IKEMEN Lab: No download URL found');
            return;
        }
        
        // Find a good place to inject the button - next to the Download button
        const downloadBtn = document.querySelector('a.newcontent_textcontrol[href*="act=down"]') ||
                           document.querySelector('a[href*="act=down"]') ||
                           document.querySelector('a.downloadbtn');
        
        let targetElement = null;
        if (downloadBtn) {
            targetElement = downloadBtn.parentElement;
        } else {
            // Fallback: find the file info table or content area
            targetElement = document.querySelector('table.tborder') ||
                           document.querySelector('.page') ||
                           document.querySelector('#content');
        }
        
        if (!targetElement) {
            console.log('IKEMEN Lab: No suitable location for button');
            return;
        }
        
        // Create button container
        const container = document.createElement('div');
        container.className = 'ikemen-lab-button-container';
        container.style.cssText = 'display: inline-block; margin: 10px 5px; vertical-align: middle;';
        
        // Create button with inline styles as fallback
        const button = createInstallButton();
        button.style.cssText = 'background: linear-gradient(135deg, #22c55e, #16a34a); color: white; border: none; padding: 10px 16px; border-radius: 6px; cursor: pointer; font-weight: bold; font-size: 14px; display: inline-flex; align-items: center;';
        button.onclick = function() {
            console.log('IKEMEN Lab: Button clicked');
            setButtonLoading(button, true);
            
            const metadata = scrapeMetadata();
            console.log('IKEMEN Lab: Scraped metadata', metadata);
            
            // Trigger installation
            triggerInstall(downloadUrl, metadata);
            
            // Show success state
            setTimeout(() => {
                setButtonSuccess(button);
            }, 1000);
        };
        
        container.appendChild(button);
        
        // Insert next to download button, or at top of target
        if (downloadBtn && downloadBtn.parentElement === targetElement) {
            targetElement.insertBefore(container, downloadBtn.nextSibling);
        } else {
            targetElement.appendChild(container);
        }
        
        console.log('IKEMEN Lab: Button injected successfully at', targetElement.tagName);
    }
    
    // Initialize
    function init() {
        if (isDownloadPage()) {
            console.log('IKEMEN Lab: Download page detected');
            
            // Wait for page to be fully loaded
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', injectButton);
            } else {
                injectButton();
            }
        } else {
            console.log('IKEMEN Lab: Not a download page');
        }
    }
    
    // Run initialization
    init();
    
})();
