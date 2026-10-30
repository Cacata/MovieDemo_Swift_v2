# MovieDemo Swift — iOS

This v2 training copy has its own app identifier (`com.armando.moviedemo.swift.v2`)
and Home Screen name (`MovieDemo v2`), so it can be installed beside the original.
See [TRAINING_PLAN.md](TRAINING_PLAN.md) for the interview practice sequence.
See [ARCHITECTURE_TRAINING.md](ARCHITECTURE_TRAINING.md) for the new MVVM,
Dependencies, Combine, RxSwift, and RIBs exercises.

This is my iOS version of MovieDemo. I used it to practice Swift, SwiftUI, structured concurrency, native iOS navigation, SQLite, and MVVM while matching the same behavior as the Kotlin and .NET MAUI versions.

I kept the app small and used Apple frameworks directly where possible. The UI is simple on purpose so the code is easier to follow and discuss.

## What the app does

- Calls the TMDB REST API with `URLSession` and bearer authentication.
- Loads popular movies page by page.
- Filters already loaded movie titles with a debounced Combine search field.
- Displays poster, title, release year, and rating in a SwiftUI `List`.
- Uses `AsyncImage` for poster thumbnails and an SF Symbol placeholder.
- Uses a native `TabView` for Movies and Favorites.
- Uses a `NavigationStack` and `NavigationLink` for Movie Details.
- Saves complete favorite records with SQLite3.
- Saves the selected tab and last successful page in a JSON file.
- Plays exact Apple movie previews with `AVPlayer` and SwiftUI `VideoPlayer`.
- Opens the selected TMDB YouTube trailer externally when direct media is unavailable.
- Shares a movie's title and overview through a UIKit activity sheet from Movie Details.
- Shows clear loading, retry, empty, unavailable, and error states.

The app has three pages only: Movies, Favorites, and Movie Details.

## Requirements

- macOS with Xcode installed.
- iOS 17.0 or newer as the deployment target.
- An iOS simulator or configured physical iPhone.
- A TMDB API Read Access Token for live movie and YouTube-trailer requests. Follow [API Token Setup](API_TOKEN_SETUP.md).

The main app uses Apple's SwiftUI, UIKit, Foundation, AVKit, Combine, and SQLite3
frameworks plus Point-Free's `Dependencies` package (pinned to 1.16.0).
RxSwift and Uber RIBs are confined to separate architecture exercises.

## App icon

The iOS app icon uses a Swift-inspired ribbon bird and movie play symbol above the exact `SWIFT` label. The 1024×1024 source master is stored at `branding/app-icon-master.png`, and the compiled application asset is `MovieDemoSwift/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.

The project sets `ASSETCATALOG_COMPILER_APPICON_NAME` to `AppIcon`. The artwork is full bleed and does not contain baked-in rounded corners; iOS applies the correct system mask.

## Project structure

```text
MovieDemo_v2/
├── Configuration/              Build and local secret configuration
├── MovieDemoSwift/
│   ├── Core/                   Models, protocols, and pure policies
│   ├── Data/                   REST, Apple Search, SQLite, JSON, and feed client
│   ├── Presentation/           ObservableObject ViewModels
│   └── App/                    SwiftUI views, UIKit share sheet, navigation, DI, and player
├── MovieDemoSwiftTests/        XCTest unit tests
├── ArchitectureExercises/     Separate RxSwift and Uber RIBs Swift packages
├── MovieDemoSwift.xcodeproj
└── generate_xcode_project.rb   Recreates the project definition if needed
```

### Core

Core contains Swift types that do not depend on SwiftUI:

- `Movie`, `MoviePage`, `AppState`, and trailer models;
- repository protocols for movies, previews, favorites, and app state;
- `MoviePolicies` for deduplication, pagination, and release-year formatting;
- `TrailerPolicy` for direct-preview matching and YouTube fallback selection.

### Data

Data provides the concrete protocol implementations:

- `TmdbMovieRepository` uses `URLSession`, `URLComponents`, and `JSONDecoder`.
- `AppleTrailerRepository` searches Apple's public API and maps optional response fields safely.
- `SQLiteFavoriteRepository` is an actor around the native SQLite3 C API.
- `JSONAppStateRepository` stores a Codable JSON document in Application Support.

### Presentation

The Presentation group contains three `@MainActor` ViewModels:

- `MoviesViewModel` owns pagination, loading/error state, and debounced local search.
- `FavoritesViewModel` reads saved favorites.
- `MovieDetailsViewModel` checks favorite state, selects trailer behavior, and updates favorites.

### App

The App group contains:

- SwiftUI screens and reusable row/layout views;
- `RootView`, which owns tabs and two navigation stacks;
- `AppContainer`, which creates the Details/Favorites repositories;
- the native `AVPlayer` controller and `VideoPlayer` view.

## How MVVM works here

The SwiftUI views do not create network requests or SQL statements. They call ViewModel functions and display published state.

```text
SwiftUI action or .task
        │
        ▼
