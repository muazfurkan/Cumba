# Security Policy

ljaspNotch runs a local HTTP/WebSocket server on `127.0.0.1` and receives Claude Code hook events, so security reports are taken seriously.

## Reporting a vulnerability

**Please do not open a public issue.** Report it privately through GitHub instead:

1. Go to the [Security tab](https://github.com/muazfurkan/ljaspNotch/security) of this repository.
2. Click **Report a vulnerability**, or open [a new advisory](https://github.com/muazfurkan/ljaspNotch/security/advisories/new) directly.

Please include the app version, your macOS version and steps to reproduce. Never include real tokens, Claude Code payloads or personal file paths.

This is a personal project maintained in spare time. You can expect an initial response within a week. Fixes ship in the next release and the advisory is published once a fix is available.

## Scope

Reports are especially welcome for:

- The local server: binding, token checks, origin checks, CORS
- The Claude Code hook integration and the permission flow
- Token storage in the Keychain
- The Chrome extension and its WebSocket connection
- Changes the app makes to `~/.claude/settings.json`

## Threat model

What ljaspNotch defends against:

- **Nothing listens unless you use it.** The extension server starts only after you turn on the YouTube extension connection, and the hook socket only while Claude Code hooks are installed.
- **Web pages** can't reach the local server: the extension socket requires our extension's exact Origin and a loopback `Host` header (DNS rebinding), and no CORS headers are sent.
- **Optional features stay off.** Script activities, the volume key tap and the microphone/camera indicator start only after you turn them on. The key tap asks only for media key events (`NX_SYSDEFINED`), not keystrokes. Script activities are text only, escaped and never clickable.
- **Separate tokens.** The hooks, the extension and script activities each have their own 256-bit token in the Keychain. The hook token is written into `~/.claude/settings.json` (which other local accounts may be able to read), but it only opens the private socket, never the extension's TCP port.
- **Other users on the same Mac and sandboxed apps** can't answer Claude Code in ljaspNotch's place: hooks go through a Unix socket in a folder only your account can open, not through a TCP port that someone else could take while the app is closed.
- **A misleading permission request** (prompt-injected text that hides part of a command) is shown in full with hidden characters made visible; suspicious requests get no Allow button, and buttons arm only after the request has been on screen briefly. Allow in the notch approves the tool call just like Allow in Claude Code, so Settings can limit it to everything except shell commands or turn it off. The limit is enforced where the answer is sent, not only by hiding the button.
- **Changes to `~/.claude/settings.json`** happen only after you review a diff; a private backup is made, unreadable files are never overwritten, a file that changed in any byte since the review isn't written, and only ljaspNotch's own entries are removed. If saving will also reformat the file (sorted keys, standard indentation), the review says so.

Out of scope: malware already running as your user. It can read your files, the Keychain prompt aside, and edit `~/.claude/settings.json` directly.

Known limits:

- Releases are signed ad hoc, not with an Apple Developer ID, and aren't notarized. macOS can't tie an update to a developer identity, so it asks again for permissions and Keychain access after each update. Check the download (below) before allowing.
- The HTTP library has no caps on headers, WebSocket frame size or connection count, so a local process can make the extension server use memory or file descriptors before authenticating. The server restarts after such failures.

## How releases are built

A release is built only by the [release workflow](.github/workflows/release.yml) when a `v*` tag is pushed. The build job has read-only access; it installs a pinned, checksummed XcodeGen, builds on a GitHub-hosted macOS runner, signs ad hoc with the [entitlements](ljaspNotch/Resources/ljaspNotch.entitlements) in the repo, and packages a `.dmg`, a `.zip`, the Chrome extension and `SHA256SUMS.txt`. A separate publish job runs no build tools: it creates the provenance attestation and the GitHub release. All actions are pinned to commit SHAs, and the repository allows only GitHub-owned actions.

## Verifying downloads

Every release lists SHA-256 checksums:

```bash
shasum -a 256 ljaspNotch-vX.Y.Z.dmg
```

From 1.1.0 on, releases are immutable and carry signed build provenance, which ties the file to this repository, the tagged commit and the workflow run:

```bash
gh attestation verify ljaspNotch-vX.Y.Z.dmg --repo muazfurkan/ljaspNotch
```

If a check fails, don't open the app, and please report it privately. To avoid trusting a prebuilt binary at all, build from source as described in the README.

## Reviewing the code

The security-relevant code is small. Start here:

| Area | Files |
|---|---|
| Local servers, tokens | `ljaspNotch/Server/` (`LocalServer`, `RequestGuard`, `MediaSocket`, `TokenStore`, `ScriptActivityRoute`) |
| Volume key tap, microphone/camera indicator | `ljaspNotch/System/` |
| Claude Code hooks and permission flow | `ljaspNotch/Claude/` (`ClaudeHookRoute`, `PermissionBroker`, `NotchApprovals`, `SafeText`, `HookInstaller`) |
| Permission card | `ljaspNotch/Widgets/ClaudeCode/ClaudeCodeWidget.swift` (`PermissionCard`) |
| AppleScript | `ljaspNotch/Media/AppleScriptRunner.swift`, `ljaspNotch/Media/Providers/` |
| Network requests | `ljaspNotch/Widgets/Media/ArtworkCache.swift`, `ljaspNotch/Widgets/Weather/WeatherService.swift`, `ljaspNotch/App/Updates/UpdateChecker.swift` |
| Chrome extension | `extensions/chrome/` |
| Entitlements, Info.plist | `ljaspNotch/Resources/`, `project.yml` |
| Release pipeline | `.github/workflows/release.yml` |

The only third-party dependency is [FlyingFox](https://github.com/swhitty/FlyingFox) (MIT), pinned to a commit in `project.yml`.

## Supported versions

Only the latest release receives security fixes.
