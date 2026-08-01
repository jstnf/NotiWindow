# Contributing

## Layout

```
Sources/NotiWindow/     the library
Tests/NotiWindowTests/  swift-testing suites
Example/                demo app and its tests
```

## Build and test

`swift build` and `swift test` do not work here — the package is iOS-only and imports
UIKit, so the macOS host build fails. Use a simulator:

```sh
xcodebuild test -scheme NotiWindow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

xcodebuild test -project Example/NotiWindowExample.xcodeproj \
  -scheme NotiWindowExample \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Any installed simulator works — `xcrun simctl list devices available` lists them.

## Linting

```sh
brew install swiftlint

scripts/lint.sh        # report violations
scripts/lint.sh --fix  # correct what can be corrected
```

Rules live in `.swiftlint.yml`. The script runs `--strict`, so warnings fail.

## CI

`.github/workflows/ci.yml` lints and tests on pushes to `main` and on every pull
request.

## Conventions

- Swift 6 language mode.
- The deployment target is iOS 18.6. Adopt newer OS features behind
  `if #available(...)` rather than raising the floor.
