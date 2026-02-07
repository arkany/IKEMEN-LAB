import Cocoa
import Combine

/// View for displaying detected duplicates and outdated content
class DuplicatesView: NSView {
    
    // MARK: - Properties
    
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var statusLabel: NSTextField!
    private var scanButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    
    private var characterDuplicates: [DuplicateDetector.DuplicateGroup<CharacterInfo>] = []
    private var stageDuplicates: [DuplicateDetector.DuplicateGroup<StageInfo>] = []
    private var screenpackDuplicates: [DuplicateDetector.DuplicateGroup<ScreenpackInfo>] = []
    
    private var outdatedCharacters: [DuplicateDetector.OutdatedItem<CharacterInfo>] = []
    private var outdatedStages: [DuplicateDetector.OutdatedItem<StageInfo>] = []
    
    private enum DisplayRow {
        case section(String)
        case characterDuplicate(DuplicateDetector.DuplicateGroup<CharacterInfo>)
        case stageDuplicate(DuplicateDetector.DuplicateGroup<StageInfo>)
        case screenpackDuplicate(DuplicateDetector.DuplicateGroup<ScreenpackInfo>)
        case outdatedCharacter(DuplicateDetector.OutdatedItem<CharacterInfo>)
        case outdatedStage(DuplicateDetector.OutdatedItem<StageInfo>)
    }
    
    private var displayRows: [DisplayRow] = []
    
    var onCharacterRemove: ((CharacterInfo) -> Void)?
    var onStageRemove: ((StageInfo) -> Void)?
    
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
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Title and scan button at top
        let headerStack = NSStackView()
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .centerY
        addSubview(headerStack)
        
        let titleLabel = NSTextField(labelWithString: "Duplicates & Outdated Content")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        headerStack.addArrangedSubview(titleLabel)
        
        // Progress indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isHidden = true
        headerStack.addArrangedSubview(progressIndicator)
        
        headerStack.addArrangedSubview(NSView())  // Spacer
        
        scanButton = NSButton(title: "Scan for Duplicates", target: self, action: #selector(scanForDuplicates))
        scanButton.bezelStyle = .rounded
        headerStack.addArrangedSubview(scanButton)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "Click 'Scan for Duplicates' to find duplicate or outdated content")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .center
        addSubview(statusLabel)
        
        // Table view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)
        
        tableView = NSTableView()
        tableView.style = .fullWidth
        tableView.rowSizeStyle = .default
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.delegate = self
        tableView.dataSource = self
        
        // Columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 300
        tableView.addTableColumn(nameColumn)
        
        let reasonColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("reason"))
        reasonColumn.title = "Reason"
        reasonColumn.width = 150
        tableView.addTableColumn(reasonColumn)
        
        let itemsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("items"))
        itemsColumn.title = "Duplicates Found"
        itemsColumn.width = 150
        tableView.addTableColumn(itemsColumn)
        
        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = "Action"
        actionColumn.width = 100
        tableView.addTableColumn(actionColumn)
        
        scrollView.documentView = tableView
        
        // Layout
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            statusLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            scrollView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func scanForDuplicates() {
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        scanButton.isEnabled = false
        statusLabel.stringValue = "Scanning..."
        
        // Run scan in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let characters = IkemenBridge.shared.characters
            let stages = IkemenBridge.shared.stages
            let screenpacks = IkemenBridge.shared.screenpacks
            
            // Detect duplicates
            let charDupes = DuplicateDetector.findDuplicateCharacters(characters)
            let stageDupes = DuplicateDetector.findDuplicateStages(stages)
            let screenpackDupes = DuplicateDetector.findDuplicateScreenpacks(screenpacks)
            
            // Detect outdated
            let outdatedChars = DuplicateDetector.findOutdatedCharacters(characters)
            let outdatedStgs = DuplicateDetector.findOutdatedStages(stages)
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.characterDuplicates = charDupes
                self.stageDuplicates = stageDupes
                self.screenpackDuplicates = screenpackDupes
                self.outdatedCharacters = outdatedChars
                self.outdatedStages = outdatedStgs
                
                self.buildDisplayRows()
                self.tableView.reloadData()
                
                self.progressIndicator.stopAnimation(nil)
                self.progressIndicator.isHidden = true
                self.scanButton.isEnabled = true
                
                let totalFound = charDupes.count + stageDupes.count + screenpackDupes.count + 
                                 outdatedChars.count + outdatedStgs.count
                
                if totalFound == 0 {
                    self.statusLabel.stringValue = "No duplicates or outdated content found"
                } else {
                    self.statusLabel.stringValue = "Found \(totalFound) issues"
                }
            }
        }
    }
    
    private func buildDisplayRows() {
        displayRows.removeAll()
        
        if !characterDuplicates.isEmpty {
            displayRows.append(.section("Duplicate Characters"))
            for group in characterDuplicates {
                displayRows.append(.characterDuplicate(group))
            }
        }
        
        if !stageDuplicates.isEmpty {
            displayRows.append(.section("Duplicate Stages"))
            for group in stageDuplicates {
                displayRows.append(.stageDuplicate(group))
            }
        }
        
        if !screenpackDuplicates.isEmpty {
            displayRows.append(.section("Duplicate Screenpacks"))
            for group in screenpackDuplicates {
                displayRows.append(.screenpackDuplicate(group))
            }
        }
        
        if !outdatedCharacters.isEmpty {
            displayRows.append(.section("Outdated Characters"))
            for item in outdatedCharacters {
                displayRows.append(.outdatedCharacter(item))
            }
        }
        
        if !outdatedStages.isEmpty {
            displayRows.append(.section("Outdated Stages"))
            for item in outdatedStages {
                displayRows.append(.outdatedStage(item))
            }
        }
    }
    
    // MARK: - Public Methods
    
    func refresh() {
        // Auto-scan when view is shown
        scanForDuplicates()
    }
}

