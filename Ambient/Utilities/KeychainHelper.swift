import Foundation
import Security

struct KeychainHelper: Sendable {
    static let shared = KeychainHelper()
    private let serviceName = "com.ambientsocial.app"

    private init() {}

    nonisolated func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(forKey: key)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    nonisolated func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  serviceName,
            kSecAttrAccount:  key,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    nonisolated func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
