import Foundation
import Combine
import AppKit

// MARK: - Errors

/// Error types for Ikemen GO operations
enum IkemenError: LocalizedError {
    case engineNotFound
    case engineLaunchFailed(String)
    case contentNotFound(String)
    case installFailed(String)
    case invalidContent(String)
    
    var errorDescription: String? {
        switch self {
        case .engineNotFound:
            return "Ikemen GO engine not found"
        case .engineLaunchFailed(let reason):
            return "Failed to launch Ikemen GO: \(reason)"
        case .contentNotFound(let name):
            return "Content not found: \(name)"
        case .installFailed(let reason):
            return "Failed to install content: \(reason)"
        case .invalidContent(let reason):
            return "Invalid content: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .engineNotFound:
            return "Make sure Ikemen GO is bundled with the application."
        case .engineLaunchFailed:
            return "Try restarting the application."
        case .contentNotFound:
            return "Check that the content files exist in the content directory."
        case .installFailed:
            return "Make sure you have write permissions and enough disk space."
        case .invalidContent:
            return "The content file may be corrupted or in an unsupported format."
        }
    }
}

// MARK: - Content Types

/// Types of MUGEN/Ikemen GO content
enum ContentType: String, CaseIterable {
    case character = "chars"
    case stage = "stages"
    case screenpack = "data"
    case font = "font"
    case sound = "sound"
    
    var displayName: String {
        switch self {
        case .character: return "Characters"
        case .stage: return "Stages"
        case .screenpack: return "Screenpacks"
        case .font: return "Fonts"
        case .sound: return "Sounds"
        }
    }
    
    var directoryName: String {
        return rawValue
    }
}

// MARK: - Character Info

/// Character metadata parsed from .def files
struct CharacterInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let author: String
    let versionDate: String
    let spriteFile: String?
    let directory: URL
    let defFile: URL
    private var _cachedPortrait: NSImage?
    
    init(directory: URL, defFile: URL) {
        self.directory = directory
        self.defFile = defFile
        self.id = directory.lastPathComponent
        
        // Parse .def file for metadata
        var parsedName = directory.lastPathComponent
        var parsedDisplayName = directory.lastPathComponent
        var parsedAuthor = "Unknown"
        var parsedVersionDate = ""
        var parsedSpriteFile: String? = nil
        
        if let content = try? String(contentsOf: defFile, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("name") && !trimmed.lowercased().hasPrefix("displayname") {
                    if let value = trimmed.split(separator: "=").last {
                        parsedName = String(value).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                    }
                } else if trimmed.lowercased().hasPrefix("displayname") {
                    if let value = trimmed.split(separator: "=").last {
                        parsedDisplayName = String(value).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                    }
                } else if trimmed.lowercased().hasPrefix("author") {
                    if let value = trimmed.split(separator: "=").last {
                        parsedAuthor = String(value).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                    }
                } else if trimmed.lowercased().hasPrefix("versiondate") {
                    if let value = trimmed.split(separator: "=").last {
                        parsedVersionDate = String(value).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                    }
                } else if trimmed.lowercased().hasPrefix("sprite") {
                    if let value = trimmed.split(separator: "=").last {
                        var sprite = String(value).trimmingCharacters(in: .whitespaces)
                        // Remove comments after the filename
                        if let commentIndex = sprite.firstIndex(of: ";") {
                            sprite = String(sprite[..<commentIndex]).trimmingCharacters(in: .whitespaces)
                        }
                        parsedSpriteFile = sprite
                    }
                }
            }
        }
        
        self.name = parsedName
        // Prefer "name" over "displayname" as it's usually more descriptive
        self.displayName = parsedName.isEmpty ? parsedDisplayName : parsedName
        self.author = parsedAuthor
        self.versionDate = parsedVersionDate
        self.spriteFile = parsedSpriteFile
    }
    
    /// Get the portrait image for this character
    /// Looks for portrait.png first, then extracts from SFF file
    func getPortraitImage() -> NSImage? {
        let fileManager = FileManager.default
        
        // First check for portrait.png in character directory
        let portraitPng = directory.appendingPathComponent("portrait.png")
        if fileManager.fileExists(atPath: portraitPng.path),
           let image = NSImage(contentsOf: portraitPng) {
            return image
        }
        
        // Check for any .png file that might be a portrait
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in contents where file.pathExtension.lowercased() == "png" {
                let name = file.deletingPathExtension().lastPathComponent.lowercased()
                if name.contains("portrait") || name.contains("select") {
                    if let image = NSImage(contentsOf: file) {
                        return image
                    }
                }
            }
        }
        
        // Try to extract from SFF file - use the one specified in DEF if available
        if let spriteFileName = spriteFile {
            let sffFile = directory.appendingPathComponent(spriteFileName)
            if fileManager.fileExists(atPath: sffFile.path) {
                return SFFPortraitExtractor.extractPortrait(from: sffFile)
            }
        }
        
        // Fallback: look for any SFF file with same name as DEF or folder
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let sffFiles = contents.filter { $0.pathExtension.lowercased() == "sff" }
            let defName = defFile.deletingPathExtension().lastPathComponent.lowercased()
            let dirName = directory.lastPathComponent.lowercased()
            
            // Prefer SFF with same name as DEF or directory
            let preferredSff = sffFiles.first { sff in
                let sffName = sff.deletingPathExtension().lastPathComponent.lowercased()
                return sffName == defName || sffName == dirName
            }
            
            if let sffFile = preferredSff ?? sffFiles.first {
                return SFFPortraitExtractor.extractPortrait(from: sffFile)
            }
        }
        
        return nil
    }
    
    // Hashable - exclude cached portrait
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CharacterInfo, rhs: CharacterInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - SFF Portrait Extractor

