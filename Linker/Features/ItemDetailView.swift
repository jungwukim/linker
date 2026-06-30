import SwiftUI
import SwiftData
import UIKit

struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Bindable var item: SavedItem
    @ObservedObject var processor: ItemProcessor

    private var videoID: String? {
        guard item.platform == .youtube, let url = item.sourceURL else { return nil }
        return TranscriptFetcher.videoID(from: url)
    }

    private var keyPointTimestamps: [Double] {
        item.keyPoints.compactMap { Timestamps.seconds(fromKeyPoint: $0) }
    }

    @State private var frames: [VideoFrame] = []
    @State private var framesLoaded = false

    private func frame(near seconds: Double) -> VideoFrame? {
        frames.min { abs($0.seconds - seconds) < abs($1.seconds - seconds) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let urlString = item.thumbnailURLString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                header

                if !frames.isEmpty {
                    KeyFrameGallery(frames: frames) { seconds in
                        openYouTube(at: seconds)
                    }
                }

                if let summary = item.summary, !summary.isEmpty {
                    section("요약") { Text(summary) }
                }

                if item.status == .failed, let error = item.analysisError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if !item.keyPoints.isEmpty {
                    section(item.platform == .youtube ? "중요 구간" : "핵심 포인트") {
                        keyPointsList
                    }
                }

                if !item.tags.isEmpty {
                    section("태그") { TagWrap(tags: item.tags) }
                }

                if !item.topics.isEmpty {
                    section("주제") { bulletList(item.topics) }
                }

                if !item.entities.isEmpty {
                    section("핵심 키워드") { bulletList(item.entities) }
                }

                if let transcript = item.transcript, !transcript.isEmpty {
                    TranscriptSection(
                        title: item.platform == .youtube ? "전체 스크립트" : "본문",
                        text: transcript
                    )
                }

                if let rawText = item.rawText, !rawText.isEmpty {
                    section("공유된 텍스트") {
                        Text(rawText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .task {
            guard !framesLoaded, let videoID else { return }
            framesLoaded = true
            // On-device first (phone IP, no cookies); cookie-less backend as fallback.
            let direct = await StoryboardFetcher.frames(videoID: videoID, timestamps: keyPointTimestamps)
            if !direct.isEmpty {
                frames = direct
            } else if let response = await YouTubeBackend.fetch(videoID: videoID) {
                frames = YouTubeBackend.videoFrames(response)
            }
        }
        .navigationTitle(item.platform.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await processor.reprocess(item, in: context) }
                } label: {
                    Image(systemName: "sparkles")
                }
                .disabled(processor.isWorking)
            }
        }
    }

    @ViewBuilder
    private var keyPointsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(item.keyPoints, id: \.self) { point in
                if item.platform == .youtube, let seconds = Timestamps.seconds(fromKeyPoint: point) {
                    Button {
                        openYouTube(at: seconds)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            if let frame = frame(near: seconds) {
                                FrameThumbnail(frame: frame, height: 64)
                            } else {
                                Image(systemName: "play.circle.fill").foregroundStyle(.tint)
                            }
                            Text(point)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("• \(point)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func openYouTube(at seconds: Double) {
        guard let videoID,
              let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)&t=\(Int(seconds))s")
        else { return }
        openURL(url)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.displayTitle)
                .font(.title2.bold())

            if let url = item.sourceURL {
                Link(destination: url) {
                    Label(url.host ?? url.absoluteString, systemImage: "link")
                        .lineLimit(1)
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bulletList(_ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(values, id: \.self) { value in
                Text("• \(value)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Full transcript/body. Collapsed by default, and when expanded the text is
/// rendered line-by-line in a LazyVStack so only on-screen lines lay out.
/// A single 10k+ char selectable Text lays out synchronously on the main
/// thread — that was what made both pushing and expanding this view slow.
private struct TranscriptSection: View {
    let title: String
    let text: String
    private let lines: [Line]

    @State private var expanded = false
    @State private var copied = false

    /// Stable identity for each line so the LazyVStack can recycle rows.
    private struct Line: Identifiable {
        let id: Int
        let text: String
    }

    init(title: String, text: String) {
        self.title = title
        self.text = text
        self.lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .enumerated()
            .map { Line(id: $0.offset, text: String($0.element)) }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        UIPasteboard.general.string = text
                        copied = true
                    } label: {
                        Label(copied ? "복사됨" : "복사", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.footnote)
                    }
                    .buttonStyle(.borderless)
                }
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(lines) { line in
                        Text(line.text)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            Text(title).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
