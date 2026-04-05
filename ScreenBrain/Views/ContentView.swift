import SwiftUI
import SwiftData

// MARK: - LayoutConstants

enum LayoutConstants {
    static let gridSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 10
    static let thumbnailSize = CGSize(width: 200, height: 200)
}

// MARK: - ViewMode

enum ViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    @Bindable var aiService: AIService

    @State private var photosService = PhotosService()
    @State private var searchService = SearchService()
    @State private var libraryViewModel = LibraryViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var selectedTab: SidebarTab = .library

    enum SidebarTab: String, CaseIterable, Identifiable {
        case library = "Library"
        case search = "Search"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .library: return "photo.on.rectangle.angled"
            case .search: return "magnifyingglass"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
                    .font(.system(size: 13, weight: .medium))
            }
            .navigationTitle("ScreenBrain")
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selectedTab {
                case .library:
                    LibraryView(
                        viewModel: libraryViewModel,
                        photosService: photosService,
                        aiService: aiService
                    )
                case .search:
                    SearchView(
                        viewModel: searchViewModel,
                        searchService: searchService
                    )
                case .settings:
                    SettingsView(aiService: aiService)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .frame(minWidth: 960, minHeight: 640)
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .importScreenshots)) { _ in
            selectedTab = .library
        }
        #endif
    }
}

#Preview {
    ContentView(aiService: AIService())
        .modelContainer(for: Screenshot.self, inMemory: true)
}
