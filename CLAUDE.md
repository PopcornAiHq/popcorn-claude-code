# CLAUDE.md — popcorn-claude-code

Popcorn messaging plugin for Claude Code.

## Structure

```
popcorn-claude-code/
├── skills/
│   ├── cli/
│   │   ├── SKILL.md       ← Always-on: CLI routing, setup, MCP fallback, guardrails
│   │   └── setup.sh       ← Deterministic setup: CLI install, auth, MCP
│   └── pop/
│       └── SKILL.md       ← /popcorn:pop — deploy/publish site files (user-triggered)
├── .claude-plugin/
│   ├── plugin.json         ← Plugin manifest
│   └── marketplace.json    ← Marketplace listing
├── scripts/
│   ├── pop-upload.sh       ← Tarball + S3 upload for MCP deploy path
│   ├── test-install.sh     ← Isolated env for testing plugin install flow
│   └── check-version-bump.sh ← Pre-commit hook: warns on missing version bump
├── docs/                       ← Plans and specs
├── Makefile                    ← make bump v=X.Y.Z
├── .pre-commit-config.yaml     ← version bump reminder hook
├── CLAUDE.md
├── README.md
└── LICENSE
```

## Skills

**cli** (alwaysApply: true):
- Routes agent to CLI (preferred) or MCP fallback
- Installs CLI and MCP on first use
- Command discovery via `popcorn commands`
- MCP deploy flow when CLI unavailable (uses `scripts/pop-upload.sh`)
- Behavioral constraints (quote channels, never use inbox for file search, etc.)

**/popcorn:pop** (slash command, user-triggered):
- Publishes local project files to a Popcorn app channel via VM
- Reads `.popcorn.local.json` (v2: multi-target, workspace-aware) for target resolution
- Wraps CLI `popcorn site deploy`

## Dependencies

This plugin has no code dependencies. It provides skills that guide the agent to use either:
- **popcorn-cli** (auto-installed on first use via uv/pipx/pip) — full-featured CLI, preferred in terminal
- **Popcorn MCP server** (`https://mcp.popcorn.ai/mcp`) — primary path outside terminal (Cowork, etc.)

## Versioning

**Bump the version with every commit.** Both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must stay in sync.

- **Patch** (0.7.0 → 0.7.1): default for any commit
- **Minor** (0.7.x → 0.8.0): notable feature additions
- **Major** (0.x → 1.x): only when explicitly requested

```bash
make bump v=X.Y.Z    # updates both files, stages, commits
```

A pre-commit hook warns if source files are staged without a version bump.

## Releasing

After bumping: `git push`.
