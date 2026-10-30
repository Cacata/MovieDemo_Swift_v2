import Foundation

final class AppleTrailerRepository: TrailerRepository, @unchecked Sendable {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func playableTrailer(for movie: Movie) async throws -> TrailerMedia? {
        let url = try Self.searchURL(for: movie.title)

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MovieDemo/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TrailerDataError.requestFailed
        }

        let candidates = try AppleTrailerResponseMapper.candidates(from: data)
        return TrailerPolicy.selectApplePreview(for: movie, from: candidates)
    }

    static func searchURL(for movieTitle: String) throws -> URL {
        guard var components = URLComponents(string: "https://itunes.apple.com/search") else {
            throw TrailerDataError.invalidURL
        }

        // The live service currently returns movie previews reliably when all media
        // types are searched and feature-movie results are filtered locally.
        components.queryItems = [
            URLQueryItem(name: "term", value: movieTitle),
            URLQueryItem(name: "country", value: "us"),
            URLQueryItem(name: "limit", value: "30"),
        ]
        guard let url = components.url else {
            throw TrailerDataError.invalidURL
        }
        return url
    }
}

struct AppleSearchResponse: Decodable {
    let results: [AppleMoviePreviewResponse]
}

struct AppleMoviePreviewResponse: Decodable {
    let trackName: String?
    let releaseDate: String?
    let kind: String?
    let previewURL: String?
    let trackViewURL: String?

    enum CodingKeys: String, CodingKey {
        case trackName
        case releaseDate
        case kind
        case previewURL = "previewUrl"
        case trackViewURL = "trackViewUrl"
    }
}

enum AppleTrailerResponseMapper {
    static func candidates(from data: Data) throws -> [TrailerPreviewCandidate] {
        let payload = try JSONDecoder().decode(AppleSearchResponse.self, from: data)
        return payload.results.compactMap { result in
            guard let title = result.trackName, let kind = result.kind else {
                return nil
            }
            return TrailerPreviewCandidate(
                title: title,
                releaseDate: result.releaseDate,
                kind: kind,
                previewURL: result.previewURL,
                providerPageURL: result.trackViewURL
            )
        }
    }
}

enum TrailerDataError: LocalizedError {
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The trailer request URL could not be created."
        case .requestFailed:
            "The trailer provider returned an unsuccessful response."
        }
    }
}