/// Extracts portrait images from SFF sprite files
class SFFPortraitExtractor {
    
    // Safe byte reading helpers (handles unaligned data)
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
    
    /// Extract portrait sprite (group 9000, image 0) from SFF file
    static func extractPortrait(from sffURL: URL) -> NSImage? {
        guard let data = try? Data(contentsOf: sffURL) else { return nil }
        guard data.count > 32 else { return nil }
        
        // Check SFF signature and version
        let signature = String(data: data[0..<12], encoding: .ascii) ?? ""
        
        guard signature.hasPrefix("ElecbyteSpr") else { return nil }
        
        // Check version: bytes 12-15 are version info
        // Version is stored as 4 bytes: verLo3, verLo2, verLo1, verHi
        // v1: 00 01 00 01 (version 1.01)
        // v2: 00 01 00 02 (version 2.01)
        // The high byte at offset 15 indicates major version
        let verHi = data[15]
        
        if verHi >= 2 {
            // SFF v2 format
            return extractSFFv2Portrait(data)
        } else {
            // SFF v1 format
            return extractSFFv1Portrait(data)
        }
    }
    
    /// Extract portrait from SFF v2 file
    private static func extractSFFv2Portrait(_ data: Data) -> NSImage? {
        guard data.count > 36 else { return nil }
        
        // SFF v2 header structure:
        // 0-11: signature "ElecbyteSpr\0"
        // 12-15: version
        // 16-19: reserved
        // 20-23: reserved
        // 24-27: compatver
        // 28-31: reserved
        // 32-35: reserved
        // 36-39: sprite offset
        // 40-43: sprite count
        // 44-47: palette offset
        // 48-51: palette count
        // 52-55: ldata offset
        // 56-59: ldata length
        // 60-63: tdata offset
        // 64-67: tdata length
        
        let spriteOffset = readUInt32(data, at: 36)
        let spriteCount = readUInt32(data, at: 40)
        let paletteOffset = readUInt32(data, at: 44)
        let ldataOffset = readUInt32(data, at: 52)
        let tdataOffset = readUInt32(data, at: 60)
        
        guard spriteCount > 0, spriteOffset < data.count else { return nil }
        
        // Each sprite node is 28 bytes:
        // 0-1: group
        // 2-3: image number
        // 4-5: width
        // 6-7: height
        // 8-9: x axis
        // 10-11: y axis
        // 12-13: linked index
        // 14: format (0=raw, 1=invalid, 2=RLE8, 3=RLE5, 4=LZ5)
        // 15: color depth (8 or 32)
        // 16-19: data offset
        // 20-23: data length
        // 24-25: palette index
        // 26-27: flags
        
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
                // Prefer a reasonably sized portrait (> 50px)
                if width > 50 && height > 50 {
                    // Keep the first large portrait we find, or replace with image 0/1 if current is neither
                    if portraitSprite == nil {
                        portraitSprite = (offset, width, height)
                    }
                } else if portraitSprite == nil {
                    // Only use small portrait if we haven't found anything yet
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
            offset = sprite.offset
            let width = sprite.width
            let height = sprite.height
            let linkedIndex = readUInt16(data, at: offset + 12)
            let format = data[offset + 14]
            let colorDepth = data[offset + 15]
            let dataOffset = readUInt32(data, at: offset + 16)
            let dataLength = readUInt32(data, at: offset + 20)
            let paletteIndex = readUInt16(data, at: offset + 24)
            let flags = readUInt16(data, at: offset + 26)
            
            // Skip linked sprites
            if linkedIndex != 0xFFFF && linkedIndex != 0 {
                continue
            }
            
            guard width > 0, width < 2000, height > 0, height < 2000 else {
                continue
            }
            
            // Determine where the data is stored
            let usesTdata = (flags & 1) != 0
            let actualOffset: Int
            if usesTdata {
                actualOffset = Int(tdataOffset) + Int(dataOffset)
            } else {
                actualOffset = Int(ldataOffset) + Int(dataOffset)
            }
            
            guard actualOffset + Int(dataLength) <= data.count else {
                continue
            }
            
            // Get palette for this sprite
            var palette: [UInt8]?
            if colorDepth == 8 && format != 10 && format != 11 && format != 12 {
                palette = extractSFFv2Palette(data, paletteOffset: Int(paletteOffset), paletteIndex: Int(paletteIndex))
            }
            
            // Decode based on format
            let spriteData = data[actualOffset..<(actualOffset + Int(dataLength))]
            
            if let image = decodeSFFv2Sprite(Data(spriteData), width: width, height: height, format: format, colorDepth: colorDepth, palette: palette) {
                return image
            }
        }
        
        return nil
    }
    
