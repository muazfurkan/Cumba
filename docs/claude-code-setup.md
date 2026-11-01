# Claude Code and Codex setup

Cumba receives [Claude Code hooks](https://code.claude.com/docs/en/hooks) on a private Unix socket. Permission requests then appear in the notch, the AI Agents widget shows what a session is doing, and you see when it finishes or fails. This works for Claude Code in the terminal, in IDE extensions and in the Claude desktop app, because they all read `~/.claude/settings.json`.

## The easy way

Open **Cumba > Settings > Agents**, choose Claude Code and click **Install…**. You see the exact change to `~/.claude/settings.json` before anything is written (the token is masked in that view). The current file is backed up next to it as `settings.json.bak-YYYYMMDD-HHMMSS`, readable only by you. Your other settings and hooks are kept, and a symlinked `settings.json` stays a symlink.

**Remove…** deletes only Cumba's entries. If the status shows **Out of date** (for example after an update changed the hook format), click **Update…**.

Cumba's socket runs only while hooks are installed. In **Settings > Agents** you also choose what can be allowed from the notch: everything, everything except shell commands, or nothing (only Deny and In Terminal). Allow in the notch is the same as Allow in Claude Code.

## How it works

Each hook is a `command` hook that pipes the event to the app with curl:

```
/usr/bin/curl -sf --max-time 299 --unix-socket '/Users/<you>/Library/Application Support/Cumba/hook.sock' -H 'X-Cumba-Token: <TOKEN>' -H 'Content-Type: application/json' -H "X-Cumba-App: ${__CFBundleIdentifier:-}" --data-binary @- http://localhost/claude/hook || true
```

- **Why a Unix socket and not a TCP port:** the socket's folder can be opened only by your user account. A TCP port on 127.0.0.1 could be taken by another user on the same Mac, or by a sandboxed app, while Cumba isn't running. That process could then answer Claude Code's permission requests, so Cumba doesn't use one for hooks.
- **When Cumba is closed**, curl fails, `-sf` keeps it quiet and `|| true` makes the hook succeed with no output. Claude Code carries on with its own permission dialog.
- **`X-Cumba-App`** is the bundle identifier of the app Claude Code runs in (Terminal, iTerm, VS Code, the Claude app), which macOS puts in `__CFBundleIdentifier`. **Open** in a notification brings that app forward; Cumba only activates an app that's already running and never starts one. Hooks from before this header show as out of date once; click **Update** in **Settings > Agents**.
- **The token is written as plain text** on purpose. Apps started from the Dock don't inherit variables from your shell profile, so a `$VAR` would be empty in the Claude desktop app.

## By hand

Copy the token with **Copy Hook Token** in **Settings > Agents**. It's separate from the Chrome extension's token. After saving the file, open **Settings > Agents** once (or restart Cumba) so the socket starts. Then add one entry per event to `~/.claude/settings.json`, keeping anything already there. Use the command above with the matching timeout, and set curl's `--max-time` one second lower:

| Event | `timeout` |
|---|---|
| `UserPromptSubmit` | 5 |
| `PreToolUse` | 5 |
| `PostToolUse` | 5 |
| `PermissionRequest` | 300 |
| `Notification` | 5 |
| `Stop` | 5 |
| `StopFailure` | 5 |
| `SessionEnd` | 2 |

```json
{
  "hooks": {
    "PermissionRequest": [{ "hooks": [{ "type": "command", "timeout": 300, "command": "/usr/bin/curl -sf --max-time 299 --unix-socket '…/hook.sock' -H 'X-Cumba-Token: <TOKEN>' -H 'Content-Type: application/json' -H \"X-Cumba-App: ${__CFBundleIdentifier:-}\" --data-binary @- http://localhost/claude/hook || true" }] }]
  }
}
```

Notes:

- `SessionStart` is not used. A session appears when you send its first prompt.
- Keep an explicit `timeout` on `SessionEnd`. Without one, Claude Code gives all `SessionEnd` hooks only 1.5 seconds together.
- If `disableAllHooks` is `true` in your settings, Claude Code ignores these hooks; the settings tab warns about it.

## What happens with a permission request

1. Claude Code sends the request and waits for the answer.
2. The notch shows the project, the tool and everything the request would do: the full command for Bash, the file for edits, the URL for fetches, the whole input as JSON for other tools. Hidden characters (control, direction and zero-width characters) are shown as `⟨U+XXXX⟩`, long runs of spaces as `⟨N spaces⟩`.
3. **Allow** or **Deny** answers Claude Code. **In Terminal** answers with nothing, so Claude Code shows its own dialog. The buttons only work after the request has been on screen for a moment, so a stray or double click can't approve something you haven't seen.
4. If the request contains hidden characters or is too long to show, only **Deny** and **In Terminal** are offered.
5. If you don't answer within 290 seconds, Cumba hands the decision back to Claude Code's own dialog.
6. Questions (`AskUserQuestion`) and plan approvals (`ExitPlanMode`) also arrive as permission requests, but Allow or Deny would answer neither. Cumba answers them at once with nothing, so Claude Code asks you itself. A notification under the notch says the agent is asking (with the question and **Open**), and the agent's mark with a question badge stays beside the notch until you answer.

## Codex

Choose Codex in **Settings > Agents** and click **Install…**. The hooks go to `~/.codex/hooks.json` and post to `http://localhost/codex/hook` on the same socket, with the same review, backup and token. Codex sends the same events except `Notification` and `StopFailure`. Codex runs new hooks only after you trust them: run `/hooks` in Codex once and trust Cumba's entries.

## Privacy

Hook payloads (commands, file paths, messages) stay in memory and are never written to disk or logged. For the context use and the session title, Cumba reads the last 256 KB of the session's transcript, and only transcripts under `~/.claude/projects`.
