# ClaudePet

ClaudePet is a native macOS overlay companion for Claude Code sessions.

It creates a transparent floating window that appears across Spaces, draws a small Claude-themed pet, and shows live Claude sessions discovered from local Claude state.

## What It Reads

- `~/.claude/sessions/*.json`
- Live process IDs for those session records

The first version does not read prompt bodies or transcript JSONL files. It uses session metadata such as PID, working directory, entrypoint, kind, status, and timestamps.

## Session Activation

Click a visible session bubble to jump to that Claude session.

ClaudePet supports app activation for:

- Terminal.app
- Ghostty
- Visual Studio Code
- Visual Studio Code Insiders
- cmux

When ClaudePet can identify the owning app but cannot identify the exact tab or window, it still brings that app forward. Exact tab/window focusing may require macOS Accessibility or Automation permission. If Accessibility permission is missing, ClaudePet asks macOS to show the permission prompt and shows an error bubble until access is granted.

## Run

```bash
./scripts/run_app.sh
```

## Check

```bash
./scripts/check.sh
```

## Notes

- The window is an accessory app, so it does not show in the Dock.
- The overlay starts near the bottom-right of the main screen.
- The app polls Claude session state every two seconds.
- Claude sessions with dead PIDs are hidden.
