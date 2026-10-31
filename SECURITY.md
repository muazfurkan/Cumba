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

- **Web pages** can't reach the local server: the extension socket requires our extension's exact Origin and a loopback `Host` header (DNS rebinding), and no CORS headers are sent.
- **Other users on the same Mac and sandboxed apps** can't answer Claude Code in ljaspNotch's place: hooks go through a Unix socket in a folder only your account can open, not through a TCP port that someone else could take while the app is closed.
- **A misleading permission request** (prompt-injected text that hides part of a command) is shown in full with hidden characters made visible; suspicious requests get no Allow button, and buttons arm only after the request has been on screen briefly.
- **Changes to `~/.claude/settings.json`** happen only after you review a diff; a private backup is made, unreadable or changed files are never overwritten, and only ljaspNotch's own entries are removed.

Out of scope: malware already running as your user. It can read your files, the Keychain prompt aside, and edit `~/.claude/settings.json` directly.

Known limit: the HTTP library has no caps on headers, WebSocket frame size or connection count, so a local process can make the extension server use memory or file descriptors before authenticating. The server restarts after such failures.

## Verifying downloads

Every release lists SHA-256 checksums. Releases after 1.0.0 are immutable and carry signed build provenance from the release workflow:

```bash
gh attestation verify ljaspNotch-vX.Y.Z.zip --repo muazfurkan/ljaspNotch
```

If verification fails, don't open the app, and please report it privately.

## Supported versions

Only the latest release receives security fixes.