    /// Extract palette from SFF v2
    private static func extractSFFv2Palette(_ data: Data, paletteOffset: Int, paletteIndex: Int) -> [UInt8]? {
        // Each palette node is 16 bytes:
        // 0-1: group
        // 2-3: item number
        // 4-5: color count
        // 6-7: linked index
        // 8-11: data offset
        // 12-15: data length
        
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
    
    /// Decode SFF v2 sprite data
    private static func decodeSFFv2Sprite(_ data: Data, width: Int, height: Int, format: UInt8, colorDepth: UInt8, palette: [UInt8]?) -> NSImage? {
        // Format 10, 11, 12 = embedded PNG data with 4-byte header
        if format == 10 || format == 11 || format == 12 {
            // Skip 4-byte decompressed size header, then it's raw PNG data
            guard data.count > 4 else { return nil }
            let pngData = data.dropFirst(4)
            if let image = NSImage(data: Data(pngData)) {
                return image
            }
            return nil
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
            // Apply palette
            for i in 0..<(width * height) {
                let colorIndex = Int(pixels[i])
                rgbaPixels[i * 4] = pal[colorIndex * 4]       // R
                rgbaPixels[i * 4 + 1] = pal[colorIndex * 4 + 1] // G
                rgbaPixels[i * 4 + 2] = pal[colorIndex * 4 + 2] // B
                rgbaPixels[i * 4 + 3] = colorIndex == 0 ? 0 : 255 // A (index 0 = transparent)
            }
        } else if colorDepth == 32 {
            // Already RGBA (but might need reordering)
            rgbaPixels = pixels
        }
        
        // Create NSImage
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
    
    // MARK: - SFF v2 Decoders
    
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
        // LZ5 is a simple LZ77-style compression
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
    
    /// Extract portrait from SFF v1 file
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
                    // This is a linked sprite - need to find the actual image data
                    // For now, skip linked sprites
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
    
    /// Extract palette from PCX data (last 768 bytes if palette marker present)
    private static func extractPCXPalette(from pcxData: Data) -> Data? {
        guard pcxData.count > 769 else { return nil }
        let paletteStart = pcxData.count - 769
        let paletteMarker = pcxData[pcxData.startIndex + paletteStart]
        if paletteMarker == 12 {
            return pcxData[(pcxData.startIndex + paletteStart + 1)...]
        }
        return nil
    }
    
    /// Decode PCX image data to NSImage
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
            
            // Make color index 0 transparent (common MUGEN convention)
            rgbaPixels[i * 4 + 3] = colorIndex == 0 ? 0 : 255
        }
        
        // Create NSImage from RGBA data
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

// MARK: - Stage Info

/// Stage metadata parsed from .def files
struct StageInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let author: String
    let defFile: URL
    
    init(defFile: URL) {
        self.defFile = defFile
        self.id = defFile.deletingPathExtension().lastPathComponent
        
        var parsedName = defFile.deletingPathExtension().lastPathComponent
        var parsedAuthor = "Unknown"
        
        if let content = try? String(contentsOf: defFile, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("name") && !trimmed.lowercased().contains("localcoord") {
                    if let value = trimmed.split(separator: "=").last {
                        parsedName = String(value).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                    }
                } else if trimmed.lowercased().hasPrefix("author") {
                    if let value = trimmed.split(separator: "=").last {
                        parsedAuthor = String(value).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                    }
                }
            }
        }
        
        self.name = parsedName
        self.author = parsedAuthor
    }
}

// MARK: - Engine State

/// Current state of the Ikemen GO engine
enum EngineState {
    case idle
    case launching
    case running
    case terminated(Int32)  // Exit code
    case error(Error)
}

// MARK: - Ikemen Bridge

