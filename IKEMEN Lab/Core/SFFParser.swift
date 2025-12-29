import Foundation
import AppKit

// MARK: - SFF Errors

/// Errors that can occur during SFF parsing
public enum SFFError: LocalizedError {
    case fileNotFound(URL)
    case fileTooSmall
    case invalidSignature
    case unsupportedVersion(Int)
    case spriteNotFound(group: Int, image: Int)
    case corruptedData(String)
    case decodingFailed(String)
    case invalidDimensions(width: Int, height: Int)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "SFF file not found: \(url.lastPathComponent)"
        case .fileTooSmall:
            return "SFF file is too small to be valid"
        case .invalidSignature:
            return "Invalid SFF signature - not a valid SFF file"
        case .unsupportedVersion(let version):
            return "Unsupported SFF version: \(version)"
        case .spriteNotFound(let group, let image):
            return "Sprite not found: group \(group), image \(image)"
        case .corruptedData(let detail):
            return "Corrupted SFF data: \(detail)"
        case .decodingFailed(let detail):
            return "Failed to decode sprite: \(detail)"
        case .invalidDimensions(let width, let height):
            return "Invalid sprite dimensions: \(width)x\(height)"
        }
    }
}

// MARK: - SFF Version Protocol

/// Protocol for version-specific SFF parsing implementations
public protocol SFFVersionParser {
    /// The SFF version this parser handles
    static var version: Int { get }
    
    /// Extract a portrait sprite (group 9000) from SFF data
    static func extractPortrait(from data: Data) -> Result<NSImage, SFFError>
    
    /// Extract a stage preview sprite from SFF data
    static func extractStagePreview(from data: Data) -> Result<NSImage, SFFError>
}

// MARK: - SFF Parser (Main Entry Point)

/// Extracts portrait and preview images from SFF sprite files
/// Supports both SFF v1 (PCX-based) and SFF v2 (PNG/RLE/LZ5-based) formats
public final class SFFParser {
    
    // MARK: - Public API (Result-based)
    
    /// Extract portrait sprite (group 9000) from SFF file
    /// - Parameter sffURL: URL to the SFF file
    /// - Returns: Result containing the extracted portrait image or an error
    public static func extractPortraitResult(from sffURL: URL) -> Result<NSImage, SFFError> {
        guard let data = try? Data(contentsOf: sffURL) else {
            return .failure(.fileNotFound(sffURL))
        }
        return extractPortraitResult(from: data)
    }
    
    /// Extract portrait sprite (group 9000) from SFF data
    /// - Parameter data: Raw SFF file data
    /// - Returns: Result containing the extracted portrait image or an error
    public static func extractPortraitResult(from data: Data) -> Result<NSImage, SFFError> {
        guard data.count > 32 else {
            return .failure(.fileTooSmall)
        }
        
        let signature = String(data: data[0..<12], encoding: .ascii) ?? ""
        guard signature.hasPrefix("ElecbyteSpr") else {
            return .failure(.invalidSignature)
        }
        
        let verHi = data[15]
        
        if verHi >= 2 {
            return SFFv2Parser.extractPortrait(from: data)
        } else {
            return SFFv1Parser.extractPortrait(from: data)
        }
    }
    
    /// Extract stage preview from SFF file
    /// - Parameter sffURL: URL to the SFF file
    /// - Returns: Result containing the extracted preview image or an error
    public static func extractStagePreviewResult(from sffURL: URL) -> Result<NSImage, SFFError> {
        guard let data = try? Data(contentsOf: sffURL) else {
            return .failure(.fileNotFound(sffURL))
        }
        return extractStagePreviewResult(from: data)
    }
    