@MainActor ViewModel
        │
        ▼
MovieFeedClient or repository protocol
        │
        ▼
URLSession / SQLite actor / JSON repository
        │
        ▼
@Published property ───> SwiftUI refresh
```

`@StateObject` gives each page ownership of its ViewModel. `@Published private(set)` lets the page observe values without mutating them directly.

## UIKit interoperability

Movie Details presents `UIActivityViewController` through a small
`UIViewControllerRepresentable` wrapper. SwiftUI owns the button and sheet
state; UIKit supplies the native sharing interface. The shared message contains
the movie title and overview when available. This provides a focused example
of using UIKit inside an existing SwiftUI screen.

## Swift concepts I practiced

### Structured concurrency

REST and database protocols use `async throws`. Movie Details starts three independent operations with `async let`:

- check whether the movie is a favorite;
- look for an exact Apple preview;
- request TMDB video candidates.

The ViewModel awaits each result and applies a clear priority: direct preview, external YouTube fallback, provider error, then unavailable.

### `@MainActor`

ViewModels are marked `@MainActor` because their published properties drive the UI. This keeps observable state changes on the main actor while `URLSession` and the SQLite actor perform their own asynchronous work.

### Actors

`SQLiteFavoriteRepository` is an actor. Actor isolation protects the shared SQLite handle from concurrent access. SQL statements use `defer` to finalize prepared statements even when a method exits early.

### Protocols and dependency injection

Details and Favorites receive repository protocols from `AppContainer`.
The Movies feed instead reads `MovieFeedClient` through Point-Free's
`@Dependency`. Its live implementation calls TMDB; preview and test values
are separate. Tests override the client with `withDependencies`.

### Codable

TMDB models use `CodingKeys` to map snake_case JSON fields such as `poster_path` and `vote_average` to Swift property names. `AppState` is also Codable, so the JSON repository can encode and decode it directly.

### Explicit trailer state

`TrailerPlaybackState` is an enum with associated values for playable media, external URLs, and failures. A SwiftUI `switch` handles every state, which is safer than coordinating several unrelated Boolean properties.

### Pure synchronous policies

Small deterministic rules stay synchronous:

- movie-ID deduplication;
- release-year formatting;
- pagination eligibility;
- poster URL construction;
- normalized title matching;
- HTTPS validation;
- preferred YouTube candidate selection.

They are fast, do not need an actor, and are easy to test with XCTest.

## Three-region layout

`ThreeRegionPage<Header, Page, Footer>` is a generic SwiftUI view that uses `@ViewBuilder` closures:

```text
VStack
├── HeaderContent       intrinsic height
├── PageContent         fills available space
└── FooterContent       intrinsic height
```

Each region has its own visibility property. The native `TabView` remains in `RootView`, outside the page layout.

## Navigation

- `TabView` supplies the native Movies and Favorites tabs with `film` and `star` SF Symbols.
- Each tab owns its own `NavigationStack`, so forward/back history remains local to that tab.
- Movie rows use `NavigationLink(value:)`.
- `.navigationDestination(for: Movie.self)` creates Movie Details.
- The system Back button returns to the originating tab stack.

This is the standard SwiftUI composition for the two required navigation styles.

## Pagination behavior

Each visible row starts a small `.task` that reports its index. `MoviePolicies.shouldLoadNextPage` returns true only near the final three items, when another page exists and no request is running.

`MoviesViewModel` appends unique TMDB IDs, preserves existing content on a failed next-page request, records the successful page in JSON, and exposes Retry.

## Persistence

The app creates this directory in Application Support:

```text
Application Support/MovieDemo/
├── movie-demo.sqlite
└── movie-demo-app-state.json
```

### SQLite favorites

The native SQLite3 repository creates `favorite_movies` and stores all movie fields needed by Favorites. Prepared statements bind user data rather than building SQL strings from movie values.

### JSON app state

The JSON repository stores the selected root tab and last successful page. It uses an `NSLock` and atomic file writes. Missing or invalid data returns the default `AppState`.

The JSON file is intentionally read synchronously because it is very small and local. REST and SQLite operations use async APIs because they can take longer.

## Trailer playback

1. `AppleTrailerRepository` builds a search URL with `URLComponents` and `URLQueryItem`.
2. `JSONDecoder` maps the response into optional candidate fields.
3. `TrailerPolicy` accepts only an HTTPS `feature-movie` result with the same normalized title and release year.
4. `NativeTrailerPlayerController` loads the URL into `AVPlayer`.
5. SwiftUI `VideoPlayer` provides native playback controls.
6. Playback does not autoplay.
7. `onDisappear` pauses the player, removes its item, and releases the current source.
8. If no direct preview matches, a SwiftUI `Link` opens the selected TMDB YouTube trailer externally.

No WebView is used.

## Build, test, and run

Open `MovieDemoSwift.xcodeproj`, select the `MovieDemoSwift` scheme and an iPhone simulator, then Run or Test.

Command-line test example:

```sh
xcodebuild -project MovieDemoSwift.xcodeproj -scheme MovieDemoSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test \
  CODE_SIGNING_ALLOWED=NO
