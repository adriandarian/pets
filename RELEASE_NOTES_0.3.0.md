## The Multi-Provider Tracker Update

Pets can now watch Claude Code, Codex, and GitHub Copilot sessions independently, and track local app and CLI activity for 15 additional tools and applications.

### What's new

- **Multi-provider session tracking**: Each pet can independently track Claude Code, Codex, GitHub Copilot, or any combination of them.
- **Tracker assignment UI**: A new Tracking section in pet settings lets you assign each provider to a specific pet.
- **Per-pet session display**: Pets show only sessions from their assigned trackers, not all active sessions.
- **Source display names**: Session bubbles now show which tracker the session comes from (Claude Code, Codex CLI, Copilot chat, etc.).
- **Local activity adapters**: Pets can now track real local app and CLI activity for Cursor, Ollama, Gemini, Antigravity, Hermes, T3 Code, Open Design, Kiro, Zed, Windsurf, opencode, pi, NotebookLM, LM Studio, and Stitch.
- **Provider icons**: Each tracker has its own icon in the Chests interface showing reward source status.
- **Reorganized settings**: Pet configuration is now split into three tabs: Pets, Chests, and Collection.

### Important notes

- Existing pets default to tracking Claude Code only. Configure the Tracking section to enable other providers.
- Activity trackers contribute to the Collection reward system (see Collection tab for details).
- Chat status visibility remains limited to Claude Code, Codex, and GitHub Copilot.

### Installing the update

Quit Pets, download `Pets-0.3.0.zip`, and replace the existing `Pets.app`. Your configured pets, positions, preferences, keys, and collection progress remain in place.

Pets is signed with the maintainer's Apple Development certificate and hardened runtime, but it is not Developer ID signed or notarized. If macOS blocks the first launch, Control-click `Pets.app`, choose **Open**, and confirm.
