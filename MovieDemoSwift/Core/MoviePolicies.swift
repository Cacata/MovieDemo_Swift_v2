import Foundation

enum MoviePolicies {
    static func appendingUnique(existingMovies: [Movie], newMovies: [Movie]) -> [Movie] {
        var seenMovieIDs = Set<Int>()
        return (existingMovies + newMovies).filter { movie in
            seenMovieIDs.insert(movie.id).inserted
        }
    }

    static func releaseYear(releaseDate: String?) -> String {
        guard let releaseDate, releaseDate.count >= 4 else { return "Unknown year" }
        return String(releaseDate.prefix(4))
    }

    static func shouldLoadNextPage(
        lastVisibleIndex: Int,
        itemCount: Int,
        isLoading: Bool,
        currentPage: Int,
        totalPages: Int
    ) -> Bool {
        let isNearEnd = itemCount > 0 && lastVisibleIndex >= itemCount - 3
        return isNearEnd && !isLoading && currentPage < totalPages
    }
}

enum TrailerPolicy {
    static func selectYouTubeKey(from candidates: [TrailerCandidate]) -> String? {
        let youtubeCandidates = candidates.filter { candidate in
            candidate.site.caseInsensitiveCompare("YouTube") == .orderedSame && !candidate.key.isEmpty
        }
        return youtubeCandidates.first { candidate in
            candidate.type.caseInsensitiveCompare("Trailer") == .orderedSame && candidate.official
        }?.key ?? youtubeCandidates.first { candidate in
            candidate.type.caseInsensitiveCompare("Trailer") == .orderedSame
        }?.key ?? youtubeCandidates.first?.key
    }

    static func selectApplePreview(
        for movie: Movie,
        from candidates: [TrailerPreviewCandidate]
    ) -> TrailerMedia? {
        guard let expectedReleaseYear = releaseYear(from: movie.releaseDate) else {
            return nil
        }
        let expectedTitle = normalizedTitle(movie.title)

        return candidates.lazy
            .filter { candidate in
                candidate.kind.caseInsensitiveCompare("feature-movie") == .orderedSame
                    && normalizedTitle(candidate.title) == expectedTitle
                    && releaseYear(from: candidate.releaseDate) == expectedReleaseYear
            }
            .compactMap { candidate in
                guard let previewURL = validHTTPSURLString(candidate.previewURL),
                      let providerPageURL = validHTTPSURLString(candidate.providerPageURL) else {
                    return nil
                }
                return TrailerMedia(
                    sourceURL: previewURL,
                    providerName: "Apple",
                    providerPageURL: providerPageURL,
                    displayTitle: candidate.title
                )
            }
            .first
    }

    static func youtubeWatchURL(for key: String?) -> String? {
        guard let key, !key.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.youtube.com/watch")
        components?.queryItems = [URLQueryItem(name: "v", value: key)]
        return components?.url?.absoluteString
    }

    private static func normalizedTitle(_ title: String) -> String {
        title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { component in !component.isEmpty }
            .joined(separator: " ")
    }

    private static func releaseYear(from releaseDate: String?) -> String? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        let year = String(releaseDate.prefix(4))
        return year.allSatisfy(\.isNumber) ? year : nil
    }

    private static func validHTTPSURLString(_ value: String?) -> String? {
        guard let value,
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host != nil else {
            return nil
        }
        return components.url?.absoluteString
    }
}
