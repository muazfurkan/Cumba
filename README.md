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

## Privacy

No telemetry. Everything stays on your Mac. These features make network requests, and only while you use them:

| Feature | Request |
|---|---|
| Media widget with Spotify | Album artwork from Spotify's image server (`i.scdn.co`) |

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Report security issues privately as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
