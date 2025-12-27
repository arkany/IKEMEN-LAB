import Foundation
import AppKit

/// Writes SFF v2 sprite files with embedded PNG images
/// Used to create stage sprites from PNG background images
public final class SFFWriter {
    
    // MARK: - Errors
    
    public enum SFFWriteError: LocalizedError {
        case invalidImage
        case pngEncodingFailed
        case writeFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Invalid image provided"
            case .pngEncodingFailed:
                return "Failed to encode image as PNG"
            case .writeFailed(let detail):
                return "Failed to write SFF file: \(detail)"
            }
        }
    }
    
    // MARK: - Sprite Entry
    
    /// Represents a sprite to be written to the SFF file
    public struct SpriteEntry {
        let group: UInt16
        let image: UInt16
        let x: Int16  // X axis offset
        let y: Int16  // Y axis offset
        let pngData: Data
        let width: UInt16
        let height: UInt16
        
        public init(group: UInt16, image: UInt16, x: Int16 = 0, y: Int16 = 0, image nsImage: NSImage) throws {
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw SFFWriteError.pngEncodingFailed
            }
            
            self.group = group
            self.image = image
            self.x = x
            self.y = y
            self.pngData = png
            self.width = UInt16(bitmap.pixelsWide)
            self.height = UInt16(bitmap.pixelsHigh)
        }
        
        public init(group: UInt16, image: UInt16, x: Int16 = 0, y: Int16 = 0, pngData: Data, width: UInt16, height: UInt16) {
            self.group = group
            self.image = image
            self.x = x
            self.y = y
            self.pngData = pngData
            self.width = width
            self.height = height
        }
    }
    
    // MARK: - Writing
    
    /// Create an SFF v2 file containing the provided sprites
    /// - Parameters:
    ///   - sprites: Array of sprite entries to include
    ///   - outputURL: Destination URL for the SFF file
    /// - Returns: Result indicating success or failure
    public static func write(sprites: [SpriteEntry], to outputURL: URL) -> Result<Void, SFFWriteError> {
        var data = Data()
        
        // --- SFF v2 Header (36 bytes base + variable) ---
        
        // Signature: "ElecbyteSpr\0" (12 bytes)
        let signature = "ElecbyteSpr\0".data(using: .ascii)!
        data.append(signature)
        
        // Version: v2.01 (4 bytes: verlo3, verlo2, verlo1, verhi)
        data.append(UInt8(0))   // verlo3
        data.append(UInt8(1))   // verlo2 
        data.append(UInt8(0))   // verlo1
        data.append(UInt8(2))   // verhi = 2
        
        // Reserved (4 bytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 4))
        
        // Reserved (4 bytes) 
        data.append(contentsOf: [UInt8](repeating: 0, count: 4))
        
        // Compatibility version (4 bytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 4))
        
        // Reserved (4 bytes)
        data.append(contentsOf: [UInt8](repeating: 0, count: 4))
        
        // Calculate offsets
        let headerSize: UInt32 = 36
        let spriteNodeSize: UInt32 = 28
        let paletteNodeSize: UInt32 = 16
        
        // We'll use 1 dummy palette node
        let paletteCount: UInt32 = 1
        let spriteCount = UInt32(sprites.count)
        
        let spriteListOffset = headerSize
        let paletteListOffset = spriteListOffset + (spriteCount * spriteNodeSize)
        let ldataOffset = paletteListOffset + (paletteCount * paletteNodeSize)
        
        // Calculate total ldata size (all PNG data with 4-byte length prefixes)
        var totalLdataSize: UInt32 = 0
        for sprite in sprites {
            totalLdataSize += UInt32(sprite.pngData.count) + 4  // 4 bytes for length prefix
        }
        
        // Add dummy palette data (4 bytes for RGBA of color 0)
        let paletteDataSize: UInt32 = 4
        totalLdataSize += paletteDataSize
        
        // Offset 36: Sprite list offset
        data.append(littleEndian: spriteListOffset)
        
        // Offset 40: Sprite count
        data.append(littleEndian: spriteCount)
        
        // Offset 44: Palette list offset
        data.append(littleEndian: paletteListOffset)
        
        // Offset 48: Palette count
        data.append(littleEndian: paletteCount)
        
        // Offset 52: Ldata offset (literal data)
        data.append(littleEndian: ldataOffset)
        
        // Offset 56: Ldata length
        data.append(littleEndian: totalLdataSize)
        
        // Offset 60: Tdata offset (not used, same as end of file)
        let tdataOffset = ldataOffset + totalLdataSize
        data.append(littleEndian: tdataOffset)
        
        // Offset 64: Tdata length (0 - not used)
        data.append(littleEndian: UInt32(0))
        
        // --- Sprite Nodes (28 bytes each) ---
        
        var currentLdataOffset: UInt32 = paletteDataSize  // Skip palette data at start
        
        for sprite in sprites {
            // Group number (2 bytes)
            data.append(littleEndian: sprite.group)
            
            // Image number (2 bytes)
            data.append(littleEndian: sprite.image)
            
            // Width (2 bytes)
            data.append(littleEndian: sprite.width)
            
            // Height (2 bytes)
            data.append(littleEndian: sprite.height)
            
            // X axis (2 bytes)
            data.append(littleEndian: UInt16(bitPattern: sprite.x))
            
            // Y axis (2 bytes)
            data.append(littleEndian: UInt16(bitPattern: sprite.y))
            
            // Linked index (2 bytes) - 0xFFFF = not linked
            data.append(littleEndian: UInt16(0xFFFF))
            
            // Format (1 byte) - 11 = PNG24, 12 = PNG32
            data.append(UInt8(12))  // PNG32 (with alpha)
            
            // Color depth (1 byte) - 32 for PNG32
            data.append(UInt8(32))
            
            // Data offset within ldata (4 bytes)
            data.append(littleEndian: currentLdataOffset)
            
            // Data length (4 bytes) - PNG data + 4 byte header
            let dataLen = UInt32(sprite.pngData.count) + 4
            data.append(littleEndian: dataLen)
            
            // Palette index (2 bytes) - 0 for PNG
            data.append(littleEndian: UInt16(0))
            
            // Flags (2 bytes) - 0 = uses ldata
            data.append(littleEndian: UInt16(0))
            
            currentLdataOffset += dataLen
        }
        
        // --- Palette Nodes (16 bytes each) ---
        
        // One dummy palette node
        // Group number (2 bytes)
        data.append(littleEndian: UInt16(0))
        
        // Item number (2 bytes)
        data.append(littleEndian: UInt16(0))
        
        // Color count (2 bytes)
        data.append(littleEndian: UInt16(1))
        
        // Linked index (2 bytes)
        data.append(littleEndian: UInt16(0))
        
        // Data offset (4 bytes)
        data.append(littleEndian: UInt32(0))
        
        // Data length (4 bytes)
        data.append(littleEndian: paletteDataSize)
        
        // --- Ldata (Literal Data) ---
        
        // Dummy palette data (RGBA for color 0 - transparent black)
        data.append(contentsOf: [UInt8(0), UInt8(0), UInt8(0), UInt8(0)])
        
        // PNG sprite data
        for sprite in sprites {
            // 4-byte header with uncompressed size (for PNG it's typically ignored)
            let uncompressedSize = UInt32(sprite.width) * UInt32(sprite.height) * 4
            data.append(littleEndian: uncompressedSize)
            
            // PNG data
            data.append(sprite.pngData)
        }
        
        // Write to file
        do {
            try data.write(to: outputURL)
            return .success(())
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }
    
    /// Create a simple SFF file with a single background sprite
    /// - Parameters:
    ///   - image: The background image
    ///   - outputURL: Destination URL for the SFF file  
    /// - Returns: Result indicating success or failure
    public static func writeStageBackground(image: NSImage, to outputURL: URL) -> Result<Void, SFFWriteError> {
        do {
            // Create background sprite (group 0, image 0)
            let bgSprite = try SpriteEntry(group: 0, image: 0, x: 0, y: 0, image: image)
            
            // Optionally create a thumbnail sprite (group 9000, image 0)
            // This is used for stage select preview
            let thumbnailImage = createThumbnail(from: image, maxSize: 320)
            let thumbSprite = try SpriteEntry(group: 9000, image: 0, x: 0, y: 0, image: thumbnailImage)
            
            return write(sprites: [bgSprite, thumbSprite], to: outputURL)
        } catch let error as SFFWriteError {
            return .failure(error)
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }
    
    /// Create a thumbnail version of the image
    private static func createThumbnail(from image: NSImage, maxSize: CGFloat) -> NSImage {
        let originalSize = image.size
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height)
        let newWidth = Int(originalSize.width * scale)
        let newHeight = Int(originalSize.height * scale)
        
        // Use NSBitmapImageRep for reliable thumbnail creation
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: newWidth,
            pixelsHigh: newHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: newWidth * 4,
            bitsPerPixel: 32
        )!
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        
        image.draw(in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        
        let thumbnail = NSImage(size: NSSize(width: newWidth, height: newHeight))
        thumbnail.addRepresentation(rep)
        
        return thumbnail
    }
}

// MARK: - Data Extension for Little Endian Writing

fileprivate extension Data {
    mutating func append(littleEndian value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }
    
    mutating func append(littleEndian value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
