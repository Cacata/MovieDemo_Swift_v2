# Local Appium iOS smoke

This QA-only script uses the installed Appium server and XCUITest driver. It needs no npm dependencies, cloud service, or token in the test script.

## Current state

`--driver-only` creates a real XCUITest session and checks that the Movies screen appears. The full flow uses the app's Debug-only `smoke-v1` fixture and accessibility identifiers to test a favorite across an app relaunch.

## Fixture and selector contract

- Launch argument pair `-qa-fixture smoke-v1` selects a local, offline fixture without requiring a TMDB token or Apple trailer request. The fixture contains movie ID `9001`, with a stable title and overview, on the first page.
- Installing the app on a fresh simulator or passing `--reset` resets favorites and selected-tab state. The fixture argument must work again after app termination and relaunch.
- Expose these accessibility identifiers: `movies.row.9001` on its Movies navigation row; `movie.details.9001` on the detail screen; `movie.favorite.toggle` on the favorite button; `tabs.favorites` on the Favorites tab; and `favorites.row.9001` on its Favorites row. Keep the visible favorite button label `Remove favorite` after adding.
- The fixture and identifiers are supplied by the app's Debug build. This script does not change app source.

## Run locally

Use an iOS Simulator dedicated to QA. Build the app with the project scheme, then set:

```sh
export MOVIEDEMO_APP_PATH='/absolute/path/to/MovieDemoSwift.app'
export MOVIEDEMO_SIM_UDID='SIMULATOR-UDID'
export APPIUM_URL='http://127.0.0.1:4723'
appium --port 4723
```

In another terminal:

```sh
node qa/appium/smoke.mjs --driver-only
node qa/appium/smoke.mjs --reset
```

`--reset` uninstalls this app from the selected simulator before the test and clears its local favorites; use it only on a dedicated QA simulator. The full flow opens movie 9001, adds it to favorites, checks its Favorites row, relaunches the app, and checks persistence. The script always deletes its Appium session when it exits.
