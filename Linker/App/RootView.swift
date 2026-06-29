import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var processor = ItemProcessor()

    var body: some View {
        TabView {
            InboxView(processor: processor)
                .tabItem { Label("보관함", systemImage: "tray.full") }

            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
        .task {
            await processor.processPending(context)
        }
    }
}
