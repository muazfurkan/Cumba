# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A new Settings window, laid out like System Settings: a searchable sidebar with pages in three groups (General, Appearance, Displays, Behavior, Indicators and Permissions; Widgets, with a page for each widget that has settings; Agents and Connections). Each page starts with its icon, title and what it's for, rows explain themselves with an ⓘ, and switches sit on the right.
- Notes is your Apple Notes: the most recent notes like Apple's Notes widget, a click opens one in Notes, and a new note can be typed in the panel. Cumba reads Notes through AppleScript (Automation access, asked once), starts Notes in the background when needed and never changes an existing note. The note kept by earlier versions moves to Apple Notes once.
- A To-dos widget for Apple Reminders: a list's open reminders with round checkboxes, overdue dates in red, and a line to add one. Ticks and new reminders sync to your other devices through Reminders.
- Widgets look like Apple's: each one's symbol and name in its own color above the content.
- Widgets are set apart by a faint line instead of cards (Appearance > Widgets: Lines or Cards).
- A tab holds as many widgets as fit on the screen: the panel grows wider instead of squeezing them, and only when the screen is full does it say there's no room, in the panel and in Settings alike. The panel also grows taller when a widget needs it, such as a long answer from an AI agent, and switching tabs animates both.
- Settings > Behavior > Opening Tab: open the panel on a tab of your choice or the one it was left on, and choose whether it opens on the agents' tab while Claude Code or Codex works.
- The first time Cumba starts, the notch opens and writes "hello" in one colorful stroke, like a new Mac, before the welcome window. Play it again from Settings > General > Hello animation. With Reduce Motion the word fades in.
- Tab bar styles (Appearance > Tabs): Compact, a bar of its own under the panel with the open tab's name; Symbols; Dots; In the Panel; and At the Top. New installations use Compact; your earlier choice carries over. Themes and tab styles are picked from cards with a small preview.

- Agent notifications: when Claude Code or Codex asks a question, wants a plan approved, needs permission, finishes or stops with an error, a notification opens under the notch. It shows the agent's mark with a badge, a title that says what happened ("Claude is asking a question"), the project, one line of detail and **Open**, which brings the app the agent runs in to the front (or opens the panel). It then folds into the agent's mark and a badge beside the notch; questions and requests stay there until answered. Resting the pointer on a notification keeps it open.
- Clipboard History shows your recent copies as cards, like a clipboard manager: text, links, images and files, each with the app it came from and when. Click a card to copy it again; right-click to remove it. Optionally, new screenshots are added as macOS saves them (Settings > Widgets > Clipboard History > Add new screenshots; macOS asks once for access to the screenshot folder).
- Volume and brightness levels have their own color in each theme: the theme's colors, white, blue, green, orange, pink or purple (Appearance > Colors > Volume and brightness). Classic, Glass and Midnight use white; Neon Tokyo, Sakura, Synthwave and Violet Night use their own colors.
- A low battery (20% or less, on battery) stays beside the notch as a red ring and the percentage until the charger is plugged in. Turn it off in Settings > General > Indicators.

### Changed

- Tabs slide like pages: a two-finger swipe drags the open tab with your fingers while the next one comes in beside it, the page being left fades, and letting go far enough opens the next tab. Clicking a tab slides the pages the same way.
- The closed notch reaches a little past the camera housing, so you can see it's there. Set how far in Appearance > Panel Size (Closed notch width and height); the panel closes while you drag them, so you see the result. Music, timers and other things beside the notch are as tall as the closed notch, and at zero both are exactly the size of the camera housing.
- Built-in themes can be changed again (material, colors, font, shape, animation). They keep their names, your changes are saved with them, and **Restore Defaults** brings back the original. They can't be deleted.
- Volume and brightness changes beside the notch use a larger symbol and a longer bar.
- Claude Code's pixel mascot replaces the sparkle for Claude sessions.
- Hooks now also send the bundle identifier of the app the agent runs in. Installed hooks show as out of date once; click **Update** in Settings > Agents.
- The notch works in full screen apps too. Hiding it there is now off by default; turn on **Hide in full screen apps** in Settings > Displays to keep the old behavior. A choice you made earlier stays.

### Fixed

- In full screen apps the notch no longer hides behind the app's title bar when the menu bar slides down.
- Live streams (a YouTube live broadcast, say) no longer stop Now Playing: their endless duration crashed the helper, and the media widget stayed empty until Cumba was restarted.
- Opening the gallery or editing a tab no longer makes the panel narrower, which could leave the pointer outside and close it. The panel keeps its width until it closes or you switch tabs.

## [1.1.0] - 2026-11-01

### Added

