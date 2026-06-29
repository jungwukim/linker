import SwiftUI

/// Compact list row shared by the Inbox and Search screens.
struct ItemRow: View {
    let item: SavedItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Thumbnail(item: item)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(item.platform.displayName)
                    Text("·")
                    Text(item.createdAt, style: .date)
                    if item.status != .done {
                        Text("·")
                        StatusBadge(status: item.status)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !item.tags.isEmpty {
                    TagWrap(tags: Array(item.tags.prefix(4)))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// 48×48 leading thumbnail — async-loads the item's image, falling back to the
/// platform glyph while loading or when there's no image.
struct Thumbnail: View {
    let item: SavedItem

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: item.platform.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
        }
    }

    var body: some View {
        Group {
            if let urlString = item.thumbnailURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatusBadge: View {
    let status: ItemStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .pending: return .secondary
        case .analyzing: return .blue
        case .done: return .green
        case .failed: return .red
        }
    }
}

/// Simple flowing tag chips.
struct TagWrap: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
