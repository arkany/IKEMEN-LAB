import AppKit

/// Custom About window showing app info and update status
final class AboutWindowController: NSWindowController {
    
    // MARK: - UI Elements
    
    private let iconImageView = NSImageView()
    private let appNameLabel = NSTextField(labelWithString: "")
    private let versionLabel = NSTextField(labelWithString: "")
    private let updateStatusLabel = NSTextField(labelWithString: "")
    private let updateSpinner = NSProgressIndicator()
    private let checkUpdateButton = NSButton()
    private let copyrightLabel = NSTextField(labelWithString: "")
    private let creditsButton = NSButton()
    private let githubButton = NSButton()
    
    // MARK: - Initialization
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "About IKEMEN Lab"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = DesignColors.cardBackground
        window.center()
        
        self.init(window: window)
        setupUI()
        loadInfo()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        
        // Container stack
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .centerX
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // App Icon
        iconImageView.image = NSApp.applicationIconImage
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // App Name
        appNameLabel.font = DesignFonts.header(size: 22)
        appNameLabel.textColor = DesignColors.textPrimary
        appNameLabel.alignment = .center
        
        // Version
        versionLabel.font = DesignFonts.body(size: 13)
        versionLabel.textColor = DesignColors.textSecondary
        versionLabel.alignment = .center
        
        // Update Status Row
        let updateStack = NSStackView()
        updateStack.orientation = .horizontal
        updateStack.spacing = 8
        updateStack.alignment = .centerY
        
        updateSpinner.style = .spinning
        updateSpinner.controlSize = .small
        updateSpinner.isHidden = true
        
        updateStatusLabel.font = DesignFonts.caption(size: 12)
        updateStatusLabel.textColor = DesignColors.textTertiary
        updateStatusLabel.alignment = .center
        
        updateStack.addArrangedSubview(updateSpinner)
        updateStack.addArrangedSubview(updateStatusLabel)
        
        // Check for Updates Button
        checkUpdateButton.title = "Check for Updates"
        checkUpdateButton.bezelStyle = .rounded
        checkUpdateButton.font = DesignFonts.body(size: 12)
        checkUpdateButton.target = self
        checkUpdateButton.action = #selector(checkForUpdates)
        
        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        
        // Copyright
        copyrightLabel.font = DesignFonts.caption(size: 11)
        copyrightLabel.textColor = DesignColors.textDisabled
        copyrightLabel.alignment = .center
        
        // Buttons row
        let buttonsStack = NSStackView()
        buttonsStack.orientation = .horizontal
        buttonsStack.spacing = 16
        
        creditsButton.title = "Acknowledgments"
        creditsButton.bezelStyle = .accessoryBarAction
        creditsButton.isBordered = false
        creditsButton.font = DesignFonts.caption(size: 11)
        creditsButton.contentTintColor = DesignColors.textSecondary
        creditsButton.target = self
        creditsButton.action = #selector(showCredits)
        
        githubButton.title = "GitHub"
        githubButton.bezelStyle = .accessoryBarAction
        githubButton.isBordered = false
        githubButton.font = DesignFonts.caption(size: 11)
        githubButton.contentTintColor = DesignColors.textSecondary
        githubButton.target = self
        githubButton.action = #selector(openGitHub)
        
        buttonsStack.addArrangedSubview(creditsButton)
        buttonsStack.addArrangedSubview(githubButton)
        
        // Add to main stack
        mainStack.addArrangedSubview(iconImageView)
        mainStack.addArrangedSubview(appNameLabel)
        mainStack.addArrangedSubview(versionLabel)
        mainStack.setCustomSpacing(16, after: versionLabel)
        mainStack.addArrangedSubview(updateStack)
        mainStack.addArrangedSubview(checkUpdateButton)
        mainStack.setCustomSpacing(24, after: checkUpdateButton)
        mainStack.addArrangedSubview(spacer)
        mainStack.addArrangedSubview(copyrightLabel)
        mainStack.setCustomSpacing(8, after: copyrightLabel)
        mainStack.addArrangedSubview(buttonsStack)
        
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 96),
            iconImageView.heightAnchor.constraint(equalToConstant: 96),
            
            spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 8)
        ])
    }
    
    private func loadInfo() {
        let bundle = Bundle.main
        
        // App name
        appNameLabel.stringValue = bundle.infoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle.infoDictionary?["CFBundleName"] as? String
            ?? "IKEMEN Lab"
        
        // Version
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        versionLabel.stringValue = "Version \(version) (\(build))"
        
        // Copyright
        copyrightLabel.stringValue = bundle.infoDictionary?["NSHumanReadableCopyright"] as? String
            ?? "© 2024 IKEMEN Lab"
        
        // Initial update status
        updateStatusLabel.stringValue = ""
        
        // Check for update status in background
        checkUpdateStatusSilently()
    }
    
    // MARK: - Update Checking
    
    private func checkUpdateStatusSilently() {
        Task { @MainActor in
            updateStatusLabel.stringValue = "Checking for updates…"
            updateSpinner.isHidden = false
            updateSpinner.startAnimation(nil)
            
            let result = await UpdateChecker.shared.checkForUpdates()
            
            updateSpinner.stopAnimation(nil)
            updateSpinner.isHidden = true
            
            switch result {
            case .updateAvailable(let release):
                updateStatusLabel.stringValue = "Update available: v\(release.version)"
                updateStatusLabel.textColor = DesignColors.positive
                checkUpdateButton.title = "Download Update"
                
            case .upToDate:
                updateStatusLabel.stringValue = "✓ You're up to date"
                updateStatusLabel.textColor = DesignColors.textTertiary
                
            case .error:
                updateStatusLabel.stringValue = "Unable to check for updates"
                updateStatusLabel.textColor = DesignColors.textDisabled
            }
        }
    }
    
    @objc private func checkForUpdates() {
        // If update is available, the button should download it
        if checkUpdateButton.title == "Download Update" {
            Task { @MainActor in
                let result = await UpdateChecker.shared.checkForUpdates()
                if case .updateAvailable(let release) = result {
                    if let dmgAsset = release.dmgAsset,
                       let url = URL(string: dmgAsset.browserDownloadUrl) {
                        NSWorkspace.shared.open(url)
                    } else if let url = URL(string: release.htmlUrl) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else {
            // Otherwise, check for updates
            checkUpdateStatusSilently()
        }
    }
    
    // MARK: - Actions
    
    @objc private func showCredits() {
        let alert = NSAlert()
        alert.messageText = "Acknowledgments"
        alert.informativeText = """
            IKEMEN Lab is built with:
            
            • IKEMEN GO — The open-source fighting game engine
            • GRDB.swift — SQLite toolkit by Gwendal Roué
            • Montserrat, Manrope, Inter — Open source fonts
            
            Special thanks to the MUGEN and IKEMEN communities.
            """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/arkany/IKEMEN-LAB") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Show Window
    
    func showAboutWindow() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
