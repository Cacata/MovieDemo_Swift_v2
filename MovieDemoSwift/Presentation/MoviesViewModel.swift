import Combine
import Dependencies
import Foundation

@MainActor
final class MoviesViewModel: ObservableObject {
    @Published private(set) var movies: [Movie] = []
    @Published var searchText = ""
    @Published private(set) var visibleMovies: [Movie] = []
    @Published private(set) var currentPage = 0
    @Published private(set) var totalPages = 1
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Dependency(\.movieFeedClient) private var movieFeedClient
    private let appStateRepository: AppStateRepository
    private var searchSubscription: AnyCancellable?

    init(appStateRepository: AppStateRepository) {
        self.appStateRepository = appStateRepository
        searchSubscription = $searchText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .prepend("")
            .removeDuplicates()
            .combineLatest($movies)
            .map { query, movies in
                let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return movies }
                return movies.filter { $0.title.localizedCaseInsensitiveContains(text) }
            }
            .sink { [weak self] in self?.visibleMovies = $0 }
    }

    func loadInitialPage() async {
        guard movies.isEmpty, !isLoading else { return }
        await loadPage(1)
    }

    func retry() async {
        let retryPage = currentPage == 0 ? 1 : currentPage + 1
        await loadPage(retryPage)
    }

    func loadNextPageIfNeeded(lastVisibleIndex: Int) async {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard MoviePolicies.shouldLoadNextPage(
            lastVisibleIndex: lastVisibleIndex,
            itemCount: movies.count,
            isLoading: isLoading,
            currentPage: currentPage,
            totalPages: totalPages
        ) else { return }
        await loadPage(currentPage + 1)
    }

    private func loadPage(_ pageNumber: Int) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let page = try await movieFeedClient.popularMovies(pageNumber)
            movies = MoviePolicies.appendingUnique(existingMovies: movies, newMovies: page.movies)
            currentPage = page.pageNumber
            totalPages = page.totalPages
            var appState = appStateRepository.load()
            appState.lastSuccessfulPage = page.pageNumber
            appStateRepository.save(appState)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
