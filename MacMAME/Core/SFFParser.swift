import Foundation
import AppKit

// MARK: - SFF Portrait/Preview Extractor

/// Extracts portrait and preview images from SFF sprite files
/// Supports both SFF v1 (PCX-based) and SFF v2 (PNG/RLE/LZ5-based) formats
public final class SFFParser {
    
    // MARK: - Public API
    
    /// Extract portrait sprite (group 9000) from SFF file
    /// - Parameter sffURL: URL to the SFF file
    /// - Returns: The extracted portrait image, or nil if not found
    public static func extractPortrait(from sffURL: URL) -> NSImage? {
        guard let data = try? Data(contentsOf: sffURL) else { return nil }
        return extractPortrait(from: data)
    }
    
    /// Extract portrait sprite (group 9000) from SFF data
    /// - Parameter data: Raw SFF file data
    /// - Returns: The extracted portrait image, or nil if not found
    public static func extractPortrait(from data: Data) -> NSImage? {
        guard data.count > 32 else { return nil }
        
        // Check SFF signature and version
        let signature = String(data: data[0..<12], encoding: .ascii) ?? ""
        guard signature.hasPrefix("ElecbyteSpr") else { return nil }
        
        // Version is at byte 15 (major version indicator)
        let verHi = data[15]
        
        if verHi >= 2 {
            return extractSFFv2Portrait(data)
        } else {
            return extractSFFv1Portrait(data)
        }
    }
    
    /// Extract stage preview (group 9000 or group 0) from SFF file
    /// - Parameter sffURL: URL to the SFF file
    /// - Returns: The extracted preview image, or nil if not found
    public static func extractStagePreview(from sffURL: URL) -> NSImage? {
        guard let data = try? Data(contentsOf: sffURL) else { return nil }
        return extractStagePreview(from: data)
    }
    
    /// Extract stage preview (group 9000 or group 0) from SFF data
    /// - Parameter data: Raw SFF file data
    /// - Returns: The extracted preview image, or nil if not found
    public static func extractStagePreview(from data: Data) -> NSImage? {
        guard data.count > 32 else { return nil }
        
        let signature = String(data: data[0..<12], encoding: .ascii) ?? ""
        guard signature.hasPrefix("ElecbyteSpr") else { return nil }
        
        let verHi = data[15]
        
        if verHi >= 2 {
            return extractSFFv2StagePreview(data)
        } else {
            return extractSFFv1StagePreview(data)
        }
    }
    
