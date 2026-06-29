import Foundation

/// Stores per-service session cookies (captured at web login) in the Keychain.
/// These are sensitive — kept on-device only and sent as the `Cookie` header on
/// that service's content requests.
enum CookieStore {
    static func cookieHeader(for service: WebService) -> String? {
        let value = KeychainStore.value(account: account(service))
        return (value?.isEmpty == false) ? value : nil
    }

    static func setCookieHeader(_ header: String?, for service: WebService) {
        KeychainStore.setValue(header, account: account(service))
    }

    static func isLoggedIn(_ service: WebService) -> Bool {
        cookieHeader(for: service) != nil
    }

    private static func account(_ service: WebService) -> String {
        "cookies-\(service.rawValue)"
    }
}
