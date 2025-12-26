import Cocoa
import Combine

/// A detail panel showing character metadata
/// Displays portrait, editable name, author, palettes, and move list
class CharacterDetailsView: NSView {
    
    // MARK: - Properties
    
    private var portraitImageView: NSImageView!
    private var nameField: NSTextField!
    private var editButton: NSButton!
    private var authorLabel: NSTextField!
    private var versionLabel: NSTextField!
    private var paletteLabel: NSTextField!
    private var moveListHeader: NSTextField!
    private var moveListStackView: NSStackView!
    private var scrollView: NSScrollView!
    private var contentView: NSView!
    
    private var currentCharacter: CharacterInfo?
    private var isEditingName = false
    
    /// Callback when close is requested
    var onClose: (() -> Void)?
    
    /// Callback when name is changed
    var onNameChanged: ((CharacterInfo, String) -> Void)?
    
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
        closeButton.contentTintColor = DesignColors.creamText.withAlphaComponent(0.6)
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
        
        // Name field (editable)
        nameField = NSTextField()
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        nameField.textColor = DesignColors.creamText
        nameField.backgroundColor = .clear
        nameField.isBordered = false
        nameField.isEditable = false
        nameField.focusRingType = .none
        nameField.lineBreakMode = .byTruncatingTail
        nameField.delegate = self
        contentView.addSubview(nameField)
        
        // Edit button
        editButton = NSButton(title: "✎", target: self, action: #selector(editNameClicked))
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.bezelStyle = .inline
        editButton.isBordered = false
        editButton.font = NSFont.systemFont(ofSize: 14)
        editButton.contentTintColor = DesignColors.creamText.withAlphaComponent(0.5)
        editButton.toolTip = "Edit display name"
        contentView.addSubview(editButton)
        
        // Author label
        authorLabel = createLabel(fontSize: 13, weight: .regular, color: DesignColors.creamText.withAlphaComponent(0.7))
        contentView.addSubview(authorLabel)
        
        // Section: Details
        let detailsHeader = createSectionHeader("DETAILS")
        contentView.addSubview(detailsHeader)
        
        versionLabel = createLabel(fontSize: 12, weight: .regular)
        contentView.addSubview(versionLabel)
        
        paletteLabel = createLabel(fontSize: 12, weight: .regular)
        contentView.addSubview(paletteLabel)
        
        // Section: Move List
        moveListHeader = createSectionHeader("MOVE LIST")
        contentView.addSubview(moveListHeader)
        
        moveListStackView = NSStackView()
        moveListStackView.translatesAutoresizingMaskIntoConstraints = false
        moveListStackView.orientation = .vertical
        moveListStackView.alignment = .leading
        moveListStackView.spacing = 8
        contentView.addSubview(moveListStackView)
        
        // Layout
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            portraitImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            portraitImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            portraitImageView.widthAnchor.constraint(equalToConstant: 160),
            portraitImageView.heightAnchor.constraint(equalToConstant: 160),
            
            nameField.topAnchor.constraint(equalTo: portraitImageView.bottomAnchor, constant: 16),
            nameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            nameField.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -4),
            
