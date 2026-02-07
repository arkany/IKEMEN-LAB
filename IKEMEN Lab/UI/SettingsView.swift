import Cocoa

/// Helper class to handle app settings toggle callbacks with closures.
/// Retained via associated objects on the toggle control.
private class AppToggleHandler: NSObject {
    static var associatedKey: UInt8 = 0
    
    let getValue: () -> Bool
    let setValue: (Bool) -> Void
    
    init(getValue: @escaping () -> Bool, setValue: @escaping (Bool) -> Void) {
        self.getValue = getValue
        self.setValue = setValue
    }
    
    @objc func toggleChanged(_ sender: NSSwitch) {
        setValue(sender.state == .on)
    }
}

/// Self-contained settings view for IKEMEN GO configuration.
/// Manages video, audio, appearance, advanced, and maintenance settings.
class SettingsView: NSView {
    
    /// Reference to the main area view, used to look up volume slider labels.
    weak var parentView: NSView?
    
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
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        addSubview(scrollView)
        
        // Use a flipped view so content starts at the top
        let contentView = FlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView
        
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 32
        stackView.alignment = .leading
        contentView.addSubview(stackView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = DesignFonts.header(size: 32)
        titleLabel.textColor = DesignColors.textPrimary
        stackView.addArrangedSubview(titleLabel)
        
        // Video Settings Section
        let videoSection = createSettingsSection(title: "Video", settings: [
            createResolutionSetting(),
            createToggleSetting(label: "Fullscreen", key: "Fullscreen", section: "Video"),
            createToggleSetting(label: "VSync", key: "VSync", section: "Video"),
            createToggleSetting(label: "Borderless", key: "Borderless", section: "Video"),
        ])
        stackView.addArrangedSubview(videoSection)
        
        // Audio Settings Section
        let audioSection = createSettingsSection(title: "Audio", settings: [
            createVolumeSetting(label: "Master Volume", key: "MasterVolume"),
            createVolumeSetting(label: "Music Volume", key: "BGMVolume"),
            createVolumeSetting(label: "Sound Effects", key: "WavVolume"),
        ])
        stackView.addArrangedSubview(audioSection)
        
        // Appearance Section
        let appearanceSection = createSettingsSection(title: "Appearance", settings: [
            createAppToggleSetting(
                label: "Light Mode",
                description: "Switch between dark and light theme",
                getValue: { AppSettings.shared.useLightTheme },
                setValue: { AppSettings.shared.useLightTheme = $0 }
            ),
        ])
        stackView.addArrangedSubview(appearanceSection)
        
        // Advanced Features Section
        let advancedSection = createSettingsSection(title: "Advanced", settings: [
            createAppToggleSetting(
                label: "EXPERIMENTAL: Create Stage from PNG",
                description: "Enable creating stages from PNG images (experimental feature)",
                getValue: { AppSettings.shared.enablePNGStageCreation },
                setValue: { AppSettings.shared.enablePNGStageCreation = $0 }
            ),
        ])
        stackView.addArrangedSubview(advancedSection)
        
        // Maintenance Section
        let maintenanceSection = createSettingsSection(title: "Maintenance", settings: [
            createButtonSetting(
                label: "Image Cache",
                buttonTitle: "Clear Cache",
                description: "Clears cached character portraits and stage previews. Use if images appear outdated.",
                action: #selector(clearImageCache(_:))
            ),
        ])
        stackView.addArrangedSubview(maintenanceSection)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
    
    // MARK: - Section Builder
    
    private func createSettingsSection(title: String, settings: [NSView]) -> NSView {
        let section = NSStackView()
        section.orientation = .vertical
        section.spacing = 16
        section.alignment = .leading
        
        let sectionTitle = NSTextField(labelWithString: title)
        sectionTitle.font = DesignFonts.header(size: 20)
        sectionTitle.textColor = DesignColors.textSecondary
        section.addArrangedSubview(sectionTitle)
        
        for setting in settings {
            section.addArrangedSubview(setting)
        }
        
        return section
    }
    
    // MARK: - Setting Row Builders
    
    private func createResolutionSetting() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let label = NSTextField(labelWithString: "Resolution")
        label.font = DesignFonts.body(size: 16)
        label.textColor = DesignColors.textPrimary
        label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(label)
        
        let popup = NSPopUpButton()
        popup.addItems(withTitles: [
            "640×480 (4:3 SD)",
            "1280×720 (720p HD)",
            "1920×1080 (1080p Full HD)",
            "2560×1440 (1440p QHD)",
        ])
        popup.tag = 1000
        popup.target = self
        popup.action = #selector(resolutionChanged(_:))
        
        // Load current value
        if let config = IkemenConfigManager.shared.loadConfig(),
           let width = config["Video"]?["GameWidth"],
           let height = config["Video"]?["GameHeight"] {
            let resString = "\(width)×\(height)"
            for (index, title) in popup.itemTitles.enumerated() {
                if title.hasPrefix(resString) {
                    popup.selectItem(at: index)
                    break
                }
            }
        }
        
        row.addArrangedSubview(popup)
        return row
    }
    
