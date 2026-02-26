# popcorn-claude-code

Popcorn messaging plugin for [Claude Code](https://claude.ai/code).

## Install

In Claude Code:

```
/plugin marketplace add PopcornAiHq/popcorn-claude-code
/plugin install popcorn@popcorn
```

## What's Included

- **popcorn** skill — always-on reference for Popcorn messaging. Detects CLI/MCP availability and guides setup.
- **pop** slash command — publish your project on Popcorn (coming soon).

## CLI vs MCP

This plugin works with either transport:

| | CLI | MCP |
|---|---|---|
| Install | `pip install popcorn-cli` | `claude mcp add popcorn --transport http https://mcp.popcorn.ai/mcp` |
| Features | Full (30+ commands) | Subset |
| Context usage | Minimal (runs in shell) | Higher (MCP tool calls) |
| Recommended | Yes | Fallback |

The plugin will guide you through setup on first use.

## License

MIT
