import Cocoa

/// Dashboard view - the main landing page with stats, quick actions, and recent activity
class DashboardView: NSView {
    
    // MARK: - Callbacks
    var onLaunchGame: (() -> Void)?
    var onFilesDropped: (([URL]) -> Void)?
    var onCharactersClicked: (() -> Void)?
    var onStagesClicked: (() -> Void)?
    
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
        
        // Fighters card - clickable to navigate to Characters
        let (fightersCard, fightersLabel) = createStatCard(
            icon: "person.2.fill",
            title: "Active Fighters",
            value: "0"
        )
        fightersCountLabel = fightersLabel
        fightersCard.onClick = { [weak self] in
            print("[DashboardView] Fighters card onClick triggered")
            self?.charactersCardClicked()
        }
        cardsContainer.addArrangedSubview(fightersCard)
        
        // Stages card - clickable to navigate to Stages
        let (stagesCard, stagesLabel) = createStatCard(
            icon: "photo.fill",
            title: "Installed Stages",
            value: "0"
        )
        stagesCountLabel = stagesLabel
        stagesCard.onClick = { [weak self] in
            print("[DashboardView] Stages card onClick triggered")
            self?.stagesCardClicked()
        }
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
    
    private func createStatCard(icon: String, title: String, value: String) -> (HoverableStatCard, NSTextField) {
        let card = HoverableStatCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        card.addSubview(stack)
        
        // Icon container - w-8 h-8 rounded bg-zinc-900 border border-white/5
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = DesignColors.cardBackground.cgColor  // zinc-900 #18181b
        iconContainer.layer?.cornerRadius = 4  // rounded (not rounded-lg)
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor  // white/5
        iconContainer.identifier = NSUserInterfaceItemIdentifier("iconContainer")
        stack.addArrangedSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.textSecondary  // zinc-400, changes to white on hover
        iconView.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        iconView.identifier = NSUserInterfaceItemIdentifier("iconView")
        iconContainer.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 32),  // w-8
            iconContainer.heightAnchor.constraint(equalToConstant: 32), // h-8
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
        ])
        
        // Spacer to push value down (mb-4 = margin-bottom 16px on icon row)
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 12).isActive = true
        stack.addArrangedSubview(spacer)
        
        // Value - text-2xl (24px) font-montserrat font-semibold tracking-wider
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = DesignFonts.header(size: 24)
        valueLabel.textColor = DesignColors.textPrimary
        stack.addArrangedSubview(valueLabel)
        
        // Title - text-xs (12px) text-zinc-500
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = DesignFonts.caption(size: 12)
        titleLabel.textColor = DesignColors.textTertiary  // zinc-500
        stack.addArrangedSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),  // p-5
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20),
        ])
        
        // Add click button on top of all subviews
        card.finalizeSetup()
        
        return (card, valueLabel)
    }
    
    private func createLaunchCard() -> NSView {
        // Launch card matches CSS: glass-panel with special white icon and hover effect
        let card = HoverableLaunchCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        card.addSubview(stack)
        
        // Icon container - w-8 h-8 rounded bg-white text-zinc-950 with glow
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = NSColor.white.cgColor
        iconContainer.layer?.cornerRadius = 4
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        // shadow-[0_0_15px_rgba(255,255,255,0.15)]
        iconContainer.layer?.shadowColor = NSColor.white.cgColor
        iconContainer.layer?.shadowOpacity = 0.15
        iconContainer.layer?.shadowRadius = 15
        iconContainer.layer?.shadowOffset = .zero
        stack.addArrangedSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        iconView.contentTintColor = DesignColors.background  // zinc-950
        iconView.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        iconContainer.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 32),
            iconContainer.heightAnchor.constraint(equalToConstant: 32),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
        ])
        
        // Spacer (mt-6 in HTML)
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stack.addArrangedSubview(spacer)
        
        // Title - text-lg font-medium tracking-tight
        let titleLabel = NSTextField(labelWithString: "Launch Game")
        titleLabel.font = DesignFonts.body(size: 16)
        titleLabel.textColor = DesignColors.textPrimary
        stack.addArrangedSubview(titleLabel)
        
        // Last played - text-xs text-zinc-500
        lastPlayedLabel = NSTextField(labelWithString: "Ready to play")
        lastPlayedLabel.font = DesignFonts.caption(size: 12)
        lastPlayedLabel.textColor = DesignColors.textTertiary
        stack.addArrangedSubview(lastPlayedLabel)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20),
        ])
        
        // Add click callback to entire card
        card.onClick = { [weak self] in
            print("[DashboardView] Launch card onClick triggered")
            self?.launchButtonClicked()
        }
        
        // Add click button on top of all subviews
        card.finalizeSetup()
        
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
    
    @objc private func charactersCardClicked() {
        print("[DashboardView] charactersCardClicked - calling onCharactersClicked callback")
        onCharactersClicked?()
    }
    
    @objc private func stagesCardClicked() {
        print("[DashboardView] stagesCardClicked - calling onStagesClicked callback")
        onStagesClicked?()
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

// MARK: - Hoverable Stat Card

/// A stats card with hover effect matching CSS:
/// glass-panel p-5 rounded-lg border border-white/5 hover:border-white/10 transition-colors
class HoverableStatCard: NSView {
    
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    private var clickButton: NSButton?  // Transparent overlay for clicks
    var onClick: (() -> Void)?  // Click callback
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    private func setupClickHandler() {
        print("[HoverableStatCard] setupClickHandler called")
        // Create transparent button overlay for click handling
        let button = NSButton(frame: bounds)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.title = ""
        button.bezelStyle = .shadowlessSquare
        button.setButtonType(.momentaryChange)
        button.target = self
        button.action = #selector(buttonClicked)
        button.alphaValue = 0.001  // Nearly invisible but still clickable
        addSubview(button, positioned: .above, relativeTo: nil)  // Add on top of all subviews
        print("[HoverableStatCard] Button added ABOVE all subviews, target=\(String(describing: button.target)), action=\(String(describing: button.action))")
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        clickButton = button
    }
    
    // Call this after all subviews are added
    func finalizeSetup() {
        print("[HoverableStatCard] finalizeSetup - adding click handler on top")
        setupClickHandler()
    }
    
    @objc private func buttonClicked() {
        print("[HoverableStatCard] buttonClicked! onClick callback: \(onClick != nil ? "SET" : "NIL")")
        
        // Call the callback FIRST, before animation
        // This ensures navigation happens immediately
        let callback = onClick
        
        // Animate press/release for visual feedback
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.08)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        self.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.98, y: 0.98))
        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            self.layer?.setAffineTransform(.identity)
            CATransaction.commit()
        }
        CATransaction.commit()
        
        // Call callback on main thread to ensure UI updates happen properly
        DispatchQueue.main.async {
            print("[HoverableStatCard] Calling onClick callback")
            callback?()
        }
    }
    
    private func setupAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 8  // rounded-lg
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor  // border-white/5
        
        // Glass panel gradient: linear-gradient(180deg, rgba(255,255,255,0.03) 0%, rgba(255,255,255,0) 100%)
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor.white.withAlphaComponent(0.03).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.cornerRadius = 8
        layer?.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }
    
    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
    }
    
    private func updateAppearance(animated: Bool) {
        // Border: white/5 -> white/10 on hover (transition-colors)
        // Tailwind default: 150ms cubic-bezier(0.4, 0, 0.2, 1)
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        // Tailwind's default timing: cubic-bezier(0.4, 0, 0.2, 1)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor  // hover:border-white/10
        } else {
            layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor  // border-white/5
        }
        
        CATransaction.commit()
        
        // Also update icon color (group-hover:text-white)
        updateIconColor(animated: animated)
    }
    
    private func updateIconColor(animated: Bool) {
        // Find icon view and update its color
        guard let iconView = findSubview(withIdentifier: "iconView") as? NSImageView else { return }
        
        let newColor = isHovered ? DesignColors.textPrimary : DesignColors.textSecondary
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                iconView.contentTintColor = newColor
            }
        } else {
            iconView.contentTintColor = newColor
        }
    }
    
    private func findSubview(withIdentifier identifier: String) -> NSView? {
        for subview in subviews {
            if subview.identifier?.rawValue == identifier {
                return subview
            }
            if let found = findInSubviews(of: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
    
    private func findInSubviews(of view: NSView, identifier: String) -> NSView? {
        for subview in view.subviews {
            if subview.identifier?.rawValue == identifier {
                return subview
            }
            if let found = findInSubviews(of: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        // .assumeInside ensures mouseExited fires even if mouse was already inside when tracking started
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .assumeInside],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
}

// MARK: - Hoverable Launch Card

/// Launch card with special hover effect - adds gradient overlay on hover
/// CSS: glass-panel with bg-gradient-to-br from-white/5 to-transparent on hover
class HoverableLaunchCard: NSView {
    
    private var trackingArea: NSTrackingArea?
    private var gradientLayer: CAGradientLayer?
    private var hoverGradientLayer: CAGradientLayer?
    private var clickButton: NSButton?  // Transparent overlay for clicks
    var onClick: (() -> Void)?  // Click callback
    private var isHovered = false {
        didSet {
            updateAppearance(animated: true)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAppearance()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    private func setupClickHandler() {
        print("[HoverableLaunchCard] setupClickHandler called")
        // Create transparent button overlay for click handling
        let button = NSButton(frame: bounds)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.title = ""
        button.bezelStyle = .shadowlessSquare
        button.setButtonType(.momentaryChange)
        button.target = self
        button.action = #selector(buttonClicked)
        button.alphaValue = 0.001  // Nearly invisible but still clickable
        addSubview(button, positioned: .above, relativeTo: nil)  // Add on top of all subviews
        print("[HoverableLaunchCard] Button added ABOVE all subviews, target=\(String(describing: button.target)), action=\(String(describing: button.action))")
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        clickButton = button
    }
    
    // Call this after all subviews are added
    func finalizeSetup() {
        print("[HoverableLaunchCard] finalizeSetup - adding click handler on top")
        setupClickHandler()
    }
    
    @objc private func buttonClicked() {
        print("[HoverableLaunchCard] buttonClicked! onClick callback: \(onClick != nil ? "SET" : "NIL")")
        
        // Call the callback FIRST, before animation
        let callback = onClick
        
        // Animate press/release for visual feedback
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.08)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        self.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.98, y: 0.98))
        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            self.layer?.setAffineTransform(.identity)
            CATransaction.commit()
        }
        CATransaction.commit()
        
        // Call callback on main thread to ensure UI updates happen properly
        DispatchQueue.main.async {
            print("[HoverableLaunchCard] Calling onClick callback")
            callback?()
        }
    }
    
    private func setupAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
        
        // Base glass gradient
        let gradient = CAGradientLayer()
        gradient.colors = [
            NSColor.white.withAlphaComponent(0.03).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        gradient.locations = [0.0, 1.0]
        gradient.cornerRadius = 8
        layer?.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
        
        // Hover gradient (initially invisible)
        // bg-gradient-to-br from-white/5 to-transparent
        let hoverGrad = CAGradientLayer()
        hoverGrad.colors = [
            NSColor.white.withAlphaComponent(0.05).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ]
        hoverGrad.startPoint = CGPoint(x: 0, y: 0)
        hoverGrad.endPoint = CGPoint(x: 1, y: 1)
        hoverGrad.cornerRadius = 8
        hoverGrad.opacity = 0
        layer?.addSublayer(hoverGrad)
        hoverGradientLayer = hoverGrad
    }
    
    override func layout() {
        super.layout()
        gradientLayer?.frame = bounds
        hoverGradientLayer?.frame = bounds
    }
    
    private func updateAppearance(animated: Bool) {
        // Tailwind default: 150ms cubic-bezier(0.4, 0, 0.2, 1)
        let duration = animated ? 0.15 : 0.0
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        // Tailwind's default timing: cubic-bezier(0.4, 0, 0.2, 1)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1))
        
        if isHovered {
            layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
            hoverGradientLayer?.opacity = 1.0
        } else {
            layer?.borderColor = NSColor.white.withAlphaComponent(0.05).cgColor
            hoverGradientLayer?.opacity = 0.0
        }
        
        CATransaction.commit()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        
        // .assumeInside ensures mouseExited fires even if mouse was already inside when tracking started
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect, .assumeInside],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
}
