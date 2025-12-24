import XCTest
@testable import Sentinel

final class KeychainManagerTests: XCTestCase {
    let testService = "com.sentinel.test"
    
    override func tearDown() {
        // Cleanup test keychain entries
    }
    
    func testSaveAndRetrieveToken() {
        let token = "test-token-\(UUID().uuidString)"
        let saved = KeychainHelper.saveToken(token)
        XCTAssertTrue(saved, "Should save token")
        
        let retrieved = KeychainHelper.getToken()
        XCTAssertEqual(retrieved, token, "Should retrieve same token")
    }
    
    func testGenerateToken() {
        let token1 = KeychainHelper.generateToken()
        let token2 = KeychainHelper.generateToken()
        
        XCTAssertEqual(token1.count, 32)
        XCTAssertNotEqual(token1, token2, "Tokens should be unique")
    }
}

extension KeychainHelper {
    static func generateToken(length: Int = 32) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
