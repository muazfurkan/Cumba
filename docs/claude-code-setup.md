# Claude Code setup

ljaspNotch receives [Claude Code hooks](https://code.claude.com/docs/en/hooks) over HTTP on `127.0.0.1`. Permission requests then appear in the notch, and you see when a session finishes or fails. This works for Claude Code in the terminal, in IDE extensions and in the Claude desktop app, because they all read `~/.claude/settings.json`.

## The easy way

Open **ljaspNotch > Settings > Claude Code** and click **Install…**. You see the exact change to `~/.claude/settings.json` before anything is written. The current file is backed up next to it as `settings.json.bak-YYYYMMDD-HHMMSS`. Your other settings and hooks are kept.

**Remove…** deletes only ljaspNotch's entries: HTTP hooks whose URL is `http://127.0.0.1:<port>/claude/hook`.

After changing the port or regenerating the token in **Settings > Connections**, the status shows **Out of date**; click **Update…**.

## By hand

Copy the port and token from **Settings > Connections** and add this to `~/.claude/settings.json`, keeping anything already there:

```json
{
  "hooks": {
    "UserPromptSubmit":  [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 5,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "PermissionRequest": [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 300, "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "Notification":      [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 5,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "Stop":              [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 5,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "StopFailure":       [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 5,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }],
    "SessionEnd":        [{ "hooks": [{ "type": "http", "url": "http://127.0.0.1:47823/claude/hook", "timeout": 2,   "headers": { "X-LjaspNotch-Token": "<TOKEN>" } }] }]
  }
}
```

Notes:

- The token is written as plain text on purpose. Apps started from the Dock don't inherit variables from your shell profile, so `$VAR` in the header would silently be empty in the Claude desktop app.
- `SessionStart` doesn't support HTTP hooks, so a session appears when you send its first prompt.
- Keep an explicit `timeout` on `SessionEnd`. Without one, Claude Code gives all `SessionEnd` hooks only 1.5 seconds together.
- Don't add `"onFailure": "block"`. With the default, Claude Code carries on normally when ljaspNotch isn't running.
- If your settings define `allowedHttpHookUrls`, add `http://127.0.0.1:*` to it, or Claude Code skips these hooks.

## What happens with a permission request

1. Claude Code posts the request and waits for the answer.
2. The notch shows the project, the tool and a short summary (the command for Bash, the file for edits).
3. **Allow** or **Deny** answers Claude Code. **In Terminal** answers with nothing, so Claude Code shows its own dialog.
4. If you don't answer within 290 seconds, ljaspNotch hands the decision back to Claude Code's own dialog.

## Privacy

Hook payloads (commands, file paths, messages) stay in memory and are never written to disk or logged. The server listens only on `127.0.0.1`, checks the `Host` header and rejects requests without the token or from a website.
