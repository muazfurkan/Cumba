# Contributing to ljaspNotch

Thanks for your interest! This is a small personal project, so please open an issue to discuss larger changes before you start working on them.

## Setup

1. Install Xcode 26 or later and sign in with your Apple ID (Xcode > Settings > Accounts). A free Personal Team is enough.
2. Install the tools:
   ```bash
   brew install xcodegen xcbeautify
   ```
3. Create your local signing config. It is gitignored, so your Team ID never ends up in the repository:
   ```bash
   cp Local.xcconfig.example Local.xcconfig
   ```
   Set `DEVELOPMENT_TEAM` to your Team ID.
4. Generate the Xcode project. Do this again whenever `project.yml` changes:
   ```bash
   xcodegen generate
   ```

Never edit `ljaspNotch.xcodeproj` by hand. It is generated from `project.yml` and is not committed.

## Build, test, run

```bash
set -o pipefail && xcodebuild -project ljaspNotch.xcodeproj -scheme ljaspNotch -configuration Debug -derivedDataPath build build | xcbeautify
xcodebuild -project ljaspNotch.xcodeproj -scheme ljaspNotch -derivedDataPath build test
open build/Build/Products/Debug/ljaspNotch.app
```

Logs:

```bash
log stream --predicate 'subsystem == "io.github.muazfurkan.ljaspnotch"' --level debug
```

## Code style

- Swift 6 with strict concurrency. UI code is `@MainActor`; I/O, AppleScript, networking and file work never run on the main thread.
- **2-space indentation.** `.editorconfig` and `.swift-format` enforce it. Check before you push:
  ```bash
  xcrun swift-format lint --strict --recursive ljaspNotch ljaspNotchTests
  ```
- No force unwraps (`!`) and no `try!`. Log errors with `os.Logger` (see `Log.swift`).
- Identifiers and code comments are in English.
- Prefer events (notifications, WebSocket messages) over timers. If polling is unavoidable, poll at most once per second and only while the panel is visible.
- Keep files under about 300 lines.
- No private APIs.

## Localization

All user-facing text goes through `Localizable.xcstrings`. English is the development language and **every string must also have a Turkish translation**. A unit test fails if one is missing. If you don't speak Turkish, say so in your PR and the maintainer will add the translation.

## Branches and commits

- Branch off `main`, for example `feat/weather-units` or `fix/hover-delay`.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `ci:`, `chore:`.
- Pull requests are squash merged into `main` once CI is green.

## Pull request checklist

- [ ] Builds and tests pass locally
- [ ] `swift-format lint` passes
- [ ] New strings have Turkish translations
- [ ] Any feature that makes network requests is listed in the README privacy section
- [ ] `CHANGELOG.md` updated under "Unreleased"
- [ ] No secrets, tokens, personal paths or `Local.xcconfig` in the diff

## Original work only

Do not copy code from other projects. In particular, code from Boring Notch (GPL) and NotchNook (closed source) is not allowed. Ideas are fine, code is not. New dependencies need a license compatible with MIT and must be discussed first.

## Security

Please don't report vulnerabilities in public issues. See [SECURITY.md](SECURITY.md).
