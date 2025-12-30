import Foundation

// MARK: - Content Validator

/// Validates IKEMEN GO content for common issues before/after installation
public class ContentValidator {
    
    public static let shared = ContentValidator()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Validation Results
    
    public enum ValidationSeverity {
        case error      // Will cause crash or fail to load
        case warning    // May cause issues but might work
        case info       // Informational only
    }
    
    public enum FixType {
        case renameFile(from: String, to: String, inDirectory: URL)
        case updateDefReference(defFile: URL, oldRef: String, newRef: String)
        case none
    }
    
    public struct ValidationIssue: Identifiable {
        public let id = UUID()
        public let severity: ValidationSeverity
        public let message: String
        public let file: String
        public let suggestion: String?
        public let fixType: FixType
        
        public var isFixable: Bool {
            if case .none = fixType { return false }
            return true
        }
        
        public init(severity: ValidationSeverity, message: String, file: String, suggestion: String? = nil, fixType: FixType = .none) {
            self.severity = severity
            self.message = message
            self.file = file
            self.suggestion = suggestion
            self.fixType = fixType
        }
    }
    
    public struct ValidationResult {
        public let contentName: String
        public let contentType: String // "character" or "stage"
        public let issues: [ValidationIssue]
        
        public var hasErrors: Bool {
            issues.contains { $0.severity == .error }
        }
        
        public var hasWarnings: Bool {
            issues.contains { $0.severity == .warning }
        }
        
        public var isValid: Bool {
            !hasErrors
        }
        
        public var errorCount: Int {
            issues.filter { $0.severity == .error }.count
        }
        
        public var warningCount: Int {
            issues.filter { $0.severity == .warning }.count
        }
    }
    
    // MARK: - Stage Validation
    
