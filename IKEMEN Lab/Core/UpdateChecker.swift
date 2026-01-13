import Foundation
import Cocoa

/// Checks GitHub releases for app updates
final class UpdateChecker {
    
    static let shared = UpdateChecker()
    
    // MARK: - Configuration
    
    /// GitHub repository in "owner/repo" format
    private let githubRepo = "arkany/ikemen-lab"  
    
    /// How often to auto-check (24 hours)
    private let autoCheckInterval: TimeInterval = 86400
    
    /// UserDefaults keys
    private enum Keys {
        static let lastCheckDate = "UpdateChecker.lastCheckDate"
        static let skippedVersion = "UpdateChecker.skippedVersion"
    }
    
    // MARK: - Types
    
    struct Release: Codable {
        let tagName: String
        let name: String
        let htmlUrl: String
        let body: String?
        let publishedAt: String?
        let prerelease: Bool
        let assets: [Asset]
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlUrl = "html_url"
            case body
            case publishedAt = "published_at"
            case prerelease
            case assets
        }
        
        struct Asset: Codable {
            let name: String
            let browserDownloadUrl: String
            let size: Int
            
            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
                case size
            }
        }
        
        /// Extracts version number from tag (removes 'v' prefix if present)
        var version: String {
            tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        }
        
        /// Finds the DMG asset if available
        var dmgAsset: Asset? {
            assets.first { $0.name.lowercased().hasSuffix(".dmg") }
        }
    }
    
    enum UpdateResult {
        case updateAvailable(Release)
        case upToDate
        case error(Error)
    }
    
    enum UpdateError: LocalizedError {
        case invalidResponse
        case noReleasesFound
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from GitHub"
            case .noReleasesFound:
                return "No releases found"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Current app version from bundle
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    
    /// Check for updates (async)
    func checkForUpdates() async -> UpdateResult {
        do {
            let release = try await fetchLatestRelease()
            
            // Include pre-releases during early development
            // TODO: Add user preference to opt-in/out of pre-releases later
            
            if isNewer(release.version, than: currentVersion) {
                return .updateAvailable(release)
            } else {
                return .upToDate
            }
        } catch {
            return .error(error)
        }
    }
    
    /// Check for updates and show UI (for menu action)
    func checkForUpdatesInteractively() {
        Task { @MainActor in
            // Show progress window
            let progressWindow = UpdateProgressWindow()
            progressWindow.show()
            
            // Perform check
            let result = await checkForUpdates()
            
            // Record check time
            UserDefaults.standard.set(Date(), forKey: Keys.lastCheckDate)
            
            // Hide progress window
            progressWindow.close()
            
            // Show results
            switch result {
            case .updateAvailable(let release):
                showUpdateAlert(for: release)
                
            case .upToDate:
                showUpToDateAlert()
                
            case .error(let error):
                showErrorAlert(error)
            }
        }
    }
    
    /// Check silently on app launch (respects auto-check interval)
    func checkOnLaunchIfNeeded() {
        let lastCheck = UserDefaults.standard.object(forKey: Keys.lastCheckDate) as? Date ?? .distantPast
        
        guard Date().timeIntervalSince(lastCheck) > autoCheckInterval else {
            return
        }
        
        Task {
            await performCheck(showUpToDateMessage: false)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchLatestRelease() async throws -> Release {
        // First try /releases/latest (for repos with published releases)
        // If that fails, try /releases to get all releases and pick the first non-prerelease
        
        if let release = try? await fetchFromEndpoint("releases/latest") {
            return release
        }
        
        // Fallback: fetch all releases and find the latest
        let releases = try await fetchAllReleases()
        
        // Prefer non-prerelease, but fall back to prerelease if that's all there is
        if let stable = releases.first(where: { !$0.prerelease && !$0.tagName.contains("draft") }) {
            return stable
        }
        
        if let any = releases.first {
            return any
        }
        
        throw UpdateError.noReleasesFound
    }
    
    private func fetchFromEndpoint(_ endpoint: String) async throws -> Release {
        let urlString = "https://api.github.com/repos/\(githubRepo)/\(endpoint)"
        
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.invalidResponse
        }
        
        return try JSONDecoder().decode(Release.self, from: data)
    }
    
    private func fetchAllReleases() async throws -> [Release] {
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases"
        
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UpdateError.invalidResponse
            }
            
            // Handle 404 (no releases yet)
            if httpResponse.statusCode == 404 {
                throw UpdateError.noReleasesFound
            }
            
            guard httpResponse.statusCode == 200 else {
                throw UpdateError.invalidResponse
            }
            
            return try JSONDecoder().decode([Release].self, from: data)
            
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.networkError(error)
        }
    }
    
    /// Compare semantic versions (e.g., "0.2.0" vs "0.1.0")
    private func isNewer(_ version: String, than current: String) -> Bool {
        // Remove any pre-release suffix for comparison
        let cleanVersion = version.components(separatedBy: "-").first ?? version
        let cleanCurrent = current.components(separatedBy: "-").first ?? current
        
        let versionParts = cleanVersion.split(separator: ".").compactMap { Int($0) }
        let currentParts = cleanCurrent.split(separator: ".").compactMap { Int($0) }
        
        // Pad arrays to same length
        let maxLength = max(versionParts.count, currentParts.count)
        let paddedVersion = versionParts + Array(repeating: 0, count: maxLength - versionParts.count)
        let paddedCurrent = currentParts + Array(repeating: 0, count: maxLength - currentParts.count)
        
        for i in 0..<maxLength {
            if paddedVersion[i] > paddedCurrent[i] {
                return true
            } else if paddedVersion[i] < paddedCurrent[i] {
                return false
            }
        }
        
        return false
    }
    
    @MainActor
    private func performCheck(showUpToDateMessage: Bool) async {
        let result = await checkForUpdates()
        
        // Record check time
        UserDefaults.standard.set(Date(), forKey: Keys.lastCheckDate)
        
        switch result {
        case .updateAvailable(let release):
            showUpdateAlert(for: release)
            
        case .upToDate:
            if showUpToDateMessage {
                showUpToDateAlert()
            }
            
        case .error(let error):
            if showUpToDateMessage {
                showErrorAlert(error)
            }
        }
    }
    
    @MainActor
    private func showUpdateAlert(for release: Release) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Update Available"
        alert.informativeText = """
            A new version of IKEMEN Lab is available!
            
            Current version: \(currentVersion)
            Latest version: \(release.version)
            
            \(release.body?.prefix(500) ?? "")
            """
        
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Download - open releases page or direct DMG link
            if let dmgAsset = release.dmgAsset,
               let url = URL(string: dmgAsset.browserDownloadUrl) {
                NSWorkspace.shared.open(url)
            } else if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
            
        case .alertThirdButtonReturn:
            // Skip this version
            UserDefaults.standard.set(release.version, forKey: Keys.skippedVersion)
            
        default:
            break
        }
    }
    
    @MainActor
    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "You're Up to Date"
        alert.informativeText = "IKEMEN Lab \(currentVersion) is the latest version."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @MainActor
    private func showErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Unable to Check for Updates"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Progress Window

/// A small floating window that shows while checking for updates
@MainActor
private final class UpdateProgressWindow {
    
    private var window: NSWindow?
    
    func show() {
        // Create window
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Checking for Updates"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.center()
        
        // Create content
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.wantsLayer = true
        
        // Stack view for vertical layout
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Label
        let label = NSTextField(labelWithString: "Checking for updates…")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.alignment = .center
        
        // Progress indicator
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(spinner)
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        
        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        
        self.window = window
    }
    
    func close() {
        window?.close()
        window = nil
    }
}