            editButton.centerYAnchor.constraint(equalTo: nameField.centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            editButton.widthAnchor.constraint(equalToConstant: 24),
            
            authorLabel.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            authorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            detailsHeader.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 20),
            detailsHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            detailsHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            versionLabel.topAnchor.constraint(equalTo: detailsHeader.bottomAnchor, constant: 8),
            versionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            versionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            paletteLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 4),
            paletteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            paletteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            moveListHeader.topAnchor.constraint(equalTo: paletteLabel.bottomAnchor, constant: 20),
            moveListHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            moveListHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            moveListStackView.topAnchor.constraint(equalTo: moveListHeader.bottomAnchor, constant: 8),
            moveListStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            moveListStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            moveListStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),
        ])
    }
    
    private func createLabel(fontSize: CGFloat, weight: NSFont.Weight, color: NSColor = DesignColors.creamText) -> NSTextField {
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
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = DesignColors.creamText.withAlphaComponent(0.5)
        return label
    }
    
    // MARK: - Actions
    
    @objc private func closeClicked() {
        onClose?()
    }
    
    @objc private func editNameClicked() {
        if isEditingName {
            // Save the name
            finishEditingName()
        } else {
            // Start editing
            isEditingName = true
            nameField.isEditable = true
            nameField.backgroundColor = NSColor.black.withAlphaComponent(0.3)
            nameField.isBordered = true
            nameField.selectText(nil)
            editButton.title = "✓"
            editButton.contentTintColor = NSColor.systemGreen
        }
    }
    
    private func finishEditingName() {
        isEditingName = false
        nameField.isEditable = false
        nameField.backgroundColor = .clear
        nameField.isBordered = false
        editButton.title = "✎"
        editButton.contentTintColor = DesignColors.creamText.withAlphaComponent(0.5)
        
        if let character = currentCharacter {
            let newName = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            if !newName.isEmpty && newName != character.displayName {
                onNameChanged?(character, newName)
            }
        }
    }
    
    // MARK: - Public Methods
    
    func configure(with character: CharacterInfo) {
        currentCharacter = character
        
        nameField.stringValue = character.displayName
        authorLabel.stringValue = "by \(character.author)"
        
        // Load extended info
        let extendedInfo = CharacterExtendedInfo(from: character)
        
        // Version info
        versionLabel.stringValue = extendedInfo.versionDate.isEmpty ? "Version: Unknown" : "Version: \(extendedInfo.versionDate)"
        
        // Palette count
        paletteLabel.stringValue = "Palettes: \(extendedInfo.paletteCount)"
        
        // Load move list
        loadMoveList(for: character)
        
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
    
    // MARK: - Move List
    
    private func loadMoveList(for character: CharacterInfo) {
        // Clear existing moves
        moveListStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Parse CMD file for moves
        let moves = CMDParser.parseMoves(for: character)
        
        if moves.isEmpty {
            let noMovesLabel = createLabel(fontSize: 12, weight: .regular, color: DesignColors.creamText.withAlphaComponent(0.5))
            noMovesLabel.stringValue = "No special moves found"
            moveListStackView.addArrangedSubview(noMovesLabel)
        } else {
            for move in moves {
                let moveView = createMoveRow(move)
                moveListStackView.addArrangedSubview(moveView)
            }
        }
    }
    
    private func createMoveRow(_ move: MoveCommand) -> NSView {
        let row = NSStackView()
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 2
        
        // Move name
        let nameLabel = NSTextField(labelWithString: move.displayName)
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = DesignColors.creamText
        row.addArrangedSubview(nameLabel)
        
        // Input notation
        let inputLabel = NSTextField(labelWithString: move.notation)
        inputLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        inputLabel.textColor = DesignColors.creamText.withAlphaComponent(0.8)
        row.addArrangedSubview(inputLabel)
        
        return row
    }
}

// MARK: - NSTextFieldDelegate

extension CharacterDetailsView: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter pressed - save
            finishEditingName()
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Escape pressed - cancel
            if let character = currentCharacter {
                nameField.stringValue = character.displayName
            }
            finishEditingName()
            return true
        }
        return false
    }
}

// MARK: - Character Extended Info

struct CharacterExtendedInfo {
    let paletteCount: Int
    let mugenVersion: String
    let versionDate: String
    
    init(from character: CharacterInfo) {
        let defFile = character.defFile
        
        var palCount = 0
        var mugenVer = "Ikemen GO / MUGEN 1.0+"
        var verDate = character.versionDate
        
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
        
        self.paletteCount = max(palCount, 1)
        self.mugenVersion = mugenVer
        self.versionDate = verDate
    }
}

// MARK: - Move Command

struct MoveCommand {
    let name: String       // Internal name (e.g., "SpecialX")
    let displayName: String // Human-readable name
    let command: String    // Raw command (e.g., "~D,DF,F, x")
    let notation: String   // Pretty notation (e.g., "↓↘→ + LP")
}

// MARK: - CMD Parser

struct CMDParser {
    
    /// Parse special moves from a character's CMD file
    static func parseMoves(for character: CharacterInfo) -> [MoveCommand] {
        // Find CMD file
        guard let cmdFile = findCMDFile(for: character),
              let content = try? String(contentsOf: cmdFile, encoding: .utf8) else {
            return []
        }
        
        var moves: [MoveCommand] = []
        var seenCommands = Set<String>()
        
        let lines = content.components(separatedBy: .newlines)
        var currentName: String?
        var currentCommand: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix(";") {
                continue
            }
            
            let lower = trimmed.lowercased()
            
            // Parse name = "..."
            if lower.hasPrefix("name") && lower.contains("=") {
                if let nameMatch = extractQuotedValue(from: trimmed) {
                    currentName = nameMatch
                }
            }
            
            // Parse command = ...
            if lower.hasPrefix("command") && lower.contains("=") {
                if let eqIdx = trimmed.firstIndex(of: "=") {
                    currentCommand = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                }
            }
            
            // If we have both name and command, create a move
            if let name = currentName, let command = currentCommand {
                // Skip AI commands and basic movement
                let skipPrefixes = ["AI_", "holdfwd", "holdback", "holdup", "holddown", "recovery", "fwd", "back", "up", "down"]
                let shouldSkip = skipPrefixes.contains { name.lowercased().hasPrefix($0.lowercased()) } ||
                                 name.lowercased() == "run" ||
                                 name.lowercased() == "dash"
                
                // Only include special/hyper moves
                if !shouldSkip && isSpecialMove(command: command) {
                    let key = "\(name)|\(command)"
                    if !seenCommands.contains(key) {
                        seenCommands.insert(key)
                        
                        let displayName = formatMoveName(name)
                        let notation = formatNotation(command)
                        
                        moves.append(MoveCommand(
                            name: name,
                            displayName: displayName,
                            command: command,
                            notation: notation
                        ))
                    }
                }
                
                currentName = nil
                currentCommand = nil
            }
        }
        
