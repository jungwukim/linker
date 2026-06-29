import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var items: [SavedItem]
    @State private var query = ""

    private var results: [SavedItem] {
        SearchService.search(query: query, in: items)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "검색할 항목이 없어요",
                        systemImage: "magnifyingglass",
                        description: Text("콘텐츠를 저장하면 한곳에서 찾아볼 수 있어요.")
                    )
                } else if !query.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { item in
                        NavigationLink {
                            ItemDetailView(item: item, processor: ItemProcessor())
                        } label: {
                            ItemRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("검색")
            .searchable(text: $query, prompt: "제목, 태그, 주제, 키워드로 검색")
        }
    }
}
