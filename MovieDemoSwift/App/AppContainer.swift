import Foundation

final class AppContainer: @unchecked Sendable {
    let movieRepository: MovieRepository
    let trailerRepository: TrailerRepository
    let favoriteRepository: FavoriteRepository
    let appStateRepository: AppStateRepository
    let movieFeedClient: MovieFeedClient

    static func forLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppContainer {
        #if DEBUG
        if let flagIndex = arguments.firstIndex(of: "-qa-fixture"),
           arguments.indices.contains(flagIndex + 1),
           arguments[flagIndex + 1] == "smoke-v1" {
            let fixture = QASmokeFixture()
            return AppContainer(
                storageDirectoryName: "MovieDemo-QA/smoke-v1",
                movieRepository: fixture,
                trailerRepository: fixture,
                movieFeedClient: MovieFeedClient(popularMovies: { page in
                    try await fixture.popularMovies(pageNumber: page)
                })
            )
        }
        #endif
        return AppContainer()
    }

    convenience init() {
        let readAccessToken = Bundle.main.object(forInfoDictionaryKey: "TMDBReadAccessToken") as? String ?? ""
        self.init(
            storageDirectoryName: "MovieDemo",
            movieRepository: TmdbMovieRepository(readAccessToken: readAccessToken),
            trailerRepository: AppleTrailerRepository(),
            movieFeedClient: .liveValue
        )
    }

    private init(
        storageDirectoryName: String,
        movieRepository: MovieRepository,
        trailerRepository: TrailerRepository,
        movieFeedClient: MovieFeedClient
    ) {
        self.movieRepository = movieRepository
        self.trailerRepository = trailerRepository
        self.movieFeedClient = movieFeedClient
        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(storageDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)

        do {
            favoriteRepository = try SQLiteFavoriteRepository(
                databaseURL: applicationSupportURL.appendingPathComponent("movie-demo.sqlite")
            )
        } catch {
            fatalError("Unable to initialize the local favorites database: \(error)")
        }
        appStateRepository = JSONAppStateRepository(
            fileURL: applicationSupportURL.appendingPathComponent("movie-demo-app-state.json")
        )
    }
}

#if DEBUG
private struct QASmokeFixture: MovieRepository, TrailerRepository {
    func popularMovies(pageNumber: Int) async throws -> MoviePage {
        MoviePage(movies: [Movie(
            id: 9001,
            title: "QA Smoke Movie",
            overview: "A local movie for the smoke-v1 favorites journey.",
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2026-01-01",
            voteAverage: 7
        )], pageNumber: 1, totalPages: 1)
    }

    func trailerKey(movieID: Int) async throws -> String? { nil }

    func playableTrailer(for movie: Movie) async throws -> TrailerMedia? { nil }
}
#endif
