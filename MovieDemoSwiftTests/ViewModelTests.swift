import Dependencies
import XCTest
@testable import MovieDemoSwift

@MainActor
final class ViewModelTests: XCTestCase {
    func testLoadingFlagRemainsTrueWhileRequestIsPending() async {
        let pending = PausedFeed()
        let model = withDependencies {
            $0.movieFeedClient = MovieFeedClient(popularMovies: { _ in try await pending.load() })
        } operation: {
            MoviesViewModel(appStateRepository: FakeAppStateRepository())
        }

        let task = Task { await model.loadInitialPage() }
        await pending.waitUntilStarted()
        XCTAssertTrue(model.isLoading)
        XCTAssertTrue(model.movies.isEmpty)

        await pending.resume(with: page(1, total: 1, movies: [movie(1)]))
        await task.value
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.movies.map(\.id), [1])
    }

    func testFirstLoadPublishesMoviesAndPageMetadata() async {
        let feed = FakeFeed(results: [.success(page(1, total: 2, movies: [movie(1)]))])
        let state = FakeAppStateRepository()
        let model = makeMoviesModel(feed: feed, state: state)

        await model.loadInitialPage()
        await model.loadInitialPage()

        XCTAssertEqual(model.movies.map(\.id), [1])
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertEqual(model.totalPages, 2)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(state.load().lastSuccessfulPage, 1)
        let requests = await feed.requests
        XCTAssertEqual(requests, [1])
    }

    func testPaginationAppendsUniqueMovies() async {
        let feed = FakeFeed(results: [
            .success(page(1, total: 2, movies: [movie(1), movie(2)])),
            .success(page(2, total: 2, movies: [movie(2), movie(3)])),
        ])
        let model = makeMoviesModel(feed: feed)
        await model.loadInitialPage()
        await model.loadNextPageIfNeeded(lastVisibleIndex: 1)

        XCTAssertEqual(model.movies.map(\.id), [1, 2, 3])
        XCTAssertEqual(model.currentPage, 2)
        let requests = await feed.requests
        XCTAssertEqual(requests, [1, 2])
    }

    func testRetryAfterFailureKeepsPreviousContent() async {
        let feed = FakeFeed(results: [
            .success(page(1, total: 2, movies: [movie(1)])),
            .failure(FakeError.failed),
            .success(page(2, total: 2, movies: [movie(2)])),
        ])
        let model = makeMoviesModel(feed: feed)
        await model.loadInitialPage()
        await model.loadNextPageIfNeeded(lastVisibleIndex: 0)
        XCTAssertEqual(model.movies.map(\.id), [1])
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.currentPage, 1)

        await model.retry()
        XCTAssertEqual(model.movies.map(\.id), [1, 2])
        XCTAssertNil(model.errorMessage)
        let requests = await feed.requests
        XCTAssertEqual(requests, [1, 2, 2])
    }

    func testEmptyAndErrorResultsStayDistinct() async {
        let empty = makeMoviesModel(feed: FakeFeed(results: [.success(page(1, total: 1, movies: []))]))
        await empty.loadInitialPage()
        XCTAssertTrue(empty.movies.isEmpty)
        XCTAssertNil(empty.errorMessage)

        let failed = makeMoviesModel(feed: FakeFeed(results: [.failure(FakeError.failed)]))
        await failed.loadInitialPage()
        XCTAssertTrue(failed.movies.isEmpty)
        XCTAssertNotNil(failed.errorMessage)
    }

    func testSearchPublishesDebouncedTitleMatches() async throws {
        let feed = FakeFeed(results: [.success(page(1, total: 1, movies: [
            Movie(id: 1, title: "Alien", overview: "", posterPath: nil, backdropPath: nil,
                  releaseDate: nil, voteAverage: 7),
            Movie(id: 2, title: "Interstellar", overview: "", posterPath: nil, backdropPath: nil,
                  releaseDate: nil, voteAverage: 7),
        ]))])
        let model = makeMoviesModel(feed: feed)
        await model.loadInitialPage()
        XCTAssertEqual(model.visibleMovies.count, 2)

        model.searchText = "Al"
        model.searchText = "Alien"
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(model.visibleMovies.map(\.title), ["Alien"])
    }

    func testFavoriteAddAndRemoveUseRepository() async {
        let favorites = FakeFavoriteRepository()
        let model = MovieDetailsViewModel(
            movie: movie(1), movieRepository: FakeMovieRepository(),
            trailerRepository: FakeTrailerRepository(), favoriteRepository: favorites
        )
        await model.load()
        XCTAssertFalse(model.isFavorite)

        await model.toggleFavorite()
        XCTAssertTrue(model.isFavorite)
        let afterAdd = await favorites.ids
        XCTAssertEqual(afterAdd, [1])

        await model.toggleFavorite()
        XCTAssertFalse(model.isFavorite)
        let afterRemove = await favorites.ids
        XCTAssertTrue(afterRemove.isEmpty)
    }

    func testFavoriteFailureLeavesPublishedValueUnchanged() async {
        let favorites = FakeFavoriteRepository(shouldFailSave: true)
        let model = MovieDetailsViewModel(
            movie: movie(1), movieRepository: FakeMovieRepository(),
            trailerRepository: FakeTrailerRepository(), favoriteRepository: favorites
        )
        await model.toggleFavorite()
        XCTAssertFalse(model.isFavorite)
        XCTAssertNotNil(model.errorMessage)
    }

    private func makeMoviesModel(
        feed: FakeFeed,
        state: FakeAppStateRepository = FakeAppStateRepository()
    ) -> MoviesViewModel {
        withDependencies {
            $0.movieFeedClient = MovieFeedClient(popularMovies: { page in try await feed.load(page) })
        } operation: {
            MoviesViewModel(appStateRepository: state)
        }
    }

    private func page(_ number: Int, total: Int, movies: [Movie]) -> MoviePage {
        MoviePage(movies: movies, pageNumber: number, totalPages: total)
    }

    private func movie(_ id: Int) -> Movie {
        Movie(id: id, title: "Movie \(id)", overview: "Overview", posterPath: nil,
              backdropPath: nil, releaseDate: "2026-01-01", voteAverage: 7)
    }
}

