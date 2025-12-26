import Cocoa
import Combine

/// A detail panel showing character metadata
/// Displays portrait, name, author, palettes, file sizes, and compatibility
class CharacterDetailsView: NSView {
    
    // MARK: - Properties
    
    private var portraitImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var authorLabel: NSTextField!
    private var versionLabel: NSTextField!
    private var paletteLabel: NSTextField!
    private var fileSizeLabel: NSTextField!
    private var compatibilityLabel: NSTextField!
    private var filesStackView: NSStackView!
    private var scrollView: NSScrollView!
    private var contentView: NSView!
    
    private var currentCharacter: CharacterInfo?
    private var cancellables = Set<AnyCancellable>()
    
    /// Callback when close is requested
    var onClose: (() -> Void)?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = DesignColors.cardBackground.cgColor
        layer?.cornerRadius = 12
        
        setupScrollView()
        setupContent()
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        scrollView = NSScrollView(frame: bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)
        
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
    
    private func setupContent() {
        let padding: CGFloat = 20
        
        // Close button
        let closeButton = NSButton(title: "✕", target: self, action: #selector(closeClicked))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        contentView.addSubview(closeButton)
        
        // Portrait image
        portraitImageView = NSImageView()
        portraitImageView.translatesAutoresizingMaskIntoConstraints = false
        portraitImageView.imageScaling = .scaleProportionallyUpOrDown
        portraitImageView.wantsLayer = true
        portraitImageView.layer?.cornerRadius = 8
        portraitImageView.layer?.masksToBounds = true
        portraitImageView.layer?.backgroundColor = DesignColors.placeholderBackground.cgColor
        contentView.addSubview(portraitImageView)
        
        // Name label
        nameLabel = createLabel(fontSize: 24, weight: .bold)
        contentView.addSubview(nameLabel)
        
        // Author label
        authorLabel = createLabel(fontSize: 14, weight: .regular, color: .secondaryLabelColor)
        contentView.addSubview(authorLabel)
        
        // Section: Details
        let detailsHeader = createSectionHeader("Details")
        contentView.addSubview(detailsHeader)
        
        versionLabel = createLabel(fontSize: 13, weight: .regular)
        contentView.addSubview(versionLabel)
        
        paletteLabel = createLabel(fontSize: 13, weight: .regular)
        contentView.addSubview(paletteLabel)
        
        compatibilityLabel = createLabel(fontSize: 13, weight: .regular)
        contentView.addSubview(compatibilityLabel)
        
        // Section: Files
        let filesHeader = createSectionHeader("Files")
        contentView.addSubview(filesHeader)
        
        fileSizeLabel = createLabel(fontSize: 13, weight: .regular)
        fileSizeLabel.maximumNumberOfLines = 10
        contentView.addSubview(fileSizeLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            portraitImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            portraitImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            portraitImageView.widthAnchor.constraint(equalToConstant: 160),
            portraitImageView.heightAnchor.constraint(equalToConstant: 160),
            
            nameLabel.topAnchor.constraint(equalTo: portraitImageView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            authorLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            authorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            detailsHeader.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 24),
            detailsHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            detailsHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            versionLabel.topAnchor.constraint(equalTo: detailsHeader.bottomAnchor, constant: 8),
            versionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            versionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            paletteLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 4),
            paletteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            paletteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            compatibilityLabel.topAnchor.constraint(equalTo: paletteLabel.bottomAnchor, constant: 4),
            compatibilityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            compatibilityLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            filesHeader.topAnchor.constraint(equalTo: compatibilityLabel.bottomAnchor, constant: 24),
            filesHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            filesHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            fileSizeLabel.topAnchor.constraint(equalTo: filesHeader.bottomAnchor, constant: 8),
            fileSizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            fileSizeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            fileSizeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),
        ])
    }
    
    private func createLabel(fontSize: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }
    
    private func createSectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        return label
    }
    
    // MARK: - Actions
    
    @objc private func closeClicked() {
        onClose?()
    }
    
    // MARK: - Public Methods
    
    func configure(with character: CharacterInfo) {
        currentCharacter = character
        
        nameLabel.stringValue = character.displayName
        authorLabel.stringValue = "by \(character.author)"
        
        // Version info
        if !character.versionDate.isEmpty {
            versionLabel.stringValue = "Version: \(character.versionDate)"
        } else {
            versionLabel.stringValue = "Version: Unknown"
        }
        
        // Load extended info
        let extendedInfo = CharacterExtendedInfo(from: character)
        
        // Palette count
        paletteLabel.stringValue = "Palettes: \(extendedInfo.paletteCount)"
        
        // MUGEN compatibility
        compatibilityLabel.stringValue = "Target: \(extendedInfo.mugenVersion)"
        
        // File sizes
        fileSizeLabel.stringValue = extendedInfo.filesSummary
        
        // Load portrait
        loadPortrait(for: character)
    }
    
    private func loadPortrait(for character: CharacterInfo) {
        // Check cache first
        let cacheKey = ImageCache.portraitKey(for: character.id)
        if let cached = ImageCache.shared.get(cacheKey) {
            portraitImageView.image = cached
            return
        }
        
        // Load in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let portrait = character.getPortraitImage()
            
            DispatchQueue.main.async {
                self?.portraitImageView.image = portrait ?? self?.createPlaceholderImage(for: character)
                
                if let realPortrait = portrait {
                    ImageCache.shared.set(realPortrait, for: cacheKey)
                }
            }
        }
    }
    
    private func createPlaceholderImage(for character: CharacterInfo) -> NSImage {
        let size = NSSize(width: 160, height: 160)
        let image = NSImage(size: size)
        
        image.lockFocus()
        DesignColors.placeholderBackground.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        let initial = String(character.displayName.prefix(1)).uppercased()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 60, weight: .medium),
            .foregroundColor: NSColor(white: 0.5, alpha: 1.0)
        ]
        let attrString = NSAttributedString(string: initial, attributes: attrs)
        let stringSize = attrString.size()
        let point = NSPoint(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2
        )
        attrString.draw(at: point)
        
        image.unlockFocus()
        return image
    }
}

