import SwiftUI

struct MoviesPage: View {
    private let container: AppContainer
    @StateObject private var viewModel: MoviesViewModel

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: MoviesViewModel(
                appStateRepository: container.appStateRepository
            )
        )
    }

    var body: some View {
        ThreeRegionPage(
            isFooterVisible: viewModel.isLoading || viewModel.errorMessage != nil,
            headerContent: {
                VStack(alignment: .leading) {
                    Text("Popular Movies").font(.title2).bold()
                    TextField("Search loaded movies", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Search loaded movies")
                }
            },
            pageContent: {
                if viewModel.movies.isEmpty && viewModel.isLoading {
                    ProgressView("Loading movies…")
                } else if viewModel.movies.isEmpty, let error = viewModel.errorMessage {
                    ContentUnavailableView("Movies unavailable", systemImage: "wifi.exclamationmark", description: Text(error))
                } else if viewModel.visibleMovies.isEmpty {
                    ContentUnavailableView(
                        viewModel.searchText.isEmpty ? "No movies available" : "No matching movies",
                        systemImage: "film",
                        description: Text(viewModel.searchText.isEmpty ? "Try again later." : "Try another title.")
                    )
                } else {
                    List(Array(viewModel.visibleMovies.enumerated()), id: \.element.id) { index, movie in
                        NavigationLink(value: movie) {
                            MovieRow(movie: movie)
                        }
                        .task { await viewModel.loadNextPageIfNeeded(lastVisibleIndex: index) }
                    }
                }
            },
            footerContent: {
                HStack {
                    if viewModel.isLoading { ProgressView() }
                    Text(viewModel.errorMessage ?? "Loading page \(viewModel.currentPage + 1)…")
                    Spacer()
                    if viewModel.errorMessage != nil {
                        Button("Retry") { Task { await viewModel.retry() } }
                    }
                }
            }
        )
        .navigationDestination(for: Movie.self) { movie in
            MovieDetailsPage(movie: movie, container: container)
        }
        .task { await viewModel.loadInitialPage() }
    }
}
