import SwiftUI

struct RootView: View {
    private let container: AppContainer
    @State private var selectedTab: RootTab

    init(container: AppContainer) {
        self.container = container
        _selectedTab = State(initialValue: container.appStateRepository.load().selectedTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MoviesPage(container: container)
            }
            .tabItem { Label("Movies", systemImage: "film") }
            .tag(RootTab.movies)

            NavigationStack {
                FavoritesPage(container: container)
            }
            .tabItem {
                Label("Favorites", systemImage: "star")
                    .accessibilityIdentifier("tabs.favorites")
            }
            .tag(RootTab.favorites)
        }
        .onChange(of: selectedTab) { _, newTab in
            var appState = container.appStateRepository.load()
            appState.selectedTab = newTab
            container.appStateRepository.save(appState)
        }
    }
}
