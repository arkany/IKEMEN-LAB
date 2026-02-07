import Foundation
import AppKit

// MARK: - Content Manager (Facade)

/// Thin facade that delegates to focused managers:
/// - `FolderSanitizer` — folder naming, sanitization, misnamed folder detection
/// - `ContentInstaller` — installing characters, stages, screenpacks from archives/folders
/// - `SelectDefManager` — reading/writing select.def (add, remove, enable/disable, reorder)
///
/// All methods are forwarded to preserve the `ContentManager.shared.xxx()` API for existing callers.
/// New code should prefer calling the specific manager directly.
public final class ContentManager {
    
    // MARK: - Singleton
    
    public static let shared = ContentManager()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - FolderSanitizer delegation
    
    public func sanitizeFolderName(_ name: String) -> String {
        FolderSanitizer.shared.sanitizeFolderName(name)
    }
    
    public func needsSanitization(_ name: String) -> Bool {
        FolderSanitizer.shared.needsSanitization(name)
    }
    
    @discardableResult
    public func sanitizeContentFolder(at folderURL: URL, updateSelectDef: Bool = true, workingDir: URL? = nil) throws -> String? {
        try FolderSanitizer.shared.sanitizeContentFolder(at: folderURL, updateSelectDef: updateSelectDef, workingDir: workingDir)
    }
    
    public func sanitizeAllCharacters(in workingDir: URL) throws -> [(String, String)] {
        try FolderSanitizer.shared.sanitizeAllCharacters(in: workingDir)
    }
    
    public func sanitizeAllStages(in workingDir: URL) throws -> [(String, String)] {
        try FolderSanitizer.shared.sanitizeAllStages(in: workingDir)
    }
    
    public func detectMismatchedCharacterFolder(_ folder: URL) -> String? {
        FolderSanitizer.shared.detectMismatchedCharacterFolder(folder)
    }
    
    public func findMisnamedCharacterFolders(in workingDir: URL) -> [(URL, String)] {
        FolderSanitizer.shared.findMisnamedCharacterFolders(in: workingDir)
    }
    
    @discardableResult
    public func fixMisnamedCharacterFolder(_ folder: URL, suggestedName: String, workingDir: URL) throws -> URL? {
        try FolderSanitizer.shared.fixMisnamedCharacterFolder(folder, suggestedName: suggestedName, workingDir: workingDir)
    }
    
    public func fixAllMisnamedCharacterFolders(in workingDir: URL) throws -> [(String, String)] {
        try FolderSanitizer.shared.fixAllMisnamedCharacterFolders(in: workingDir)
    }
    
    public func renameStage(_ stage: StageInfo, to newName: String) throws {
        try FolderSanitizer.shared.renameStage(stage, to: newName)
    }
    
    public func stageNeedsBetterName(_ stage: StageInfo) -> Bool {
        FolderSanitizer.shared.stageNeedsBetterName(stage)
    }
    
    public func suggestStageName(_ stage: StageInfo) -> String {
        FolderSanitizer.shared.suggestStageName(stage)
    }
    
    // MARK: - ContentInstaller delegation
    
    public func installContent(from archiveURL: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        try ContentInstaller.shared.installContent(from: archiveURL, to: workingDir, overwrite: overwrite)
    }
    
    public func installContentFolder(from folderURL: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        try ContentInstaller.shared.installContentFolder(from: folderURL, to: workingDir, overwrite: overwrite)
    }
    
    public func installScreenpack(from source: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        try ContentInstaller.shared.installScreenpack(from: source, to: workingDir, overwrite: overwrite)
    }
    
    public func redirectScreenpackToGlobalSelectDef(screenpackPath: URL) {
        ContentInstaller.shared.redirectScreenpackToGlobalSelectDef(screenpackPath: screenpackPath)
    }
    
    public func redirectAllScreenpacksToGlobalSelectDef(in workingDir: URL) -> Int {
        ContentInstaller.shared.redirectAllScreenpacksToGlobalSelectDef(in: workingDir)
    }
    
    @available(*, deprecated, message: "Use redirectScreenpackToGlobalSelectDef instead")
    public func syncCharactersToScreenpack(selectDefPath: URL, workingDir: URL) {
        ContentInstaller.shared.syncCharactersToScreenpack(selectDefPath: selectDefPath, workingDir: workingDir)
    }
    
    @available(*, deprecated, message: "Use redirectAllScreenpacksToGlobalSelectDef instead")
    public func syncAllScreenpacks(in workingDir: URL) -> Int {
        ContentInstaller.shared.syncAllScreenpacks(in: workingDir)
    }
    
    public func installCharacter(from source: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        try ContentInstaller.shared.installCharacter(from: source, to: workingDir, overwrite: overwrite)
    }
    
    public func findCharacterDefEntry(charName: String, in charPath: URL) -> String {
        ContentInstaller.shared.findCharacterDefEntry(charName: charName, in: charPath)
    }
    
    public func installStage(from source: URL, to workingDir: URL, overwrite: Bool = false) throws -> String {
        try ContentInstaller.shared.installStage(from: source, to: workingDir, overwrite: overwrite)
    }
    
    public func validateCharacterPortrait(in charPath: URL) -> [String] {
        ContentInstaller.shared.validateCharacterPortrait(in: charPath)
    }
    
    // MARK: - SelectDefManager delegation
    
    public func readCharacterOrder(from workingDir: URL) -> [String] {
        SelectDefManager.shared.readCharacterOrder(from: workingDir)
    }
    
    public func reorderCharacters(_ newOrder: [String], in workingDir: URL) throws {
        try SelectDefManager.shared.reorderCharacters(newOrder, in: workingDir)
    }
    
    public func addCharacterToSelectDef(_ charEntry: String, in workingDir: URL) throws {
        try SelectDefManager.shared.addCharacterToSelectDef(charEntry, in: workingDir)
    }
    
    public func addStageToSelectDef(_ stageName: String, in workingDir: URL) throws {
        try SelectDefManager.shared.addStageToSelectDef(stageName, in: workingDir)
    }
    
    @discardableResult
    public func disableStage(_ stage: StageInfo, in workingDir: URL) throws -> Bool {
        try SelectDefManager.shared.disableStage(stage, in: workingDir)
    }
    
    @discardableResult
    public func enableStage(_ stage: StageInfo, in workingDir: URL) throws -> Bool {
        try SelectDefManager.shared.enableStage(stage, in: workingDir)
    }
    
    public func removeStage(_ stage: StageInfo, in workingDir: URL) throws {
        try SelectDefManager.shared.removeStage(stage, in: workingDir)
    }
    
    public func isStageDisabled(_ stage: StageInfo, in workingDir: URL) -> Bool {
        SelectDefManager.shared.isStageDisabled(stage, in: workingDir)
    }
    
    @discardableResult
    public func disableCharacter(_ character: CharacterInfo, in workingDir: URL) throws -> Bool {
        try SelectDefManager.shared.disableCharacter(character, in: workingDir)
    }
    
    @discardableResult
    public func enableCharacter(_ character: CharacterInfo, in workingDir: URL) throws -> Bool {
        try SelectDefManager.shared.enableCharacter(character, in: workingDir)
    }
    
    public func isCharacterDisabled(_ character: CharacterInfo, in workingDir: URL) -> Bool {
        SelectDefManager.shared.isCharacterDisabled(character, in: workingDir)
    }
    
    public func removeCharacter(_ character: CharacterInfo, in workingDir: URL) throws {
        try SelectDefManager.shared.removeCharacter(character, in: workingDir)
    }
}
