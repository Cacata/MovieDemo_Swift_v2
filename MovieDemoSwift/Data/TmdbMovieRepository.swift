import Foundation

final class TmdbMovieRepository: MovieRepository, @unchecked Sendable {
    private let readAccessToken: String
    private let urlSession: URLSession
    private let decoder: JSONDecoder

    init(
        readAccessToken: String,
        urlSession: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.readAccessToken = readAccessToken
        self.urlSession = urlSession
        self.decoder = decoder
    }

    func popularMovies(pageNumber: Int) async throws -> MoviePage {
        let response: PopularMoviesResponse = try await get(
            path: "/movie/popular",
            queryItems: [
                URLQueryItem(name: "language", value: "en-US"),
                URLQueryItem(name: "page", value: String(pageNumber)),
            ]
        )
        return MoviePage(
            movies: response.results,
            pageNumber: response.page,
            totalPages: response.totalPages
        )
    }

    func trailerKey(movieID: Int) async throws -> String? {
        let response: VideosResponse = try await get(
            path: "/movie/\(movieID)/videos",
            queryItems: [URLQueryItem(name: "language", value: "en-US")]
        )
        return TrailerPolicy.selectYouTubeKey(from: response.results)
    }

    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response {
        guard !readAccessToken.isEmpty, readAccessToken != "your_token_here" else {
            throw MovieDataError.missingReadAccessToken
        }
        var components = URLComponents(string: "https://api.themoviedb.org/3\(path)")
        components?.queryItems = queryItems
        guard let url = components?.url else { throw MovieDataError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(readAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MovieDataError.requestFailed
        }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct PopularMoviesResponse: Decodable {
    let page: Int
    let totalPages: Int
    let results: [Movie]

    enum CodingKeys: String, CodingKey {
        case page
        case totalPages = "total_pages"
        case results
    }
}

private struct VideosResponse: Decodable {
    let results: [TrailerCandidate]
}

enum MovieDataError: LocalizedError {
    case missingReadAccessToken
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .missingReadAccessToken:
            "TMDB_READ_ACCESS_TOKEN is missing. See API_TOKEN_SETUP.md for secure setup."
        case .invalidURL:
            "The TMDB request URL could not be created."
        case .requestFailed:
            "TMDB returned an unsuccessful response."
        }
    }
}