```

Current main-app unit result: **18 passed, 0 failed**.

The tests cover:

- movie-ID deduplication;
- pagination eligibility;
- preferred YouTube selection;
- exact Apple preview matching;
- insecure preview rejection;
- YouTube URL creation;
- Apple response mapping;
- Apple search URL construction;
- JSON app-state round trip;
- compact poster URL construction.
- pending-load, first load, pagination, retry, empty/error behavior, favorite changes, and
  debounced search through fake clients/repositories.

The app was runtime-validated on an iPhone 17 Pro simulator, including posters, tab icons, push navigation, direct AVPlayer playback, external fallback, and player cleanup when navigating back.

If the Xcode project file needs to be recreated after adding source files, run:

```sh
ruby generate_xcode_project.rb
```

Do not regenerate the project during normal builds.

## Manual check list

- Movies shows loading and then poster rows.
- Scrolling near the end requests one additional page.
- Typing a title filters loaded movies after a short debounce; clearing it restores the list.
- A failed request keeps existing rows and exposes Retry.
- Both tab icons appear and switching tabs persists the selected tab.
- A movie pushes Details and the system Back button returns correctly.
- Add/Remove Favorite updates the button and Favorites list.
- A matching Apple preview plays with native controls.
- Leaving Details stops and releases the current player item.
- A movie without a matching preview displays the external YouTube option.

## What I would improve next

For a production iOS app, I would add UI tests, broader ViewModel coverage,
accessibility verification, localization, a SQLite migration strategy, offline
feed caching, retry/backoff rules, and a backend for protecting third-party
credentials. These remain outside this interview demo.
