protocol MovieRepository: Sendable {
    func popularMovies(pageNumber: Int) async throws -> MoviePage
    func trailerKey(movieID: Int) async throws -> String?
}

protocol TrailerRepository: Sendable {
    func playableTrailer(for movie: Movie) async throws -> TrailerMedia?
}

protocol FavoriteRepository: Sendable {
    func favorites() async throws -> [Movie]
    func isFavorite(movieID: Int) async throws -> Bool
    func saveFavorite(_ movie: Movie) async throws
    func removeFavorite(movieID: Int) async throws
}

protocol AppStateRepository: Sendable {
    func load() -> AppState
    func save(_ appState: AppState)
}
