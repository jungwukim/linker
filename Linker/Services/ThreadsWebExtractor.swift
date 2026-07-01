import Foundation
import UIKit
import WebKit

/// Extracts a full Threads thread (the author's connected chain of posts plus
/// their media) by loading the public post in an offscreen WKWebView and letting
/// Threads' own JavaScript render it, then scraping the DOM.
///
/// Why a WebView: the post page HTML carries only the first post's text + one
/// image; the connected posts and any carousel/video media are fetched after
/// load via Meta's private GraphQL (whose `doc_id` rotates constantly). Letting
/// the page's own JS make that call sidesteps the rotating id entirely. Runs
/// on-device, no login required for public posts.
@MainActor
final class ThreadsWebExtractor: NSObject, WKNavigationDelegate {

    struct Result {
        /// Connected posts joined in order (oldest first), separator between them.
        var text: String
        /// De-duplicated media URLs (carousel images + video posters) across the chain.
        var mediaURLs: [String]
    }

    /// Loads `url` and returns the chain text + media, or nil on timeout/failure.
    static func extract(url: URL, timeout: TimeInterval = 14) async -> Result? {
        await ThreadsWebExtractor().run(url: url, timeout: timeout)
    }

    private var webView: WKWebView?

    private func run(url: URL, timeout: TimeInterval) async -> Result? {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 430, height: 2400), configuration: config)
        // Desktop Safari UA: matches the rendering path verified to expose the
        // whole thread without an app-install interstitial.
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        wv.navigationDelegate = self
        attach(wv)
        webView = wv

        wv.load(URLRequest(url: url))

        let deadline = Date().addingTimeInterval(timeout)
        var best: Payload?
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 800_000_000)
            // Nudge lazy media into loading, then scrape.
            _ = try? await wv.evaluateJavaScript("window.scrollTo(0, document.body.scrollHeight); 1")
            guard let json = try? await wv.evaluateJavaScript(Self.extractionJS) as? String,
                  let data = json.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(Payload.self, from: data)
            else { continue }
            let usable = payload.posts.filter { !$0.text.isEmpty || !$0.images.isEmpty }
            if !usable.isEmpty {
                best = payload
                // Settle: once media has appeared, give one more cycle to pull
                // the rest of a carousel, then stop.
                if usable.contains(where: { !$0.images.isEmpty }) { break }
            }
        }
        cleanup()
        guard let payload = best else { return nil }
        return assemble(payload)
    }

    private func assemble(_ payload: Payload) -> Result? {
        let posts = payload.posts.filter { !$0.text.isEmpty || !$0.images.isEmpty }
        guard !posts.isEmpty else { return nil }
        let text = posts.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n\n———\n\n")
        var media: [String] = []
        var seen = Set<String>()
        for post in posts {
            for url in post.images + post.videos where seen.insert(url).inserted {
                media.append(url)
            }
        }
        return Result(text: text, mediaURLs: media)
    }

    // MARK: Offscreen hosting

    private func attach(_ wv: WKWebView) {
        wv.isHidden = true
        wv.isUserInteractionEnabled = false
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        (scene?.keyWindow ?? scene?.windows.first)?.addSubview(wv)
    }

    private func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.removeFromSuperview()
        webView = nil
    }

    // MARK: Decoding

    private struct Payload: Decodable {
        var author: String?
        var posts: [Post]
        struct Post: Decodable {
            var text: String
            var images: [String]
            var videos: [String]
        }
    }

    /// Scrapes the author's connected chain (the leading run of same-author post
    /// containers, stopping at the first reply by someone else). Post text drops
    /// author/date links; media keeps content images (t51.82787 bucket) and video
    /// posters, excluding avatars (t51.2885 bucket).
    private static let extractionJS = """
    (function(){
      try {
        var mainAuthor = location.pathname.split('/')[1] || '';
        var containers = Array.prototype.slice.call(
          document.querySelectorAll('div[data-pressable-container]'));
        var chain = [];
        for (var k = 0; k < containers.length; k++) {
          var c = containers[k];
          var a = c.querySelector('a[href^="/@"]');
          var handle = a ? a.getAttribute('href').split('/')[1] : null;
          if (handle !== mainAuthor) break;
          var spans = Array.prototype.slice.call(c.querySelectorAll('span[dir="auto"]'));
          var parts = [];
          for (var j = 0; j < spans.length; j++) {
            if (spans[j].closest('a')) continue;
            var t = (spans[j].innerText || '').trim();
            if (!t || t === '번역하기' || t === '작성자' || t === '·') continue;
            if (/^\\d{4}-\\d{2}-\\d{2}$/.test(t)) continue;
            if (/^\\d+\\s*[smhdwy]$/.test(t)) continue;
            parts.push(t);
          }
          var text = parts.join(' ').replace(/\\s+/g, ' ').trim();
          var imgSeen = {}, imgs = [];
          Array.prototype.slice.call(c.querySelectorAll('img')).forEach(function(i) {
            var s = i.src || '';
            if (s.indexOf('cdninstagram') >= 0 && s.indexOf('t51.82787') >= 0 && !imgSeen[s]) {
              imgSeen[s] = 1; imgs.push(s);
            }
          });
          var vids = [];
          Array.prototype.slice.call(c.querySelectorAll('video')).forEach(function(v) {
            var s = v.poster || v.src || '';
            if (s) vids.push(s);
          });
          chain.push({ handle: handle, text: text, images: imgs, videos: vids });
        }
        return JSON.stringify({ author: mainAuthor, posts: chain });
      } catch (e) {
        return JSON.stringify({ posts: [] });
      }
    })()
    """
}
