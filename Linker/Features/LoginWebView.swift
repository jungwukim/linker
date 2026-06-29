import SwiftUI
import WebKit

/// Owns a WKWebView with the persistent (default) data store so a web login
/// survives app restarts, and can snapshot its cookies into a `Cookie` header.
@MainActor
final class LoginModel: ObservableObject {
    let webView: WKWebView

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default() // persistent
        webView = WKWebView(frame: .zero, configuration: configuration)
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    /// Snapshot cookies for the given domains into a "name=value; ..." header.
    func captureCookieHeader(domains: [String]) async -> String {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            store.getAllCookies { continuation.resume(returning: $0) }
        }
        let relevant = cookies.filter { cookie in
            domains.contains { cookie.domain.contains($0) }
        }
        return relevant.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// In-app login sheet: the user signs in normally; on "완료" we capture the
/// session cookies for the service and store them.
struct LoginSheet: View {
    let service: WebService
    var onDone: () -> Void

    @StateObject private var model = LoginModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebViewContainer(webView: model.webView)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("\(service.displayName) 로그인")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("완료") { Task { await save() } }
                    }
                }
                .onAppear { model.load(service.loginURL) }
        }
    }

    private func save() async {
        let header = await model.captureCookieHeader(domains: service.cookieDomains)
        if !header.isEmpty {
            CookieStore.setCookieHeader(header, for: service)
        }
        onDone()
        dismiss()
    }
}
