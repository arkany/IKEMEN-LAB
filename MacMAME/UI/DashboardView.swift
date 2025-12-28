import Cocoa

/// Dashboard view - the main landing page with stats, quick actions, and recent activity
class DashboardView: NSView {
    
    // MARK: - Callbacks
    var onLaunchGame: (() -> Void)?
    var onFilesDropped: (([URL]) -> Void)?
    
    // MARK: - UI Elements
    private var scrollView: NSScrollView!
    private var contentStack: NSStackView!
    
    // Stats cards
    private var fightersCountLabel: NSTextField!
    private var stagesCountLabel: NSTextField!
    private var storageLabel: NSTextField!
    private var lastPlayedLabel: NSTextField!
    
    // Drop zone
    private var dropZoneView: DashboardDropZone!
    
    // Quick settings
    private var vsyncToggle: NSSwitch!
    private var fullscreenToggle: NSSwitch!
    private var volumeSlider: NSSlider!
    private var volumeLabel: NSTextField!
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Scroll view for dashboard content
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        
        // Content view
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        
        // Main stack
        contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .leading
        documentView.addSubview(contentStack)
        
        // Build sections
        setupHeader()
        setupStatsCards()
        setupDropZone()
        setupQuickSettings()
        
        // Layout
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -32),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -64),
            
            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
    
    // MARK: - Header
    
    private func setupHeader() {
        let headerStack = NSStackView()
        headerStack.orientation = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .leading
        
        let titleLabel = NSTextField(labelWithString: "Dashboard")
        titleLabel.font = DesignFonts.header(size: 28)
        titleLabel.textColor = DesignColors.textPrimary
        headerStack.addArrangedSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Manage your local IKEMEN GO assets and configuration")
        subtitleLabel.font = DesignFonts.body(size: 14)
        subtitleLabel.textColor = DesignColors.textSecondary
        headerStack.addArrangedSubview(subtitleLabel)
        
        contentStack.addArrangedSubview(headerStack)
    }
    
    // MARK: - Stats Cards
    
    private func setupStatsCards() {
        let cardsContainer = NSStackView()
        cardsContainer.orientation = .horizontal
        cardsContainer.spacing = 16
        cardsContainer.distribution = .fillEqually
        cardsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Fighters card
        let (fightersCard, fightersLabel) = createStatCard(
            icon: "person.2.fill",
            title: "Active Fighters",
            value: "0"
        )
        fightersCountLabel = fightersLabel
        cardsContainer.addArrangedSubview(fightersCard)
        
        // Stages card
        let (stagesCard, stagesLabel) = createStatCard(
            icon: "photo.fill",
            title: "Installed Stages",
            value: "0"
        )
        stagesCountLabel = stagesLabel
        cardsContainer.addArrangedSubview(stagesCard)
        
        // Storage card
        let (storageCard, storageValueLabel) = createStatCard(
            icon: "externaldrive.fill",
            title: "Storage Used",
            value: "—"
        )
        storageLabel = storageValueLabel
        cardsContainer.addArrangedSubview(storageCard)
        
        // Launch card (special - has button)
        let launchCard = createLaunchCard()
        cardsContainer.addArrangedSubview(launchCard)
        
        // Width constraint for cards container
        cardsContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 600).isActive = true
        
        contentStack.addArrangedSubview(cardsContainer)
    }
    
    private func createStatCard(icon: String, title: String, value: String) -> (NSView, NSTextField) {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        card.addSubview(stack)
        
        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textSecondary
        iconView.symbolConfiguration = .init(pointSize: 20, weight: .medium)
        stack.addArrangedSubview(iconView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignFonts.caption(size: 12)
        titleLabel.textColor = DesignColors.textSecondary
        stack.addArrangedSubview(titleLabel)
        
        // Value
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = DesignFonts.header(size: 32)
        valueLabel.textColor = DesignColors.textPrimary
        stack.addArrangedSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 120),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        
        return (card, valueLabel)
    }
    
    private func createLaunchCard() -> NSView {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.15).cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.3).cgColor
        
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        card.addSubview(stack)
        
        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.positive
        iconView.symbolConfiguration = .init(pointSize: 20, weight: .medium)
        stack.addArrangedSubview(iconView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Launch Game")
        titleLabel.font = DesignFonts.caption(size: 12)
        titleLabel.textColor = DesignColors.positive
        stack.addArrangedSubview(titleLabel)
        
        // Last played
        lastPlayedLabel = NSTextField(labelWithString: "Ready to play")
        lastPlayedLabel.font = DesignFonts.body(size: 14)
        lastPlayedLabel.textColor = DesignColors.textSecondary
        stack.addArrangedSubview(lastPlayedLabel)
        
        // Launch button
        let launchButton = NSButton(title: "Play Now", target: self, action: #selector(launchButtonClicked))
        launchButton.translatesAutoresizingMaskIntoConstraints = false
        launchButton.bezelStyle = .rounded
        launchButton.controlSize = .large
        launchButton.font = DesignFonts.body(size: 14)
        stack.addArrangedSubview(launchButton)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 120),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        
        return card
    }
    
    // MARK: - Drop Zone
    
    private func setupDropZone() {
        let sectionLabel = NSTextField(labelWithString: "INSTALL CONTENT")
        sectionLabel.font = DesignFonts.caption(size: 11)
        sectionLabel.textColor = DesignColors.textTertiary
        contentStack.addArrangedSubview(sectionLabel)
        
        dropZoneView = DashboardDropZone(frame: .zero)
        dropZoneView.translatesAutoresizingMaskIntoConstraints = false
        dropZoneView.onFilesDropped = { [weak self] urls in
            self?.onFilesDropped?(urls)
        }
        
        NSLayoutConstraint.activate([
            dropZoneView.heightAnchor.constraint(equalToConstant: 140),
        ])
        
        contentStack.addArrangedSubview(dropZoneView)
        
        // Make drop zone fill width
        dropZoneView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        dropZoneView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
    }
    
    // MARK: - Quick Settings
    
    private func setupQuickSettings() {
        let sectionLabel = NSTextField(labelWithString: "QUICK SETTINGS")
        sectionLabel.font = DesignFonts.caption(size: 11)
        sectionLabel.textColor = DesignColors.textTertiary
        contentStack.addArrangedSubview(sectionLabel)
        
        let settingsCard = NSView()
        settingsCard.translatesAutoresizingMaskIntoConstraints = false
        settingsCard.wantsLayer = true
        settingsCard.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        settingsCard.layer?.cornerRadius = 12
        settingsCard.layer?.borderWidth = 1
        settingsCard.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        let settingsStack = NSStackView()
        settingsStack.translatesAutoresizingMaskIntoConstraints = false
        settingsStack.orientation = .vertical
        settingsStack.spacing = 16
        settingsCard.addSubview(settingsStack)
        
        // V-Sync toggle
        let vsyncRow = createSettingRow(label: "V-Sync", type: .toggle)
        vsyncToggle = vsyncRow.1 as? NSSwitch
        settingsStack.addArrangedSubview(vsyncRow.0)
        
        // Fullscreen toggle
        let fullscreenRow = createSettingRow(label: "Fullscreen", type: .toggle)
        fullscreenToggle = fullscreenRow.1 as? NSSwitch
        settingsStack.addArrangedSubview(fullscreenRow.0)
        
        // Volume slider
        let volumeRow = createVolumeRow()
        settingsStack.addArrangedSubview(volumeRow)
        
        NSLayoutConstraint.activate([
            settingsStack.topAnchor.constraint(equalTo: settingsCard.topAnchor, constant: 16),
            settingsStack.leadingAnchor.constraint(equalTo: settingsCard.leadingAnchor, constant: 16),
            settingsStack.trailingAnchor.constraint(equalTo: settingsCard.trailingAnchor, constant: -16),
            settingsStack.bottomAnchor.constraint(equalTo: settingsCard.bottomAnchor, constant: -16),
        ])
        
        contentStack.addArrangedSubview(settingsCard)
        
        // Make settings card fill width
        settingsCard.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        settingsCard.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
        
        // Load current settings
        loadSettings()
    }
    
    private enum SettingType {
        case toggle
    }
    
    private func createSettingRow(label: String, type: SettingType) -> (NSView, NSControl) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 14)
        labelField.textColor = DesignColors.textPrimary
        row.addArrangedSubview(labelField)
        
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(settingToggled(_:))
        row.addArrangedSubview(toggle)
        
        return (row, toggle)
    }
    
    private func createVolumeRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: "Master Volume")
        labelField.font = DesignFonts.body(size: 14)
        labelField.textColor = DesignColors.textPrimary
        row.addArrangedSubview(labelField)
        
        volumeSlider = NSSlider()
        volumeSlider.minValue = 0
        volumeSlider.maxValue = 100
        volumeSlider.intValue = 100
        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged(_:))
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(volumeSlider)
        
        volumeLabel = NSTextField(labelWithString: "100%")
        volumeLabel.font = DesignFonts.caption(size: 12)
        volumeLabel.textColor = DesignColors.textSecondary
        volumeLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
        row.addArrangedSubview(volumeLabel)
        
        return row
    }
    
    // MARK: - Actions
    
    @objc private func launchButtonClicked() {
        onLaunchGame?()
    }
    
    @objc private func settingToggled(_ sender: NSSwitch) {
        saveSettings()
    }
    
    @objc private func volumeChanged(_ sender: NSSlider) {
        volumeLabel.stringValue = "\(sender.intValue)%"
        saveSettings()
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        // Load from Ikemen config
        guard let configPath = getIkemenConfigPath(),
              let config = parseIniFile(at: configPath) else { return }
        
        if let vsync = config["Video"]?["VSync"] {
            vsyncToggle?.state = vsync == "1" ? .on : .off
        }
        if let fullscreen = config["Video"]?["Fullscreen"] {
            fullscreenToggle?.state = fullscreen == "1" ? .on : .off
        }
        if let volume = config["Sound"]?["MasterVolume"], let intVal = Int(volume) {
            volumeSlider?.intValue = Int32(intVal)
            volumeLabel?.stringValue = "\(intVal)%"
        }
    }
    
    private func saveSettings() {
        guard let configPath = getIkemenConfigPath() else { return }
        guard var config = parseIniFile(at: configPath) else { return }
        
        // Update values
        if config["Video"] == nil { config["Video"] = [:] }
        if config["Sound"] == nil { config["Sound"] = [:] }
        
        config["Video"]?["VSync"] = vsyncToggle?.state == .on ? "1" : "0"
        config["Video"]?["Fullscreen"] = fullscreenToggle?.state == .on ? "1" : "0"
        config["Sound"]?["MasterVolume"] = "\(volumeSlider?.intValue ?? 100)"
        
        writeIniFile(config, to: configPath)
    }
    
    private func getIkemenConfigPath() -> String? {
        // Hardcoded for now - should use EmulatorBridge.shared.workingDirectory in production
        let configPath = "/Users/davidphillips/Sites/macmame/Ikemen-GO/save/config.ini"
        return FileManager.default.fileExists(atPath: configPath) ? configPath : nil
    }
    
    private func parseIniFile(at path: String) -> [String: [String: String]]? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        
        var result: [String: [String: String]] = [:]
        var currentSection = ""
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                if result[currentSection] == nil {
                    result[currentSection] = [:]
                }
            } else if trimmed.contains("=") {
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    result[currentSection]?[key] = value
                }
            }
        }
        return result
    }
    
    private func writeIniFile(_ config: [String: [String: String]], to path: String) {
        var content = ""
        for (section, values) in config.sorted(by: { $0.key < $1.key }) {
            content += "[\(section)]\n"
            for (key, value) in values.sorted(by: { $0.key < $1.key }) {
                content += "\(key) = \(value)\n"
            }
            content += "\n"
        }
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Public Methods
    
    func updateStats(characters: Int, stages: Int, storageBytes: Int64?) {
        fightersCountLabel?.stringValue = "\(characters)"
        stagesCountLabel?.stringValue = "\(stages)"
        
        if let bytes = storageBytes {
            storageLabel?.stringValue = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } else {
            storageLabel?.stringValue = "—"
        }
    }
}

