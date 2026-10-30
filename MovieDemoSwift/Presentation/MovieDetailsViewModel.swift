import Foundation

enum TrailerPlaybackState: Equatable {
    case idle
    case loading
    case playable(TrailerMedia)
    case externalOnly(String)
    case unavailable
    case failed(String)
}

@MainActor
final class MovieDetailsViewModel: ObservableObject {
    let movie: Movie
    @Published private(set) var isFavorite = false
    @Published private(set) var trailerPlaybackState: TrailerPlaybackState = .idle
    @Published private(set) var errorMessage: String?

    private let movieRepository: MovieRepository
    private let trailerRepository: TrailerRepository
    private let favoriteRepository: FavoriteRepository

    init(
        movie: Movie,
        movieRepository: MovieRepository,
        trailerRepository: TrailerRepository,
        favoriteRepository: FavoriteRepository
    ) {
        self.movie = movie
        self.movieRepository = movieRepository
        self.trailerRepository = trailerRepository
        self.favoriteRepository = favoriteRepository
    }

    func load() async {
        errorMessage = nil
        trailerPlaybackState = .loading

        let selectedMovie = movie
        let selectedMovieRepository = movieRepository
        let selectedTrailerRepository = trailerRepository
        let selectedFavoriteRepository = favoriteRepository

        async let favoriteResult = selectedFavoriteRepository.isFavorite(movieID: selectedMovie.id)
        async let playableTrailerResult = selectedTrailerRepository.playableTrailer(for: selectedMovie)
        async let youtubeTrailerKeyResult = selectedMovieRepository.trailerKey(movieID: selectedMovie.id)

        do {
            isFavorite = try await favoriteResult
        } catch {
            errorMessage = error.localizedDescription
        }

        var playableTrailer: TrailerMedia?
        var externalTrailerURL: String?
        var trailerErrors: [Error] = []

        do {
            playableTrailer = try await playableTrailerResult
        } catch {
            trailerErrors.append(error)
        }

        do {
            let trailerKey = try await youtubeTrailerKeyResult
            externalTrailerURL = TrailerPolicy.youtubeWatchURL(for: trailerKey)
        } catch {
            trailerErrors.append(error)
        }

        if let playableTrailer {
            trailerPlaybackState = .playable(playableTrailer)
        } else if let externalTrailerURL {
            trailerPlaybackState = .externalOnly(externalTrailerURL)
        } else if let firstError = trailerErrors.first {
            trailerPlaybackState = .failed(firstError.localizedDescription)
        } else {
            trailerPlaybackState = .unavailable
        }
    }

    func toggleFavorite() async {
        errorMessage = nil
        do {
            if isFavorite {
                try await favoriteRepository.removeFavorite(movieID: movie.id)
            } else {
                try await favoriteRepository.saveFavorite(movie)
            }
            isFavorite.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