    // MARK: - Byte Reading Helpers
    
    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        guard offset + 1 < data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    
    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }
    
    // MARK: - SFF v1 Extraction
    
    private static func extractSFFv1Portrait(_ data: Data) -> NSImage? {
        guard data.count > 32 else { return nil }
        
        // SFF v1 header:
        // 0-11: signature "ElecbyteSpr\0"
        // 12-15: version (little endian)
        // 16-19: number of groups
        // 20-23: number of images
        // 24-27: offset to first subfile
        // 28-31: size of subfile header
        
        let numImages = readUInt32(data, at: 20)
        let firstSubfileOffset = readUInt32(data, at: 24)
        
        guard numImages > 0, firstSubfileOffset < data.count else { return nil }
        
        var offset = Int(firstSubfileOffset)
        var paletteData: Data? // Store palette from first sprite if needed
        
        for i in 0..<min(Int(numImages), 2000) {
            guard offset + 32 <= data.count else { break }
            
            let nextOffset = readUInt32(data, at: offset)
            let subfileLength = readUInt32(data, at: offset + 4)
            let groupNum = readUInt16(data, at: offset + 12)
            let imageNum = readUInt16(data, at: offset + 14)
            let linkedIndex = readUInt16(data, at: offset + 16)
            let samePalette = data[offset + 18]
            
            // Store palette from first sprite for later use
            if i == 0 && subfileLength > 0 {
                let pcxStart = offset + 32
                let pcxEnd = min(pcxStart + Int(subfileLength), data.count)
                if pcxEnd > pcxStart {
                    paletteData = extractPCXPalette(from: data[pcxStart..<pcxEnd])
                }
            }
            
            // Portrait is typically group 9000, image 0
            if groupNum == 9000 && imageNum == 0 {
                // Check if it's a linked sprite
                if linkedIndex != 0 && linkedIndex < numImages {
                    // This is a linked sprite - skip for now
                } else if subfileLength > 0 {
                    // Extract PCX data
                    let pcxStart = offset + 32
                    let pcxEnd = min(pcxStart + Int(subfileLength), data.count)
                    if pcxEnd > pcxStart {
                        let pcxData = data[pcxStart..<pcxEnd]
                        if let image = decodePCX(Data(pcxData), sharedPalette: samePalette != 0 ? paletteData : nil) {
                            return image
                        }
                    }
                }
            }
            
            if nextOffset == 0 || nextOffset <= offset { break }
            offset = Int(nextOffset)
        }
        
        return nil
    }
    
    private static func extractSFFv1StagePreview(_ data: Data) -> NSImage? {
        let spriteCount = readUInt32(data, at: 20)
        let firstSpriteOffset = readUInt32(data, at: 24)
        
        guard spriteCount > 0, firstSpriteOffset < data.count else { return nil }
        
        // First pass: look for group 9000 (stage preview thumbnail)
        var offset = Int(firstSpriteOffset)
        
        for _ in 0..<min(Int(spriteCount), 100) {
            guard offset + 32 <= data.count else { break }
            
            let nextOffset = readUInt32(data, at: offset)
            let dataLength = readUInt32(data, at: offset + 4)
            let groupNum = readUInt16(data, at: offset + 12)
            
            if groupNum == 9000 && dataLength > 0 {
                let pcxStart = offset + 32
                let pcxEnd = pcxStart + Int(dataLength)
                guard pcxEnd <= data.count else { continue }
                
                let pcxData = data[pcxStart..<pcxEnd]
                if let image = decodePCX(Data(pcxData), sharedPalette: nil) {
                    return image
                }
            }
            
            if nextOffset == 0 || nextOffset <= offset { break }
            offset = Int(nextOffset)
        }
        
        // Second pass: fall back to group 0 (background sprite)
        offset = Int(firstSpriteOffset)
        
        for _ in 0..<min(Int(spriteCount), 100) {
            guard offset + 32 <= data.count else { break }
            
            let nextOffset = readUInt32(data, at: offset)
            let dataLength = readUInt32(data, at: offset + 4)
            let groupNum = readUInt16(data, at: offset + 12)
            let imageNum = readUInt16(data, at: offset + 14)
            
            if groupNum == 0 && imageNum == 0 && dataLength > 0 {
                let pcxStart = offset + 32
                let pcxEnd = pcxStart + Int(dataLength)
                guard pcxEnd <= data.count else { continue }
                
                let pcxData = data[pcxStart..<pcxEnd]
                if let image = decodePCX(Data(pcxData), sharedPalette: nil) {
                    return image
                }
            }
            
            if nextOffset == 0 || nextOffset <= offset { break }
            offset = Int(nextOffset)
        }
        
        return nil
    }
    
    // MARK: - SFF v2 Extraction
    
    private static func extractSFFv2Portrait(_ data: Data) -> NSImage? {
        guard data.count > 36 else { return nil }
        
        // SFF v2 header structure:
        // 36-39: sprite offset
        // 40-43: sprite count
        // 44-47: palette offset
        // 52-55: ldata offset
        // 60-63: tdata offset
        
        let spriteOffset = readUInt32(data, at: 36)
        let spriteCount = readUInt32(data, at: 40)
        let paletteOffset = readUInt32(data, at: 44)
        let ldataOffset = readUInt32(data, at: 52)
        let tdataOffset = readUInt32(data, at: 60)
        
        guard spriteCount > 0, spriteOffset < data.count else { return nil }
        
        // Build a list of sprite nodes for group 9000 and fallback to group 0 (standing)
        var offset = Int(spriteOffset)
        var portraitSprite: (offset: Int, width: Int, height: Int)? = nil
        var standingSprite: (offset: Int, width: Int, height: Int)? = nil
        
        for _ in 0..<min(Int(spriteCount), 5000) {
            guard offset + 28 <= data.count else { break }
            
            let groupNum = readUInt16(data, at: offset)
            let imageNum = readUInt16(data, at: offset + 2)
            let width = Int(readUInt16(data, at: offset + 4))
            let height = Int(readUInt16(data, at: offset + 6))
            
            // Portrait candidates: group 9000, prefer larger portrait
            if groupNum == 9000 {
                if width > 50 && height > 50 {
                    if portraitSprite == nil {
                        portraitSprite = (offset, width, height)
                    }
                } else if portraitSprite == nil {
                    portraitSprite = (offset, width, height)
                }
            }
            
            // Standing sprite: group 0, image 0
            if groupNum == 0 && imageNum == 0 && width > 30 && height > 30 {
                standingSprite = (offset, width, height)
            }
            
            offset += 28
        }
        
        // Try portrait first, then standing sprite
        let candidateSprites = [portraitSprite, standingSprite].compactMap { $0 }
        
        for sprite in candidateSprites {
            if let image = extractSFFv2SpriteAtOffset(data, offset: sprite.offset, 
                                                       paletteOffset: Int(paletteOffset), 
                                                       ldataOffset: Int(ldataOffset), 
                                                       tdataOffset: Int(tdataOffset)) {
                return image
            }
        }
        
        return nil
    }
    
    private static func extractSFFv2StagePreview(_ data: Data) -> NSImage? {
        guard data.count > 36 else { return nil }
        
        let spriteOffset = readUInt32(data, at: 36)
        let spriteCount = readUInt32(data, at: 40)
        let paletteOffset = readUInt32(data, at: 44)
        let ldataOffset = readUInt32(data, at: 52)
        let tdataOffset = readUInt32(data, at: 60)
        
        guard spriteCount > 0, spriteOffset < data.count else { return nil }
        
        // First pass: look for group 9000 (stage preview thumbnail)
        var offset = Int(spriteOffset)
        
        for _ in 0..<min(Int(spriteCount), 100) {
            guard offset + 28 <= data.count else { break }
            
            let groupNum = readUInt16(data, at: offset)
            let width = Int(readUInt16(data, at: offset + 4))
            let height = Int(readUInt16(data, at: offset + 6))
            
            if groupNum == 9000 && width > 0 && height > 0 {
                if let image = extractSFFv2SpriteAtOffset(data, offset: offset, 
                                                           paletteOffset: Int(paletteOffset), 
                                                           ldataOffset: Int(ldataOffset), 
                                                           tdataOffset: Int(tdataOffset)) {
                    return image
                }
            }
            
            offset += 28
        }
        
        // Second pass: fall back to group 0 image 0 (background)
        offset = Int(spriteOffset)
        
        for _ in 0..<min(Int(spriteCount), 100) {
            guard offset + 28 <= data.count else { break }
            
            let groupNum = readUInt16(data, at: offset)
            let imageNum = readUInt16(data, at: offset + 2)
            let width = Int(readUInt16(data, at: offset + 4))
            let height = Int(readUInt16(data, at: offset + 6))
            
            if groupNum == 0 && imageNum == 0 && width > 0 && height > 0 {
                if let image = extractSFFv2SpriteAtOffset(data, offset: offset, 
                                                           paletteOffset: Int(paletteOffset), 
                                                           ldataOffset: Int(ldataOffset), 
                                                           tdataOffset: Int(tdataOffset)) {
                    return image
                }
            }
            
            offset += 28
        }
        
        return nil
    }
    
    private static func extractSFFv2SpriteAtOffset(_ data: Data, offset: Int, paletteOffset: Int, ldataOffset: Int, tdataOffset: Int) -> NSImage? {
        let width = Int(readUInt16(data, at: offset + 4))
        let height = Int(readUInt16(data, at: offset + 6))
        let linkedIndex = readUInt16(data, at: offset + 12)
        let format = data[offset + 14]
        let colorDepth = data[offset + 15]
        let dataOffset = readUInt32(data, at: offset + 16)
        let dataLength = readUInt32(data, at: offset + 20)
        let paletteIndex = readUInt16(data, at: offset + 24)
        let flags = readUInt16(data, at: offset + 26)
        
        // Skip linked sprites
        if linkedIndex != 0xFFFF && linkedIndex != 0 {
            return nil
        }
        
        guard width > 0, width < 4000, height > 0, height < 4000 else {
            return nil
        }
        
        let usesTdata = (flags & 1) != 0
        let actualOffset: Int
        if usesTdata {
            actualOffset = tdataOffset + Int(dataOffset)
        } else {
            actualOffset = ldataOffset + Int(dataOffset)
        }
        
        guard actualOffset + Int(dataLength) <= data.count else {
            return nil
        }
        
        // Extract palette for 8-bit formats
        var palette: [UInt8]?
        if colorDepth == 8 && format != 11 && format != 12 {
            palette = extractSFFv2Palette(data, paletteOffset: paletteOffset, paletteIndex: Int(paletteIndex))
        }
        
        let spriteData = data[actualOffset..<(actualOffset + Int(dataLength))]
        
        return decodeSFFv2Sprite(Data(spriteData), width: width, height: height, format: format, colorDepth: colorDepth, palette: palette)
    }
    
    private static func extractSFFv2Palette(_ data: Data, paletteOffset: Int, paletteIndex: Int) -> [UInt8]? {
        // Each palette node is 16 bytes
        let nodeOffset = paletteOffset + (paletteIndex * 16)
        guard nodeOffset + 16 <= data.count else { return nil }
        
        let colorCount = Int(readUInt16(data, at: nodeOffset + 4))
        let linkedIndex = readUInt16(data, at: nodeOffset + 6)
        let palDataOffset = readUInt32(data, at: nodeOffset + 8)
        let palDataLength = readUInt32(data, at: nodeOffset + 12)
        
        // Handle linked palette
        if linkedIndex != 0 && palDataLength == 0 {
            return extractSFFv2Palette(data, paletteOffset: paletteOffset, paletteIndex: Int(linkedIndex))
        }
        
        // Palette data is at ldata offset + palDataOffset
        let ldataOffset = readUInt32(data, at: 52)
        let actualOffset = Int(ldataOffset) + Int(palDataOffset)
        
        guard actualOffset + (colorCount * 4) <= data.count else { return nil }
        
        // Read RGBA palette (4 bytes per color)
        var palette = [UInt8](repeating: 0, count: 256 * 4)
        for i in 0..<min(colorCount, 256) {
            palette[i * 4] = data[actualOffset + i * 4]     // R
            palette[i * 4 + 1] = data[actualOffset + i * 4 + 1] // G
            palette[i * 4 + 2] = data[actualOffset + i * 4 + 2] // B
            palette[i * 4 + 3] = data[actualOffset + i * 4 + 3] // A
        }
        
        return palette
    }
    
    // MARK: - SFF v2 Decoders
    
    private static func decodeSFFv2Sprite(_ data: Data, width: Int, height: Int, format: UInt8, colorDepth: UInt8, palette: [UInt8]?) -> NSImage? {
        // Format 11, 12 = true color PNG with embedded palette
        if format == 11 || format == 12 {
            guard data.count > 4 else { return nil }
            let pngData = data.dropFirst(4)
            if let image = NSImage(data: Data(pngData)) {
                return image
            }
            return nil
        }
        
        // Format 10 = 8-bit indexed PNG with external palette from SFF
        if format == 10 {
            guard data.count > 4, let pal = palette else { return nil }
            let pngData = Data(data.dropFirst(4))
            
            // Decode PNG to get pixel indices
            guard let cgImageSource = CGImageSourceCreateWithData(pngData as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil),
                  let dataProvider = cgImage.dataProvider,
                  let pixelData = dataProvider.data else {
                return nil
            }
            
            let indices = CFDataGetBytePtr(pixelData)!
            let indexCount = CFDataGetLength(pixelData)
            let w = cgImage.width
            let h = cgImage.height
            
            // Apply SFF's palette to pixel indices
            var rgbaPixels = [UInt8](repeating: 255, count: w * h * 4)
            for i in 0..<min(indexCount, w * h) {
                let colorIndex = Int(indices[i])
                rgbaPixels[i * 4] = pal[colorIndex * 4]       // R
                rgbaPixels[i * 4 + 1] = pal[colorIndex * 4 + 1] // G
                rgbaPixels[i * 4 + 2] = pal[colorIndex * 4 + 2] // B
                let alpha = colorIndex == 0 ? UInt8(0) : pal[colorIndex * 4 + 3]
                rgbaPixels[i * 4 + 3] = alpha
            }
            
            return createImageFromRGBA(&rgbaPixels, width: w, height: h)
        }
        
        var pixels: [UInt8]
        
        switch format {
        case 0: // Raw
            if colorDepth == 8 {
                pixels = decodeRaw8(data, width: width, height: height)
            } else {
                pixels = decodeRaw32(data, width: width, height: height)
            }
        case 2: // RLE8
            pixels = decodeRLE8(data, width: width, height: height)
        case 3: // RLE5 (not commonly used for portraits)
            return nil
        case 4: // LZ5
            pixels = decodeLZ5(data, width: width, height: height)
        default:
            return nil
        }
        
        guard pixels.count == width * height else { return nil }
        
        // Convert to RGBA
        var rgbaPixels = [UInt8](repeating: 255, count: width * height * 4)
        
        if colorDepth == 8, let pal = palette {
            for i in 0..<(width * height) {
                let colorIndex = Int(pixels[i])
                rgbaPixels[i * 4] = pal[colorIndex * 4]
                rgbaPixels[i * 4 + 1] = pal[colorIndex * 4 + 1]
                rgbaPixels[i * 4 + 2] = pal[colorIndex * 4 + 2]
                rgbaPixels[i * 4 + 3] = colorIndex == 0 ? 0 : 255
            }
        } else if colorDepth == 32 {
            rgbaPixels = pixels
        }
        
        return createImageFromRGBA(&rgbaPixels, width: width, height: height)
    }
    
    private static func decodeRaw8(_ data: Data, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let copyCount = min(data.count, pixels.count)
        for i in 0..<copyCount {
            pixels[i] = data[data.startIndex + i]
        }
        return pixels
    }
    
    private static func decodeRaw32(_ data: Data, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let copyCount = min(data.count, pixels.count)
        for i in 0..<copyCount {
            pixels[i] = data[data.startIndex + i]
        }
        return pixels
    }
    
    private static func decodeRLE8(_ data: Data, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        var srcIdx = 0
        var dstIdx = 0
        
        while srcIdx < data.count && dstIdx < pixels.count {
            let ctrl = data[data.startIndex + srcIdx]
            srcIdx += 1
            
            if (ctrl & 0xC0) == 0x40 {
                // RLE run of color
                let runLen = Int(ctrl & 0x3F)
                guard srcIdx < data.count else { break }
                let color = data[data.startIndex + srcIdx]
                srcIdx += 1
                
                for _ in 0..<runLen {
                    if dstIdx < pixels.count {
                        pixels[dstIdx] = color
                        dstIdx += 1
                    }
                }
            } else if (ctrl & 0xC0) == 0x00 {
                // Raw run
                let runLen = Int(ctrl & 0x3F)
                for _ in 0..<runLen {
                    guard srcIdx < data.count, dstIdx < pixels.count else { break }
                    pixels[dstIdx] = data[data.startIndex + srcIdx]
                    srcIdx += 1
                    dstIdx += 1
                }
            } else {
                // Single pixel or transparent run
                if dstIdx < pixels.count {
                    pixels[dstIdx] = ctrl
                    dstIdx += 1
                }
            }
        }
        
        return pixels
    }
    
    private static func decodeLZ5(_ data: Data, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        var srcIdx = 4 // Skip 4-byte decompressed size header
        var dstIdx = 0
        
        while srcIdx < data.count && dstIdx < pixels.count {
            guard srcIdx < data.count else { break }
            let ctrl = data[data.startIndex + srcIdx]
            srcIdx += 1
            
            for bit in 0..<8 {
                guard srcIdx < data.count, dstIdx < pixels.count else { break }
                
                if (ctrl & (1 << bit)) != 0 {
                    // Copy from output buffer
                    guard srcIdx + 1 < data.count else { break }
                    let b1 = Int(data[data.startIndex + srcIdx])
                    let b2 = Int(data[data.startIndex + srcIdx + 1])
                    srcIdx += 2
                    
                    let length = (b1 & 0x3F) + 1
                    let offset = ((b1 & 0xC0) << 2) | b2
                    
                    let copyFrom = dstIdx - offset - 1
                    for j in 0..<length {
                        if dstIdx < pixels.count && copyFrom + j >= 0 && copyFrom + j < pixels.count {
                            pixels[dstIdx] = pixels[copyFrom + j]
                            dstIdx += 1
                        }
                    }
                } else {
                    // Literal byte
                    pixels[dstIdx] = data[data.startIndex + srcIdx]
                    srcIdx += 1
                    dstIdx += 1
                }
            }
        }
        
        return pixels
    }
    
    // MARK: - PCX Decoder
    
    private static func extractPCXPalette(from pcxData: Data) -> Data? {
        guard pcxData.count > 769 else { return nil }
        let paletteStart = pcxData.count - 769
        let paletteMarker = pcxData[pcxData.startIndex + paletteStart]
        if paletteMarker == 12 {
            return pcxData[(pcxData.startIndex + paletteStart + 1)...]
        }
        return nil
    }
    
    private static func decodePCX(_ data: Data, sharedPalette: Data?) -> NSImage? {
        guard data.count > 128 else { return nil }
        
        // PCX header
        let manufacturer = data[0]
        guard manufacturer == 10 else { return nil } // PCX magic number
        
        let encoding = data[2]
        let bitsPerPixel = data[3]
        
        let xmin = UInt16(data[4]) | (UInt16(data[5]) << 8)
        let ymin = UInt16(data[6]) | (UInt16(data[7]) << 8)
        let xmax = UInt16(data[8]) | (UInt16(data[9]) << 8)
        let ymax = UInt16(data[10]) | (UInt16(data[11]) << 8)
        
        let width = Int(xmax - xmin + 1)
        let height = Int(ymax - ymin + 1)
        
        guard width > 0, width < 2000, height > 0, height < 2000 else { return nil }
        guard bitsPerPixel == 8 else { return nil } // Only support 8-bit indexed
        
        let bytesPerLine = Int(UInt16(data[66]) | (UInt16(data[67]) << 8))
        
        // Extract palette (last 768 bytes of file, after marker byte 12)
        var palette = [UInt8](repeating: 0, count: 768)
        if data.count > 769 {
            let paletteStart = data.count - 769
            if data[paletteStart] == 12 { // Palette marker
                for i in 0..<768 {
                    palette[i] = data[paletteStart + 1 + i]
                }
            }
        } else if let sharedPal = sharedPalette, sharedPal.count >= 768 {
            for i in 0..<768 {
                palette[i] = sharedPal[sharedPal.startIndex + i]
            }
        }
        
        // Decode RLE image data
        var pixels = [UInt8](repeating: 0, count: width * height)
        var srcIndex = 128 // Skip header
        var dstIndex = 0
        var y = 0
        
        while y < height && srcIndex < data.count - 769 {
            var x = 0
            while x < bytesPerLine && srcIndex < data.count - 769 {
                let byte = data[srcIndex]
                srcIndex += 1
                
                if encoding == 1 && (byte & 0xC0) == 0xC0 {
                    // RLE run
                    let count = Int(byte & 0x3F)
                    let value = srcIndex < data.count ? data[srcIndex] : 0
                    srcIndex += 1
                    
                    for _ in 0..<count {
                        if x < width && dstIndex < pixels.count {
                            pixels[dstIndex] = value
                            dstIndex += 1
                        }
                        x += 1
                    }
                } else {
                    // Single pixel
                    if x < width && dstIndex < pixels.count {
                        pixels[dstIndex] = byte
                        dstIndex += 1
                    }
                    x += 1
                }
            }
            y += 1
        }
        
        // Convert indexed pixels to RGBA
        var rgbaPixels = [UInt8](repeating: 255, count: width * height * 4)
        for i in 0..<(width * height) {
            let colorIndex = Int(pixels[i])
            let r = palette[colorIndex * 3]
            let g = palette[colorIndex * 3 + 1]
            let b = palette[colorIndex * 3 + 2]
            
            rgbaPixels[i * 4] = r
            rgbaPixels[i * 4 + 1] = g
            rgbaPixels[i * 4 + 2] = b
            rgbaPixels[i * 4 + 3] = colorIndex == 0 ? 0 : 255
        }
        
        return createImageFromRGBA(&rgbaPixels, width: width, height: height)
    }
    
    // MARK: - Image Creation Helper
    
    private static func createImageFromRGBA(_ rgbaPixels: inout [UInt8], width: Int, height: Int) -> NSImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &rgbaPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        guard let cgImage = context.makeImage() else { return nil }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}

// MARK: - Legacy Alias

/// Alias for backwards compatibility with existing code
public typealias SFFPortraitExtractor = SFFParser
