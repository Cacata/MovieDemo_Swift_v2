# MovieDemo v2 architecture exercises

These are interview practice examples added to the copied demo. They are not
claims about production use of Point-Free Dependencies, RxSwift, or Uber RIBs.

## 3. MVVM: name the exact value that changed

`MoviesViewModel` remains `@MainActor`. A SwiftUI `.task` calls
`loadInitialPage()`, which requests a `MoviePage` through `MovieFeedClient`.
On success, the model assigns `movies`, `currentPage`, and `totalPages`; on
failure, it assigns `errorMessage` and preserves existing rows. The page reads
those published properties and presents these distinct cases:

| Case | Source values | Visible result |
| --- | --- | --- |
| First load | `movies.isEmpty && isLoading` | Progress indicator |
| Content | `visibleMovies` contains rows | Movie list |
| Empty | `movies.isEmpty && errorMessage == nil` | Empty message |
| Initial error | `movies.isEmpty && errorMessage != nil` | Error and Retry |
| Later page error | Existing `movies` plus `errorMessage` | Existing rows and Retry footer |

The MAUI equivalent is a command changing ViewModel properties that notify
bound controls. Here `@Published movies` tells SwiftUI that the source array
changed; `List` uses movie IDs to reconcile rows. No API or SQLite call is in
a View. `ViewModelTests.swift` uses fakes to check first load, unique
pagination, retry, empty/error, and favorite add/remove/failure behavior.

## 4. Point-Free Dependencies: one feature boundary

The Movies feed reads `MovieFeedClient` through `@Dependency(\.movieFeedClient)`.
The client has one operation, `popularMovies(pageNumber)`, and three values:

- `liveValue`: builds a TMDB repository using the local app configuration;
- `previewValue`: returns a sample movie without an API call;
- `testValue`: fails if a test forgets to provide a fake.

`testFirstLoadPublishesMoviesAndPageMetadata` calls `withDependencies` to
replace that client while constructing `MoviesViewModel`. That is analogous
to supplying an `IMovieRepository` fake to a MAUI ViewModel constructor, with
the override scoped to the operation. The Details and Favorites paths still
use their existing protocol-based injection so this change is easy to trace.

## 5. Combine: one ongoing event stream

The search field binds to `MoviesViewModel.searchText`. Each edit makes
`$searchText` publish a new string. The pipeline:

```text
$searchText (Publisher)
  → debounce 250 ms on RunLoop.main
  → prepend an initial empty query
  → remove duplicate queries
  → combine with $movies
  → filter loaded titles
  → sink into visibleMovies
```

`MoviesPage` reads `visibleMovies`; after a search, it shows matching rows or
“No matching movies.” `AnyCancellable` retains the subscription for the
ViewModel lifetime and cancels it when the ViewModel is released. Pagination
is skipped while a query is active, so the search is explicitly over already
loaded movies. One-shot TMDB calls remain `async`/`await`.

In MAUI terms, the `TextField` binding changes a ViewModel property, while
the Combine pipeline is the processing step that assigns the displayed
collection. `@Published visibleMovies` is the exact value that causes the
list to be recomputed.

## 6. RxSwift: same search, separate package

`ArchitectureExercises/RxSearch` is not linked into the app. Its
`RxMovieSearch` uses a `PublishSubject<String>` as input, then RxSwift
`Observable` operators `debounce`, `distinctUntilChanged`, and `map` to
produce title matches. `subscribe(onNext:)` consumes results. A `DisposeBag`
owns the subscription and disposes it when the search object is released.
The caller supplies a scheduler: a production caller would choose the main
scheduler for UI work, while the test supplies `TestScheduler` at millisecond
resolution to advance virtual time deterministically.

Run it from `ArchitectureExercises/RxSearch`:

```sh
swift test
```

Compare this directly with Combine: `Observable` ↔ `Publisher`, Rx operators
↔ Combine operators, `subscribe` ↔ `sink`, and `DisposeBag` ↔ a retained
`AnyCancellable`. Those pairings explain this example; the APIs differ in
their full behavior and type systems.

## 7. Uber RIBs: separate Movies → Details tree

`ArchitectureExercises/RIBsMovies` links the actual Uber RIBs package. It is
an isolated library/test exercise, not a replacement for the working app.

```text
Movies RIB (root)
├── Builder: creates View, Interactor, Router, child Builder
├── Interactor: receives movie selection and Details close event
└── Router: attaches and presents Details; detaches it on close
    └── Details RIB (child)
        ├── Builder: receives title and parent listener
        ├── Interactor: reports close to parent
        └── Router: owns the Details view/controller lifecycle
```

`MoviesRouter.attachChild` activates the Details Interactor and places the
child in the router tree. `detachChild` deactivates it and removes it.
`MoviesRoutingTests` checks both transitions on an iOS simulator. The screen
presentation is intentionally small: one movie button opens a Details sheet,
and one close button returns to Movies. The exercise is about feature
ownership and routing, not a second implementation of the movie catalog.

Run it from `ArchitectureExercises/RIBsMovies`:

```sh
xcodebuild -scheme RIBsMoviesExercise \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  test CODE_SIGNING_ALLOWED=NO
```

## Main app check

```sh
xcodebuild -project MovieDemoSwift.xcodeproj -scheme MovieDemoSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  test CODE_SIGNING_ALLOWED=NO
```

The TMDB token stays in the ignored local `Configuration/Secrets.xcconfig`;
the tests use fake values and do not require it.
