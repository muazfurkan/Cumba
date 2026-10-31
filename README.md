<p align="center"><img src="docs/banner.png" alt="The ljaspNotch panel open below the notch, showing a mini player"></p>

<h1 align="center">ljaspNotch</h1>

<p align="center">
  <a href="https://github.com/muazfurkan/ljaspNotch/releases/latest"><img src="https://img.shields.io/github/v/release/muazfurkan/ljaspNotch?label=download&color=DCB669" alt="Latest release"></a>
  <a href="https://github.com/muazfurkan/ljaspNotch/actions/workflows/build.yml"><img src="https://github.com/muazfurkan/ljaspNotch/actions/workflows/build.yml/badge.svg?branch=main" alt="Build status"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-111111?logo=apple" alt="macOS 26 or later">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/muazfurkan/ljaspNotch?color=111111" alt="MIT license"></a>
</p>

<p align="center"><a href="README.tr.md">Türkçe</a></p>

A free, open source notch app for macOS. It turns the MacBook notch into a panel that grows out of the camera housing when you rest the pointer on it: music from Spotify, Apple Music and YouTube, Claude Code permission requests, and a set of widgets, all in a look you can make your own.

## Features

- **Media**: Spotify, Apple Music, YouTube and YouTube Music in one mini player with artwork, progress, seeking and controls. A small waveform beside the notch shows what's playing.
- **Claude Code**: permission requests from the terminal, IDE extensions or the Claude desktop app show up in the notch with **Allow**, **Deny** and **In Terminal**. You also see when a session is done or fails.
- **Widgets in tabs**: calendar, timer, battery, file tray with AirDrop, camera mirror, weather, Shortcuts and a CPU/memory graph. Add, remove and reorder them in Settings.
- **Live activities**: a running timer, a pending Claude request, charging or the current song appear on both sides of the closed notch.
- **Themes**: Liquid Glass, solid black or tinted glass; colors, font, panel size, corner radius, shadow and animation. Import and export themes as JSON.
- **Stays out of the way**: clicks pass through to the menu bar, the panel hides in full screen apps, idle CPU use is zero.
- English and Turkish interface.

## Download

1. Get `ljaspNotch-vX.Y.Z.zip` from [Releases](https://github.com/muazfurkan/ljaspNotch/releases) and move `ljaspNotch.app` to Applications.
2. The app is free and not notarized by Apple, so macOS warns the first time you open it. Open it once, then go to **System Settings > Privacy & Security** and click **Open Anyway**. Or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/ljaspNotch.app
   ```
3. ljaspNotch lives in the menu bar. If the menu bar is crowded and its icon hides behind the notch, open the app again from Finder or Spotlight to get to Settings.

Each release has SHA-256 checksums next to the files. Releases after 1.0.0 are also immutable (their files and tag can't change once published) and carry signed build provenance, so you can check that a download was built by this repository's release workflow:

```bash
gh attestation verify ljaspNotch-vX.Y.Z.zip --repo muazfurkan/ljaspNotch
```

After an update, macOS may ask again for permissions (Automation, Calendar, Camera) and Keychain access, because release builds are signed ad hoc.

## Requirements

- A Mac with a notch (other Macs can show a virtual notch, see Settings > General)
- macOS 26 or later

## Build from source

You need Xcode 26 or later and [Homebrew](https://brew.sh).

```bash
brew install xcodegen
git clone https://github.com/muazfurkan/ljaspNotch.git
cd ljaspNotch
cp Local.xcconfig.example Local.xcconfig   # then set your DEVELOPMENT_TEAM
xcodegen generate
open ljaspNotch.xcodeproj
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## YouTube and YouTube Music

A small Chrome extension (also works in other Chromium browsers) sends what plays in YouTube tabs to the app over a local connection, and the app sends play, pause, next and seek back.

1. In ljaspNotch, open **Settings > Connections** and click **Show Extension Folder**.
2. In Chrome, open `chrome://extensions`, turn on **Developer mode** and click **Load unpacked**. Choose the folder from step 1.
3. Open the extension's **Details > Extension options**, paste the port and the token from **Settings > Connections**, and save.

The extension has no permissions besides storage, reads only `youtube.com` and `music.youtube.com`, and talks only to `127.0.0.1`.

## Claude Code

Permission requests from Claude Code (terminal, IDE extensions and the Claude desktop app) appear in the notch with **Allow**, **Deny** and **In Terminal**, and you see when a session finishes or fails. The card shows the full request with hidden characters made visible. Install the hooks in **Settings > Claude Code**; you review the change to `~/.claude/settings.json` first and a backup is made. Hooks reach the app through a private socket that only your user account can open, so nothing else can answer Claude Code in its place. See [docs/claude-code-setup.md](docs/claude-code-setup.md) for details and manual setup.

## Privacy

No telemetry. Everything stays on your Mac. These features make network requests, and only while you use them:

| Feature | Request |
|---|---|
| Media widget with Spotify | Album artwork from Spotify's image server (`i.scdn.co`) |
| Media widget with YouTube | Thumbnails from YouTube's image servers (the URL the page itself uses) |
| Weather widget | The coordinates of the place you choose to `api.open-meteo.com`; the city you search for to `geocoding-api.open-meteo.com` |
| Update check | The list of releases from `api.github.com` at launch and once a day; turn it off in Settings > General |

The camera (Mirror widget) runs only while the panel shows it, and nothing is recorded. The Tray keeps only file paths on your Mac.

The extension server listens only on `127.0.0.1`, accepts only the ljaspNotch extension and requires a token stored in your Keychain. Updating an ad-hoc signed build may make macOS ask once more for Keychain access.

## Contributing

Questions and ideas are welcome in [Discussions](https://github.com/muazfurkan/ljaspNotch/discussions). Contributions are welcome too; please read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Report security issues privately as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
