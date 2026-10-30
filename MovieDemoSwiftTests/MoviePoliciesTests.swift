import XCTest
@testable import MovieDemoSwift

final class MoviePoliciesTests: XCTestCase {
    func testAppendingUniqueRemovesDuplicateMovieIDs() {
        let firstMovie = movie(id: 1, title: "First")
        let replacement = movie(id: 1, title: "Updated")
        let secondMovie = movie(id: 2, title: "Second")

        let result = MoviePolicies.appendingUnique(
            existingMovies: [firstMovie],
            newMovies: [replacement, secondMovie]
        )

        XCTAssertEqual(result, [firstMovie, secondMovie])
    }

    func testPaginationRequiresNearEndAndAvailablePage() {
        XCTAssertTrue(MoviePolicies.shouldLoadNextPage(
            lastVisibleIndex: 8, itemCount: 10, isLoading: false, currentPage: 1, totalPages: 2
        ))
        XCTAssertFalse(MoviePolicies.shouldLoadNextPage(
            lastVisibleIndex: 8, itemCount: 10, isLoading: true, currentPage: 1, totalPages: 2
        ))
        XCTAssertFalse(MoviePolicies.shouldLoadNextPage(
            lastVisibleIndex: 8, itemCount: 10, isLoading: false, currentPage: 2, totalPages: 2
        ))
    }

    func testTrailerSelectionPrefersOfficialYouTubeTrailer() {
        let candidates = [
            TrailerCandidate(site: "YouTube", type: "Teaser", official: true, key: "teaser"),
            TrailerCandidate(site: "YouTube", type: "Trailer", official: true, key: "official"),
        ]
        XCTAssertEqual(TrailerPolicy.selectYouTubeKey(from: candidates), "official")
    }

    func testApplePreviewRequiresExactNormalizedTitleAndReleaseYear() {
        let selectedMovie = movie(id: 1, title: "Spider-Man: Brand New Day")
        let candidates = [
            TrailerPreviewCandidate(
                title: "Spider Man Brand New Day",
                releaseDate: "2025-07-31T00:00:00Z",
                kind: "feature-movie",
                previewURL: "https://media.example/incorrect-year.m4v",
                providerPageURL: "https://tv.apple.com/incorrect"
            ),
            TrailerPreviewCandidate(
                title: "Spider Man - Brand New Day",
                releaseDate: "2026-07-31T00:00:00Z",
                kind: "feature-movie",
                previewURL: "https://media.example/trailer.m4v",
                providerPageURL: "https://tv.apple.com/correct"
            ),
        ]

        let result = TrailerPolicy.selectApplePreview(for: selectedMovie, from: candidates)

        XCTAssertEqual(result?.sourceURL, "https://media.example/trailer.m4v")
        XCTAssertEqual(result?.providerPageURL, "https://tv.apple.com/correct")
        XCTAssertEqual(result?.providerName, "Apple")
    }

    func testApplePreviewRejectsInsecureMediaURL() {
        let candidates = [
            TrailerPreviewCandidate(
                title: "First",
                releaseDate: "2026-01-01T00:00:00Z",
                kind: "feature-movie",
                previewURL: "http://media.example/trailer.m4v",
                providerPageURL: "https://tv.apple.com/first"
            ),
        ]

        XCTAssertNil(TrailerPolicy.selectApplePreview(
            for: movie(id: 1, title: "First"),
            from: candidates
        ))
    }

    func testYouTubeFallbackCreatesExternalWatchURL() {
        XCTAssertEqual(
            TrailerPolicy.youtubeWatchURL(for: "abc-123"),
            "https://www.youtube.com/watch?v=abc-123"
        )
        XCTAssertNil(TrailerPolicy.youtubeWatchURL(for: nil))
    }

    func testAppleResponseMapperDecodesDirectPreviewFields() throws {
        let responseData = Data(
            """
            {
              "results": [
                {
                  "wrapperType": "artist",
                  "artistName": "Christopher Nolan"
                },
                {
                  "trackName": "Interstellar",
                  "releaseDate": "2014-11-07T08:00:00Z",
                  "kind": "feature-movie",
                  "previewUrl": "https://video.example/interstellar.m4v",
                  "trackViewUrl": "https://tv.apple.com/interstellar"
                }
              ]
            }
            """.utf8
        )

        let candidates = try AppleTrailerResponseMapper.candidates(from: responseData)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].title, "Interstellar")
        XCTAssertEqual(candidates[0].previewURL, "https://video.example/interstellar.m4v")
    }

    func testAppleSearchURLPreservesMovieTitleAndLimitsResults() throws {
        let url = try AppleTrailerRepository.searchURL(for: "Spider-Man: Brand New Day")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: components.queryItems?.map { item in
            (item.name, item.value ?? "")
        } ?? [])

        XCTAssertEqual(queryItems["term"], "Spider-Man: Brand New Day")
        XCTAssertEqual(queryItems["country"], "us")
        XCTAssertEqual(queryItems["limit"], "30")
        XCTAssertNil(queryItems["media"])
    }

    func testJSONAppStateRepositoryRoundTripsState() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("movie-demo-state-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let repository = JSONAppStateRepository(fileURL: fileURL)
        let expectedState = AppState(lastSuccessfulPage: 4, selectedTab: .favorites)

        repository.save(expectedState)

        XCTAssertEqual(repository.load(), expectedState)
    }

    func testPosterURLUsesCompactTMDBThumbnailSize() {
        let movieWithPoster = Movie(
            id: 1,
            title: "Poster",
            overview: "Overview",
            posterPath: "/poster.jpg",
            backdropPath: nil,
            releaseDate: nil,
            voteAverage: 7
        )
        let movieWithoutPoster = movie(id: 2, title: "No Poster")

        XCTAssertEqual(movieWithPoster.posterURL?.absoluteString, "https://image.tmdb.org/t/p/w185/poster.jpg")
        XCTAssertNil(movieWithoutPoster.posterURL)
    }

    private func movie(id: Int, title: String) -> Movie {
        Movie(
            id: id,
            title: title,
            overview: "Overview",
            posterPath: nil,
            backdropPath: nil,
            releaseDate: "2026-01-01",
            voteAverage: 7
        )
    }
}