- Volume and brightness changes show in the notch, on by default (Settings > General > Indicators). Either can also replace the system indicator, which needs Accessibility. Brightness uses the private DisplayServices framework, since Apple silicon has no public brightness API.
- New widgets in the gallery: Notes (one quick note, saved as plain text), Clipboard History (last 20 copied texts, in memory only, passwords skipped), Keep Awake, Pomodoro and Teleprompter (scrolls a script under the camera and can hide the panel from screen sharing).
- Calendar: a Join button for Zoom, Meet, Teams, Webex, FaceTime, Whereby and Jitsi links, and an optional countdown before the next event.
- Settings > General: show the panel on the display with a notch, the main display or the display with the pointer; a dot while the microphone or camera is in use; and the app's own CPU and memory use.
- Media sources can be turned off one by one.
- Script activities (Settings > Connections > Scripts): your own scripts can show a status or progress beside the notch through the private socket, with their own token.
- Right-click the notch for Settings, Reset Panel and Quit, so they're reachable even when the menu bar icon hides behind the notch.
- A widget gallery in Settings > Widgets: every widget with a short description and an Add or Remove button. Widgets in a tab reorder by dragging.
- Settings > Permissions shows the live state of every permission, with one button to ask or to open System Settings.
- Swipe sideways with two fingers on the open panel to move between tabs. A swipe over something that scrolls sideways, like the calendar's days, scrolls that instead.
- Calendar: scroll the days or click one to see that day's events; alone in its tab, scroll up and down through the months and click a day. Click the month to go back to today. Resting the pointer on an event shows its location and notes, and events that are over are dimmed.
- Weather: click one of the coming days to see it, and click it again to go back to now; alone in its tab, the hours scroll sideways through the next day or the day you picked.
- AI Agents: with several sessions, click "+N" to step through them.
- Four new built-in themes: Neon Tokyo (deep indigo with a pink to cyan neon edge and monospaced text), Sakura, Synthwave and Violet Night. Themes can now fade the background into a second color (Appearance > Material > Gradient) and draw a glowing neon edge around the open panel (Appearance > Colors > Neon edge).
- A welcome window on first launch: how to open the panel, where Settings are, how to connect apps, and a Launch at login switch. It asks you to move the app to Applications when it runs from somewhere else.
- Releases include a `.dmg` with an Applications shortcut next to the `.zip`.
- README sections on uninstalling.
- Release downloads carry signed build provenance; check them with `gh attestation verify`. Releases are immutable once published.
- README banner, also used as the GitHub social preview.
- Settings > Claude Code: choose what can be allowed from the notch (everything, everything except shell commands, or nothing), and copy the hook token for manual setup.
- README sections on project status, verifying a download before opening it, and the permissions the app uses and when; SECURITY.md explains how releases are built and maps the security-relevant code.

### Changed

- **ljaspNotch is now Cumba**, made by LJASP. The app, the disk image, the Chrome extension and the repository use the new name; the bundle identifier stays, so settings and Keychain tokens carry over. The app moves its folder in Application Support from `ljaspNotch` to `Cumba` on first launch. Claude Code hooks from earlier versions show as out of date: click **Update…** once in Settings > Claude Code. Load the Chrome extension again from the new app. The hook and script token header is now `X-Cumba-Token`.
- New app icon and menu bar icon: the notch resting on the brackets of a cumba, gold on deep navy.
- Tabs sit at the bottom of the panel by default (Settings > General > Tabs: at the bottom or at the top), with "+" to add a widget from a gallery and an Edit button. Editing a tab in the panel renames it, picks its symbol, moves it, adds or deletes tabs, and reorders or removes its widgets. Right-click a widget to remove it.
- The panel's width follows the open tab: as wide as its widgets, with room for a detailed view when a tab has one widget.
- The Claude Code widget is now AI Agents and also follows Codex (through its hooks in ~/.codex/hooks.json; trust them once with /hooks in Codex). It shows the session's title, what it's doing now ("Editing Notch.swift", "Running tests"), its last answer, and on a second page how full its context window is, read locally from the session transcript. While an agent works, a turning ring sits beside the closed notch, opening the panel shows the agent's tab, and a line under the notch shows the answer when it finishes. Installed Claude Code hooks show as out of date once, since two tool events were added; click Update in Settings > Agents.
- Widgets alone in a tab show a detailed view, and a compact one beside others. Weather looks like Apple's widget (sky colors, place, high and low, the next days, and the next hours when alone) and is now two units wide. Calendar shows the month with a week strip and the next events, or the whole month beside the list when alone. Media shows large artwork with the title and controls when alone.
- While something plays, the closed notch shows larger artwork and a larger waveform, sized to the notch. The Mirror widget turns the camera on only when you click it.
- Text size for the panel (Appearance > Panel Size > Text size), larger by default.
- A widget can be in several tabs; adding it to one tab no longer takes it out of another.
- The closed notch is always black over the hardware notch, whatever the theme's background color.
- The panel's width, height, indicator width and text size are set once in Appearance > Panel Size and stay when you switch themes; a theme sets only the look (material, colors, font, corner radius, shadow and animation). The size saved in an older custom theme carries over once, and theme files no longer store sizes.
- Weather shows the weather where you are by default (Location Services, rounded to about 10 km); choosing a city still works. Calendar and Weather ask for access with one click right in the widget.
- Built-in themes keep their names and settings. **New Theme…** in Appearance makes your own theme from the selected one under a name you choose, and your themes can be renamed any time. The Settings window shows the open pane's name as its title.
- Media reads whatever any app plays from the system's Now Playing: Safari, Chrome, YouTube, Spotify, Music, podcasts and more, with no extension or Automation access. This uses the private MediaRemote framework through a small helper run by the system's perl; the README explains it. Turn off "Read media from every app" for the previous behavior. The YouTube extension is now optional.
- New installations start with Media, Calendar and Timer; the other widgets, and widgets added in later versions, wait in the gallery. Installing the Claude Code hooks adds the Claude Code widget.
- Dragging a window or a browser tab past the notch no longer opens the panel; dragging files still does.
- Settings has no minimize button, reopens on the last pane and shows the pane's name as its title.
- Calmer motion: the lowest spring damping a theme can use is 0.7. Increase Contrast draws a clear panel rim, and Reduce Transparency replaces glass with an opaque fill.
- Empty and error states in widgets open the Settings pane that fixes them. The welcome window starts with a live "try it" step.
- The Chrome extension connection is off until you turn it on in Settings > Connections; if you use the extension, turn it on and paste the new extension token into its options.
- With Reduce Motion turned on in System Settings, the panel opens and closes with a short ease instead of a spring.
- Questions and ideas go to GitHub Discussions; issues are for bugs and concrete feature requests.

