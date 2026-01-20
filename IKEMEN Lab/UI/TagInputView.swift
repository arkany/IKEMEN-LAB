import Cocoa

/// A text field with native macOS autocomplete for tag input
/// Shows suggestions from existing tags as the user types
class TagInputView: NSView, NSTextFieldDelegate {
    
    // MARK: - Properties
    
    private var textField: NSTextField!
    
    private var allTags: [String] = []
    private var recentTags: [String] = []
    private var excludedTags: Set<String> = []
    
    /// The current text value
    var stringValue: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }
    
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
        
        // Load tags from database
        loadTags()
        
        setupTextField()
        setupConstraints()
    }
    
    private func loadTags() {
        allTags = (try? MetadataStore.shared.allCustomTags()) ?? []
        recentTags = (try? MetadataStore.shared.recentCustomTags(limit: 5)) ?? []
    }
    
    // MARK: - Setup
    
    private func setupTextField() {
        textField = NSTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholderString = "Tag name"
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.delegate = self
        textField.focusRingType = .exterior
        textField.bezelStyle = .roundedBezel
        addSubview(textField)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    // MARK: - Public Methods
    
    /// Set tags to exclude from suggestions (e.g., tags already on the character)
    func setExcludedTags(_ tags: [String]) {
        excludedTags = Set(tags.map { $0.lowercased() })
    }
    
    /// Make the text field first responder and show initial completions
    func focus() {
        window?.makeFirstResponder(textField)
        
        // Show recent tags dropdown after a brief delay to ensure field is active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showInitialCompletions()
        }
    }
    
    /// Reload the suggestions from the database
    func reloadTags() {
        loadTags()
    }
    
    // MARK: - Completions
    
    private func showInitialCompletions() {
        guard let editor = textField.currentEditor() as? NSTextView else { return }
        
        // Trigger completion to show recent tags
        editor.complete(nil)
    }
    
    private func filteredCompletions(for partialWord: String) -> [String] {
        let query = partialWord.lowercased()
        
        if query.isEmpty {
            // Show recent tags when empty, excluding already-used tags
            return recentTags.filter { !excludedTags.contains($0.lowercased()) }
        }
        
        // Filter all tags, prioritizing prefix matches
        let prefixMatches = allTags.filter { 
            $0.lowercased().hasPrefix(query) && !excludedTags.contains($0.lowercased())
        }
        let containsMatches = allTags.filter { 
            $0.lowercased().contains(query) && 
            !$0.lowercased().hasPrefix(query) && 
            !excludedTags.contains($0.lowercased())
        }
        
        return prefixMatches + containsMatches
    }
    
    // MARK: - NSTextFieldDelegate
    
    func controlTextDidBeginEditing(_ obj: Notification) {
        // Show completions when field gains focus
        showInitialCompletions()
    }
    
    func control(_ control: NSControl, textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        // Get the partial word being typed
        let text = textView.string
        let partialWord: String
        if charRange.location != NSNotFound && charRange.length > 0 {
            let start = text.index(text.startIndex, offsetBy: charRange.location)
            let end = text.index(start, offsetBy: charRange.length)
            partialWord = String(text[start..<end])
        } else {
            partialWord = text
        }
        
        let completions = filteredCompletions(for: partialWord)
        
        // Select first item by default
        if !completions.isEmpty {
            index.pointee = 0
        }
        
        return completions
    }
    
    // MARK: - First Responder
    
    override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}
