import SwiftUI

struct FavoritesPage: View {
    private let container: AppContainer
    @StateObject private var viewModel: FavoritesViewModel

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(favoriteRepository: container.favoriteRepository))
    }

    var body: some View {
        ThreeRegionPage(
            isFooterVisible: viewModel.isLoading || (viewModel.errorMessage != nil && !viewModel.movies.isEmpty),
            headerContent: { Text("Favorites").font(.title2).bold() },
            pageContent: {
                if viewModel.movies.isEmpty, let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Favorites unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.movies.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text("Add a movie from its details page.")
                    )
                } else {
                    List(viewModel.movies) { movie in
                        NavigationLink(value: movie) { MovieRow(movie: movie) }
                            .accessibilityIdentifier("favorites.row.\(movie.id)")
                    }
                }
            },
            footerContent: { Text(viewModel.errorMessage ?? "Loading saved movies…") }
        )
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailsPage(movie: movie, container: container)
        }
        .task { await viewModel.refresh() }
    }
}
