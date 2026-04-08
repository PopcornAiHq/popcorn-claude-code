# CLAUDE.md — popcorn-claude-code

Popcorn messaging plugin for Claude Code.

## Structure

```
popcorn-claude-code/
├── skills/
│   ├── popcorn/
│   │   ├── SKILL.md       ← Always-on: CLI + MCP routing, setup, guardrails
│   │   └── setup.sh       ← Deterministic setup: CLI install, auth, MCP
│   └── pop/
│       └── SKILL.md       ← /popcorn:pop — deploy/publish site files (user-triggered)
├── .claude-plugin/
│   ├── plugin.json         ← Plugin manifest
│   └── marketplace.json    ← Marketplace listing
├── dev/                        ← Dev-only tooling (not used at runtime)
│   ├── test-install.sh         ← Isolated env for testing plugin install flow
│   ├── check-version-bump.sh   ← Pre-commit hook: warns on missing version bump
├── Makefile                    ← make bump v=X.Y.Z
├── .pre-commit-config.yaml     ← version bump reminder hook
├── CLAUDE.md
├── README.md
└── LICENSE
```

## Skills

**popcorn** (alwaysApply: true):
- Routes agent to CLI (preferred) or MCP tools (fallback)
- Installs CLI and MCP on first use via setup.sh
- Command discovery via `popcorn commands`
- MCP tool reference (whoami, get_channel, update_channel, post_message, read_messages, search, react)
- Behavioral constraints (quote channels, confirm before sending, JSON envelope parsing)

**/popcorn:pop** (slash command, user-triggered):
- Publishes local project files to a Popcorn app channel via VM
- Reads `.popcorn.local.json` (v2: multi-target, workspace-aware) for target resolution
- CLI deploy path (preferred): `popcorn site deploy`
- MCP deploy path (fallback): delegates to server-side `pop` prompt

## Dependencies

This plugin has no code dependencies. It provides skills that guide the agent to use either:
- **popcorn-cli** (auto-installed on first use via uv/pipx/pip) — full-featured CLI, preferred in terminal
- **Popcorn MCP server** (`https://mcp.popcorn.ai/mcp`) — always installed, enables conversational features and deploy fallback

## Versioning

**Bump the version with every set of changes.** Both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must stay in sync.

- **Patch** (0.7.0 → 0.7.1): default for any change
- **Minor** (0.7.x → 0.8.0): notable feature additions
- **Major** (0.x → 1.x): only when explicitly requested

### Workflow

1. Commit your changes first (do NOT include version bump in the same commit)
2. Run `make bump v=X.Y.Z` — this creates a separate version bump commit
3. `git push`

```bash
make bump v=X.Y.Z    # updates both files, stages, commits
```

A pre-commit hook warns if source files are staged without a version bump.

## Releasing

After bumping: `git push`.
