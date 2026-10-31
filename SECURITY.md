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

## Supported versions

Only the latest release receives security fixes.
