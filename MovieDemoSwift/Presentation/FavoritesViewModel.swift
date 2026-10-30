import Foundation

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published private(set) var movies: [Movie] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let favoriteRepository: FavoriteRepository

    init(favoriteRepository: FavoriteRepository) {
        self.favoriteRepository = favoriteRepository
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            movies = try await favoriteRepository.favorites()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
