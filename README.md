# Local Reader for iOS

[![中文 README](https://img.shields.io/badge/README-中文-blue)](README.zh-CN.md)

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

## Tag and Summary Format

Book tag and summary metadata can be embedded at the beginning of a text file. For the best compatibility with both the import tools and the app runtime parser, use this format:

```text
【标签】#classic #short-story #offline
【简介】A short one-line summary of the book.

Book content starts here...
```

Format rules:

- Put the tag line before the summary line.
- The first line should start with `【标签】`.
- The second line should start with `【简介】`.
- Separate tags with whitespace.
- Tags displayed by the app should start with `#`.
- Keep the summary on one line for import-tool compatibility.
- Use UTF-8 text when possible.

The app runtime has a fallback parser that scans the first 1,200 characters and first 8 lines for lines beginning with `【标签】` or `【简介】`, but the import tools expect the first two lines shown above.

## Build

1. Open `App.xcodeproj` in Xcode.
2. Set your own bundle identifier and signing team.
3. Build and run on an iOS device or simulator.

The default bundle identifier is a placeholder: `com.example.localreader`.

## Privacy

The app is designed for local-only reading. It does not include analytics, tracking, network sync, cloud upload, or any bundled reading content in this public release.

## Repository Hygiene

Before publishing, the repository is checked to ensure that database files, archives, local paths, signing data, and private reading content are not present.
