# CLAUDE.md — popcorn-claude-code

Popcorn messaging plugin for Claude Code.

## Structure

```
popcorn-claude-code/
├── skills/
│   ├── popcorn/
│   │   ├── SKILL.md       ← Always-on: setup detection + CLI reference + MCP fallback
│   │   └── setup.sh       ← Deterministic setup: CLI install, auth, MCP
│   ├── pop/
│   │   ├── SKILL.md       ← /popcorn:pop — publish project to Popcorn channel
│   │   └── pop.sh         ← Deploy script: tarball + upload + deploy via CLI
│   └── messages/
│       └── SKILL.md       ← /popcorn:messages — pull channel context for iteration
├── .claude-plugin/
│   ├── plugin.json         ← Plugin manifest
│   └── marketplace.json    ← Marketplace listing
├── scripts/
│   └── test-install.sh     ← Isolated env for testing plugin install flow
├── CLAUDE.md
├── README.md
└── LICENSE
```

## Skills

**popcorn** (alwaysApply: true):
- Installs CLI and MCP on first use
- Full CLI command reference and recipes
- Behavioral constraints (quote channels, never use inbox for file search, etc.)

**/popcorn:pop** (slash command):
- Publishes local project files to a Popcorn app channel via VM
- Creates `.popcorn.local.json` to track channel link (gitignored)
- Uses CLI `deploy push` with MCP fallback

**/popcorn:messages** (slash command):
- Pulls recent channel conversation into context
- Lets developer iterate based on team feedback, then `/popcorn:pop` again

## Dependencies

This plugin has no code dependencies. It provides skills that guide the agent to use either:
- **popcorn-cli** (auto-installed on first use via uv/pipx/pip) — full-featured CLI
- **Popcorn MCP server** (`https://mcp.popcorn.ai/mcp`) — lighter alternative

## Releasing

Update version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, then push.
