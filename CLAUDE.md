# CLAUDE.md — popcorn-claude-code

Popcorn messaging plugin for Claude Code.

## Structure

```
popcorn-claude-code/
├── skills/
│   ├── popcorn/
│   │   └── SKILL.md       ← Always-on: setup detection + CLI reference + MCP fallback
│   └── pop/
│       └── SKILL.md       ← Slash command: publish project (coming soon)
├── .claude-plugin/
│   ├── plugin.json         ← Plugin manifest
│   └── marketplace.json    ← Marketplace listing
├── CLAUDE.md
├── README.md
└── LICENSE
```

## Skills

**popcorn** (alwaysApply: true):
- Detects whether CLI or MCP is available
- Guides users through setup if neither is found (recommends CLI, falls back to MCP)
- Full CLI command reference and recipes
- Behavioral constraints (quote channels, never use inbox for file search, etc.)

**pop** (slash command):
- Placeholder — not yet implemented

## Dependencies

This plugin has no code dependencies. It provides skills that guide the agent to use either:
- **popcorn-cli** (`pip install popcorn-cli`) — full-featured CLI
- **Popcorn MCP server** (`https://mcp.popcorn.ai/mcp`) — lighter alternative

## Releasing

Update version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, then push.
