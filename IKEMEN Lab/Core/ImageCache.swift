import Foundation
import AppKit

// MARK: - Image Cache

/// Thread-safe image cache using NSCache for automatic memory management
/// Used for caching extracted SFF portraits and stage previews
public final class ImageCache {
    
    // MARK: - Singleton
    
    public static let shared = ImageCache()
    
    // MARK: - Properties
    
    private let cache: NSCache<NSString, NSImage>
    
    /// Cache statistics for debugging
    private(set) var hitCount: Int = 0
    private(set) var missCount: Int = 0
    
    // MARK: - Initialization
    
    private init() {
        cache = NSCache<NSString, NSImage>()
        cache.name = "com.macmugen.ImageCache"
        
        // Set reasonable limits
        // countLimit: max number of images to cache
        // totalCostLimit: approximate max bytes (we'll estimate image sizes)
        cache.countLimit = 500  // Up to 500 images
        cache.totalCostLimit = 100 * 1024 * 1024  // ~100MB
    }
    
    // MARK: - Cache Key Generation
    
    /// Generate a cache key for a character portrait
    public static func portraitKey(for characterId: String) -> String {
        return "portrait:\(characterId)"
    }
    
    /// Generate a cache key for a stage preview
    public static func stagePreviewKey(for stageId: String) -> String {
        return "stage:\(stageId)"
    }
    
    /// Generate a cache key for an SFF sprite
    public static func sffKey(filePath: String, group: Int, image: Int) -> String {
        return "sff:\(filePath):\(group):\(image)"
    }
    
    // MARK: - Cache Operations
    
    /// Get an image from cache
    public func get(_ key: String) -> NSImage? {
        let nsKey = key as NSString
        if let image = cache.object(forKey: nsKey) {
            hitCount += 1
            return image
        }
        missCount += 1
        return nil
    }
    
    /// Store an image in cache
    public func set(_ image: NSImage, for key: String) {
        let nsKey = key as NSString
        // Estimate cost based on image size (width * height * 4 bytes per pixel)
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: nsKey, cost: cost)
    }
    
    /// Remove an image from cache
    public func remove(_ key: String) {
        let nsKey = key as NSString
        cache.removeObject(forKey: nsKey)
    }
    
    /// Clear all cached images
    public func clear() {
        cache.removeAllObjects()
        hitCount = 0
        missCount = 0
    }
    
    /// Remove cached images for a specific character
    public func clearCharacter(_ characterId: String) {
        remove(ImageCache.portraitKey(for: characterId))
    }
    
    /// Remove cached images for a specific stage
    public func clearStage(_ stageId: String) {
        remove(ImageCache.stagePreviewKey(for: stageId))
    }
    
    // MARK: - Convenience Methods
    
    /// Get or load a character portrait
    public func getPortrait(for character: CharacterInfo) -> NSImage? {
        let key = ImageCache.portraitKey(for: character.id)
        
        // Check cache first
        if let cached = get(key) {
            return cached
        }
        
        // Load from SFF
        if let image = character.getPortraitImage() {
            set(image, for: key)
            return image
        }
        
        return nil
    }
    
    /// Get or load a stage preview
    public func getStagePreview(for stage: StageInfo) -> NSImage? {
        let key = ImageCache.stagePreviewKey(for: stage.id)
        
        // Check cache first
        if let cached = get(key) {
            return cached
        }
        
        // Load from SFF
        if let image = stage.loadPreviewImage() {
            set(image, for: key)
            return image
        }
        
        return nil
    }
    
    // MARK: - Debug
    
    /// Cache hit rate for debugging
    public var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }
    
    /// Debug description
    public var debugDescription: String {
        return "ImageCache: \(hitCount) hits, \(missCount) misses (\(String(format: "%.1f", hitRate * 100))% hit rate)"
    }
}

// MARK: - Protocol Conformance

extension ImageCache: ImageCacheProtocol {}
