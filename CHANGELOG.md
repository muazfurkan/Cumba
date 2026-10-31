# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
