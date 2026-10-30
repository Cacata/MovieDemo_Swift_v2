# MovieDemo v2 — Swift interview practice

This is a local training copy of `../../MovieDemo/swift` (source commit
`bde52233310388b4457f9e625375664be53bf384`). The original project is
untouched. The copy began with tracked source files only, without the original
repository's Git history or copied build output. A local TMDB token was added on 2026-10-30 in the
local-only `Configuration/Secrets.xcconfig` file.

## Starting point

- SwiftUI screens, navigation, and native video playback already exist.
- MVVM already exists: three `@MainActor` ViewModels expose `@Published` state
  and depend on repository protocols.
- `AppContainer` currently supplies concrete repositories through manual
  dependency injection.
- Networking and persistence use Swift `async`/`await`; SQLite access is actor
  isolated.
- The copied Xcode project was recognized by Xcode, and all 10 existing unit
  tests passed on an iPhone 17 Pro iOS 26.5 simulator on 2026-10-29.

## Implementation order

1. **Isolate v2 — implemented.** The app and test targets have separate v2
   bundle identifiers, and the Home Screen shows `MovieDemo v2`. The local
   token is in `Configuration/Secrets.xcconfig` as described in
   `API_TOKEN_SETUP.md`. The live Movies feed loaded in the iPhone 17 Pro
   simulator on 2026-10-30.
2. **Deepen SwiftUI and add UIKit — implemented.** Movie Details now presents
   a native `UIActivityViewController` through `UIViewControllerRepresentable`
   to share a title and overview. SwiftUI owns the button and presentation
   state. The project builds and its 10 existing tests pass. On 2026-10-29,
   the share sheet was opened and dismissed in the iPhone 17 Pro simulator
   using a local sample favorite; this check did not require a TMDB token.
   Be ready to explain `UIHostingController` for the reverse direction in an
   existing UIKit app.
3. **Strengthen MVVM — implemented.** `ViewModelTests.swift` covers first load,
   pending loading, pagination, retry, empty/error results, favorite add/remove, and failure.
   `MoviesPage` shows distinct loading, content, empty, and error presentations.
4. **Use Point-Free Dependencies in one feature — implemented.** The Movies
   feed uses `MovieFeedClient` through `@Dependency`, with live, preview, and
   test values. `ViewModelTests` overrides the client with a deterministic fake.
   Details and Favorites keep their existing repository injection.
5. **Demonstrate Combine — implemented.** `MoviesViewModel` debounces
   `searchText`, filters loaded titles, and publishes `visibleMovies`. A test
   checks the resulting list; one-shot requests stay on `async`/`await`.
6. **Compare RxSwift — implemented in isolation.** `ArchitectureExercises/RxSearch`
   contains the equivalent title search using `Observable`, `debounce`, a
   caller-provided scheduler, subscription, and `DisposeBag`. A virtual-time
   test proves the debounce behavior.
7. **Explore RIBs — implemented in isolation.** `ArchitectureExercises/RIBsMovies`
   uses Uber RIBs for a Movies → Details child route. Its simulator test
   checks attach/active and detach/inactive behavior. The main app remains MVVM.

See [ARCHITECTURE_TRAINING.md](ARCHITECTURE_TRAINING.md) for the runnable examples,
design explanations, and the MAUI comparison.

## Interview outcome

For each step, keep one runnable example, one short explanation of the design
choice, and one test or manual check. Be explicit about which parts are
practice work and which patterns came from prior production experience. The
friend's list does not yet define what “AI-enhanced development” means; confirm
whether the position expects AI-assisted coding, in-app AI features, or both.

## Reference documentation

- [Apple: UIKit integration with SwiftUI](https://developer.apple.com/documentation/swiftui/uikit-integration)
- [Uber: RIBs architecture](https://github.com/uber/RIBs/wiki)
- [Point-Free: Dependencies](https://github.com/pointfreeco/swift-dependencies)
- [Apple: Combine](https://developer.apple.com/documentation/combine)
- [ReactiveX: RxSwift](https://github.com/ReactiveX/RxSwift)
