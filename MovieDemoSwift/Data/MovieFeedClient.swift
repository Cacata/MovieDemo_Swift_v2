import Dependencies
import Foundation

struct MovieFeedClient: Sendable {
    var popularMovies: @Sendable (Int) async throws -> MoviePage
}

extension MovieFeedClient: DependencyKey {
    static var liveValue: Self {
        let token = Bundle.main.object(forInfoDictionaryKey: "TMDBReadAccessToken") as? String ?? ""
        let repository = TmdbMovieRepository(readAccessToken: token)
        return Self(popularMovies: { page in
            try await repository.popularMovies(pageNumber: page)
        })
    }

    static let previewValue = Self(popularMovies: { page in
        MoviePage(movies: [Movie(
            id: 1, title: "Preview Movie", overview: "Preview data", posterPath: nil,
            backdropPath: nil, releaseDate: "2026-01-01", voteAverage: 7
        )], pageNumber: page, totalPages: 1)
    })

    static let testValue = Self(popularMovies: { _ in
        throw MovieFeedClientError.unimplemented
    })
}

enum MovieFeedClientError: Error {
    case unimplemented
}

extension DependencyValues {
    var movieFeedClient: MovieFeedClient {
        get { self[MovieFeedClient.self] }
        set { self[MovieFeedClient.self] = newValue }
    }
}