    /// Extract stage preview from SFF data
    /// - Parameter data: Raw SFF file data
    /// - Returns: Result containing the extracted preview image or an error
    public static func extractStagePreviewResult(from data: Data) -> Result<NSImage, SFFError> {
        guard data.count > 32 else {
            return .failure(.fileTooSmall)
        }
        
        let signature = String(data: data[0..<12], encoding: .ascii) ?? ""
        guard signature.hasPrefix("ElecbyteSpr") else {
            return .failure(.invalidSignature)
        }
        
        let verHi = data[15]
        
        if verHi >= 2 {
            return SFFv2Parser.extractStagePreview(from: data)
        } else {
            return SFFv1Parser.extractStagePreview(from: data)
        }
    }
    
    // MARK: - Legacy API (Optional returns for backwards compatibility)
    
    /// Extract portrait sprite (group 9000) from SFF file
    /// - Parameter sffURL: URL to the SFF file
    /// - Returns: The extracted portrait image, or nil if not found
    public static func extractPortrait(from sffURL: URL) -> NSImage? {
        switch extractPortraitResult(from: sffURL) {
        case .success(let image): return image
        case .failure: return nil
        }
    }
    
    /// Extract portrait sprite (group 9000) from SFF data
    /// - Parameter data: Raw SFF file data
    /// - Returns: The extracted portrait image, or nil if not found
    public static func extractPortrait(from data: Data) -> NSImage? {
        switch extractPortraitResult(from: data) {
        case .success(let image): return image
        case .failure: return nil
        }
    }
    
    /// Extract stage preview (group 9000 or group 0) from SFF file
    /// - Parameter sffURL: URL to the SFF file
    /// - Returns: The extracted preview image, or nil if not found
    public static func extractStagePreview(from sffURL: URL) -> NSImage? {
        switch extractStagePreviewResult(from: sffURL) {
        case .success(let image): return image
        case .failure: return nil
        }
    }
    
    /// Extract stage preview (group 9000 or group 0) from SFF data
    /// - Parameter data: Raw SFF file data
    /// - Returns: The extracted preview image, or nil if not found
    public static func extractStagePreview(from data: Data) -> NSImage? {
        switch extractStagePreviewResult(from: data) {
        case .success(let image): return image
        case .failure: return nil
        }
    }
}

// MARK: - Shared Utilities

/// Shared utilities for SFF parsing
internal enum SFFUtils {
    
