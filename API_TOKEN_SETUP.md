# TMDB API Token Setup

MovieDemo needs a TMDB **API Read Access Token** for live movie and trailer requests. I keep it in a local Xcode configuration file so it does not become part of the public repository.

## 1. Get the correct TMDB credential

1. Sign in to TMDB.
2. Open **Account Settings → API**.
3. Copy the long **API Read Access Token**.

Use the read access token, not the shorter API key.

## 2. Create the local secrets file

From the `MovieDemo_v2` directory:

```sh
cp Configuration/Secrets.example.xcconfig Configuration/Secrets.xcconfig
```

Open `Configuration/Secrets.xcconfig` and replace the placeholder:

```text
TMDB_READ_ACCESS_TOKEN = your_token_here
```

`Configuration/Base.xcconfig` optionally includes this local file and makes the value available to the app configuration.

## 3. Keep the secret local

Before every push, confirm that `.gitignore` excludes the token file:

```sh
git check-ignore -v Configuration/Secrets.xcconfig
```

The command should report that `.gitignore` excludes the file. Do not force-add it and do not place the token directly in Swift source, an asset catalog, or a plist committed to Git.

## 4. Build and run

Open `MovieDemoSwift.xcodeproj`, select the `MovieDemoSwift` scheme and an iPhone simulator, and run the app.

The app still builds when the local secrets file is missing, but live TMDB requests will show a configuration error.

## If a credential is exposed

Regenerate the credential in TMDB, update only the ignored `Secrets.xcconfig` file, and remove the exposed value from Git history before publishing.