// MARK: - Dashboard Drop Zone

class DashboardDropZone: NSView {
    
    var onFilesDropped: (([URL]) -> Void)?
    
    private var isDragging = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var dashedBorderLayer: CAShapeLayer?
    private var iconView: NSImageView!
    private var label: NSTextField!
    private var subLabel: NSTextField!
    
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
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Dashed border
        let dashedBorder = CAShapeLayer()
        dashedBorder.strokeColor = DesignColors.borderDashed.cgColor
        dashedBorder.fillColor = nil
        dashedBorder.lineDashPattern = [8, 6]
        dashedBorder.lineWidth = 2
        layer?.addSublayer(dashedBorder)
        self.dashedBorderLayer = dashedBorder
        
        // Register for drag
        registerForDraggedTypes([.fileURL])
        
        // Icon
        iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "arrow.down.doc.fill", accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textTertiary
        iconView.symbolConfiguration = .init(pointSize: 32, weight: .light)
        addSubview(iconView)
        
        // Label
        label = NSTextField(labelWithString: "Drop characters or stages here")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignFonts.body(size: 16)
        label.textColor = DesignColors.textSecondary
        label.alignment = .center
        addSubview(label)
        
        // Sub-label
        subLabel = NSTextField(labelWithString: "Supports .zip, .rar, .7z archives or folders")
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.font = DesignFonts.caption(size: 12)
        subLabel.textColor = DesignColors.textTertiary
        subLabel.alignment = .center
        addSubview(subLabel)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -24),
            
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            
            subLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
        ])
    }
    
    override func layout() {
        super.layout()
        let path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 12, cornerHeight: 12, transform: nil)
        dashedBorderLayer?.path = path
        dashedBorderLayer?.frame = bounds
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if isDragging {
            dashedBorderLayer?.strokeColor = DesignColors.positive.cgColor
            layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.1).cgColor
        } else {
            dashedBorderLayer?.strokeColor = DesignColors.borderDashed.cgColor
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    // MARK: - Drag & Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasValidFiles(sender) {
            isDragging = true
            return .copy
        }
        return []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        let validURLs = urls.filter { isValidFile($0) }
        if !validURLs.isEmpty {
            onFilesDropped?(validURLs)
            return true
        }
        return false
    }
    
    private func hasValidFiles(_ info: NSDraggingInfo) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        return urls.contains { isValidFile($0) }
    }
    
    private func isValidFile(_ url: URL) -> Bool {
        let validExtensions = ["zip", "rar", "7z"]
        var isDirectory: ObjCBool = false
        
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return true
            }
            return validExtensions.contains(url.pathExtension.lowercased())
        }
        return false
    }
}
