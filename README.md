<p align="center"><img src="docs/icon.png" width="128" alt="ljaspNotch icon"></p>

# ljaspNotch

[Türkçe](README.tr.md)

A customizable notch app for macOS. It turns the MacBook notch into a panel that expands on hover.

> **Status: work in progress.** Nothing to download yet. The roadmap and technical spec are in [docs/SPEC.md](docs/SPEC.md) (in Turkish).

## Planned features

- **YouTube and YouTube Music** mini player for music and videos playing in your browser (Chrome extension)
- **Spotify and Apple Music** controls with artwork and progress
- **Claude Code** notifications, and approving or denying permission requests right from the notch
- **Themes**: Liquid Glass, solid black or tinted glass; custom colors, panel size and animations
- **Widgets**: calendar, timer, battery, file tray, camera mirror, weather, shortcuts and more
- English and Turkish interface

## Requirements

- A Mac with a notch
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

Permission requests from Claude Code (terminal, IDE extensions and the Claude desktop app) appear in the notch with **Allow**, **Deny** and **In Terminal**, and you see when a session finishes or fails. Install the hooks in **Settings > Claude Code**; you review the change to `~/.claude/settings.json` first and a backup is made. See [docs/claude-code-setup.md](docs/claude-code-setup.md) to set it up by hand.

## Privacy

No telemetry. Everything stays on your Mac. These features make network requests, and only while you use them:

| Feature | Request |
|---|---|
| Media widget with Spotify | Album artwork from Spotify's image server (`i.scdn.co`) |
| Media widget with YouTube | Thumbnails from YouTube's image servers (the URL the page itself uses) |
| Weather widget | The coordinates of the place you choose to `api.open-meteo.com`; the city you search for to `geocoding-api.open-meteo.com` |

The camera (Mirror widget) runs only while the panel shows it, and nothing is recorded. The Tray keeps only file paths on your Mac.

The local server listens only on `127.0.0.1` and requires a token stored in your Keychain. Updating an ad-hoc signed build may make macOS ask once more for Keychain access.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Report security issues privately as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
