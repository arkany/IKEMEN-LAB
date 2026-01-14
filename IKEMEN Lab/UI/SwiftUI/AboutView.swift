import SwiftUI

// MARK: - About View

/// Modern SwiftUI-based About window
/// This serves as a reference implementation for new SwiftUI views
struct AboutView: View, AppKitHostable {
    @State private var updateStatus: String = "Checking for updates..."
    @StateObject private var appState = AppState.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // App Icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 128, height: 128)
            }
            
            // App Name & Version
            Text("IKEMEN Lab")
                .font(.header(size: 24))
                .foregroundColor(.textPrimary)
            
            Text("Version \(Bundle.main.appVersion)")
                .font(.body(size: 14))
                .foregroundColor(.textSecondary)
            
            // Library Stats
            VStack(spacing: 8) {
                HStack {
                    Text("Characters:")
                        .font(.caption(size: 12))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(appState.characters.count)")
                        .font(.header(size: 12))
                        .foregroundColor(.textPrimary)
                }
                
                HStack {
                    Text("Stages:")
                        .font(.caption(size: 12))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(appState.stages.count)")
                        .font(.header(size: 12))
                        .foregroundColor(.textPrimary)
                }
            }
            .padding(.horizontal, 32)
            
            Divider()
                .background(Color.borderSubtle)
            
            // Update Status
            Text(updateStatus)
                .font(.caption(size: 12))
                .foregroundColor(.textSecondary)
            
            // Credits
            VStack(spacing: 4) {
                Text("Built with ❤️ for the MUGEN community")
                    .font(.caption(size: 11))
                    .foregroundColor(.textTertiary)
                
                Link("Visit on GitHub", destination: URL(string: "https://github.com/arkany/IKEMEN-LAB")!)
                    .font(.caption(size: 11))
                    .foregroundColor(.accentBlue)
            }
            
            Spacer()
        }
        .padding(32)
        .frame(width: 400, height: 500)
        .background(Color.zinc950)
        .onAppear {
            checkForUpdates()
        }
    }
    
    // MARK: - Actions
    
    private func checkForUpdates() {
        // Use existing UpdateChecker
        Task {
            // Simulate async update check
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // In a real implementation, call UpdateChecker
            // For now, just show a simple message
            updateStatus = "You're on the latest version"
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    /// App version from Info.plist
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// Build number from Info.plist
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Preview

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
#endif