### Fixed

- When Claude Code asks a question or wants a plan approved, the notch no longer shows it as a permission request with Allow and Deny; Claude Code asks it itself, and the notch shows that the session is waiting, with the question under the notch.
- Long tool and project names, and the edges of icons, beside the closed notch are no longer cut off.
- Notes were never saved: macOS 26.6 refuses writes with complete file protection. The note is now written atomically and readable only by you.
- Context menus inside the panel (e.g. on files in the tray) now open; the notch's own menu used to replace them.

### Security

- Script activities are off by default, use their own token on the private socket, are escaped like permission requests and can't be clicked. The volume key handling sees only media key events, never typing, and is off by default.
- Nothing listens unless you use it: the extension server runs only while the extension connection is on, the hook socket only while hooks are installed.
- The hooks and the extension have separate tokens, so the hook token in `~/.claude/settings.json` can't be used on the extension's port.
- Allow from the notch can be limited, and the limit is enforced when the answer is sent, not only in the UI.
- The hook installer refuses to save if the settings file changed in any byte since the review, and says when saving will also reformat it.
- The release build uses a pinned, checksummed XcodeGen instead of the latest Homebrew version.

## [1.0.0] - 2026-10-31

### Added

- Update check against GitHub Releases at launch and once a day, with an optional pre-release channel and a menu bar item when a newer version exists.
- Copy Diagnostics in Settings > General for bug reports, without tokens, paths or personal data.
- Optional haptic tap when the panel opens.

### Changed

- Panel polish: content materializes from a slight blur, a hairline edge, hover and press feedback on every control, animated tab and pin symbols, and an album-art glow on the media card.
- Artwork is decoded once per track off the main thread.
- README rewritten for the first stable release.

### Security

Fixes from a security review of the code, done with AI assistance (not an external audit):

- Claude Code hooks now reach the app through a Unix socket in a folder only your account can open, using `command` hooks with curl, instead of HTTP on a TCP port. Another user or a sandboxed app could otherwise have taken the port while the app was closed and approved commands. Update the hooks in Settings > Claude Code.
- The permission card shows the full request, makes control, direction and zero-width characters and long space runs visible, offers no Allow button for suspicious requests, and arms its buttons only after a short delay.
- The extension socket accepts only the ljaspNotch extension (fixed extension ID) and closes on anything but a valid hello; the extension keeps the token away from content scripts.
- Both local servers restart after a failure.
- The hook installer recognizes only its own entries, resolves symlinks, refuses to touch a settings file it can't read, keeps backups private and masks the token in the diff.
- The token is copied as concealed and cleared from the clipboard after a minute.
- Artwork is fetched only from Spotify and YouTube image hosts, streamed with a size cap.
- Release builds run without write access; only the publish step can write. FlyingFox and all actions are pinned to commits; checkout without persisted credentials; Dependabot for actions.

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

[Unreleased]: https://github.com/muazfurkan/Cumba/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/muazfurkan/Cumba/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/muazfurkan/Cumba/compare/v0.7.0...v1.0.0
[0.7.0]: https://github.com/muazfurkan/Cumba/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/muazfurkan/Cumba/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/muazfurkan/Cumba/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/muazfurkan/Cumba/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/muazfurkan/Cumba/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/muazfurkan/Cumba/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/muazfurkan/Cumba/releases/tag/v0.1.0
