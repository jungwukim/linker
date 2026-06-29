import UIKit
import UniformTypeIdentifiers
import SwiftData

/// Receives content from the iOS Share Sheet (URL, text, or image), writes a
/// lightweight pending `SavedItem` into the shared store, and dismisses.
/// Heavy work (metadata fetch + AI analysis) happens later in the main app.
final class ShareViewController: UIViewController {

    private let card = UIView()
    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        setupCard()
        Task { await handleShare() }
    }

    private func setupCard() {
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        label.text = "Linker에 저장 중…"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
        ])
    }

    private func handleShare() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap { $0.attachments }
            .flatMap { $0 } ?? []

        var url: URL?
        var text: String?

        for provider in providers {
            if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                url = await loadURL(provider)
            }
            if text == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                text = await loadText(provider)
            }
        }

        await persist(url: url, text: text)
        await showSavedThenClose()
    }

    private func loadURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }

    private func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? String)
            }
        }
    }

    @MainActor
    private func persist(url: URL?, text: String?) {
        guard url != nil || (text?.isEmpty == false) else { return }
        let platform = Platform.infer(fromURL: url, hasText: text?.isEmpty == false)
        let item = SavedItem(
            sourceURLString: url?.absoluteString,
            rawText: text,
            platform: platform,
            status: .pending
        )
        let context = SharedStore.container.mainContext
        context.insert(item)
        try? context.save()
    }

    @MainActor
    private func showSavedThenClose() async {
        label.text = "Linker에 저장됨 ✓"
        try? await Task.sleep(nanoseconds: 600_000_000)
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
