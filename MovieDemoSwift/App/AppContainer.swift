import Foundation

final class AppContainer: @unchecked Sendable {
    let movieRepository: MovieRepository
    let trailerRepository: TrailerRepository
    let favoriteRepository: FavoriteRepository
    let appStateRepository: AppStateRepository

    init() {
        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MovieDemo", isDirectory: true)
        try? fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)

        let readAccessToken = Bundle.main.object(forInfoDictionaryKey: "TMDBReadAccessToken") as? String ?? ""
        movieRepository = TmdbMovieRepository(readAccessToken: readAccessToken)
        trailerRepository = AppleTrailerRepository()
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
