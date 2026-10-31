# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-10-31

### Added

- Tray widget: drop files on the panel, drag them out again, send them with AirDrop.
- Mirror widget: the camera as a mirror, only while the panel shows it.
- Weather widget with Open-Meteo for a place you pick; no location permission.
- Shortcuts widget: run up to six favorite shortcuts.
- System widget: CPU and memory load with a small graph, sampled only while visible.

### Changed

- New widgets spread over tabs by width instead of all landing in the first tab.

## [0.6.0] - 2026-10-31

### Added

- Claude Code integration: permission requests appear in the notch with Allow, Deny and In Terminal; sessions show working, waiting, done and error states; finishing and failing show briefly beside the notch.
- Claude Code widget, plus a permission card above the widgets when the widget isn't in the visible tab.
- Settings > Claude Code installs, updates and removes the hooks in ~/.claude/settings.json after showing a diff, with a backup, and warns when `allowedHttpHookUrls` would block them.
- docs/claude-code-setup.md for setting the hooks up by hand.

## [0.5.0] - 2026-10-31

### Added

- YouTube and YouTube Music in the media widget through a Chrome extension (`extensions/chrome`), including controls and seeking. The right tab is picked when several play.
- Local server on 127.0.0.1 with a Keychain token, Host and Origin checks, and Settings > Connections to change the port, copy or regenerate the token and find the extension.

## [0.4.0] - 2026-10-31

### Added

- Media widget for Spotify and Music: artwork, title, artist, progress with click to seek, play/pause, next and previous.
- With several players, the one that started playing last wins; a paused player stays for 10 minutes. You can switch players by hand.
- Playing media shows as a live activity beside the closed notch.
- Automation access is asked for in Settings > Widgets > Media; a closed player is never launched.

## [0.3.0] - 2026-10-31

### Added

- Widgets in tabs: add, remove and reorder widgets and tabs in Settings > Widgets. New widgets in future versions appear once on their own.
- Calendar widget: today's and tomorrow's events. Access is requested from Settings, never from the panel.
- Timer widget: presets from 5 to 50 minutes, pause and resume; plays a sound when done.
- Battery widget: level, charging state and time remaining.
- Live activities beside the closed notch: running and finished timer, charger plugged in, low battery.

## [0.2.0] - 2026-10-31

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

[Unreleased]: https://github.com/muazfurkan/ljaspNotch/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/muazfurkan/ljaspNotch/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/muazfurkan/ljaspNotch/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/muazfurkan/ljaspNotch/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/muazfurkan/ljaspNotch/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/muazfurkan/ljaspNotch/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/muazfurkan/ljaspNotch/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/muazfurkan/ljaspNotch/releases/tag/v0.1.0
