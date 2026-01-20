import Cocoa

// MARK: - Toast Type

enum ToastType {
    case success
    case error
    case info
    
    var iconName: String {
        switch self {
        case .success: return "checkmark"
        case .error: return "xmark"
        case .info: return "info"
        }
    }
    
    var iconColor: NSColor {
        switch self {
        case .success: return DesignColors.positive
        case .error: return DesignColors.negative
        case .info: return DesignColors.info
        }
    }
}

// MARK: - Toast View

class ToastNotificationView: NSView {
    
    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var closeButton: NSButton!
    private var actionButton: NSButton?
    
    var onDismiss: (() -> Void)?
    var onAction: (() -> Void)?
    
    private let toastType: ToastType
    private let title: String
    private let subtitle: String?
    private let actionTitle: String?
    
    init(type: ToastType, title: String, subtitle: String? = nil, actionTitle: String? = nil) {
        self.toastType = type
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        
        // Background: theme-aware with border
        layer?.backgroundColor = DesignColors.toastBackground.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = DesignColors.toastBorder.cgColor
        
        // Shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.4
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        layer?.shadowRadius = 12
        
        // Icon container (circle with icon)
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 12
        iconContainer.layer?.borderWidth = 2
        iconContainer.layer?.borderColor = toastType.iconColor.cgColor
        addSubview(iconContainer)
        
        // Icon
        iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        iconView.image = NSImage(systemSymbolName: toastType.iconName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        iconView.contentTintColor = toastType.iconColor
        iconContainer.addSubview(iconView)
        
        // Title
        titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = DesignFonts.body(size: 14)
        titleLabel.textColor = DesignColors.textPrimary
        addSubview(titleLabel)
        
        // Subtitle (optional)
        if let subtitle = subtitle {
            subtitleLabel = NSTextField(labelWithString: subtitle)
            subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
            subtitleLabel.font = DesignFonts.caption(size: 13)
            subtitleLabel.textColor = DesignColors.textTertiary
            subtitleLabel.maximumNumberOfLines = 2
            subtitleLabel.lineBreakMode = .byWordWrapping
            addSubview(subtitleLabel)
        }
        
        // Action button (optional)
        if let actionTitle = actionTitle {
            actionButton = NSButton(title: actionTitle, target: self, action: #selector(actionTapped))
            actionButton!.translatesAutoresizingMaskIntoConstraints = false
            actionButton!.bezelStyle = .inline
            actionButton!.isBordered = false
            actionButton!.font = DesignFonts.body(size: 13)
            actionButton!.contentTintColor = DesignColors.positive
            addSubview(actionButton!)
        }
        
        // Close button
        closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.contentTintColor = DesignColors.textTertiary
        closeButton.target = self
        closeButton.action = #selector(dismissTapped)
        addSubview(closeButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // Icon container
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 24),
            iconContainer.heightAnchor.constraint(equalToConstant: 24),
            
            // Icon centered in container
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            // Close button
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),
        ])
        
        // Action button layout (if present)
        if let actionButton = actionButton {
            NSLayoutConstraint.activate([
                actionButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
                actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -12).isActive = true
        } else {
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -12).isActive = true
        }
        
        titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12).isActive = true
        
        if let subtitleLabel = subtitleLabel {
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
                subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
                subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            ])
        } else {
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
    }
    
    @objc private func actionTapped() {
        onAction?()
        onDismiss?()
    }
    
    @objc private func dismissTapped() {
        onDismiss?()
    }
}

// MARK: - Toast Manager

class ToastManager {
    
    static let shared = ToastManager()
    
    private var currentToast: ToastNotificationView?
    private var dismissTimer: Timer?
    private weak var parentView: NSView?
    
    private init() {}
    
    func setParentView(_ view: NSView) {
        self.parentView = view
    }
    
    func showSuccess(title: String, subtitle: String? = nil, duration: TimeInterval = 4.0, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        show(type: .success, title: title, subtitle: subtitle, duration: duration, actionTitle: actionTitle, action: action)
    }
    
    func showError(title: String, subtitle: String? = nil, duration: TimeInterval = 6.0) {
        show(type: .error, title: title, subtitle: subtitle, duration: duration, actionTitle: nil, action: nil)
    }
    
    func showInfo(title: String, subtitle: String? = nil, duration: TimeInterval = 4.0) {
        show(type: .info, title: title, subtitle: subtitle, duration: duration, actionTitle: nil, action: nil)
    }
    
    private func show(type: ToastType, title: String, subtitle: String?, duration: TimeInterval, actionTitle: String?, action: (() -> Void)?) {
        guard let parent = parentView else {
            NSLog("ToastManager: No parent view set")
            return
        }
        
        // Dismiss any existing toast
        dismissCurrentToast(animated: false)
        
        // Create new toast
        let toast = ToastNotificationView(type: type, title: title, subtitle: subtitle, actionTitle: actionTitle)
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.alphaValue = 0
        toast.onDismiss = { [weak self] in
            self?.dismissCurrentToast(animated: true)
        }
        toast.onAction = action
        
        parent.addSubview(toast)
        currentToast = toast
        
        // Position: top-right with padding, starting off-screen
        let toastWidth: CGFloat = actionTitle != nil ? 420 : 360  // Wider if action button present
        let toastHeight: CGFloat = subtitle != nil ? 72 : 52
        
        NSLayoutConstraint.activate([
            toast.topAnchor.constraint(equalTo: parent.topAnchor, constant: 16),
            toast.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -16),
            toast.widthAnchor.constraint(equalToConstant: toastWidth),
            toast.heightAnchor.constraint(greaterThanOrEqualToConstant: toastHeight),
        ])
        
        // Initial position (off-screen to the right)
        toast.layer?.transform = CATransform3DMakeTranslation(toastWidth + 20, 0, 0)
        
        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            toast.animator().alphaValue = 1
            toast.animator().layer?.transform = CATransform3DIdentity
        }
        
        // Auto-dismiss timer
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismissCurrentToast(animated: true)
        }
    }
    
    private func dismissCurrentToast(animated: Bool) {
        guard let toast = currentToast else { return }
        
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                toast.animator().alphaValue = 0
                toast.animator().layer?.transform = CATransform3DMakeTranslation(380, 0, 0)
            }, completionHandler: {
                toast.removeFromSuperview()
            })
        } else {
            toast.removeFromSuperview()
        }
        
        currentToast = nil
    }
}