/// Bridge between Swift app and Ikemen GO engine
class IkemenBridge: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = IkemenBridge()
    
    // MARK: - Published State
    
    @Published private(set) var engineState: EngineState = .idle
    @Published private(set) var characters: [CharacterInfo] = []
    @Published private(set) var stages: [StageInfo] = []
    
    // MARK: - Process
    
    private var ikemenProcess: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    
    // MARK: - Paths
    
    private let appSupportURL: URL
    private let contentPath: URL
    private let charsPath: URL
    private let stagesPath: URL
    private let dataPath: URL
    private let fontPath: URL
    private let soundPath: URL
    
    // Engine binary path (bundled or development)
    private var enginePath: URL?
    private var engineWorkingDirectory: URL?
    
    // MARK: - Initialization
    
    private init() {
        // Setup application support directories
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportURL = appSupport.appendingPathComponent("MacMugen", isDirectory: true)
        
        // Content directories mirror Ikemen GO structure
        contentPath = appSupportURL.appendingPathComponent("Content", isDirectory: true)
        charsPath = contentPath.appendingPathComponent("chars", isDirectory: true)
        stagesPath = contentPath.appendingPathComponent("stages", isDirectory: true)
        dataPath = contentPath.appendingPathComponent("data", isDirectory: true)
        fontPath = contentPath.appendingPathComponent("font", isDirectory: true)
        soundPath = contentPath.appendingPathComponent("sound", isDirectory: true)
        
        createDirectoriesIfNeeded()
        findEngine()
        loadContent()
        
        print("IkemenBridge initialized")
        print("Content path: \(contentPath.path)")
        if let enginePath = enginePath {
            print("Engine path: \(enginePath.path)")
        }
    }
    
    deinit {
        terminateEngine()
    }
    
    // MARK: - Directory Setup
    
    private func createDirectoriesIfNeeded() {
        let fileManager = FileManager.default
        let directories = [appSupportURL, contentPath, charsPath, stagesPath, dataPath, fontPath, soundPath]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Engine Discovery
    
    private func findEngine() {
        let fileManager = FileManager.default
        
        // Check for bundled engine first
        if let bundledEngine = Bundle.main.url(forResource: "Ikemen_GO_MacOSARM", withExtension: nil, subdirectory: "Ikemen-GO") {
            enginePath = bundledEngine
            engineWorkingDirectory = bundledEngine.deletingLastPathComponent()
            return
        }
        
        // Check for bundled .app
        if let bundledApp = Bundle.main.url(forResource: "I.K.E.M.E.N-Go", withExtension: "app", subdirectory: "Ikemen-GO") {
            let binary = bundledApp.appendingPathComponent("Contents/MacOS/Ikemen_GO_MacOSARM")
            if fileManager.fileExists(atPath: binary.path) {
                enginePath = binary
                // Working directory should be where the content is (parent of .app)
                engineWorkingDirectory = bundledApp.deletingLastPathComponent()
                return
            }
        }
        
        // Development fallback - look in workspace
        let devPaths = [
            URL(fileURLWithPath: "/Users/davidphillips/Sites/macmame/Ikemen-GO/I.K.E.M.E.N-Go.app/Contents/MacOS/Ikemen_GO_MacOSARM"),
        ]
        
        for path in devPaths {
            if fileManager.fileExists(atPath: path.path) {
                enginePath = path
                // For the .app bundle, working directory is where content folders are
                engineWorkingDirectory = URL(fileURLWithPath: "/Users/davidphillips/Sites/macmame/Ikemen-GO")
                print("Found development engine at: \(path.path)")
                return
            }
        }
        
        print("Warning: Ikemen GO engine not found")
    }
    
    // MARK: - Content Management
    
    /// Reload all content from disk
    func loadContent() {
        loadCharacters()
        loadStages()
    }
    
    /// Load all characters from the chars directory
    private func loadCharacters() {
        var foundCharacters: [CharacterInfo] = []
        let fileManager = FileManager.default
        
        // Scan the chars directory in the engine's working directory
        guard let workingDir = engineWorkingDirectory else { return }
        let engineCharsPath = workingDir.appendingPathComponent("chars")
        
        guard let charDirs = try? fileManager.contentsOfDirectory(at: engineCharsPath, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for charDir in charDirs {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: charDir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            
            // Look for .def file with same name as directory
            let defFile = charDir.appendingPathComponent(charDir.lastPathComponent + ".def")
            if fileManager.fileExists(atPath: defFile.path) {
                let charInfo = CharacterInfo(directory: charDir, defFile: defFile)
                foundCharacters.append(charInfo)
            } else {
                // Try to find any .def file in the directory
                if let contents = try? fileManager.contentsOfDirectory(at: charDir, includingPropertiesForKeys: nil) {
                    for file in contents where file.pathExtension.lowercased() == "def" {
                        let charInfo = CharacterInfo(directory: charDir, defFile: file)
                        foundCharacters.append(charInfo)
                        break
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.characters = foundCharacters.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        }
        
        print("Loaded \(foundCharacters.count) characters")
    }
    
    /// Load all stages from the stages directory
    private func loadStages() {
        var foundStages: [StageInfo] = []
        let fileManager = FileManager.default
        
        guard let workingDir = engineWorkingDirectory else { return }
        let engineStagesPath = workingDir.appendingPathComponent("stages")
        
        guard let stageFiles = try? fileManager.contentsOfDirectory(at: engineStagesPath, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in stageFiles where file.pathExtension.lowercased() == "def" {
            let stageInfo = StageInfo(defFile: file)
            foundStages.append(stageInfo)
        }
        
        DispatchQueue.main.async {
            self.stages = foundStages.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        print("Loaded \(foundStages.count) stages")
    }
    
    // MARK: - Engine Control
    
    /// Launch Ikemen GO
    func launchEngine() throws {
        guard let workingDir = engineWorkingDirectory else {
            throw IkemenError.engineNotFound
        }
        
        // Don't launch if already running
        if case .running = engineState {
            print("Engine already running")
            return
        }
        
        DispatchQueue.main.async {
            self.engineState = .launching
        }
        
        // Find the .app bundle in the working directory
        let appBundlePath = workingDir.appendingPathComponent("I.K.E.M.E.N-Go.app")
        
        guard FileManager.default.fileExists(atPath: appBundlePath.path) else {
            throw IkemenError.engineNotFound
        }
        
        // Use NSWorkspace to properly launch the .app bundle
        // This is the correct way to launch macOS apps with proper window server integration
        let workspace = NSWorkspace.shared
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        
        DispatchQueue.main.async {
            self.engineState = .running
        }
        
        workspace.openApplication(at: appBundlePath, configuration: configuration) { [weak self] runningApp, error in
            if let error = error {
                print("Failed to launch Ikemen GO: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.engineState = .error(error)
                }
            } else if let app = runningApp {
                print("Ikemen GO launched successfully: \(app.localizedName ?? "unknown")")
                // We could monitor the app's termination via NSWorkspace notifications if needed
            }
        }
    }
    
    /// Terminate the running engine
    func terminateEngine() {
        // Find running Ikemen GO instances by name since we launched via NSWorkspace
        let runningApps = NSWorkspace.shared.runningApplications
        
        var terminated = false
        for app in runningApps {
            // Check for Ikemen GO by executable name or bundle name
            if let executableURL = app.executableURL,
               executableURL.lastPathComponent.contains("Ikemen") {
                app.terminate()
                terminated = true
                print("Terminating Ikemen GO: \(app.localizedName ?? "unknown")")
            }
        }
        
        // Also try the old process reference if we have one
        if let process = ikemenProcess, process.isRunning {
            process.terminate()
            terminated = true
        }
        
        ikemenProcess = nil
        
        if terminated {
            DispatchQueue.main.async {
                self.engineState = .idle
            }
            print("Ikemen GO terminated")
        } else {
            print("No running Ikemen GO instance found")
            // Still reset state in case we're out of sync
            DispatchQueue.main.async {
                self.engineState = .idle
            }
        }
    }
    
    /// Check if engine is currently running
    var isEngineRunning: Bool {
        if case .running = engineState {
            return true
        }
        return false
    }
    
    // MARK: - Content Installation
    
    /// Install content from an archive file (zip, rar, 7z - auto-detects character or stage)
    func installContent(from archiveURL: URL) throws -> String {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Create temp directory
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let ext = archiveURL.pathExtension.lowercased()
        
        // Extract based on file type
        if ext == "zip" {
            // Extract zip using ditto (macOS native)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", archiveURL.path, tempDir.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw IkemenError.installFailed("Failed to extract zip file")
            }
        } else if ext == "rar" {
            // Use unrar for RAR files (better RAR5 support than 7z)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/unrar")
            process.arguments = ["x", "-y", archiveURL.path, tempDir.path + "/"]
            
            // Suppress output
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw IkemenError.installFailed("Failed to extract RAR file. Make sure unrar is installed (brew install rar)")
            }
        } else if ext == "7z" {
            // Use 7z for 7z files
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/7z")
            process.arguments = ["x", "-o\(tempDir.path)", "-y", archiveURL.path]
            
            // Suppress output
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw IkemenError.installFailed("Failed to extract 7z file. Make sure p7zip is installed (brew install p7zip)")
            }
        } else {
            throw IkemenError.installFailed("Unsupported archive format: \(ext). Supported: zip, rar, 7z")
        }
        
        // Find the extracted content
        let extractedItems = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.isDirectoryKey])
        
        // Skip __MACOSX folder if present
        let contentItems = extractedItems.filter { !$0.lastPathComponent.hasPrefix("__MACOSX") && !$0.lastPathComponent.hasPrefix(".") }
        
        guard let firstItem = contentItems.first else {
            throw IkemenError.installFailed("Archive appears to be empty")
        }
        
        // Determine if it's a directory or files
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: firstItem.path, isDirectory: &isDirectory)
        
        let contentFolder: URL
        if isDirectory.boolValue {
            contentFolder = firstItem
        } else {
            // Files are at root level, use temp dir as content folder
            contentFolder = tempDir
        }
        
        return try installContentFolder(from: contentFolder)
    }
    
    /// Install content from a folder (auto-detects character or stage)
    func installContentFolder(from folderURL: URL) throws -> String {
        let fileManager = FileManager.default
        
        guard let workingDir = engineWorkingDirectory else {
            throw IkemenError.installFailed("Engine directory not found")
        }
        
        // Scan the folder to determine content type
        let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // Read DEF file to determine content type
        for defFile in defFiles {
            if let defContent = try? String(contentsOf: defFile, encoding: .utf8).lowercased() {
                // Stage DEF files have [StageInfo] section or bgdef/spr entries
                let isStageFile = defContent.contains("[stageinfo]") || 
                                  defContent.contains("[bg ") ||
                                  defContent.contains("bgdef") ||
                                  (defContent.contains("spr") && !defContent.contains("[files]"))
                
                // Character DEF files have [Files] section with cmd, cns, air, etc.
                let isCharacterFile = defContent.contains("[files]") && 
                                     (defContent.contains(".cmd") || defContent.contains(".cns") || defContent.contains(".air"))
                
                if isStageFile && !isCharacterFile {
                    return try installStageFolder(from: folderURL, to: workingDir)
                } else if isCharacterFile {
                    return try installCharacterFolder(from: folderURL, to: workingDir)
                }
            }
        }
        
        // Fallback: check for character-specific files
        let fileNames = contents.map { $0.lastPathComponent.lowercased() }
        let hasCharacterFiles = fileNames.contains { name in
            name.hasSuffix(".air") || name.hasSuffix(".cmd") || name.hasSuffix(".cns")
        }
        
        if hasCharacterFiles {
            return try installCharacterFolder(from: folderURL, to: workingDir)
        } else if !defFiles.isEmpty {
            // Default to stage if only has .def and .sff
            return try installStageFolder(from: folderURL, to: workingDir)
        }
        
        throw IkemenError.invalidContent("Could not determine content type. Ensure the folder contains character files (.def, .sff, .air, .cmd, .cns) or stage files (.def, .sff).")
    }
    
    private func installCharacterFolder(from source: URL, to workingDir: URL) throws -> String {
        let fileManager = FileManager.default
        let charsDir = workingDir.appendingPathComponent("chars")
        
        // Find the .def file to get the proper character name
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // Determine character name from DEF file or folder
        var charName = source.lastPathComponent
        var displayName = charName
        
        if let defFile = defFiles.first {
            // Use DEF filename as the folder name (standard convention)
            charName = defFile.deletingPathExtension().lastPathComponent
            
            // Try to read the "name" field from DEF file for display
            if let defContent = try? String(contentsOf: defFile, encoding: .utf8) {
                for line in defContent.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.lowercased().hasPrefix("name") && !trimmed.lowercased().hasPrefix("displayname") {
                        if let value = trimmed.split(separator: "=").last {
                            displayName = String(value).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                            break
                        }
                    }
                }
            }
        }
        
        let destPath = charsDir.appendingPathComponent(charName)
        
        // Check if character already exists
        let isUpdate = fileManager.fileExists(atPath: destPath.path)
        if isUpdate {
            // Remove old version
            try fileManager.removeItem(at: destPath)
        }
        
        // Copy to chars directory
        try fileManager.copyItem(at: source, to: destPath)
        
        // Find the .def file to determine the correct select.def entry
        let defEntry = findCharacterDefEntry(charName: charName, in: destPath)
        
        // Add to select.def if not already present
        if !isUpdate {
            try addCharacterToSelectDef(defEntry, in: workingDir)
        }
        
        // Check for portrait issues and generate warning
        let warnings = validateCharacterPortrait(in: destPath)
        
        // Reload characters
        loadCharacters()
        
        if !warnings.isEmpty {
            return "Installed character: \(displayName) ⚠️ \(warnings.joined(separator: ", "))"
        }
        return "Installed character: \(displayName)"
    }
    
    /// Validate character portrait and return any warnings
    private func validateCharacterPortrait(in charPath: URL) -> [String] {
        var warnings: [String] = []
        let fileManager = FileManager.default
        
        // Check for SFF file
        guard let contents = try? fileManager.contentsOfDirectory(at: charPath, includingPropertiesForKeys: nil) else {
            return warnings
        }
        
        let sffFiles = contents.filter { $0.pathExtension.lowercased() == "sff" }
        
        guard let sffFile = sffFiles.first else {
            warnings.append("No sprite file found")
            return warnings
        }
        
        // Try to read SFF header to check portrait sprite (9000,0)
        // SFF v1 and v2 have different formats
        if let portraitInfo = checkSFFPortrait(sffFile) {
            if portraitInfo.width > 200 || portraitInfo.height > 200 {
                warnings.append("Large portrait (\(portraitInfo.width)x\(portraitInfo.height))")
            } else if portraitInfo.width == 0 || portraitInfo.height == 0 {
                warnings.append("Missing portrait sprite")
            }
        }
        
        return warnings
    }
    
    /// Check SFF file for portrait sprite dimensions
    /// Returns (width, height) or nil if unable to parse
    private func checkSFFPortrait(_ sffURL: URL) -> (width: Int, height: Int)? {
        guard let data = try? Data(contentsOf: sffURL) else { return nil }
        guard data.count > 32 else { return nil }
        
        // Check SFF signature
        let signature = String(data: data[0..<12], encoding: .ascii) ?? ""
        
        if signature.hasPrefix("ElecbyteSpr") {
            // SFF v1 format
            return parseSFFv1Portrait(data)
        } else if signature.hasPrefix("ElecbyteSpr2") {
            // SFF v2 format - more complex, skip for now
            return nil
        }
        
        return nil
    }
    
    /// Parse SFF v1 to find portrait sprite (group 9000, image 0)
    private func parseSFFv1Portrait(_ data: Data) -> (width: Int, height: Int)? {
        guard data.count > 32 else { return nil }
        
        // Helper for safe unaligned reads
        func readUInt16(at offset: Int) -> UInt16 {
            guard offset + 1 < data.count else { return 0 }
            return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        }
        
        func readUInt32(at offset: Int) -> UInt32 {
            guard offset + 3 < data.count else { return 0 }
            return UInt32(data[offset]) |
                   (UInt32(data[offset + 1]) << 8) |
                   (UInt32(data[offset + 2]) << 16) |
                   (UInt32(data[offset + 3]) << 24)
        }
        
        // SFF v1 header:
        // 0-11: signature "ElecbyteSpr\0"
        // 12-15: version (little endian)
        // 16-19: number of groups
        // 20-23: number of images
        // 24-27: offset to first subfile
        // 28-31: size of subfile header
        
        let numImages = readUInt32(at: 20)
        let firstSubfileOffset = readUInt32(at: 24)
        
        guard numImages > 0, firstSubfileOffset < data.count else { return nil }
        
        // Each subfile header in v1:
        // 0-3: offset to next subfile
        // 4-7: subfile length
        // 8-9: x axis
        // 10-11: y axis
        // 12-13: group number
        // 14-15: image number
        // 16-17: index of previous image (for linked sprites)
        // 18: same palette flag
        // 19: blank/comment
        // Then: PCX image data
        
        var offset = Int(firstSubfileOffset)
        
        for _ in 0..<min(Int(numImages), 1000) { // Limit iterations
            guard offset + 20 <= data.count else { break }
            
            let nextOffset = readUInt32(at: offset)
            let groupNum = readUInt16(at: offset + 12)
            let imageNum = readUInt16(at: offset + 14)
            
            // Portrait is typically group 9000, image 0
            if groupNum == 9000 && imageNum == 0 {
                // Found portrait, try to get dimensions from PCX header
                let pcxOffset = offset + 32 // Skip subfile header
                if pcxOffset + 12 <= data.count {
                    // PCX header: xmin(2), ymin(2), xmax(2), ymax(2) at offset 4
                    let xmin = readUInt16(at: pcxOffset + 4)
                    let ymin = readUInt16(at: pcxOffset + 6)
                    let xmax = readUInt16(at: pcxOffset + 8)
                    let ymax = readUInt16(at: pcxOffset + 10)
                    
                    let width = Int(xmax) - Int(xmin) + 1
                    let height = Int(ymax) - Int(ymin) + 1
                    
                    if width > 0 && height > 0 && width < 2000 && height < 2000 {
                        return (width, height)
                    }
                }
            }
            
            if nextOffset == 0 || nextOffset <= offset { break }
            offset = Int(nextOffset)
        }
        
        return nil
    }
    
    /// Find the correct select.def entry for a character
    /// Returns "folder/name.def" if folder name doesn't match def name, otherwise just "folder"
    private func findCharacterDefEntry(charName: String, in charPath: URL) -> String {
        let fileManager = FileManager.default
        
        // Look for .def files in the character folder
        guard let contents = try? fileManager.contentsOfDirectory(at: charPath, includingPropertiesForKeys: nil) else {
            return charName
        }
        
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // If there's exactly one .def file and its name doesn't match the folder
        if defFiles.count == 1, let defFile = defFiles.first {
            let defName = defFile.deletingPathExtension().lastPathComponent
            if defName.lowercased() != charName.lowercased() {
                // Need to specify the full path: folder/name.def
                return "\(charName)/\(defFile.lastPathComponent)"
            }
        }
        
        // If there's a .def file matching the folder name, just use folder name
        let matchingDef = defFiles.first { $0.deletingPathExtension().lastPathComponent.lowercased() == charName.lowercased() }
        if matchingDef != nil {
            return charName
        }
        
        // If no exact match but there are def files, use the first one
        if let firstDef = defFiles.first {
            return "\(charName)/\(firstDef.lastPathComponent)"
        }
        
        // Fallback to just folder name
        return charName
    }
    
    private func addCharacterToSelectDef(_ charEntry: String, in workingDir: URL) throws {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard FileManager.default.fileExists(atPath: selectDefPath.path) else {
            print("Warning: select.def not found at \(selectDefPath.path)")
            return
        }
        
        // Read current content
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        // Check if character is already in the file (check both full entry and folder name)
        let folderName = charEntry.contains("/") ? String(charEntry.split(separator: "/").first!) : charEntry
        let charPattern = "(?m)^\\s*\(NSRegularExpression.escapedPattern(for: folderName))(/|\\s|,|$)"
        if let regex = try? NSRegularExpression(pattern: charPattern, options: .caseInsensitive),
           regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
            print("Character \(charEntry) already in select.def")
            return
        }
        
        // Find the [Characters] section and add the character after it
        // Look for existing character entries and add after them
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        var foundCharactersSection = false
        var insertedCharacter = false
        
        for line in lines {
            newLines.append(line)
            
            // Check if we're entering the [Characters] section
            if line.trimmingCharacters(in: .whitespaces).lowercased() == "[characters]" {
                foundCharactersSection = true
            }
            
            // If we're in the Characters section and haven't inserted yet,
            // look for a good place to insert (after comment block or after existing chars)
            if foundCharactersSection && !insertedCharacter {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Insert after we see a non-comment, non-empty line that looks like a character entry
                // or after the section header's comment block ends
                if !trimmed.isEmpty && !trimmed.hasPrefix(";") && !trimmed.hasPrefix("[") {
                    // This is likely a character entry, we'll insert after a few of these
                    continue
                }
                // If we hit a new section, insert before it
                if trimmed.hasPrefix("[") && trimmed.lowercased() != "[characters]" {
                    // Insert before this section
                    newLines.insert(charEntry, at: newLines.count - 1)
                    insertedCharacter = true
                }
            }
        }
        
        // If we still haven't inserted (maybe the file structure is different),
        // just append after [Characters] section
        if !insertedCharacter && foundCharactersSection {
            // Find [Characters] and insert after it and its comments
            var insertIndex = 0
            var inCharSection = false
            for (i, line) in newLines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased() == "[characters]" {
                    inCharSection = true
                    insertIndex = i + 1
                    continue
                }
                if inCharSection {
                    // Skip comments and empty lines
                    if trimmed.isEmpty || trimmed.hasPrefix(";") {
                        insertIndex = i + 1
                    } else if trimmed.hasPrefix("[") {
                        // Hit next section, insert here
                        break
                    } else {
                        // Found a character entry, insert after it
                        insertIndex = i + 1
                    }
                }
            }
            newLines.insert(charEntry, at: insertIndex)
        }
        
        // Write back
        content = newLines.joined(separator: "\n")
        try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
        print("Added \(charEntry) to select.def")
    }
    
    private func installStageFolder(from source: URL, to workingDir: URL) throws -> String {
        let fileManager = FileManager.default
        let stagesDir = workingDir.appendingPathComponent("stages")
        
        // For stages, we need to copy the .def file(s) and any associated files
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        var installedStages: [String] = []
        
        for file in contents {
            let ext = file.pathExtension.lowercased()
            let destPath = stagesDir.appendingPathComponent(file.lastPathComponent)
            
            // Remove existing file if present
            if fileManager.fileExists(atPath: destPath.path) {
                try fileManager.removeItem(at: destPath)
            }
            
            try fileManager.copyItem(at: file, to: destPath)
            
            if ext == "def" {
                installedStages.append(file.deletingPathExtension().lastPathComponent)
            }
        }
        
        // Add stages to select.def
        for stageName in installedStages {
            try addStageToSelectDef(stageName, in: workingDir)
        }
        
        // Reload stages
        loadStages()
        
        if installedStages.count == 1 {
            return "Installed stage: \(installedStages[0])"
        } else if installedStages.count > 1 {
            return "Installed \(installedStages.count) stages: \(installedStages.joined(separator: ", "))"
        } else {
            return "No stages found to install"
        }
    }
    
    private func addStageToSelectDef(_ stageName: String, in workingDir: URL) throws {
        let selectDefPath = workingDir.appendingPathComponent("data/select.def")
        
        guard FileManager.default.fileExists(atPath: selectDefPath.path) else {
            return
        }
        
        var content = try String(contentsOf: selectDefPath, encoding: .utf8)
        
        // Check if stage is already in the [ExtraStages] section
        let stageEntry = "stages/\(stageName).def"
        if content.contains(stageEntry) {
            return
        }
        
        // Find [ExtraStages] section and add the stage
        if let range = content.range(of: "[ExtraStages]", options: .caseInsensitive) {
            // Find the end of the line after [ExtraStages]
            if let lineEnd = content.range(of: "\n", range: range.upperBound..<content.endIndex) {
                let insertPosition = lineEnd.upperBound
                content.insert(contentsOf: "\(stageEntry)\n", at: insertPosition)
                try content.write(to: selectDefPath, atomically: true, encoding: .utf8)
                print("Added stage \(stageName) to select.def")
            }
        }
    }
    
    /// Install a character from a zip file
    func installCharacter(from zipURL: URL) throws {
        _ = try installContent(from: zipURL)
    }
    
    /// Install a stage from a zip file
    func installStage(from zipURL: URL) throws {
        _ = try installContent(from: zipURL)
    }
    
    // MARK: - Paths
    
    /// Get the content directory URL
    func getContentPath() -> URL {
        return contentPath
    }
    
    /// Get the characters directory URL
    func getCharsPath() -> URL {
        return charsPath
    }
    
    /// Get the stages directory URL
    func getStagesPath() -> URL {
        return stagesPath
    }
    
    /// Get path for a specific content type
    func getPath(for contentType: ContentType) -> URL {
        switch contentType {
        case .character: return charsPath
        case .stage: return stagesPath
        case .screenpack: return dataPath
        case .font: return fontPath
        case .sound: return soundPath
        }
    }
}
