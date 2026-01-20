import Cocoa

// MARK: - Dashed Border View

/// Custom view that draws a dashed border
class DashedBorderView: NSView {
    override var wantsUpdateLayer: Bool { true }
    
    private var dashedBorderLayer: CAShapeLayer?
    
    override func layout() {
        super.layout()
        updateDashedBorder()
    }
    
    private func updateDashedBorder() {
        dashedBorderLayer?.removeFromSuperlayer()
        
        let borderLayer = CAShapeLayer()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        borderLayer.path = path.cgPath
        borderLayer.strokeColor = DesignColors.borderDashed.cgColor
        borderLayer.fillColor = nil
        borderLayer.lineDashPattern = [6, 4]
        borderLayer.lineWidth = 1
        
        layer?.addSublayer(borderLayer)
        dashedBorderLayer = borderLayer
    }
}

// MARK: - NSBezierPath Extension

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        return path
    }
}

/// Import mode determines how IKEMEN Lab interacts with existing content
public enum ImportMode: String, Codable {
    /// Full automation: normalize names, organize folders, manage select.def
    case freshStart = "freshStart"
    /// Read-only indexing; all modifications are opt-in and reversible
    case existingSetup = "existingSetup"
}

/// First Run Experience (FRE) overlay view
/// Guides new users through setting up IKEMEN Lab with their IKEMEN GO installation
class FirstRunView: NSView {
    
    // MARK: - Properties
    
    private var currentStep: Int = 1
    private var selectedFolderPath: URL?
    private var isValidated: Bool = false
    private var selectedImportMode: ImportMode = .freshStart
    
    // Main container
    private var cardView: NSView!
    private var backgroundGradient: CAGradientLayer!
    
    // Progress dots
    private var progressDots: [NSView] = []
    private var skipButton: NSButton!
    
    // Step containers
    private var stepContainers: [NSView] = []
    
    // Step 3 specific
    private var dropZone: NSView!
    private var successState: NSView!
    private var pathTextField: NSTextField!
    private var continueButton: NSButton!
    private var dropZoneContainer: NSView!
    private var dropZoneHeightConstraint: NSLayoutConstraint!
    
    // Step 4 specific (Content Detection)
    private var scanningSpinner: NSProgressIndicator?
    private var scanningLabel: NSTextField?
    private var statsGrid: NSView?
    private var messageLabel: NSTextField?
    private var step4ContinueButton: NSButton?
    private var charactersValueLabel: NSTextField?
    private var stagesValueLabel: NSTextField?
    private var screenpacksValueLabel: NSTextField?
    
    private var detectionStats: (characters: Int, stages: Int, screenpacks: Int)?
    
    // Step 5 specific (Import Mode Choice)
    private var importModeContainer: NSView?
    private var freshStartOption: NSView?
    private var existingSetupOption: NSView?
    private var freshStartIconView: NSImageView?
    private var freshStartCheckContainer: NSView?
    private var freshStartCheckIcon: NSImageView?
    private var existingSetupIconView: NSImageView?
    private var existingSetupCheckContainer: NSView?
    private var existingSetupCheckIcon: NSImageView?
    
    // Callbacks
    var onComplete: ((URL, ImportMode) -> Void)?
    var onSkip: (() -> Void)?
    
    // MARK: - Constants
    
    private let cardWidth: CGFloat = 520
    private let animationDuration: CGFloat = 0.3
    
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
        
        // Semi-transparent black overlay with blur effect
        layer?.backgroundColor = DesignColors.overlayDim.cgColor
        
        setupCard()
        setupProgressHeader()
        setupSteps()
        
