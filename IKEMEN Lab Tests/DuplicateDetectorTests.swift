import XCTest
@testable import IKEMEN_Lab

final class DuplicateDetectorTests: XCTestCase {
    
    func testSameNameDifferentAuthorsNotDuplicates() throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let charA = try makeCharacter(
            name: "Omega Red",
            author: "Cyanide",
            versionDate: "03/03/2010",
            folderName: "OmegaRed_Cyanide",
            root: tempRoot
        )
        
        let charB = try makeCharacter(
            name: "Omega Red",
            author: "ZVitor",
            versionDate: "04/14/2001",
            folderName: "OmegaRed_ZVitor",
            root: tempRoot
        )
        
        let duplicates = DuplicateDetector.findDuplicateCharacters([charA, charB])
        XCTAssertTrue(duplicates.isEmpty, "Different authors should not be flagged as duplicates.")
    }
    
    private func makeCharacter(
        name: String,
        author: String,
        versionDate: String,
        folderName: String,
        root: URL
    ) throws -> CharacterInfo {
        let folderURL = root.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let defURL = folderURL.appendingPathComponent("\(folderName).def")
        let contents = """
        [Info]
        name = \(name)
        author = \(author)
        versiondate = \(versionDate)
        """
        try contents.write(to: defURL, atomically: true, encoding: .utf8)
        
        return CharacterInfo(directory: folderURL, defFile: defURL)
    }
}
