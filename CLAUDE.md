@AGENTS.md

## Claude Code specifics

- **Hooks** (`.claude/settings.json`):
  - SessionStart prints the active stage.
  - PostToolUse runs `dart format` on edited `.dart` files, and **blocks** a `pubspec.yaml` edit that adds a denylisted dependency. The scripts are in `tool/hooks/`; they need `dart` on PATH.
- **Skills** (`.claude/skills/`): `orchestrate-wave`, `run-session`, `plan-stage`, `invariant-review`.
- **MCP:** the `dart` server (`dart mcp-server`, from `.mcp.json`) provides analyze, format, tests, pub, `pub_dev_search` and running-app tools. Prefer it for package lookups.
- **Plugins** (project-enabled): `dart-lsp` (this repo's marketplace), `context7` (current library docs), `commit-commands`, `pr-review-toolkit`.
- **Parallel sessions:** dispatch with the Agent tool, `isolation: "worktree"`, one agent per session brief, all in one message. Never predict or fabricate a background agent's result.