        // Sort: Hypers first, then specials
        return moves.sorted { m1, m2 in
            let isHyper1 = m1.name.lowercased().contains("hyper") || m1.name.lowercased().contains("super")
            let isHyper2 = m2.name.lowercased().contains("hyper") || m2.name.lowercased().contains("super")
            if isHyper1 != isHyper2 { return isHyper1 }
            return m1.displayName < m2.displayName
        }
    }
    
    private static func findCMDFile(for character: CharacterInfo) -> URL? {
        let fileManager = FileManager.default
        
        // First, check the DEF file for cmd reference
        if let content = try? String(contentsOf: character.defFile, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
                if trimmed.hasPrefix("cmd") && trimmed.contains("=") {
                    if let eqIdx = line.firstIndex(of: "=") {
                        let cmdName = String(line[line.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
                        let cmdPath = character.directory.appendingPathComponent(cmdName)
                        if fileManager.fileExists(atPath: cmdPath.path) {
                            return cmdPath
                        }
                    }
                }
            }
        }
        
        // Fallback: look for .cmd file with same name as character
        let defName = character.defFile.deletingPathExtension().lastPathComponent
        let cmdFile = character.directory.appendingPathComponent("\(defName).cmd")
        if fileManager.fileExists(atPath: cmdFile.path) {
            return cmdFile
        }
        
        // Last resort: any .cmd file
        if let contents = try? fileManager.contentsOfDirectory(at: character.directory, includingPropertiesForKeys: nil) {
            return contents.first { $0.pathExtension.lowercased() == "cmd" }
        }
        
        return nil
    }
    
    private static func extractQuotedValue(from line: String) -> String? {
        guard let firstQuote = line.firstIndex(of: "\""),
              let lastQuote = line.lastIndex(of: "\""),
              firstQuote != lastQuote else {
            return nil
        }
        return String(line[line.index(after: firstQuote)..<lastQuote])
    }
    
    private static func isSpecialMove(command: String) -> Bool {
        let lower = command.lowercased()
        // Special moves typically have direction sequences
        let hasDirectionSequence = lower.contains("~d") || lower.contains("~f") || lower.contains("~b") ||
                                   lower.contains(",d") || lower.contains(",f") || lower.contains(",b") ||
                                   lower.contains("df") || lower.contains("db") || lower.contains("uf") || lower.contains("ub")
        // And end with a button
        let hasButton = lower.contains("x") || lower.contains("y") || lower.contains("z") ||
                       lower.contains("a") || lower.contains("b") || lower.contains("c")
        return hasDirectionSequence && hasButton
    }
    
    private static func formatMoveName(_ name: String) -> String {
        // Convert "SpecialX" to "Special X", "Hyper1" to "Hyper 1", etc.
        var result = name
        
        // Insert space before capital letters and numbers
        var formatted = ""
        for (i, char) in result.enumerated() {
            if i > 0 && (char.isUppercase || char.isNumber) {
                let prevChar = result[result.index(result.startIndex, offsetBy: i - 1)]
                if !prevChar.isUppercase && !prevChar.isNumber && prevChar != " " {
                    formatted += " "
                }
            }
            formatted += String(char)
        }
        
        return formatted
    }
    
    private static func formatNotation(_ command: String) -> String {
        var result = command
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "~", with: "")
        
        // Direction mappings
        let directionMap: [(String, String)] = [
            ("DF", "↘"),
            ("DB", "↙"),
            ("UF", "↗"),
            ("UB", "↖"),
            ("D", "↓"),
            ("U", "↑"),
            ("F", "→"),
            ("B", "←"),
        ]
        
        // Button mappings (case-sensitive for final output)
        let buttonMap: [(String, String)] = [
            ("x+y", "LP+MP"),
            ("y+z", "MP+HP"),
            ("x+z", "LP+HP"),
            ("a+b", "LK+MK"),
            ("b+c", "MK+HK"),
            ("a+c", "LK+HK"),
            ("x", "LP"),
            ("y", "MP"),
            ("z", "HP"),
            ("a", "LK"),
            ("b", "MK"),
            ("c", "HK"),
        ]
        
        // Apply direction mappings (case-insensitive)
        for (from, to) in directionMap {
            result = result.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        
        // Apply button mappings
        for (from, to) in buttonMap {
            result = result.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        
        // Clean up separators
        result = result.replacingOccurrences(of: ",", with: " ")
        
        // Add + before button at the end
        let buttons = ["LP", "MP", "HP", "LK", "MK", "HK", "LP+MP", "MP+HP", "LP+HP", "LK+MK", "MK+HK", "LK+HK"]
        for button in buttons {
            if result.hasSuffix(button) && !result.hasSuffix("+ \(button)") {
                let prefix = String(result.dropLast(button.count)).trimmingCharacters(in: .whitespaces)
                if !prefix.isEmpty {
                    result = "\(prefix) + \(button)"
                }
                break
            }
        }
        
        return result
    }
}
