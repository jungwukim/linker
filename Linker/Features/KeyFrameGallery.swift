import SwiftUI
import UIKit

/// Horizontal gallery of storyboard frames. Tapping a frame opens YouTube at
/// that time. Pure view — the parent owns fetching the frames.
struct KeyFrameGallery: View {
    let frames: [VideoFrame]
    let onTap: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("구간 미리보기").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(frames) { frame in
                        Button { onTap(frame.seconds) } label: {
                            FrameThumbnail(frame: frame, height: 120, showTimestamp: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Downloads the sprite sheet (cached) and crops out one frame's rect.
struct FrameThumbnail: View {
    let frame: VideoFrame
    var height: CGFloat = 120
    var showTimestamp: Bool = false

    @State private var image: UIImage?

    private var width: CGFloat {
        let aspect = frame.rect.height > 0 ? frame.rect.width / frame.rect.height : 16.0 / 9.0
        return height * aspect
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(Color.secondary.opacity(0.12)).overlay(ProgressView())
            }
            if showTimestamp {
                Text(Timestamps.label(frame.seconds))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(6)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task { await load() }
    }

    private func load() async {
        guard image == nil,
              let sheet = await SheetImageCache.shared.image(for: frame.sheetURL),
              let cropped = sheet.cgImage?.cropping(to: frame.rect) else { return }
        image = UIImage(cgImage: cropped)
    }
}

/// Caches downloaded sprite sheets so frames sharing a sheet download it once.
private actor SheetImageCache {
    static let shared = SheetImageCache()
    private var cache: [URL: UIImage] = [:]

    func image(for url: URL) async -> UIImage? {
        if let cached = cache[url] { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        cache[url] = image
        return image
    }
}