private enum FakeError: Error { case failed }

private actor FakeFeed {
    private var results: [Result<MoviePage, Error>]
    private(set) var requests: [Int] = []

    init(results: [Result<MoviePage, Error>]) { self.results = results }

    func load(_ page: Int) throws -> MoviePage {
        requests.append(page)
        return try results.removeFirst().get()
    }
}

private actor PausedFeed {
    private var pending: CheckedContinuation<MoviePage, Error>?
    private var started: CheckedContinuation<Void, Never>?

    func load() async throws -> MoviePage {
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { continuation in started = continuation }
    }

    func resume(with page: MoviePage) {
        pending?.resume(returning: page)
        pending = nil
    }
}

private final class FakeAppStateRepository: AppStateRepository, @unchecked Sendable {
    private var state = AppState()
    func load() -> AppState { state }
    func save(_ state: AppState) { self.state = state }
}

private actor FakeFavoriteRepository: FavoriteRepository {
    private(set) var ids = Set<Int>()
    let shouldFailSave: Bool
    init(shouldFailSave: Bool = false) { self.shouldFailSave = shouldFailSave }
    func favorites() throws -> [Movie] { [] }
    func isFavorite(movieID: Int) throws -> Bool { ids.contains(movieID) }
    func saveFavorite(_ movie: Movie) throws {
        if shouldFailSave { throw FakeError.failed }
        ids.insert(movie.id)
    }
    func removeFavorite(movieID: Int) throws { ids.remove(movieID) }
}

private struct FakeMovieRepository: MovieRepository {
    func popularMovies(pageNumber: Int) async throws -> MoviePage { throw FakeError.failed }
    func trailerKey(movieID: Int) async throws -> String? { nil }
}

private struct FakeTrailerRepository: TrailerRepository {
    func playableTrailer(for movie: Movie) async throws -> TrailerMedia? { nil }
}