    private func createToggleSetting(label: String, key: String, section: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 16)
        labelField.textColor = DesignColors.textPrimary
        labelField.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(labelField)
        
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = #selector(toggleSettingChanged(_:))
        toggle.identifier = NSUserInterfaceItemIdentifier("\(section).\(key)")
        
        // Load current value
        if let config = IkemenConfigManager.shared.loadConfig(),
           let value = config[section]?[key] {
            toggle.state = value == "1" ? .on : .off
        }
        
        row.addArrangedSubview(toggle)
        return row
    }
    
    private func createVolumeSetting(label: String, key: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 16)
        labelField.textColor = DesignColors.textPrimary
        labelField.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(labelField)
        
        let slider = NSSlider()
        slider.minValue = 0
        slider.maxValue = 100
        slider.intValue = 100
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        slider.target = self
        slider.action = #selector(volumeSliderChanged(_:))
        slider.identifier = NSUserInterfaceItemIdentifier("Sound.\(key)")
        
        // Load current value
        if let config = IkemenConfigManager.shared.loadConfig(),
           let value = config["Sound"]?[key],
           let intValue = Int(value) {
            slider.intValue = Int32(intValue)
        }
        
        let valueLabel = NSTextField(labelWithString: "\(slider.intValue)%")
        valueLabel.font = DesignFonts.body(size: 14)
        valueLabel.textColor = DesignColors.textSecondary
        valueLabel.widthAnchor.constraint(equalToConstant: 50).isActive = true
        valueLabel.identifier = NSUserInterfaceItemIdentifier("Sound.\(key).label")
        
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }
    
    private func createAppToggleSetting(label: String, description: String, getValue: @escaping () -> Bool, setValue: @escaping (Bool) -> Void) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 4
        container.alignment = .leading
        
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 16)
        labelField.textColor = DesignColors.textPrimary
        labelField.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addArrangedSubview(labelField)
        
        let toggle = NSSwitch()
        toggle.state = getValue() ? .on : .off
        
        // Create a wrapper to handle the toggle action
        let handler = AppToggleHandler(getValue: getValue, setValue: setValue)
        toggle.target = handler
        toggle.action = #selector(AppToggleHandler.toggleChanged(_:))
        objc_setAssociatedObject(toggle, &AppToggleHandler.associatedKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        row.addArrangedSubview(toggle)
        container.addArrangedSubview(row)
        
        // Add description label
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = DesignColors.textSecondary
        container.addArrangedSubview(descLabel)
        
        return container
    }
    
    private func createButtonSetting(label: String, buttonTitle: String, description: String, action: Selector) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 4
        container.alignment = .leading
        
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 16
        row.alignment = .centerY
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = DesignFonts.body(size: 16)
        labelField.textColor = DesignColors.textPrimary
        labelField.widthAnchor.constraint(equalToConstant: 200).isActive = true
        row.addArrangedSubview(labelField)
        
        let button = NSButton(title: buttonTitle, target: self, action: action)
        button.bezelStyle = .rounded
        row.addArrangedSubview(button)
        
        container.addArrangedSubview(row)
        
        // Add description label
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = DesignColors.textSecondary
        container.addArrangedSubview(descLabel)
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func resolutionChanged(_ sender: NSPopUpButton) {
        let resolutions = [(640, 480), (1280, 720), (1920, 1080), (2560, 1440)]
        let selected = resolutions[sender.indexOfSelectedItem]
        IkemenConfigManager.shared.saveValue(section: "Video", key: "GameWidth", value: "\(selected.0)")
        IkemenConfigManager.shared.saveValue(section: "Video", key: "GameHeight", value: "\(selected.1)")
    }
    
    @objc private func toggleSettingChanged(_ sender: NSSwitch) {
        guard let id = sender.identifier?.rawValue else { return }
        let parts = id.split(separator: ".")
        guard parts.count == 2 else { return }
        let section = String(parts[0])
        let key = String(parts[1])
        IkemenConfigManager.shared.saveValue(section: section, key: key, value: sender.state == .on ? "1" : "0")
    }
    
    @objc private func volumeSliderChanged(_ sender: NSSlider) {
        guard let id = sender.identifier?.rawValue else { return }
        let parts = id.split(separator: ".")
        guard parts.count == 2 else { return }
        let section = String(parts[0])
        let key = String(parts[1])
        
        // Update label — look in the parent view hierarchy
        let labelId = NSUserInterfaceItemIdentifier("\(section).\(key).label")
        let lookupView = parentView ?? self
        if let label = lookupView.viewWithIdentifier(labelId) as? NSTextField {
            label.stringValue = "\(sender.intValue)%"
        }
        
        IkemenConfigManager.shared.saveValue(section: section, key: key, value: "\(sender.intValue)")
    }
    
    @objc private func clearImageCache(_ sender: NSButton) {
        ImageCache.shared.clear()
        
        let alert = NSAlert()
        alert.messageText = "Cache Cleared"
        alert.informativeText = "The image cache has been cleared. Character portraits and stage previews will be reloaded."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        NotificationCenter.default.post(name: NSNotification.Name("ImageCacheCleared"), object: nil)
    }
}