// MARK: - Table View Data Source

extension DuplicatesView: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayRows.count
    }
}

// MARK: - Table View Delegate

extension DuplicatesView: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < displayRows.count else { return nil }
        
        let rowItem = displayRows[row]
        let columnId = tableColumn?.identifier.rawValue ?? ""
        
        switch rowItem {
        case .section(let title):
            if columnId == "name" {
                let textField = NSTextField(labelWithString: title)
                textField.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
                textField.textColor = .labelColor
                return textField
            }
            return nil
            
        case .characterDuplicate(let group):
            return makeCellForDuplicateGroup(group, columnId: columnId, isCharacter: true)
            
        case .stageDuplicate(let group):
            return makeCellForDuplicateGroup(group, columnId: columnId, isCharacter: false)
            
        case .screenpackDuplicate(let group):
            return makeCellForDuplicateGroup(group, columnId: columnId, isCharacter: false)
            
        case .outdatedCharacter(let item):
            return makeCellForOutdatedItem(
                name: item.item.displayName,
                version: item.itemVersion.version ?? item.itemVersion.date ?? "Unknown",
                newerVersion: item.newerVersion.version ?? item.newerVersion.date ?? "Unknown",
                columnId: columnId
            )
            
        case .outdatedStage(let item):
            return makeCellForOutdatedItem(
                name: item.item.name,
                version: item.itemVersion.date ?? "Unknown",
                newerVersion: item.newerVersion.date ?? "Unknown",
                columnId: columnId
            )
        }
    }
    
    private func makeCellForDuplicateGroup<T>(_ group: DuplicateDetector.DuplicateGroup<T>, 
                                               columnId: String, isCharacter: Bool) -> NSView? {
        switch columnId {
        case "name":
            let names = group.items.compactMap { item -> String? in
                if let char = item as? CharacterInfo {
                    return char.displayName
                } else if let stage = item as? StageInfo {
                    return stage.name
                } else if let sp = item as? ScreenpackInfo {
                    return sp.name
                }
                return nil
            }
            let text = names.joined(separator: ", ")
            let textField = NSTextField(labelWithString: text)
            textField.font = NSFont.systemFont(ofSize: 12)
            return textField
            
        case "reason":
            let textField = NSTextField(labelWithString: group.reason.rawValue)
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.textColor = .secondaryLabelColor
            return textField
            
        case "items":
            let textField = NSTextField(labelWithString: "\(group.items.count) items")
            textField.font = NSFont.systemFont(ofSize: 12)
            return textField
            
        case "action":
            let button = NSButton(title: "Review", target: self, action: #selector(reviewDuplicate(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            return button
            
        default:
            return nil
        }
    }
    
    private func makeCellForOutdatedItem(name: String, version: String, newerVersion: String, columnId: String) -> NSView? {
        switch columnId {
        case "name":
            let textField = NSTextField(labelWithString: name)
            textField.font = NSFont.systemFont(ofSize: 12)
            return textField
            
        case "reason":
            let textField = NSTextField(labelWithString: "Outdated")
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.textColor = .secondaryLabelColor
            return textField
            
        case "items":
            let text = "v\(version) (latest: v\(newerVersion))"
            let textField = NSTextField(labelWithString: text)
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.textColor = .secondaryLabelColor
            return textField
            
        case "action":
            let button = NSButton(title: "Update", target: self, action: #selector(updateOutdated(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.isEnabled = false  // Not implemented yet
            return button
            
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        if case .section = displayRows[row] {
            return true
        }
        return false
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .section = displayRows[row] {
            return false
        }
        return true
    }
    
    @objc private func reviewDuplicate(_ sender: NSButton) {
        // Find which row was clicked
        let clickedRow = tableView.row(for: sender)
        guard clickedRow >= 0, clickedRow < displayRows.count else { return }
        
        // Show alert with duplicate info
        let alert = NSAlert()
        alert.messageText = "Duplicate Found"
        alert.informativeText = "Review the duplicate items and remove the ones you don't need from the Characters or Stages browser."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func updateOutdated(_ sender: NSButton) {
        // Placeholder for future implementation
        let alert = NSAlert()
        alert.messageText = "Update Not Available"
        alert.informativeText = "Automatic updates are not yet implemented. Please manually download and install the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
