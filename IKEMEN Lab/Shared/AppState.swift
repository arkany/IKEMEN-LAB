import SwiftUI
import Combine

// MARK: - App State

/// Global app state for SwiftUI views
/// Provides a bridge between existing AppKit singletons and SwiftUI's reactive paradigm
@MainActor
class AppState: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AppState()
    
    // MARK: - Published State
    
    /// Characters from EmulatorBridge (alias for IkemenBridge)
    @Published var characters: [CharacterInfo] = []
    
    /// Stages from EmulatorBridge
    @Published var stages: [StageInfo] = []
    
    /// Screenpacks from EmulatorBridge
    @Published var screenpacks: [ScreenpackInfo] = []
    
    /// Currently selected character (if any)
    @Published var selectedCharacter: CharacterInfo?
    
    /// Currently selected stage (if any)
    @Published var selectedStage: StageInfo?
    
    /// IKEMEN GO installation path
    @Published var ikemenPath: URL?
    
    /// Current engine state
    @Published var engineState: String = "idle"
    
    // MARK: - Cancellables
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Sync with EmulatorBridge (IkemenBridge)
        // Note: EmulatorBridge is the legacy name, actual class is IkemenBridge
        syncWithBridge()
    }
    
    // MARK: - Sync with AppKit Bridge
    
    private func syncWithBridge() {
        // Sync characters
        IkemenBridge.shared.$characters
            .receive(on: DispatchQueue.main)
            .assign(to: &$characters)
        
        // Sync stages
        IkemenBridge.shared.$stages
            .receive(on: DispatchQueue.main)
            .assign(to: &$stages)
        
        // Sync screenpacks
        IkemenBridge.shared.$screenpacks
            .receive(on: DispatchQueue.main)
            .assign(to: &$screenpacks)
        
        // Sync engine state
        IkemenBridge.shared.$engineState
            .receive(on: DispatchQueue.main)
            .map { state in
                switch state {
                case .idle: return "idle"
                case .launching: return "launching"
                case .running: return "running"
                case .terminated(let code): return "terminated(\(code))"
                case .error(let error): return "error: \(error.localizedDescription)"
                }
            }
            .assign(to: &$engineState)
        
        // Load IKEMEN path from settings
        if let path = AppSettings.shared.ikemenPath {
            self.ikemenPath = path
        }
    }
    
    // MARK: - Actions
    
    /// Launch the game with current configuration
    func launchGame() {
        Task {
            do {
                try await IkemenBridge.shared.launchGame()
            } catch {
                print("Failed to launch game: \(error)")
            }
        }
    }
    
    /// Refresh content from filesystem
    func refreshContent() {
        Task {
            await IkemenBridge.shared.scanContent()
        }
    }
}

// MARK: - Convenience Accessors

extension AppState {
    /// Active characters (not disabled/missing/broken)
    var activeCharacters: [CharacterInfo] {
        characters.filter { $0.status == .active }
    }
    
    /// Active stages
    var activeStages: [StageInfo] {
        stages.filter { $0.status == .active }
    }
    
    /// Total content count
    var totalContentCount: Int {
        characters.count + stages.count
    }
    
    /// Is game currently running?
    var isGameRunning: Bool {
        engineState == "running"
    }
}
