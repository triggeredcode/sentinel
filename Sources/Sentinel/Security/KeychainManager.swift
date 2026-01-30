import Foundation
import Security

/// Manages secure token storage in macOS Keychain
final class KeychainManager: Sendable {
    static let shared = KeychainManager()
    
    private let service = "com.sentinel.auth"
    private let account = "auth-token"
    
    private init() {}
    
    /// Retrieves the authentication token from Keychain
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    /// Stores the authentication token in Keychain
    @discardableResult
    func setToken(_ token: String) -> Bool {
        deleteToken()
        
        guard let tokenData = token.data(using: .utf8) else {
            Logger.shared.log("Failed to encode token", level: .error)
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            Logger.shared.log("Token saved to Keychain")
            return true
        } else {
            Logger.shared.log("Keychain write failed: \(status)", level: .error)
            return false
        }
    }
    
    /// Deletes the authentication token from Keychain
    @discardableResult
    func deleteToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Checks if a token exists
    func hasToken() -> Bool {
        return getToken() != nil
    }
    
    /// Generates a cryptographically secure random token
    static func generateToken(length: Int = 32) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var token = ""
        var randomBytes = [UInt8](repeating: 0, count: length)
        
        let result = SecRandomCopyBytes(kSecRandomDefault, length, &randomBytes)
        
        if result == errSecSuccess {
            for byte in randomBytes {
                let index = Int(byte) % characters.count
                token.append(characters[characters.index(characters.startIndex, offsetBy: index)])
            }
        } else {
            for _ in 0..<length {
                token.append(characters.randomElement()!)
            }
        }
        
        return token
    }
}
