import Foundation

/// A content service the user can log into (via in-app web login) so Linker can
/// fetch authenticated content reliably. Only YouTube is wired into a fetcher for
/// now; the others are scaffolded and shown as "coming soon".
enum WebService: String, CaseIterable, Identifiable {
    case youtube
    case instagram
    case x
    case threads
    case facebook

    var id: String { rawValue }

    /// Whether logging in currently changes behavior (a fetcher uses its cookies).
    var isAvailable: Bool { self == .youtube }

    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .instagram: return "Instagram"
        case .x: return "X"
        case .threads: return "Threads"
        case .facebook: return "Facebook"
        }
    }

    var symbolName: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .x: return "bird.fill"
        case .threads: return "at"
        case .facebook: return "person.2.fill"
        }
    }

    var loginURL: URL {
        switch self {
        case .youtube: return URL(string: "https://www.youtube.com/")!
        case .instagram: return URL(string: "https://www.instagram.com/accounts/login/")!
        case .x: return URL(string: "https://x.com/login")!
        case .threads: return URL(string: "https://www.threads.net/login")!
        case .facebook: return URL(string: "https://www.facebook.com/login/")!
        }
    }

    /// Cookie domains to capture for this service.
    var cookieDomains: [String] {
        switch self {
        case .youtube: return ["youtube.com", "google.com"]
        case .instagram: return ["instagram.com"]
        case .x: return ["x.com", "twitter.com"]
        case .threads: return ["threads.net", "instagram.com"]
        case .facebook: return ["facebook.com"]
        }
    }
}
