import Foundation

final class JSONAppStateRepository: AppStateRepository, @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() -> AppState {
        lock.withLock {
            guard let data = try? Data(contentsOf: fileURL),
                  let state = try? JSONDecoder().decode(AppState.self, from: data) else {
                return AppState()
            }
            return state
        }
    }

    func save(_ appState: AppState) {
        lock.withLock {
            guard let data = try? JSONEncoder().encode(appState) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
