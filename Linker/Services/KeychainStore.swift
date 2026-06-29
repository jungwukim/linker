import Foundation
import Security

/// Per-provider API key storage in the Keychain (one entry per provider, so the
/// user can register Claude / OpenAI / Gemini keys independently).
enum KeychainStore {
    private static let service = "dev.linker.app"

    static func apiKey(for provider: LLMProvider) -> String? {
        read(account: account(provider))
    }

    static func setAPIKey(_ value: String?, for provider: LLMProvider) {
        let key = account(provider)
        if let value, !value.isEmpty { save(value, account: key) }
        else { delete(account: key) }
    }

    private static func account(_ provider: LLMProvider) -> String {
        "\(provider.rawValue)-api-key"
    }

    // Generic secret storage (used for service-login cookies too).
    static func value(account: String) -> String? { read(account: account) }

    static func setValue(_ value: String?, account: String) {
        if let value, !value.isEmpty { save(value, account: account) } else { delete(account: account) }
    }

    private static func save(_ value: String, account: String) {
        delete(account: account)
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
