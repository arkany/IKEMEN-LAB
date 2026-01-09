import XCTest
@testable import IKEMEN_Lab

/// Tests for SFFParser signature validation and error handling
/// Note: Full sprite extraction tests require real SFF files
final class SFFParserTests: XCTestCase {
    
    // MARK: - Signature Validation Tests
    
    func testInvalidSignatureReturnsError() {
        // Given - Random data that isn't an SFF file
        let invalidData = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                                0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
                                0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
                                0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
                                0x20, 0x21, 0x22, 0x23])
        
        // When
        let result = SFFParser.extractPortraitResult(from: invalidData)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure for invalid signature")
        case .failure(let error):
            XCTAssertTrue(isInvalidSignatureError(error))
        }
    }
    
    func testFileTooSmallReturnsError() {
        // Given - Data smaller than minimum header size
        let tinyData = Data([0x00, 0x01, 0x02, 0x03])
        
        // When
        let result = SFFParser.extractPortraitResult(from: tinyData)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure for file too small")
        case .failure(let error):
            XCTAssertTrue(isFileTooSmallError(error))
        }
    }
    
    func testEmptyDataReturnsError() {
        // Given
        let emptyData = Data()
        
        // When
        let result = SFFParser.extractPortraitResult(from: emptyData)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure for empty data")
        case .failure(let error):
            XCTAssertTrue(isFileTooSmallError(error))
        }
    }
    
    func testFileNotFoundReturnsError() {
        // Given
        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/path/to/file.sff")
        
        // When
        let result = SFFParser.extractPortraitResult(from: nonexistentURL)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure for file not found")
        case .failure(let error):
            XCTAssertTrue(isFileNotFoundError(error))
        }
    }
    
    // MARK: - Error Description Tests
    
    func testSFFErrorDescriptions() {
        XCTAssertNotNil(SFFError.fileTooSmall.errorDescription)
        XCTAssertNotNil(SFFError.invalidSignature.errorDescription)
        XCTAssertNotNil(SFFError.unsupportedVersion(3).errorDescription)
        XCTAssertNotNil(SFFError.spriteNotFound(group: 9000, image: 0).errorDescription)
        XCTAssertNotNil(SFFError.corruptedData("test").errorDescription)
        XCTAssertNotNil(SFFError.decodingFailed("test").errorDescription)
        XCTAssertNotNil(SFFError.invalidDimensions(width: -1, height: 100).errorDescription)
        
        // Verify descriptions contain useful info
        XCTAssertTrue(SFFError.unsupportedVersion(3).errorDescription!.contains("3"))
        XCTAssertTrue(SFFError.spriteNotFound(group: 9000, image: 0).errorDescription!.contains("9000"))
    }
    
    // MARK: - Version Detection Tests (with valid header structure)
    
    func testValidSFFv1SignatureAccepted() {
        // Given - Valid SFFv1 header structure
        // "ElecbyteSpr\0" (12 bytes) + version bytes
        var data = Data("ElecbyteSpr\0".utf8)
        // Pad to 16 bytes for version info
        data.append(contentsOf: [0x00, 0x01, 0x00, 0x01])  // verlo3, verlo2, verlo1, verhi (v1)
        // Add more data to pass minimum size check
        data.append(contentsOf: Array(repeating: UInt8(0), count: 20))
        
        // When
        let result = SFFParser.extractPortraitResult(from: data)
        
        // Then - Should fail with sprite not found (valid file, but no sprites)
        // rather than invalid signature
        switch result {
        case .success:
            XCTFail("Should not succeed with minimal header")
        case .failure(let error):
            XCTAssertFalse(isInvalidSignatureError(error), "Header should be recognized as valid SFF")
        }
    }
    
    func testValidSFFv2SignatureAccepted() {
        // Given - Valid SFFv2 header structure
        var data = Data("ElecbyteSpr\0".utf8)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x02])  // verlo3, verlo2, verlo1, verhi (v2)
        data.append(contentsOf: Array(repeating: UInt8(0), count: 20))
        
        // When
        let result = SFFParser.extractPortraitResult(from: data)
        
        // Then - Should fail with something other than invalid signature
        switch result {
        case .success:
            XCTFail("Should not succeed with minimal header")
        case .failure(let error):
            XCTAssertFalse(isInvalidSignatureError(error), "Header should be recognized as valid SFF")
        }
    }
    
    // MARK: - Helper Methods for Error Matching
    
    private func isInvalidSignatureError(_ error: SFFError) -> Bool {
        if case .invalidSignature = error { return true }
        return false
    }
    
    private func isFileTooSmallError(_ error: SFFError) -> Bool {
        if case .fileTooSmall = error { return true }
        return false
    }
    
    private func isFileNotFoundError(_ error: SFFError) -> Bool {
        if case .fileNotFound = error { return true }
        return false
    }
}
