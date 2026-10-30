import Foundation

struct Movie: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)")
    }
}

struct MoviePage: Sendable {
    let movies: [Movie]
    let pageNumber: Int
    let totalPages: Int
}

enum RootTab: String, Codable, Sendable {
    case movies
    case favorites
}

struct AppState: Codable, Equatable, Sendable {
    var lastSuccessfulPage: Int = 0
    var selectedTab: RootTab = .movies
}

struct TrailerCandidate: Codable, Sendable {
    let site: String
    let type: String
    let official: Bool
    let key: String
}

struct TrailerPreviewCandidate: Equatable, Sendable {
    let title: String
    let releaseDate: String?
    let kind: String
    let previewURL: String?
    let providerPageURL: String?
}

struct TrailerMedia: Equatable, Sendable {
    let sourceURL: String
    let providerName: String
    let providerPageURL: String
    let displayTitle: String
}
