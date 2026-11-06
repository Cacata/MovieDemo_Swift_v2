import SwiftUI

@main
struct MovieDemoSwiftApp: App {
    private let container = AppContainer.forLaunch()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