    /// Validate a stage .def file and its referenced resources
    public func validateStage(defFile: URL) -> ValidationResult {
        var issues: [ValidationIssue] = []
        let stageName = defFile.deletingPathExtension().lastPathComponent
        let stageDir = defFile.deletingLastPathComponent()
        
        // Parse the .def file (try multiple encodings)
        guard let content = readFileContent(at: defFile) else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Cannot read .def file",
                file: defFile.lastPathComponent,
                suggestion: "Check file encoding (UTF-8, ISO-8859-1, or Windows-1252)"
            ))
            return ValidationResult(contentName: stageName, contentType: "stage", issues: issues)
        }
        
        // Check for sprite file reference
        var spriteFile: String?
        var soundFile: String?
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments
            if trimmed.hasPrefix(";") { continue }
            
            let lowercased = trimmed.lowercased()
            
            // Check for spr = (exact key, not spriteno/spriteinfo/etc)
            // Must be "spr" or "sprite" followed by optional whitespace and "="
            if lowercased.hasPrefix("spr") && !lowercased.hasPrefix("spriteno") && !lowercased.hasPrefix("spriteinfo") {
                if let value = extractValue(from: trimmed) {
                    // Only accept if it looks like a filename (ends in .sff or contains path separator)
                    if value.lowercased().hasSuffix(".sff") || value.contains("/") || value.contains("\\") {
                        spriteFile = value
                    }
                }
            }
            
            // Check for snd = or sound = (exact key)
            if (lowercased.hasPrefix("snd") && !lowercased.hasPrefix("sndtime")) || lowercased.hasPrefix("sound") {
                if let value = extractValue(from: trimmed) {
                    // Only accept if it looks like a filename
                    if value.lowercased().hasSuffix(".snd") || value.contains("/") || value.contains("\\") {
                        soundFile = value
                    }
                }
            }
        }
        
        // Validate sprite file exists
        if let spr = spriteFile {
            let sprValidation = validateResourceFile(
                reference: spr,
                defFile: defFile,
                resourceType: "Sprite file (.sff)"
            )
            issues.append(contentsOf: sprValidation)
        } else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "No sprite file (spr) defined",
                file: defFile.lastPathComponent,
                suggestion: "Add 'spr = <filename>.sff' to [BGdef] section"
            ))
        }
        
        // Validate sound file if referenced (optional)
        if let snd = soundFile {
            let sndValidation = validateResourceFile(
                reference: snd,
                defFile: defFile,
                resourceType: "Sound file (.snd)"
            )
            // Sound is optional, so make missing sound a warning not error
            for issue in sndValidation {
                if issue.severity == .error {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: issue.message,
                        file: issue.file,
                        suggestion: issue.suggestion
                    ))
                } else {
                    issues.append(issue)
                }
            }
        }
        
        // Check for problematic characters in filenames
        let problematicChars = validateFilename(stageName)
        issues.append(contentsOf: problematicChars)
        
        return ValidationResult(contentName: stageName, contentType: "stage", issues: issues)
    }
    
    // MARK: - Character Validation
    
    /// Validate a character folder and its referenced resources
    public func validateCharacter(folder: URL) -> ValidationResult {
        var issues: [ValidationIssue] = []
        let charName = folder.lastPathComponent
        
        // Find .def file
        guard let defFile = findMainDefFile(in: folder) else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "No .def file found",
                file: charName,
                suggestion: "Character folder must contain a .def file (e.g., \(charName).def)"
            ))
            return ValidationResult(contentName: charName, contentType: "character", issues: issues)
        }
        
        // Parse the .def file (try multiple encodings)
        guard let content = readFileContent(at: defFile) else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Cannot read .def file",
                file: defFile.lastPathComponent,
                suggestion: "Check file encoding (UTF-8, ISO-8859-1, or Windows-1252)"
            ))
            return ValidationResult(contentName: charName, contentType: "character", issues: issues)
        }
        
        // Check for required file references in [Files] section
        var inFilesSection = false
        var requiredFiles: [String: String?] = [
            "sprite": nil,
            "anim": nil,
            "cmd": nil,
            "cns": nil
        ]
        var optionalFiles: [String: String?] = [
            "sound": nil,
            "ai": nil
        ]
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments
            if trimmed.hasPrefix(";") { continue }
            
            // Check section
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let section = trimmed.dropFirst().dropLast().lowercased()
                inFilesSection = (section == "files")
                continue
            }
            
            if inFilesSection {
                let lowercased = trimmed.lowercased()
                
                for key in requiredFiles.keys {
                    if lowercased.hasPrefix(key) {
                        if let value = extractValue(from: trimmed) {
                            requiredFiles[key] = value
                        }
                    }
                }
                
                for key in optionalFiles.keys {
                    if lowercased.hasPrefix(key) {
                        if let value = extractValue(from: trimmed) {
                            optionalFiles[key] = value
                        }
                    }
                }
            }
        }
        
        // Validate required files
        for (key, value) in requiredFiles {
            if let ref = value {
                let validation = validateResourceFile(
                    reference: ref,
                    defFile: defFile,
                    resourceType: "\(key.capitalized) file"
                )
                issues.append(contentsOf: validation)
            } else {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Missing required '\(key)' reference in [Files] section",
                    file: defFile.lastPathComponent,
                    suggestion: "Add '\(key) = <filename>' to [Files] section"
                ))
            }
        }
        
        // Validate optional files (warnings only)
        for (key, value) in optionalFiles {
            if let ref = value {
                let validation = validateResourceFile(
                    reference: ref,
                    defFile: defFile,
                    resourceType: "\(key.capitalized) file"
                )
                for issue in validation {
                    if issue.severity == .error {
                        issues.append(ValidationIssue(
                            severity: .warning,
                            message: issue.message,
                            file: issue.file,
                            suggestion: issue.suggestion
                        ))
                    } else {
                        issues.append(issue)
                    }
                }
            }
        }
        
        // Check for problematic characters in folder name
        let problematicChars = validateFilename(charName)
        issues.append(contentsOf: problematicChars)
        
        return ValidationResult(contentName: charName, contentType: "character", issues: issues)
    }
    
    // MARK: - Batch Validation
    
    /// Validate all stages in the stages folder
    public func validateAllStages(in workingDir: URL) -> [ValidationResult] {
        let stagesDir = workingDir.appendingPathComponent("stages")
        var results: [ValidationResult] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: stagesDir, includingPropertiesForKeys: nil) else {
            return results
        }
        
        for file in contents {
            if file.pathExtension.lowercased() == "def" {
                let result = validateStage(defFile: file)
                if !result.issues.isEmpty {
                    results.append(result)
                }
            }
        }
        
        return results
    }
    
    /// Validate all characters in the chars folder
    public func validateAllCharacters(in workingDir: URL) -> [ValidationResult] {
        let charsDir = workingDir.appendingPathComponent("chars")
        var results: [ValidationResult] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(at: charsDir, includingPropertiesForKeys: nil) else {
            return results
        }
        
        for folder in contents {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue {
                let result = validateCharacter(folder: folder)
                if !result.issues.isEmpty {
                    results.append(result)
                }
            }
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    /// Extract value from "key = value" line
    private func extractValue(from line: String) -> String? {
        guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
        var value = String(line[line.index(after: equalsIndex)...])
            .trimmingCharacters(in: .whitespaces)
        
        // Remove inline comments
        if let commentIndex = value.firstIndex(of: ";") {
            value = String(value[..<commentIndex]).trimmingCharacters(in: .whitespaces)
        }
        
        // Remove quotes if present
        if value.hasPrefix("\"") && value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        
        return value.isEmpty ? nil : value
    }
    
    /// Validate a resource file reference exists
    private func validateResourceFile(reference: String, defFile: URL, resourceType: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Normalize path separators
        let normalizedRef = reference.replacingOccurrences(of: "\\", with: "/")
        
        // Determine the search directory
        let searchDir: URL
        if normalizedRef.contains("/") {
            let rootDir = defFile.deletingLastPathComponent().deletingLastPathComponent()
            searchDir = rootDir.appendingPathComponent((normalizedRef as NSString).deletingLastPathComponent)
        } else {
            searchDir = defFile.deletingLastPathComponent()
        }
        
        // Determine the actual file path
        let resolvedPath: URL
        if normalizedRef.contains("/") {
            // Root-relative path (e.g., "stages/Bifrost.sff")
            let rootDir = defFile.deletingLastPathComponent().deletingLastPathComponent()
            resolvedPath = rootDir.appendingPathComponent(normalizedRef)
        } else {
            // File-relative path (e.g., "Bifrost.sff")
            resolvedPath = defFile.deletingLastPathComponent().appendingPathComponent(normalizedRef)
        }
        
        // Check if file exists with exact name
        if !fileManager.fileExists(atPath: resolvedPath.path) {
            // Try case-insensitive/fuzzy search
            if let actualFile = findFileCaseInsensitive(reference: normalizedRef, relativeTo: defFile) {
                // Determine type of mismatch
                let refLower = reference.lowercased()
                let actualLower = actualFile.lowercased()
                let refNormalized = normalizeForComparison(reference)
                let actualNormalized = normalizeForComparison(actualFile)
                
                var mismatchType = "name mismatch"
                if refNormalized == actualNormalized && refLower != actualLower {
                    mismatchType = "case and character mismatch"
                } else if refLower == actualLower {
                    mismatchType = "case mismatch"
                } else if refNormalized == actualNormalized {
                    mismatchType = "special character mismatch (e.g., apostrophe)"
                }
                
                // Provide fixable issue - update .def to match actual file
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "\(resourceType) has \(mismatchType): '\(reference)' → actual: '\(actualFile)'",
                    file: defFile.lastPathComponent,
                    suggestion: "Update .def to reference '\(actualFile)'",
                    fixType: .updateDefReference(defFile: defFile, oldRef: reference, newRef: actualFile)
                ))
            } else {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "\(resourceType) not found: '\(reference)'",
                    file: defFile.lastPathComponent,
                    suggestion: "Check that '\(normalizedRef.components(separatedBy: "/").last ?? reference)' exists in the correct location"
                ))
            }
        }
        
        return issues
    }
    
    /// Find a file with case-insensitive and special-character-tolerant matching
    private func findFileCaseInsensitive(reference: String, relativeTo defFile: URL) -> String? {
        let normalizedRef = reference.replacingOccurrences(of: "\\", with: "/")
        let searchDir: URL
        let searchName: String
        
        if normalizedRef.contains("/") {
            let rootDir = defFile.deletingLastPathComponent().deletingLastPathComponent()
            let components = normalizedRef.components(separatedBy: "/")
            searchName = components.last ?? reference
            searchDir = rootDir.appendingPathComponent(components.dropLast().joined(separator: "/"))
        } else {
            searchDir = defFile.deletingLastPathComponent()
            searchName = normalizedRef
        }
        
        guard let contents = try? fileManager.contentsOfDirectory(at: searchDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        // Normalize for comparison: lowercase and remove common problematic chars
        let normalizedSearchName = normalizeForComparison(searchName)
        
        for file in contents {
            let fileName = file.lastPathComponent
            // Exact case mismatch
            if fileName.lowercased() == searchName.lowercased() && fileName != searchName {
                return fileName
            }
            // Special character mismatch (e.g., apostrophe removed)
            if normalizeForComparison(fileName) == normalizedSearchName && fileName != searchName {
                return fileName
            }
        }
        
        return nil
    }
    
    /// Normalize filename for fuzzy comparison
    private func normalizeForComparison(_ name: String) -> String {
        // Remove common problematic characters and lowercase
        var normalized = name.lowercased()
        // Remove apostrophes, quotes, and other common variations
        let charsToRemove = CharacterSet(charactersIn: "''`\"")
        normalized = normalized.unicodeScalars.filter { !charsToRemove.contains($0) }.map { String($0) }.joined()
        return normalized
    }
    
    /// Find the main .def file in a character folder
    private func findMainDefFile(in folder: URL) -> URL? {
        guard let contents = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        let defFiles = contents.filter { $0.pathExtension.lowercased() == "def" }
        
        // Prefer file matching folder name
        let folderName = folder.lastPathComponent.lowercased()
        if let match = defFiles.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == folderName }) {
            return match
        }
        
        // Otherwise return first .def file found
        return defFiles.first
    }
    
    /// Check for problematic characters in filename
    private func validateFilename(_ name: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check for apostrophes (can cause path issues)
        if name.contains("'") {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Filename contains apostrophe (')",
                file: name,
                suggestion: "Consider removing apostrophe to avoid path issues on some systems"
            ))
        }
        
        // Check for spaces
        if name.contains(" ") {
            issues.append(ValidationIssue(
                severity: .info,
                message: "Filename contains spaces",
                file: name,
                suggestion: "Spaces may cause issues with some configurations"
            ))
        }
        
        // Check for special characters
        let problematic = CharacterSet(charactersIn: "&%$#@!*()[]{}|\\:\"<>?")
        if name.unicodeScalars.contains(where: { problematic.contains($0) }) {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Filename contains special characters",
                file: name,
                suggestion: "Use only letters, numbers, underscores, and hyphens"
            ))
        }
        
        return issues
    }
    
    /// Read file content trying multiple encodings (MUGEN content uses various encodings)
    private func readFileContent(at url: URL) -> String? {
        // Try common encodings in order of likelihood
        let encodings: [String.Encoding] = [
            .utf8,
            .isoLatin1,        // ISO-8859-1 (common for old MUGEN content)
            .windowsCP1252,    // Windows Latin-1
            .ascii
        ]
        
        for encoding in encodings {
            if let content = try? String(contentsOf: url, encoding: encoding) {
                return content
            }
        }
        
        return nil
    }
    
    // MARK: - Auto-Fix Methods
    
    /// Fix a single issue
    public func fixIssue(_ issue: ValidationIssue) -> Bool {
        switch issue.fixType {
        case .renameFile(let from, let to, let directory):
            let fromPath = directory.appendingPathComponent(from)
            let toPath = directory.appendingPathComponent(to)
            do {
                try fileManager.moveItem(at: fromPath, to: toPath)
                return true
            } catch {
                print("Failed to rename file: \(error)")
                return false
            }
            
        case .updateDefReference(let defFile, let oldRef, let newRef):
            guard let content = readFileContent(at: defFile) else { return false }
            
            // Replace the old reference with the new one
            let updatedContent = content.replacingOccurrences(of: oldRef, with: newRef)
            
            do {
                try updatedContent.write(to: defFile, atomically: true, encoding: .utf8)
                return true
            } catch {
                print("Failed to update .def file: \(error)")
                return false
            }
            
        case .none:
            return false
        }
    }
    
    /// Fix all fixable issues in a validation result
    public func fixAllIssues(in result: ValidationResult) -> (fixed: Int, failed: Int) {
        var fixed = 0
        var failed = 0
        
        for issue in result.issues where issue.isFixable {
            if fixIssue(issue) {
                fixed += 1
            } else {
                failed += 1
            }
        }
        
        return (fixed, failed)
    }
    
    /// Fix all fixable issues across multiple validation results
    public func fixAllIssues(in results: [ValidationResult]) -> (fixed: Int, failed: Int) {
        var totalFixed = 0
        var totalFailed = 0
        
        for result in results {
            let (fixed, failed) = fixAllIssues(in: result)
            totalFixed += fixed
            totalFailed += failed
        }
        
        return (totalFixed, totalFailed)
    }
}
