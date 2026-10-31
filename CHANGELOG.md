# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Themes: Classic, Glass and Midnight built in, plus your own themes with material (Liquid Glass, solid, tinted glass), colors, font, panel size, corner radius, shadow and animation. Changes preview live in the notch.
- Import and export themes as JSON. Broken theme files are skipped instead of crashing the app.
- Panel settings: open on hover or only on click, open and close delays, hide in full screen apps, and a virtual notch for screens without one.
- CI checks that every string in the code is in the string catalog.

### Changed

- New app and menu bar icon: the "L | J" mark.

## [0.1.0] - 2026-10-31

### Added

- Notch panel: opens when the pointer rests on the notch or on click, closes when the pointer leaves, and can be pinned open.
- ljasp logo as the app icon and menu bar icon.
- The panel stays out of the way: clicks pass through to the menu bar while it is closed, and it hides in full screen apps and while paused.
- The panel follows screen changes, sleep/wake and space switches.
- Menu bar app skeleton: no Dock icon, a status item with Settings, Pause and Quit.
- Settings window with a General tab and launch at login.
- English and Turkish localization, with a test that fails on missing Turkish strings.
- XcodeGen project, `os.Logger` setup and a single source for the app version.
- CI workflow (build, test, swift-format lint) and a release workflow that publishes an ad-hoc signed zip.
- Contributor docs: README in Turkish, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, issue and pull request templates.

[Unreleased]: https://github.com/muazfurkan/ljaspNotch/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/muazfurkan/ljaspNotch/releases/tag/v0.1.0
