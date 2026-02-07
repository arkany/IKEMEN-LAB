import Cocoa
import UniformTypeIdentifiers

/// Handles the "Create Stage from PNG" feature — file picker, name/author dialog,
/// and calling StageGenerator to produce the stage files.
final class StageCreationController {
    
    /// The window to present dialogs in.
    weak var window: NSWindow?
    
    /// Called on status changes (message string).
    var onStatusUpdate: ((String) -> Void)?
    
    /// Called after a stage is successfully created so views can refresh.
    var onStageCreated: (() -> Void)?
    
    // MARK: - Public API
    
    /// Entry point — validates the feature flag and opens a PNG file picker.
    func createStageFromPNG() {
        guard AppSettings.shared.enablePNGStageCreation else {
            showAlert(title: "Feature Disabled", message: "PNG stage creation is disabled. Enable it in Settings → Advanced.")
            return
        }
        
        guard let window = window else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.title = "Select a PNG Image"
        openPanel.message = "Choose a PNG image to use as a stage background"
        openPanel.allowedContentTypes = [.png]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            self?.showStageCreationDialog(forImage: url)
        }
    }
    
    // MARK: - Dialog
    
    private func showStageCreationDialog(forImage imageURL: URL) {
        guard let window = window else { return }
        
        let alert = NSAlert()
        alert.messageText = "Create Stage"
        alert.informativeText = "Enter details for the new stage:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.frame = NSRect(x: 0, y: 36, width: 50, height: 20)
        container.addSubview(nameLabel)
        
        let nameInput = NSTextField(frame: NSRect(x: 55, y: 34, width: 245, height: 24))
        nameInput.stringValue = imageURL.deletingPathExtension().lastPathComponent
        nameInput.placeholderString = "Stage Name"
        container.addSubview(nameInput)
        
        let authorLabel = NSTextField(labelWithString: "Author:")
        authorLabel.frame = NSRect(x: 0, y: 4, width: 50, height: 20)
        container.addSubview(authorLabel)
        
        let authorInput = NSTextField(frame: NSRect(x: 55, y: 2, width: 245, height: 24))
        authorInput.stringValue = NSFullUserName()
        authorInput.placeholderString = "Your Name"
        container.addSubview(authorInput)
        
        alert.accessoryView = container
        
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            
            let stageName = nameInput.stringValue.trimmingCharacters(in: .whitespaces)
            guard !stageName.isEmpty else {
                self?.showAlert(title: "Invalid Name", message: "Please enter a stage name.")
                return
            }
            
            let author = authorInput.stringValue.trimmingCharacters(in: .whitespaces)
            self?.createStage(from: imageURL, name: stageName, author: author.isEmpty ? "Unknown" : author)
        }
    }
    
    // MARK: - Stage Generation
    
    private func createStage(from imageURL: URL, name: String, author: String = "MacMugen") {
        guard let workingDir = IkemenBridge.shared.workingDirectory else {
            showAlert(title: "Error", message: "Ikemen GO directory not found.")
            return
        }
        
        let stagesDir = workingDir.appendingPathComponent("stages")
        
        var options = StageGenerator.StageOptions.withDefaults(name: name)
        options.author = author
        
        let result = StageGenerator.generate(from: imageURL, in: stagesDir, options: options)
        
        switch result {
        case .success(let generated):
            let dataDir = workingDir.appendingPathComponent("data")
            let relativePath = generated.stageDirectory.lastPathComponent + "/" + generated.defFile.lastPathComponent
            StageGenerator.registerStageInSelectDef(stagePath: relativePath, dataDirectory: dataDir)
            
            onStageCreated?()
            
            showAlert(title: "Stage Created", message: "Successfully created stage '\(generated.stageName)' at:\n\(generated.stageDirectory.path)")
            onStatusUpdate?("Created stage: \(generated.stageName)")
            
        case .failure(let error):
            showAlert(title: "Stage Creation Failed", message: error.localizedDescription)
        }
    }
    
    // MARK: - Helpers
    
    private func showAlert(title: String, message: String) {
        guard let window = window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
}
