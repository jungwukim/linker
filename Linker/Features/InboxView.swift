import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var processor: ItemProcessor
    @Query(sort: \SavedItem.createdAt, order: .reverse) private var items: [SavedItem]

    @State private var selectedFilter: String?
    @State private var pasteError: String?

    private var filters: [String] {
        // Tags + topics across all items, most frequent first.
        var counts: [String: Int] = [:]
        for item in items {
            for value in item.tags + item.topics {
                counts[value, default: 0] += 1
            }
        }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }

    private var visibleItems: [SavedItem] {
        guard let selectedFilter else { return items }
        return items.filter { ($0.tags + $0.topics).contains(selectedFilter) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyInbox(onPaste: paste)
                } else {
                    VStack(spacing: 0) {
                        if !filters.isEmpty {
                            FilterBar(filters: filters, selected: $selectedFilter)
                        }
                        List {
                            ForEach(visibleItems) { item in
                                NavigationLink {
                                    ItemDetailView(item: item, processor: processor)
                                } label: {
                                    ItemRow(item: item)
                                }
                            }
                            .onDelete(perform: delete)
                        }
                    }
                }
            }
            .navigationTitle("보관함")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        paste()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if processor.isWorking {
                        ProgressView()
                    } else {
                        Button {
                            Task { await processor.processPending(context) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .refreshable {
                await processor.processPending(context)
            }
            .alert("붙여넣기", isPresented: .constant(pasteError != nil)) {
                Button("확인") { pasteError = nil }
            } message: {
                Text(pasteError ?? "")
            }
        }
    }

    private func paste() {
        do {
            try PasteboardImporter.importFromClipboard(into: context)
            Task { await processor.processPending(context) }
        } catch {
            pasteError = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        let target = visibleItems
        for index in offsets { context.delete(target[index]) }
        try? context.save()
    }
}

/// Horizontally scrolling tag/topic chips that filter the list.
private struct FilterBar: View {
    let filters: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "전체", isSelected: selected == nil) { selected = nil }
                ForEach(filters, id: \.self) { filter in
                    Chip(title: "#\(filter)", isSelected: selected == filter) {
                        selected = (selected == filter) ? nil : filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private struct Chip: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12),
                                in: Capsule())
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct EmptyInbox: View {
    let onPaste: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("아직 저장된 항목이 없어요", systemImage: "tray")
        } description: {
            Text("유튜브·인스타·스레드·X 등에서 공유 버튼을 눌러\nLinker로 콘텐츠를 보내거나, 링크를 복사한 뒤\n아래 버튼으로 붙여넣어 보세요.")
        } actions: {
            Button {
                onPaste()
            } label: {
                Label("클립보드에서 붙여넣기", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