// MARK: - Character Extended Info

/// Extended character metadata parsed on demand
struct CharacterExtendedInfo {
    let paletteCount: Int
    let mugenVersion: String
    let totalSize: Int64
    let filesSummary: String
    
    init(from character: CharacterInfo) {
        let fileManager = FileManager.default
        let defFile = character.defFile
        
        // Parse DEF file for additional info
        var palCount = 0
        var mugenVer = "Ikemen GO / MUGEN 1.0+"
        
        if let content = try? String(contentsOf: defFile, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
                
                // Count palette entries (pal1 through pal12)
                if trimmed.hasPrefix("pal") && trimmed.contains("=") {
                    let parts = trimmed.split(separator: "=")
                    if parts.count == 2 {
                        let palKey = String(parts[0]).trimmingCharacters(in: .whitespaces)
                        let palValue = String(parts[1]).trimmingCharacters(in: .whitespaces)
                        // Check if it's a numbered palette (pal1, pal2, etc.) with a value
                        if palKey.hasPrefix("pal"), let _ = Int(String(palKey.dropFirst(3))), !palValue.isEmpty {
                            palCount += 1
                        }
                    }
                }
                
                // Check MUGEN version
                if trimmed.hasPrefix("mugenversion") && trimmed.contains("=") {
                    let parts = trimmed.split(separator: "=")
                    if parts.count == 2 {
                        let version = String(parts[1]).trimmingCharacters(in: .whitespaces)
                        if version.contains("1.1") {
                            mugenVer = "MUGEN 1.1"
                        } else if version.contains("1.0") {
                            mugenVer = "MUGEN 1.0"
                        } else if version.contains("win") || version.contains("04") {
                            mugenVer = "WinMUGEN"
                        } else {
                            mugenVer = "MUGEN \(version)"
                        }
                    }
                }
            }
        }
        
        self.paletteCount = max(palCount, 1)  // At least 1 palette
        self.mugenVersion = mugenVer
        
        // Calculate total folder size and file breakdown
        var total: Int64 = 0
        var fileSizes: [(String, Int64)] = []
        
        if let enumerator = fileManager.enumerator(at: character.directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      resourceValues.isRegularFile == true,
                      let fileSize = resourceValues.fileSize else {
                    continue
                }
                
                let size = Int64(fileSize)
                total += size
                
                let ext = fileURL.pathExtension.lowercased()
                // Track sizes for main file types
                if ["sff", "snd", "air", "cmd", "cns", "def", "act"].contains(ext) {
                    fileSizes.append((fileURL.lastPathComponent, size))
                }
            }
        }
        
        self.totalSize = total
        
        // Build files summary
        var summary = "Total: \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))\n"
        
        // Sort by size descending and show top files
        let sortedFiles = fileSizes.sorted { $0.1 > $1.1 }
        for (name, size) in sortedFiles.prefix(5) {
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            summary += "\n• \(name): \(sizeStr)"
        }
        
        self.filesSummary = summary
    }
}
