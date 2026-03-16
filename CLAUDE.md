# CLAUDE.md — popcorn-claude-code

Popcorn messaging plugin for Claude Code.

## Structure

```
popcorn-claude-code/
├── skills/
│   ├── cli/
│   │   ├── SKILL.md       ← Always-on: CLI routing, setup, command discovery, guardrails
│   │   └── setup.sh       ← Deterministic setup: CLI install, auth, MCP
│   ├── pop/
│   │   └── SKILL.md       ← /popcorn:pop — deploy/publish site files only
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

**cli** (alwaysApply: true):
- Routes agent to correct skill vs direct CLI usage
- Installs CLI and MCP on first use
- Command discovery via `popcorn commands`
- Behavioral constraints (quote channels, never use inbox for file search, etc.)

**/popcorn:pop** (slash command):
- Publishes local project files to a Popcorn app channel via VM
- Creates `.popcorn.local.json` to track channel link (gitignored)
- Uses CLI `popcorn pop` with MCP fallback

**/popcorn:messages** (slash command):
- Pulls recent channel conversation into context
- Lets developer iterate based on team feedback, then `/popcorn:pop` again

## Dependencies

This plugin has no code dependencies. It provides skills that guide the agent to use either:
- **popcorn-cli** (auto-installed on first use via uv/pipx/pip) — full-featured CLI
- **Popcorn MCP server** (`https://mcp.popcorn.ai/mcp`) — lighter alternative

## Releasing

Update version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, then push.