        // Start at step 1
        showStep(1, animated: false)
    }
    
    // MARK: - Card Setup
    
    private func setupCard() {
        cardView = NSView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = DesignColors.background.cgColor
        cardView.layer?.cornerRadius = 16
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = DesignColors.borderHover.cgColor
        cardView.layer?.shadowColor = DesignColors.overlayDim.cgColor
        cardView.layer?.shadowOpacity = 0.5
        cardView.layer?.shadowOffset = CGSize(width: 0, height: -10)
        cardView.layer?.shadowRadius = 40
        addSubview(cardView)
        
        // Background decorative gradient
        backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [
            DesignColors.overlayHighlight.cgColor,
            NSColor.clear.cgColor
        ]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.startPoint = CGPoint(x: 0.5, y: 1)
        backgroundGradient.endPoint = CGPoint(x: 0.5, y: 0)
        cardView.layer?.addSublayer(backgroundGradient)
        
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: cardWidth),
        ])
    }
    
    override func layout() {
        super.layout()
        backgroundGradient.frame = CGRect(x: 0, y: cardView.bounds.height - 256, width: cardView.bounds.width, height: 256)
    }
    
    // MARK: - Progress Header
    
    private func setupProgressHeader() {
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(headerView)
        
        // Progress dots
        let dotsStack = NSStackView()
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        dotsStack.orientation = .horizontal
        dotsStack.spacing = 8
        headerView.addSubview(dotsStack)
        
        for i in 1...6 {
            let dot = NSView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = (i == 1 ? DesignColors.textPrimary : DesignColors.textDisabled).cgColor
            dotsStack.addArrangedSubview(dot)
            progressDots.append(dot)
            
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
        }
        
        // Skip button
        skipButton = NSButton(title: "Skip for now", target: self, action: #selector(skipClicked))
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.isBordered = false
        skipButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        skipButton.contentTintColor = DesignColors.textTertiary
        headerView.addSubview(skipButton)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: cardView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 64),
            
            dotsStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 32),
            dotsStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            skipButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -32),
            skipButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ])
    }
    
    // MARK: - Steps Setup
    
    private func setupSteps() {
        setupStep1()
        setupStep2()
        setupStep3()
        setupStep4()
        setupStep5()  // Import Mode Choice (shown only when content detected)
        setupStep6()  // Ready / Success
    }
    
    // MARK: - Step 1: Welcome
    
    private func setupStep1() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = false
        cardView.addSubview(container)
        stepContainers.append(container)
        
        // App Icon
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 16
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.borderHover.cgColor
        
        let iconGradient = CAGradientLayer()
        iconGradient.colors = [DesignColors.panelBackground.cgColor, DesignColors.background.cgColor]
        iconGradient.startPoint = CGPoint(x: 0, y: 0)
        iconGradient.endPoint = CGPoint(x: 1, y: 1)
        iconGradient.cornerRadius = 16
        iconContainer.layer?.insertSublayer(iconGradient, at: 0)
        container.addSubview(iconContainer)
        
        // Flask icon (using SF Symbol)
        let iconImageView = NSImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        if let flaskImage = NSImage(systemSymbolName: "flask", accessibilityDescription: "Flask") {
            let config = NSImage.SymbolConfiguration(pointSize: 40, weight: .light)
            iconImageView.image = flaskImage.withSymbolConfiguration(config)
        }
        iconImageView.contentTintColor = DesignColors.textOnAccent
        iconContainer.addSubview(iconImageView)
        
        // Green dot indicator
        let greenDot = NSView()
        greenDot.translatesAutoresizingMaskIntoConstraints = false
        greenDot.wantsLayer = true
        greenDot.layer?.cornerRadius = 6
        greenDot.layer?.backgroundColor = DesignColors.positive.cgColor
        greenDot.layer?.borderWidth = 2
        greenDot.layer?.borderColor = DesignColors.background.cgColor
        iconContainer.addSubview(greenDot)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Welcome to IKEMEN Lab")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.header(size: 24)
        titleLabel.textColor = DesignColors.textPrimary
        titleLabel.alignment = .center
        container.addSubview(titleLabel)
        
        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "The easiest way to manage your IKEMEN GO characters, stages, and screenpacks directly on your Mac.")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        descLabel.textColor = DesignColors.textSecondary
        descLabel.alignment = .center
        container.addSubview(descLabel)
        
        // Get Started button
        let getStartedButton = createPrimaryButton(title: "Get Started", action: #selector(step1Continue))
        container.addSubview(getStartedButton)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 64),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -32),
            container.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40),
            
            iconContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            iconContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 80),
            iconContainer.heightAnchor.constraint(equalToConstant: 80),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            greenDot.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: -4),
            greenDot.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 4),
            greenDot.widthAnchor.constraint(equalToConstant: 12),
            greenDot.heightAnchor.constraint(equalToConstant: 12),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            
            getStartedButton.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 32),
            getStartedButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            getStartedButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            getStartedButton.heightAnchor.constraint(equalToConstant: 40),
            getStartedButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        
        // Update gradient frame after layout
        DispatchQueue.main.async {
            iconGradient.frame = iconContainer.bounds
        }
    }
    
    // MARK: - Step 2: Install Check
    
    private func setupStep2() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        cardView.addSubview(container)
        stepContainers.append(container)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "First, you'll need IKEMEN GO")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.header(size: 20)
        titleLabel.textColor = DesignColors.textPrimary
        container.addSubview(titleLabel)
        
        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "IKEMEN Lab manages content for the IKEMEN GO engine. Do you have the game installed on this Mac?")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        descLabel.textColor = DesignColors.textSecondary
        container.addSubview(descLabel)
        
        // Options stack
        let optionsStack = NSStackView()
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.orientation = .vertical
        optionsStack.spacing = 12
        container.addSubview(optionsStack)
        
        // Option 1: I already have it
        let option1 = createOptionButton(
            icon: "externaldrive.badge.checkmark",
            title: "I already have it",
            subtitle: "I have the Ikemen_GO folder",
            showChevron: true,
            action: #selector(step2AlreadyHaveIt)
        )
        optionsStack.addArrangedSubview(option1)
        
        // Option 2: Download IKEMEN GO
        let option2 = createOptionButton(
            icon: "icloud.and.arrow.down",
            title: "Download IKEMEN GO",
            subtitle: "Get the latest release from GitHub",
            showChevron: false,
            isExternalLink: true,
            action: #selector(step2Download)
        )
        optionsStack.addArrangedSubview(option2)
        
        // Footer with Back and Continue
        let footerStack = NSStackView()
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerStack.orientation = .horizontal
        footerStack.distribution = .equalSpacing
        container.addSubview(footerStack)
        
        let backButton = createTextButton(title: "← Back", action: #selector(goBackToStep1))
        footerStack.addArrangedSubview(backButton)
        
        let continueWhenInstalledButton = createTextButton(title: "Continue when installed", action: #selector(step2AlreadyHaveIt))
        continueWhenInstalledButton.contentTintColor = DesignColors.textSecondary
        footerStack.addArrangedSubview(continueWhenInstalledButton)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 64),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -32),
            container.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            optionsStack.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 24),
            optionsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            footerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            footerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            footerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
    
    // MARK: - Step 3: Location
    
    private func setupStep3() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        cardView.addSubview(container)
        stepContainers.append(container)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Where is IKEMEN GO installed?")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.header(size: 20)
        titleLabel.textColor = DesignColors.textPrimary
        container.addSubview(titleLabel)
        
        // Description with code span
        let descLabel = NSTextField(labelWithString: "")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        let descAttr = NSMutableAttributedString(string: "Locate your ")
        descAttr.append(NSAttributedString(string: "Ikemen_GO_MacOS", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: DesignColors.textSecondary,
            .backgroundColor: DesignColors.overlayHighlightStrong
        ]))
        descAttr.append(NSAttributedString(string: " folder."))
        descAttr.addAttributes([
            .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: DesignColors.textSecondary
        ], range: NSRange(location: 0, length: 12))
        descAttr.addAttributes([
            .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: DesignColors.textSecondary
        ], range: NSRange(location: descAttr.length - 8, length: 8))
        descLabel.attributedStringValue = descAttr
        container.addSubview(descLabel)
        
        // Drop zone container
        dropZoneContainer = NSView()
        dropZoneContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(dropZoneContainer)
        
        // Drop zone
        dropZone = createDropZone()
        dropZoneContainer.addSubview(dropZone)
        
        // Success state
        successState = createSuccessState()
        successState.isHidden = true
        dropZoneContainer.addSubview(successState)
        
        // Manual path input
        let pathContainer = NSView()
        pathContainer.translatesAutoresizingMaskIntoConstraints = false
        pathContainer.wantsLayer = true
        pathContainer.layer?.cornerRadius = 8
        pathContainer.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        pathContainer.layer?.borderWidth = 1
        pathContainer.layer?.borderColor = DesignColors.borderSubtle.cgColor
        container.addSubview(pathContainer)
        
        let pathIcon = NSImageView()
        pathIcon.translatesAutoresizingMaskIntoConstraints = false
        if let driveImage = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil) {
            pathIcon.image = driveImage
        }
        pathIcon.contentTintColor = DesignColors.textDisabled
        pathContainer.addSubview(pathIcon)
        
        pathTextField = NSTextField()
        pathTextField.translatesAutoresizingMaskIntoConstraints = false
        pathTextField.placeholderString = "/Users/username/Games/Ikemen-GO"
        pathTextField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        pathTextField.textColor = DesignColors.textSecondary
        pathTextField.backgroundColor = .clear
        pathTextField.isBordered = false
        pathTextField.focusRingType = .none
        pathTextField.target = self
        pathTextField.action = #selector(pathTextChanged)
        pathContainer.addSubview(pathTextField)
        
        // Footer
        let footerStack = NSStackView()
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerStack.orientation = .horizontal
        footerStack.distribution = .equalSpacing
        container.addSubview(footerStack)
        
        let backButton = createTextButton(title: "← Back", action: #selector(goBackToStep2))
        footerStack.addArrangedSubview(backButton)
        
        continueButton = NSButton(title: "Continue", target: self, action: #selector(step3Continue))
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.bezelStyle = .rounded
        continueButton.isBordered = false
        continueButton.wantsLayer = true
        continueButton.layer?.cornerRadius = 8
        continueButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
        continueButton.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        continueButton.contentTintColor = DesignColors.textTertiary
        continueButton.isEnabled = false
        footerStack.addArrangedSubview(continueButton)
        
        dropZoneHeightConstraint = dropZoneContainer.heightAnchor.constraint(equalToConstant: 160)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 64),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -32),
            container.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            dropZoneContainer.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 24),
            dropZoneContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dropZoneContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dropZoneHeightConstraint,
            
            dropZone.topAnchor.constraint(equalTo: dropZoneContainer.topAnchor),
            dropZone.leadingAnchor.constraint(equalTo: dropZoneContainer.leadingAnchor),
            dropZone.trailingAnchor.constraint(equalTo: dropZoneContainer.trailingAnchor),
            dropZone.bottomAnchor.constraint(equalTo: dropZoneContainer.bottomAnchor),
            
            successState.topAnchor.constraint(equalTo: dropZoneContainer.topAnchor),
            successState.leadingAnchor.constraint(equalTo: dropZoneContainer.leadingAnchor),
            successState.trailingAnchor.constraint(equalTo: dropZoneContainer.trailingAnchor),
            successState.heightAnchor.constraint(equalToConstant: 80),
            
            pathContainer.topAnchor.constraint(equalTo: dropZoneContainer.bottomAnchor, constant: 24),
            pathContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pathContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pathContainer.heightAnchor.constraint(equalToConstant: 36),
            
            pathIcon.leadingAnchor.constraint(equalTo: pathContainer.leadingAnchor, constant: 12),
            pathIcon.centerYAnchor.constraint(equalTo: pathContainer.centerYAnchor),
            pathIcon.widthAnchor.constraint(equalToConstant: 14),
            pathIcon.heightAnchor.constraint(equalToConstant: 14),
            
            pathTextField.leadingAnchor.constraint(equalTo: pathIcon.trailingAnchor, constant: 8),
            pathTextField.trailingAnchor.constraint(equalTo: pathContainer.trailingAnchor, constant: -12),
            pathTextField.centerYAnchor.constraint(equalTo: pathContainer.centerYAnchor),
            
            footerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            footerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            footerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            continueButton.widthAnchor.constraint(equalToConstant: 100),
            continueButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }
    
    private func createDropZone() -> NSView {
        let zone = DashedBorderView()
        zone.translatesAutoresizingMaskIntoConstraints = false
        zone.wantsLayer = true
        zone.layer?.cornerRadius = 12
        zone.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.3).cgColor
        
        // Icon
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 24
        iconContainer.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        zone.addSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let folderImage = NSImage(systemSymbolName: "folder.badge.questionmark", accessibilityDescription: nil) {
            iconView.image = folderImage
        }
        iconView.contentTintColor = DesignColors.textSecondary
        iconContainer.addSubview(iconView)
        
        // Labels
        let mainLabel = NSTextField(labelWithString: "Click to browse or drag folder here")
        mainLabel.translatesAutoresizingMaskIntoConstraints = false
        mainLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        mainLabel.textColor = DesignColors.textPrimary
        zone.addSubview(mainLabel)
        
        let subLabel = NSTextField(labelWithString: "Usually in /Applications/Ikemen-GO/")
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subLabel.textColor = DesignColors.textTertiary
        zone.addSubview(subLabel)
        
        // Click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(dropZoneClicked))
        zone.addGestureRecognizer(clickGesture)
        
        // Register for drag
        zone.registerForDraggedTypes([.fileURL])
        
        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: zone.centerXAnchor),
            iconContainer.topAnchor.constraint(equalTo: zone.topAnchor, constant: 32),
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            mainLabel.centerXAnchor.constraint(equalTo: zone.centerXAnchor),
            mainLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            
            subLabel.centerXAnchor.constraint(equalTo: zone.centerXAnchor),
            subLabel.topAnchor.constraint(equalTo: mainLabel.bottomAnchor, constant: 4),
        ])
        
        return zone
    }
    
    private func createSuccessState() -> NSView {
        let state = NSView()
        state.translatesAutoresizingMaskIntoConstraints = false
        state.wantsLayer = true
        state.layer?.cornerRadius = 12
        state.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        state.layer?.borderWidth = 1
        state.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.3).cgColor
        
        // Checkmark icon
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.1).cgColor
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.2).cgColor
        state.addSubview(iconContainer)
        
        let checkIcon = NSImageView()
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        if let checkImage = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) {
            checkIcon.image = checkImage
        }
        checkIcon.contentTintColor = DesignColors.positive
        iconContainer.addSubview(checkIcon)
        
        // Path label
        let pathLabel = NSTextField(labelWithString: "/Applications/Ikemen-GO/")
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        pathLabel.textColor = DesignColors.textPrimary
        pathLabel.tag = 100 // For updating later
        state.addSubview(pathLabel)
        
        // Status row
        let statusStack = NSStackView()
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.orientation = .horizontal
        statusStack.spacing = 12
        state.addSubview(statusStack)
        
        // Validated indicator
        let validatedStack = NSStackView()
        validatedStack.orientation = .horizontal
        validatedStack.spacing = 4
        
        let greenDot = NSView()
        greenDot.translatesAutoresizingMaskIntoConstraints = false
        greenDot.wantsLayer = true
        greenDot.layer?.cornerRadius = 3
        greenDot.layer?.backgroundColor = DesignColors.positive.cgColor
        validatedStack.addArrangedSubview(greenDot)
        
        let validatedLabel = NSTextField(labelWithString: "Validated")
        validatedLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        validatedLabel.textColor = DesignColors.textSecondary
        validatedStack.addArrangedSubview(validatedLabel)
        statusStack.addArrangedSubview(validatedStack)
        
        // Version label (will be updated with detected version)
        let versionLabel = NSTextField(labelWithString: "")
        versionLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        versionLabel.textColor = DesignColors.textTertiary
        versionLabel.tag = 101 // For updating later with detected version
        statusStack.addArrangedSubview(versionLabel)
        
        // Close button
        let closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Remove")!, target: self, action: #selector(resetFolderSelection))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.contentTintColor = DesignColors.textTertiary
        state.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: state.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: state.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
            
            checkIcon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 24),
            checkIcon.heightAnchor.constraint(equalToConstant: 24),
            
            pathLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            pathLabel.topAnchor.constraint(equalTo: state.topAnchor, constant: 20),
            
            statusStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            statusStack.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 6),
            
            greenDot.widthAnchor.constraint(equalToConstant: 6),
            greenDot.heightAnchor.constraint(equalToConstant: 6),
            
            closeButton.trailingAnchor.constraint(equalTo: state.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: state.centerYAnchor),
        ])
        
        return state
    }
    
    // MARK: - Step 4: Content Detection
    
    private func setupStep4() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        cardView.addSubview(container)
        stepContainers.append(container)
        
        // Icon
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 24
        iconContainer.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        container.addSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let magnifyImage = NSImage(systemSymbolName: "magnifyingglass.circle.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .light)
            iconView.image = magnifyImage.withSymbolConfiguration(config)
        }
        iconView.contentTintColor = DesignColors.textSecondary
        iconContainer.addSubview(iconView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Library Detected")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.header(size: 20)
        titleLabel.textColor = DesignColors.textPrimary
        container.addSubview(titleLabel)
        
        // Scanning state label
        let label = NSTextField(labelWithString: "Scanning your library...")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = DesignColors.textSecondary
        container.addSubview(label)
        scanningLabel = label
        
        // Spinner
        let spinner = NSProgressIndicator()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        container.addSubview(spinner)
        scanningSpinner = spinner
        
        // Stats grid (initially hidden)
        let statsGridView = NSView()
        statsGridView.translatesAutoresizingMaskIntoConstraints = false
        statsGridView.isHidden = true
        container.addSubview(statsGridView)
        statsGrid = statsGridView
        
        // Create 3 stat cards
        let charComponents = createStatCard(icon: "person.fill", label: "Characters", value: "0")
        charactersValueLabel = charComponents.label
        
        let stageComponents = createStatCard(icon: "mountain.2.fill", label: "Stages", value: "0")
        stagesValueLabel = stageComponents.label
        
        let screenpackComponents = createStatCard(icon: "paintbrush.fill", label: "Screenpacks", value: "0")
        screenpacksValueLabel = screenpackComponents.label
        
        let statsStack = NSStackView(views: [charComponents.view, stageComponents.view, screenpackComponents.view])
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsStack.orientation = .horizontal
        statsStack.distribution = .fillEqually
        statsStack.spacing = 12
        statsGridView.addSubview(statsStack)
        
        // Message label (for edge cases)
        let msgLabel = NSTextField(labelWithString: "")
        msgLabel.translatesAutoresizingMaskIntoConstraints = false
        msgLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        msgLabel.textColor = DesignColors.textSecondary
        msgLabel.alignment = .center
        msgLabel.isHidden = true
        container.addSubview(msgLabel)
        messageLabel = msgLabel
        
        // Continue button
        let continueBtn = createPrimaryButton(title: "Continue", action: #selector(step4Continue))
        continueBtn.isEnabled = false
        container.addSubview(continueBtn)
        step4ContinueButton = continueBtn
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 64),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -32),
            container.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40),
            
            iconContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            iconContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 64),
            iconContainer.heightAnchor.constraint(equalToConstant: 64),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            spinner.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            statsGridView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            statsGridView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statsGridView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            statsStack.topAnchor.constraint(equalTo: statsGridView.topAnchor),
            statsStack.leadingAnchor.constraint(equalTo: statsGridView.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: statsGridView.trailingAnchor),
            statsStack.bottomAnchor.constraint(equalTo: statsGridView.bottomAnchor),
            
            msgLabel.topAnchor.constraint(equalTo: statsGridView.bottomAnchor, constant: 16),
            msgLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            msgLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            continueBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            continueBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            continueBtn.heightAnchor.constraint(equalToConstant: 40),
            continueBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
    
    private func createStatCard(icon: String, label: String, value: String) -> (view: NSView, label: NSTextField) {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 12
        card.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = DesignColors.borderSubtle.cgColor
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            iconView.image = image
        }
        iconView.contentTintColor = DesignColors.textTertiary
        card.addSubview(iconView)
        
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = DesignFonts.stat(size: 28)
        valueLabel.textColor = DesignColors.textPrimary
        valueLabel.alignment = .center
        card.addSubview(valueLabel)
        
        let labelField = NSTextField(labelWithString: label)
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        labelField.textColor = DesignColors.textSecondary
        labelField.alignment = .center
        card.addSubview(labelField)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 120),
            
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            
            labelField.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            labelField.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            labelField.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
        ])
        
        return (card, valueLabel)
    }
    
    // MARK: - Step 5: Import Mode Choice
    
    private func setupStep5() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        cardView.addSubview(container)
        stepContainers.append(container)
        importModeContainer = container
        
        // Icon
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 24
        iconContainer.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        container.addSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let gearImage = NSImage(systemSymbolName: "gearshape.2.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .light)
            iconView.image = gearImage.withSymbolConfiguration(config)
        }
        iconView.contentTintColor = DesignColors.textSecondary
        iconContainer.addSubview(iconView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "How should we manage this?")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.header(size: 20)
        titleLabel.textColor = DesignColors.textPrimary
        container.addSubview(titleLabel)
        
        // Description
        let descLabel = NSTextField(wrappingLabelWithString: "We found an existing library. Choose how IKEMEN Lab should work with your content.")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        descLabel.textColor = DesignColors.textSecondary
        descLabel.alignment = .center
        container.addSubview(descLabel)
        
        // Options stack
        let optionsStack = NSStackView()
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.orientation = .vertical
        optionsStack.spacing = 12
        container.addSubview(optionsStack)
        
        // Option 1: Fresh Start (full automation)
        let freshStartComponents = createImportModeCard(
            icon: "wand.and.stars",
            title: "Fresh Start",
            subtitle: "Full automation — organize folders, normalize names",
            isSelected: true,
            action: #selector(selectFreshStartMode)
        )
        freshStartOption = freshStartComponents.card
        freshStartIconView = freshStartComponents.iconView
        freshStartCheckContainer = freshStartComponents.checkContainer
        freshStartCheckIcon = freshStartComponents.checkIcon
        optionsStack.addArrangedSubview(freshStartComponents.card)
        
        // Option 2: Existing Setup (preserve everything)
        let existingSetupComponents = createImportModeCard(
            icon: "shield.checkered",
            title: "Preserve My Setup",
            subtitle: "Read-only indexing — no changes without permission",
            isSelected: false,
            action: #selector(selectExistingSetupMode)
        )
        existingSetupOption = existingSetupComponents.card
        existingSetupIconView = existingSetupComponents.iconView
        existingSetupCheckContainer = existingSetupComponents.checkContainer
        existingSetupCheckIcon = existingSetupComponents.checkIcon
        optionsStack.addArrangedSubview(existingSetupComponents.card)
        
        // Info note
        let infoLabel = NSTextField(wrappingLabelWithString: "You can change this later in Settings.")
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        infoLabel.textColor = DesignColors.textTertiary
        infoLabel.alignment = .center
        container.addSubview(infoLabel)
        
        // Continue button
        let continueBtn = createPrimaryButton(title: "Continue", action: #selector(step5Continue))
        container.addSubview(continueBtn)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 64),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -32),
            container.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40),
            
            iconContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            iconContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 56),
            iconContainer.heightAnchor.constraint(equalToConstant: 56),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            optionsStack.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 24),
            optionsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            infoLabel.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 16),
            infoLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            infoLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            continueBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            continueBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            continueBtn.heightAnchor.constraint(equalToConstant: 40),
            continueBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
    
    private func createImportModeCard(icon: String, title: String, subtitle: String, isSelected: Bool, action: Selector) -> (card: NSView, iconView: NSImageView, checkContainer: NSView, checkIcon: NSImageView) {
        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 2
        
        if isSelected {
            card.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
            card.layer?.borderColor = DesignColors.borderStrong.cgColor
        } else {
            card.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.3).cgColor
            card.layer?.borderColor = DesignColors.borderHover.cgColor
        }
        
        // Icon container
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.backgroundColor = DesignColors.inputBackground.cgColor
        card.addSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            iconView.image = image
        }
        iconView.contentTintColor = isSelected ? DesignColors.textOnAccent : DesignColors.textSecondary
        iconContainer.addSubview(iconView)
        
        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = DesignColors.textPrimary
        card.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = DesignColors.textTertiary
        card.addSubview(subtitleLabel)
        
        // Selection indicator (checkmark)
        let checkContainer = NSView()
        checkContainer.translatesAutoresizingMaskIntoConstraints = false
        checkContainer.wantsLayer = true
        checkContainer.layer?.cornerRadius = 10
        checkContainer.layer?.borderWidth = 2
        
        if isSelected {
            checkContainer.layer?.backgroundColor = DesignColors.textOnAccent.cgColor
            checkContainer.layer?.borderColor = DesignColors.textOnAccent.cgColor
        } else {
            checkContainer.layer?.backgroundColor = NSColor.clear.cgColor
            checkContainer.layer?.borderColor = DesignColors.textDisabled.cgColor
        }
        card.addSubview(checkContainer)
        
        let checkIcon = NSImageView()
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        if let checkImage = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            checkIcon.image = checkImage.withSymbolConfiguration(config)
        }
        checkIcon.contentTintColor = DesignColors.iconOnLightSurface
        checkIcon.isHidden = !isSelected
        checkContainer.addSubview(checkIcon)
        
        // Click gesture
        let click = NSClickGestureRecognizer(target: self, action: action)
        card.addGestureRecognizer(click)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 72),
            
            iconContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: checkContainer.leadingAnchor, constant: -12),
            
            checkContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            checkContainer.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            checkContainer.widthAnchor.constraint(equalToConstant: 20),
            checkContainer.heightAnchor.constraint(equalToConstant: 20),
            
            checkIcon.centerXAnchor.constraint(equalTo: checkContainer.centerXAnchor),
            checkIcon.centerYAnchor.constraint(equalTo: checkContainer.centerYAnchor),
        ])
        
        return (card, iconView, checkContainer, checkIcon)
    }
    
    private func updateImportModeSelection(freshStart: Bool) {
        // Update Fresh Start card
        if let card = freshStartOption {
            card.layer?.backgroundColor = freshStart
                ? DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
                : DesignColors.cardBackground.withAlphaComponent(0.3).cgColor
            card.layer?.borderColor = freshStart ? DesignColors.borderStrong.cgColor : DesignColors.borderHover.cgColor
        }
        freshStartIconView?.contentTintColor = freshStart ? DesignColors.textOnAccent : DesignColors.textSecondary
        freshStartCheckContainer?.layer?.backgroundColor = freshStart ? DesignColors.textOnAccent.cgColor : NSColor.clear.cgColor
        freshStartCheckContainer?.layer?.borderColor = freshStart ? DesignColors.textOnAccent.cgColor : DesignColors.textDisabled.cgColor
        freshStartCheckIcon?.isHidden = !freshStart
        
        // Update Existing Setup card
        if let card = existingSetupOption {
            card.layer?.backgroundColor = !freshStart
                ? DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
                : DesignColors.cardBackground.withAlphaComponent(0.3).cgColor
            card.layer?.borderColor = !freshStart ? DesignColors.borderStrong.cgColor : DesignColors.borderHover.cgColor
        }
        existingSetupIconView?.contentTintColor = !freshStart ? DesignColors.textOnAccent : DesignColors.textSecondary
        existingSetupCheckContainer?.layer?.backgroundColor = !freshStart ? DesignColors.textOnAccent.cgColor : NSColor.clear.cgColor
        existingSetupCheckContainer?.layer?.borderColor = !freshStart ? DesignColors.textOnAccent.cgColor : DesignColors.textDisabled.cgColor
        existingSetupCheckIcon?.isHidden = freshStart
    }
    
    // MARK: - Step 6: Ready
    
    private func setupStep6() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        cardView.addSubview(container)
        stepContainers.append(container)
        
        // Party icon
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 40
        iconContainer.layer?.backgroundColor = DesignColors.positive.withAlphaComponent(0.1).cgColor
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.positive.withAlphaComponent(0.2).cgColor
        container.addSubview(iconContainer)
        
        let partyIcon = NSImageView()
        partyIcon.translatesAutoresizingMaskIntoConstraints = false
        if let partyImage = NSImage(systemSymbolName: "party.popper", accessibilityDescription: nil) {
            partyIcon.image = partyImage
        }
        partyIcon.contentTintColor = DesignColors.positive
        iconContainer.addSubview(partyIcon)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "You're all set!")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.header(size: 24)
        titleLabel.textColor = DesignColors.textPrimary
        titleLabel.alignment = .center
        container.addSubview(titleLabel)
        
        // Description
        let descLabel = NSTextField(labelWithString: "IKEMEN Lab is now synced with your installation.")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        descLabel.textColor = DesignColors.textSecondary
        descLabel.alignment = .center
        container.addSubview(descLabel)
        
        // Tips card
        let tipsCard = NSView()
        tipsCard.translatesAutoresizingMaskIntoConstraints = false
        tipsCard.wantsLayer = true
        tipsCard.layer?.cornerRadius = 12
        tipsCard.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.5).cgColor
        tipsCard.layer?.borderWidth = 1
        tipsCard.layer?.borderColor = DesignColors.borderSubtle.cgColor
        container.addSubview(tipsCard)
        
        let tipsStack = NSStackView()
        tipsStack.translatesAutoresizingMaskIntoConstraints = false
        tipsStack.orientation = .vertical
        tipsStack.alignment = .leading
        tipsStack.spacing = 12
        tipsCard.addSubview(tipsStack)
        
        let tips = [
            ("Drag & Drop ", "ZIP files anywhere to install content"),
            ("Manage your ", "select.def visually without coding"),
            ("Launch the game ", "directly from the dashboard")
        ]
        
        for (bold, regular) in tips {
            let tipRow = createTipRow(boldText: bold, regularText: regular)
            tipsStack.addArrangedSubview(tipRow)
        }
        
        // Open Dashboard button
        let openDashboardButton = createPrimaryButton(title: "Open Dashboard", action: #selector(completeFRE))
        container.addSubview(openDashboardButton)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 64),
            container.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -32),
            container.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -40),
            
            iconContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            iconContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 80),
            iconContainer.heightAnchor.constraint(equalToConstant: 80),
            
            partyIcon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            partyIcon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            partyIcon.widthAnchor.constraint(equalToConstant: 40),
            partyIcon.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            descLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            
            tipsCard.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 32),
            tipsCard.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tipsCard.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            tipsStack.topAnchor.constraint(equalTo: tipsCard.topAnchor, constant: 16),
            tipsStack.leadingAnchor.constraint(equalTo: tipsCard.leadingAnchor, constant: 16),
            tipsStack.trailingAnchor.constraint(equalTo: tipsCard.trailingAnchor, constant: -16),
            tipsStack.bottomAnchor.constraint(equalTo: tipsCard.bottomAnchor, constant: -16),
            
            openDashboardButton.topAnchor.constraint(equalTo: tipsCard.bottomAnchor, constant: 32),
            openDashboardButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            openDashboardButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            openDashboardButton.heightAnchor.constraint(equalToConstant: 40),
            openDashboardButton.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
    }
    
    // MARK: - Helper Methods
    
    private func createPrimaryButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.layer?.backgroundColor = DesignColors.buttonPrimary.cgColor
        button.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        button.contentTintColor = DesignColors.buttonPrimaryText
        
        // Add shadow
        button.layer?.shadowColor = DesignColors.textPrimary.cgColor
        button.layer?.shadowOpacity = 0.1
        button.layer?.shadowOffset = CGSize(width: 0, height: 0)
        button.layer?.shadowRadius = 20
        
        return button
    }
    
    private func createTextButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.contentTintColor = DesignColors.textTertiary
        return button
    }
    
    private func createOptionButton(icon: String, title: String, subtitle: String, showChevron: Bool, isExternalLink: Bool = false, action: Selector) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.2).cgColor
        container.layer?.borderWidth = 1
        container.layer?.borderColor = DesignColors.borderHover.cgColor
        
        // Icon container
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.backgroundColor = DesignColors.cardBackground.cgColor
        iconContainer.layer?.borderWidth = 1
        iconContainer.layer?.borderColor = DesignColors.borderHover.cgColor
        container.addSubview(iconContainer)
        
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            iconView.image = image
        }
        iconView.contentTintColor = DesignColors.textSecondary
        iconContainer.addSubview(iconView)
        
        // Labels
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = DesignColors.textPrimary
        container.addSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = DesignColors.textTertiary
        container.addSubview(subtitleLabel)
        
        // Chevron or external link icon
        let trailingIcon = NSImageView()
        trailingIcon.translatesAutoresizingMaskIntoConstraints = false
        let trailingIconName = isExternalLink ? "arrow.up.right.square" : "chevron.right"
        if let image = NSImage(systemSymbolName: trailingIconName, accessibilityDescription: nil) {
            trailingIcon.image = image
        }
        trailingIcon.contentTintColor = DesignColors.textDisabled
        container.addSubview(trailingIcon)
        
        // Click gesture
        let click = NSClickGestureRecognizer(target: self, action: action)
        container.addGestureRecognizer(click)
        
        // Tracking for hover
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: container,
            userInfo: ["container": container]
        )
        container.addTrackingArea(trackingArea)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 72),
            
            iconContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            
            trailingIcon.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            trailingIcon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            trailingIcon.widthAnchor.constraint(equalToConstant: 16),
            trailingIcon.heightAnchor.constraint(equalToConstant: 16),
        ])
        
        return container
    }
    
    private func createTipRow(boldText: String, regularText: String) -> NSView {
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        
        // Checkmark icon
        let checkIcon = NSImageView()
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        if let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil) {
            checkIcon.image = image
        }
        checkIcon.contentTintColor = DesignColors.textTertiary
        row.addArrangedSubview(checkIcon)
        
        // Text
        let textLabel = NSTextField(labelWithString: "")
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        let attr = NSMutableAttributedString(string: boldText, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: DesignColors.textPrimary
        ])
        attr.append(NSAttributedString(string: regularText, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: DesignColors.textSecondary
        ]))
        textLabel.attributedStringValue = attr
        row.addArrangedSubview(textLabel)
        
        NSLayoutConstraint.activate([
            checkIcon.widthAnchor.constraint(equalToConstant: 18),
            checkIcon.heightAnchor.constraint(equalToConstant: 18),
        ])
        
        return row
    }
    
    // MARK: - Navigation
    
    private func showStep(_ step: Int, animated: Bool) {
        currentStep = step
        
        // Update dots
        for (index, dot) in progressDots.enumerated() {
            let isActive = index < step
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animated ? animationDuration : 0
                dot.layer?.backgroundColor = (isActive ? DesignColors.textPrimary : DesignColors.textDisabled).cgColor
            }
        }
        
        // Hide all containers, show current
        for (index, container) in stepContainers.enumerated() {
            let shouldShow = index == step - 1
            
            if animated && shouldShow {
                container.alphaValue = 0
                container.isHidden = false
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = animationDuration
                    container.animator().alphaValue = 1
                }
            } else {
                container.isHidden = !shouldShow
                container.alphaValue = shouldShow ? 1 : 0
            }
        }
    }
    
    private func updateContinueButton(enabled: Bool) {
        continueButton.isEnabled = enabled
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            if enabled {
                continueButton.layer?.backgroundColor = DesignColors.buttonPrimary.cgColor
                continueButton.contentTintColor = DesignColors.buttonPrimaryText
            } else {
                continueButton.layer?.backgroundColor = DesignColors.buttonSecondaryBackground.cgColor
                continueButton.contentTintColor = DesignColors.textTertiary
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func skipClicked() {
        onSkip?()
        dismissWithAnimation()
    }
    
    @objc private func step1Continue() {
        showStep(2, animated: true)
    }
    
    @objc private func goBackToStep1() {
        showStep(1, animated: true)
    }
    
    @objc private func step2AlreadyHaveIt() {
        showStep(3, animated: true)
    }
    
    @objc private func step2Download() {
        // Open GitHub releases page
        if let url = URL(string: "https://github.com/ikemen-engine/Ikemen-GO/releases") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func goBackToStep2() {
        showStep(2, animated: true)
    }
    
    @objc private func dropZoneClicked() {
        // Open folder picker
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your IKEMEN GO installation folder"
        panel.prompt = "Select"
        
        // Try to start at common locations
        if FileManager.default.fileExists(atPath: "/Applications/Ikemen-GO") {
            panel.directoryURL = URL(fileURLWithPath: "/Applications/Ikemen-GO")
        } else {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        }
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.validateFolder(url)
            }
        }
    }
    
    @objc private func pathTextChanged() {
        let path = pathTextField.stringValue.trimmingCharacters(in: .whitespaces)
        if !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            validateFolder(url)
        }
    }
    
    @objc private func resetFolderSelection() {
        isValidated = false
        selectedFolderPath = nil
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            self.successState.animator().alphaValue = 0
            self.dropZoneHeightConstraint.constant = 160
            self.dropZoneContainer.superview?.layoutSubtreeIfNeeded()
        } completionHandler: { [weak self] in
            self?.successState.isHidden = true
            self?.successState.alphaValue = 1
            self?.dropZone.isHidden = false
        }
        
        updateContinueButton(enabled: false)
        pathTextField.stringValue = ""
    }
    
    @objc private func step3Continue() {
        guard isValidated, let folderPath = selectedFolderPath else { return }
        showStep(4, animated: true)
        
        // Start content detection scan
        performContentScan(at: folderPath)
    }
    
    @objc private func step4Continue() {
        // If content was detected, show import mode choice (step 5)
        // If empty, skip to success (step 6)
        if let stats = detectionStats, (stats.characters > 0 || stats.stages > 0) {
            showStep(5, animated: true)
        } else {
            // Empty installation - default to fresh start mode
            selectedImportMode = .freshStart
            showStep(6, animated: true)
        }
    }
    
    @objc private func selectFreshStartMode() {
        selectedImportMode = .freshStart
        updateImportModeSelection(freshStart: true)
    }
    
    @objc private func selectExistingSetupMode() {
        selectedImportMode = .existingSetup
        updateImportModeSelection(freshStart: false)
    }
    
    @objc private func step5Continue() {
        showStep(6, animated: true)
    }
    
    @objc private func completeFRE() {
        guard let folderPath = selectedFolderPath else {
            onSkip?()
            dismissWithAnimation()
            return
        }
        
        onComplete?(folderPath, selectedImportMode)
        dismissWithAnimation()
    }
    
    // MARK: - Validation
    
    private func validateFolder(_ url: URL) {
        let fm = FileManager.default
        
        // Check for required files/folders
        let requiredItems = [
            "Ikemen_GO_MacOS",
            "data",
            "chars"
        ]
        
        var isValid = true
        for item in requiredItems {
            let itemPath = url.appendingPathComponent(item).path
            if !fm.fileExists(atPath: itemPath) {
                isValid = false
                break
            }
        }
        
        if isValid {
            selectedFolderPath = url
            isValidated = true
            
            // Update success state
            if let pathLabel = successState.viewWithTag(100) as? NSTextField {
                pathLabel.stringValue = url.path
            }
            
            // Try to detect version
            let version = detectVersion(at: url)
            if let versionLabel = successState.viewWithTag(101) as? NSTextField {
                versionLabel.stringValue = version.isEmpty ? "Version detected" : "\(version) detected"
            }
            
            // Show success state and shrink container
            dropZone.isHidden = true
            successState.isHidden = false
            successState.alphaValue = 0
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.allowsImplicitAnimation = true
                self.dropZoneHeightConstraint.constant = 80
                self.dropZoneContainer.superview?.layoutSubtreeIfNeeded()
                self.successState.animator().alphaValue = 1
            }
            
            updateContinueButton(enabled: true)
            pathTextField.stringValue = url.path
        } else {
            // Show error (invalid folder)
            let alert = NSAlert()
            alert.messageText = "Invalid IKEMEN GO Folder"
            alert.informativeText = "The selected folder doesn't appear to be a valid IKEMEN GO installation. Please select a folder containing Ikemen_GO_MacOS, data, and chars folders."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    private func detectVersion(at url: URL) -> String {
        // Try to detect version from various sources
        // Check README or other files that might contain version info
        let readmePath = url.appendingPathComponent("README.md")
        if let content = try? String(contentsOf: readmePath, encoding: .utf8) {
            // Look for version pattern
            if let range = content.range(of: "v\\d+\\.\\d+\\.\\d+", options: .regularExpression) {
                return String(content[range])
            }
        }
        
        return "v0.99.x"
    }
    
    // MARK: - Content Detection
    
    private func performContentScan(at url: URL) {
        // Show scanning UI
        scanningLabel?.stringValue = "Scanning your library..."
        scanningLabel?.isHidden = false
        scanningSpinner?.isHidden = false
        scanningSpinner?.startAnimation(nil)
        
        // Use properties instead of tags
        
        // Perform scan on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fm = FileManager.default
            var characterCount = 0
            var stageCount = 0
            var screenpackCount = 0
            
            // Scan characters
            let charsPath = url.appendingPathComponent("chars")
            if let charDirs = try? fm.contentsOfDirectory(at: charsPath, includingPropertiesForKeys: [.isDirectoryKey]) {
                for charDir in charDirs {
                    var isDirectory: ObjCBool = false
                    if fm.fileExists(atPath: charDir.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        // Check for .def file
                        if let contents = try? fm.contentsOfDirectory(at: charDir, includingPropertiesForKeys: nil) {
                            let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
                            if !defFiles.isEmpty {
                                characterCount += 1
                            }
                        }
                    }
                }
            }
            
            // Scan stages
            let stagesPath = url.appendingPathComponent("stages")
            if let stageItems = try? fm.contentsOfDirectory(at: stagesPath, includingPropertiesForKeys: [.isDirectoryKey]) {
                for item in stageItems {
                    // Check if it's a .def file at top level
                    if item.pathExtension.lowercased() == "def" {
                        stageCount += 1
                    }
                    
                    // Check if it's a directory - look for .def files inside
                    var isDirectory: ObjCBool = false
                    if fm.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        if let subItems = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) {
                            for subItem in subItems where subItem.pathExtension.lowercased() == "def" {
                                stageCount += 1
                            }
                        }
                    }
                }
            }
            
            // Scan screenpacks
            let dataPath = url.appendingPathComponent("data")
            if let dataDirs = try? fm.contentsOfDirectory(at: dataPath, includingPropertiesForKeys: [.isDirectoryKey]) {
                for dir in dataDirs {
                    var isDirectory: ObjCBool = false
                    if fm.fileExists(atPath: dir.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        // Look for system.def in the directory
                        let systemDef = dir.appendingPathComponent("system.def")
                        if fm.fileExists(atPath: systemDef.path) {
                            screenpackCount += 1
                        }
                    }
                }
                
                // Also check for system.def directly in data/ (default screenpack)
                let defaultSystemDef = dataPath.appendingPathComponent("system.def")
                if fm.fileExists(atPath: defaultSystemDef.path) {
                    screenpackCount += 1
                }
            }
            
            // Store results
            self.detectionStats = (characterCount, stageCount, screenpackCount)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.updateContentDetectionUI(characters: characterCount, stages: stageCount, screenpacks: screenpackCount)
            }
        }
    }
    
    private func updateContentDetectionUI(characters: Int, stages: Int, screenpacks: Int) {
        // Hide scanning UI
        scanningLabel?.isHidden = true
        scanningSpinner?.stopAnimation(nil)
        scanningSpinner?.isHidden = true
        
        // Show stats grid
        statsGrid?.isHidden = false
        
        // Update stat values
        charactersValueLabel?.stringValue = "\(characters)"
        stagesValueLabel?.stringValue = "\(stages)"
        screenpacksValueLabel?.stringValue = "\(screenpacks)"
        
        // Show appropriate message
        if let messageLabel = messageLabel {
            messageLabel.isHidden = false
            
            if characters == 0 && stages == 0 {
                // Empty installation
                messageLabel.stringValue = "Ready to build your library!"
                messageLabel.textColor = DesignColors.textSecondary
            } else if characters >= 100 {
                // Large library
                messageLabel.stringValue = "Nice collection! IKEMEN Lab will index everything."
                messageLabel.textColor = DesignColors.positive
            } else {
                // Normal case - show summary
                messageLabel.stringValue = "Found \(characters) character\(characters == 1 ? "" : "s"), \(stages) stage\(stages == 1 ? "" : "s"), \(screenpacks) screenpack\(screenpacks == 1 ? "" : "s")"
                messageLabel.textColor = DesignColors.textSecondary
            }
        }
        
        // Enable continue button
        if let continueBtn = step4ContinueButton {
            continueBtn.isEnabled = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                continueBtn.layer?.backgroundColor = DesignColors.buttonPrimary.cgColor
                continueBtn.contentTintColor = DesignColors.buttonPrimaryText
            }
        }
    }
    
    // MARK: - Animation
    
    private func dismissWithAnimation() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            self.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.removeFromSuperview()
        }
    }
}

// MARK: - Drag and Drop Support

extension FirstRunView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if currentStep == 3 {
            // Highlight drop zone
            dropZone.layer?.borderColor = DesignColors.positive.cgColor
            dropZone.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.6).cgColor
            return .copy
        }
        return []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        if currentStep == 3 {
            dropZone.layer?.borderColor = DesignColors.borderHover.cgColor
            dropZone.layer?.backgroundColor = DesignColors.cardBackground.withAlphaComponent(0.3).cgColor
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard currentStep == 3 else { return false }
        
        let pasteboard = sender.draggingPasteboard
        
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                validateFolder(url)
                return true
            }
        }
        
        return false
    }
}