    static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        guard offset + 1 < data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    
    static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }
    
    static func createImageFromRGBA(_ rgbaPixels: inout [UInt8], width: Int, height: Int) -> NSImage? {
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

// MARK: - SFF v1 Parser

/// Parser for SFF version 1 files (PCX-based sprites)
public struct SFFv1Parser: SFFVersionParser {
    
    public static var version: Int { 1 }
    
    public static func extractPortrait(from data: Data) -> Result<NSImage, SFFError> {
        guard data.count > 32 else {
            return .failure(.fileTooSmall)
        }
        
        let numImages = SFFUtils.readUInt32(data, at: 20)
        let firstSubfileOffset = SFFUtils.readUInt32(data, at: 24)
        
        guard numImages > 0, firstSubfileOffset < data.count else {
            return .failure(.corruptedData("Invalid sprite count or offset"))
        }
        
        var offset = Int(firstSubfileOffset)
        var paletteData: Data?
        
        for i in 0..<min(Int(numImages), 2000) {
            guard offset + 32 <= data.count else { break }
            
            let nextOffset = SFFUtils.readUInt32(data, at: offset)
            let subfileLength = SFFUtils.readUInt32(data, at: offset + 4)
            let groupNum = SFFUtils.readUInt16(data, at: offset + 12)
            let imageNum = SFFUtils.readUInt16(data, at: offset + 14)
            let linkedIndex = SFFUtils.readUInt16(data, at: offset + 16)
            let samePalette = data[offset + 18]
            
            // Store palette from first sprite
            if i == 0 && subfileLength > 0 {
                let pcxStart = offset + 32
                let pcxEnd = min(pcxStart + Int(subfileLength), data.count)
                if pcxEnd > pcxStart {
                    paletteData = extractPCXPalette(from: data[pcxStart..<pcxEnd])
                }
            }
            
            // Portrait is group 9000, image 0
            if groupNum == 9000 && imageNum == 0 {
                if linkedIndex != 0 && linkedIndex < numImages {
                    // Linked sprite - skip
                } else if subfileLength > 0 {
                    let pcxStart = offset + 32
                    let pcxEnd = min(pcxStart + Int(subfileLength), data.count)
                    if pcxEnd > pcxStart {
                        let pcxData = data[pcxStart..<pcxEnd]
                        if let image = decodePCX(Data(pcxData), sharedPalette: samePalette != 0 ? paletteData : nil) {
                            return .success(image)
                        }
                    }
                }
            }
            
            if nextOffset == 0 || nextOffset <= offset { break }
            offset = Int(nextOffset)
        }
        
        return .failure(.spriteNotFound(group: 9000, image: 0))
    }
    
    public static func extractStagePreview(from data: Data) -> Result<NSImage, SFFError> {
        let spriteCount = SFFUtils.readUInt32(data, at: 20)
        let firstSpriteOffset = SFFUtils.readUInt32(data, at: 24)
        
        guard spriteCount > 0, firstSpriteOffset < data.count else {
            return .failure(.corruptedData("Invalid sprite count or offset"))
        }
        
        // First pass: look for group 9000 (stage preview thumbnail)
        var offset = Int(firstSpriteOffset)
        
        for _ in 0..<min(Int(spriteCount), 100) {
            guard offset + 32 <= data.count else { break }
            
            let nextOffset = SFFUtils.readUInt32(data, at: offset)
            let dataLength = SFFUtils.readUInt32(data, at: offset + 4)
            let groupNum = SFFUtils.readUInt16(data, at: offset + 12)
            
            if groupNum == 9000 && dataLength > 0 {
                let pcxStart = offset + 32
                let pcxEnd = pcxStart + Int(dataLength)
                guard pcxEnd <= data.count else { continue }
                
                let pcxData = data[pcxStart..<pcxEnd]
                if let image = decodePCX(Data(pcxData), sharedPalette: nil) {
                    return .success(image)
                }
            }
            
            if nextOffset == 0 || nextOffset <= offset { break }
            offset = Int(nextOffset)
        }
        
        // Second pass: fall back to group 0 (background sprite)
        offset = Int(firstSpriteOffset)
        
        for _ in 0..<min(Int(spriteCount), 100) {
            guard offset + 32 <= data.count else { break }
            
            let nextOffset = SFFUtils.readUInt32(data, at: offset)
            let dataLength = SFFUtils.readUInt32(data, at: offset + 4)
            let groupNum = SFFUtils.readUInt16(data, at: offset + 12)
            let imageNum = SFFUtils.readUInt16(data, at: offset + 14)
            
            if groupNum == 0 && imageNum == 0 && dataLength > 0 {
                let pcxStart = offset + 32
                let pcxEnd = pcxStart + Int(dataLength)
                guard pcxEnd <= data.count else { continue }
                
                let pcxData = data[pcxStart..<pcxEnd]
                if let image = decodePCX(Data(pcxData), sharedPalette: nil) {
                    return .success(image)
                }
            }
            
            if nextOffset == 0 || nextOffset <= offset { break }
            offset = Int(nextOffset)
        }
        
        return .failure(.spriteNotFound(group: 9000, image: 0))
    }
    
    // MARK: - PCX Helpers
    
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
        
        let manufacturer = data[0]
        guard manufacturer == 10 else { return nil }
        
        let encoding = data[2]
        let bitsPerPixel = data[3]
        
        let xmin = UInt16(data[4]) | (UInt16(data[5]) << 8)
        let ymin = UInt16(data[6]) | (UInt16(data[7]) << 8)
        let xmax = UInt16(data[8]) | (UInt16(data[9]) << 8)
        let ymax = UInt16(data[10]) | (UInt16(data[11]) << 8)
        
        let width = Int(xmax - xmin + 1)
        let height = Int(ymax - ymin + 1)
        
        guard width > 0, width < 2000, height > 0, height < 2000 else { return nil }
        guard bitsPerPixel == 8 else { return nil }
        
        let bytesPerLine = Int(UInt16(data[66]) | (UInt16(data[67]) << 8))
        
        // Extract palette
        var palette = [UInt8](repeating: 0, count: 768)
        if data.count > 769 {
            let paletteStart = data.count - 769
            if data[paletteStart] == 12 {
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
        var srcIndex = 128
        var dstIndex = 0
        var y = 0
        
        while y < height && srcIndex < data.count - 769 {
            var x = 0
            while x < bytesPerLine && srcIndex < data.count - 769 {
                let byte = data[srcIndex]
                srcIndex += 1
                
                if encoding == 1 && (byte & 0xC0) == 0xC0 {
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
            rgbaPixels[i * 4] = palette[colorIndex * 3]
            rgbaPixels[i * 4 + 1] = palette[colorIndex * 3 + 1]
            rgbaPixels[i * 4 + 2] = palette[colorIndex * 3 + 2]
            rgbaPixels[i * 4 + 3] = colorIndex == 0 ? 0 : 255
        }
        
        return SFFUtils.createImageFromRGBA(&rgbaPixels, width: width, height: height)
    }
}

// MARK: - SFF v2 Parser

/// Parser for SFF version 2 files (PNG/RLE/LZ5-based sprites)
public struct SFFv2Parser: SFFVersionParser {
    
    public static var version: Int { 2 }
    
    public static func extractPortrait(from data: Data) -> Result<NSImage, SFFError> {
        guard data.count > 36 else {
            return .failure(.fileTooSmall)
        }
        
        let spriteOffset = SFFUtils.readUInt32(data, at: 36)
        let spriteCount = SFFUtils.readUInt32(data, at: 40)
        let paletteOffset = SFFUtils.readUInt32(data, at: 44)
        let ldataOffset = SFFUtils.readUInt32(data, at: 52)
        let tdataOffset = SFFUtils.readUInt32(data, at: 60)
        
        guard spriteCount > 0, spriteOffset < data.count else {
            return .failure(.corruptedData("Invalid sprite count or offset"))
        }
        
        var offset = Int(spriteOffset)
        var portraitSprite: (offset: Int, width: Int, height: Int)?
        var standingSprite: (offset: Int, width: Int, height: Int)?
        
        for _ in 0..<min(Int(spriteCount), 5000) {
            guard offset + 28 <= data.count else { break }
            
            let groupNum = SFFUtils.readUInt16(data, at: offset)
            let imageNum = SFFUtils.readUInt16(data, at: offset + 2)
            let width = Int(SFFUtils.readUInt16(data, at: offset + 4))
            let height = Int(SFFUtils.readUInt16(data, at: offset + 6))
            
            if groupNum == 9000 {
                if width > 50 && height > 50 {
                    if portraitSprite == nil {
                        portraitSprite = (offset, width, height)
                    }
                } else if portraitSprite == nil {
                    portraitSprite = (offset, width, height)
                }
            }
            
            if groupNum == 0 && imageNum == 0 && width > 30 && height > 30 {
                standingSprite = (offset, width, height)
            }
            
            offset += 28
        }
        
        let candidateSprites = [portraitSprite, standingSprite].compactMap { $0 }
        
        for sprite in candidateSprites {
            if let image = extractSpriteAtOffset(data, offset: sprite.offset,
                                                  paletteOffset: Int(paletteOffset),
                                                  ldataOffset: Int(ldataOffset),
                                                  tdataOffset: Int(tdataOffset)) {
                return .success(image)
            }
        }
        
        return .failure(.spriteNotFound(group: 9000, image: 0))
    }
    
    public static func extractStagePreview(from data: Data) -> Result<NSImage, SFFError> {
        guard data.count > 36 else {
            return .failure(.fileTooSmall)
        }
        
        let spriteOffset = SFFUtils.readUInt32(data, at: 36)
        let spriteCount = SFFUtils.readUInt32(data, at: 40)
        let paletteOffset = SFFUtils.readUInt32(data, at: 44)
        let ldataOffset = SFFUtils.readUInt32(data, at: 52)
        let tdataOffset = SFFUtils.readUInt32(data, at: 60)
        
        guard spriteCount > 0, spriteOffset < data.count else {
            return .failure(.corruptedData("Invalid sprite count or offset"))
        }
        
        // First pass: look for group 9000
        var offset = Int(spriteOffset)
        
        for _ in 0..<min(Int(spriteCount), 100) {
            guard offset + 28 <= data.count else { break }
            
            let groupNum = SFFUtils.readUInt16(data, at: offset)
            let width = Int(SFFUtils.readUInt16(data, at: offset + 4))
            let height = Int(SFFUtils.readUInt16(data, at: offset + 6))
            
            if groupNum == 9000 && width > 0 && height > 0 {
                if let image = extractSpriteAtOffset(data, offset: offset,
                                                      paletteOffset: Int(paletteOffset),
                                                      ldataOffset: Int(ldataOffset),
                                                      tdataOffset: Int(tdataOffset)) {
                    return .success(image)
                }
            }
            
            offset += 28
        }
        
        // Second pass: fall back to group 0 image 0
        offset = Int(spriteOffset)
        
        for _ in 0..<min(Int(spriteCount), 100) {
            guard offset + 28 <= data.count else { break }
            
            let groupNum = SFFUtils.readUInt16(data, at: offset)
            let imageNum = SFFUtils.readUInt16(data, at: offset + 2)
            let width = Int(SFFUtils.readUInt16(data, at: offset + 4))
            let height = Int(SFFUtils.readUInt16(data, at: offset + 6))
            
            if groupNum == 0 && imageNum == 0 && width > 0 && height > 0 {
                if let image = extractSpriteAtOffset(data, offset: offset,
                                                      paletteOffset: Int(paletteOffset),
                                                      ldataOffset: Int(ldataOffset),
                                                      tdataOffset: Int(tdataOffset)) {
                    return .success(image)
                }
            }
            
            offset += 28
        }
        
        return .failure(.spriteNotFound(group: 9000, image: 0))
    }
    
    // MARK: - Sprite Extraction
    
    private static func extractSpriteAtOffset(_ data: Data, offset: Int, paletteOffset: Int, ldataOffset: Int, tdataOffset: Int) -> NSImage? {
        let width = Int(SFFUtils.readUInt16(data, at: offset + 4))
        let height = Int(SFFUtils.readUInt16(data, at: offset + 6))
        let linkedIndex = SFFUtils.readUInt16(data, at: offset + 12)
        let format = data[offset + 14]
        let colorDepth = data[offset + 15]
        let dataOffset = SFFUtils.readUInt32(data, at: offset + 16)
        let dataLength = SFFUtils.readUInt32(data, at: offset + 20)
        let paletteIndex = SFFUtils.readUInt16(data, at: offset + 24)
        let flags = SFFUtils.readUInt16(data, at: offset + 26)
        
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
        
        var palette: [UInt8]?
        if colorDepth == 8 && format != 11 && format != 12 {
            palette = extractPalette(data, paletteOffset: paletteOffset, paletteIndex: Int(paletteIndex))
        }
        
        let spriteData = data[actualOffset..<(actualOffset + Int(dataLength))]
        
        return decodeSprite(Data(spriteData), width: width, height: height, format: format, colorDepth: colorDepth, palette: palette)
    }
    
    private static func extractPalette(_ data: Data, paletteOffset: Int, paletteIndex: Int) -> [UInt8]? {
        let nodeOffset = paletteOffset + (paletteIndex * 16)
        guard nodeOffset + 16 <= data.count else { return nil }
        
        let colorCount = Int(SFFUtils.readUInt16(data, at: nodeOffset + 4))
        let linkedIndex = SFFUtils.readUInt16(data, at: nodeOffset + 6)
        let palDataOffset = SFFUtils.readUInt32(data, at: nodeOffset + 8)
        let palDataLength = SFFUtils.readUInt32(data, at: nodeOffset + 12)
        
        if linkedIndex != 0 && palDataLength == 0 {
            return extractPalette(data, paletteOffset: paletteOffset, paletteIndex: Int(linkedIndex))
        }
        
        let ldataOffset = SFFUtils.readUInt32(data, at: 52)
        let actualOffset = Int(ldataOffset) + Int(palDataOffset)
        
        guard actualOffset + (colorCount * 4) <= data.count else { return nil }
        
        var palette = [UInt8](repeating: 0, count: 256 * 4)
        for i in 0..<min(colorCount, 256) {
            palette[i * 4] = data[actualOffset + i * 4]
            palette[i * 4 + 1] = data[actualOffset + i * 4 + 1]
            palette[i * 4 + 2] = data[actualOffset + i * 4 + 2]
            palette[i * 4 + 3] = data[actualOffset + i * 4 + 3]
        }
        
        return palette
    }
    
    // MARK: - Sprite Decoders
    
    private static func decodeSprite(_ data: Data, width: Int, height: Int, format: UInt8, colorDepth: UInt8, palette: [UInt8]?) -> NSImage? {
        // PNG formats
        if format == 11 || format == 12 {
            guard data.count > 4 else { return nil }
            let pngData = data.dropFirst(4)
            return NSImage(data: Data(pngData))
        }
        
        // 8-bit indexed PNG with external palette
        if format == 10 {
            guard data.count > 4, let pal = palette else { return nil }
            let pngData = Data(data.dropFirst(4))
            
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
            
            var rgbaPixels = [UInt8](repeating: 255, count: w * h * 4)
            for i in 0..<min(indexCount, w * h) {
                let colorIndex = Int(indices[i])
                rgbaPixels[i * 4] = pal[colorIndex * 4]
                rgbaPixels[i * 4 + 1] = pal[colorIndex * 4 + 1]
                rgbaPixels[i * 4 + 2] = pal[colorIndex * 4 + 2]
                let alpha = colorIndex == 0 ? UInt8(0) : pal[colorIndex * 4 + 3]
                rgbaPixels[i * 4 + 3] = alpha
            }
            
            return SFFUtils.createImageFromRGBA(&rgbaPixels, width: w, height: h)
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
        case 3: // RLE5
            return nil
        case 4: // LZ5
            pixels = decodeLZ5(data, width: width, height: height)
        default:
            return nil
        }
        
        guard pixels.count == width * height else { return nil }
        
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
        
        return SFFUtils.createImageFromRGBA(&rgbaPixels, width: width, height: height)
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
                let runLen = Int(ctrl & 0x3F)
                for _ in 0..<runLen {
                    guard srcIdx < data.count, dstIdx < pixels.count else { break }
                    pixels[dstIdx] = data[data.startIndex + srcIdx]
                    srcIdx += 1
                    dstIdx += 1
                }
            } else {
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
        var srcIdx = 4
        var dstIdx = 0
        
        while srcIdx < data.count && dstIdx < pixels.count {
            guard srcIdx < data.count else { break }
            let ctrl = data[data.startIndex + srcIdx]
            srcIdx += 1
            
            for bit in 0..<8 {
                guard srcIdx < data.count, dstIdx < pixels.count else { break }
                
                if (ctrl & (1 << bit)) != 0 {
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
                    pixels[dstIdx] = data[data.startIndex + srcIdx]
                    srcIdx += 1
                    dstIdx += 1
                }
            }
        }
        
        return pixels
    }
}

// MARK: - Legacy Alias

/// Alias for backwards compatibility with existing code
public typealias SFFPortraitExtractor = SFFParser
