# Local Reader for iOS

Local Reader is a native iOS text-library reader focused on large offline text collections. It uses SQLite/FTS5 for local catalog storage and search, and keeps reading state on device.

## What Is Included

- Native iOS source code.
- UIKit/Swift reader UI.
- Local SQLite catalog/search integration.
- Favorites, recent reading, deleted items, and reading-state persistence logic.
- Buildable Xcode project structure.

## What Is Not Included

This public repository intentionally does not include:

- Book databases or text files.
- User reading state, favorites, search history, deleted-item records, or preferences.
- Private runtime data.
- Signing credentials or local machine metadata.
- Any private or adult content.

## Book Database

The app expects a local database named `Books.sqlite` at runtime. The database is not distributed with this repository. If you want to use the app, create or import your own local database on your own device.

The app also supports chunked database assembly using files named `Books.sqlite.part-0000`, `Books.sqlite.part-0001`, and so on, plus a manifest file. These runtime data files are ignored by Git.

## Build

1. Open `App.xcodeproj` in Xcode.
2. Set your own bundle identifier and signing team.
3. Build and run on an iOS device or simulator.

The default bundle identifier is a placeholder: `com.example.localreader`.

## Privacy

The app is designed for local-only reading. It does not include analytics, tracking, network sync, cloud upload, or any bundled reading content in this public release.

## Repository Hygiene

Before publishing, the repository is checked to ensure that database files, archives, local paths, signing data, and private reading content are not present.
