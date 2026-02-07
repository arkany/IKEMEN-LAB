import Foundation

/// Manages reading and writing IKEMEN GO's config.ini file (INI format).
/// Handles video, audio, and other engine settings.
final class IkemenConfigManager {
    
    // MARK: - Singleton
    
    static let shared = IkemenConfigManager()
    
    // MARK: - Config Path
    
    /// Path to IKEMEN GO's config.ini, derived from the bridge's working directory.
    var configPath: URL? {
        guard let workingDir = IkemenBridge.shared.workingDirectory else { return nil }
        return workingDir.appendingPathComponent("save/config.ini")
    }
    
    // MARK: - Reading
    
    /// Load and parse the IKEMEN GO config.ini into a nested dictionary.
    /// - Returns: Dictionary of [section: [key: value]], or nil if the file doesn't exist.
    func loadConfig() -> [String: [String: String]]? {
        guard let path = configPath,
              FileManager.default.fileExists(atPath: path.path) else { return nil }
        
        do {
            let content = try String(contentsOf: path, encoding: .utf8)
            var config: [String: [String: String]] = [:]
            var currentSection = ""
            
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix(";") { continue }
                
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    currentSection = String(trimmed.dropFirst().dropLast())
                    if config[currentSection] == nil {
                        config[currentSection] = [:]
                    }
                    continue
                }
                
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let key = trimmed[..<equalsIndex].trimmingCharacters(in: .whitespaces)
                    let value = trimmed[trimmed.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
                    config[currentSection]?[key] = value
                }
            }
            return config
        } catch {
            print("Error loading config: \(error)")
            return nil
        }
    }
    
    // MARK: - Writing
    
    /// Update a single value in the IKEMEN GO config.ini file.
    /// - Parameters:
    ///   - section: The INI section (e.g., "Video", "Sound")
    ///   - key: The setting key (e.g., "GameWidth", "MasterVolume")
    ///   - value: The new value to write
    func saveValue(section: String, key: String, value: String) {
        guard let path = configPath,
              FileManager.default.fileExists(atPath: path.path) else { return }
        
        do {
            var content = try String(contentsOf: path, encoding: .utf8)
            var lines = content.components(separatedBy: "\n")
            var inSection = false
            
            for i in 0..<lines.count {
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    let sectionName = String(trimmed.dropFirst().dropLast())
                    inSection = (sectionName == section)
                    continue
                }
                
                if inSection && trimmed.hasPrefix(key) {
                    if let equalsIndex = trimmed.firstIndex(of: "=") {
                        let keyPart = trimmed[..<equalsIndex].trimmingCharacters(in: .whitespaces)
                        if keyPart == key {
                            let leadingWhitespace = String(lines[i].prefix(while: { $0 == " " || $0 == "\t" }))
                            lines[i] = "\(leadingWhitespace)\(key) = \(value)"
                            break
                        }
                    }
                }
            }
            
            content = lines.joined(separator: "\n")
            try content.write(to: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving config: \(error)")
        }
    }
}
