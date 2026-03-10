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
- `/popcorn:pop` — publish your project on Popcorn (coming soon)
- `/popcorn:messages` — pull recent channel conversation into context

## CLI vs MCP

This plugin works with either transport:

| | CLI | MCP |
|---|---|---|
| Install | `pip install popcorn-cli` | `claude mcp add popcorn --transport http https://mcp.popcorn.ai/mcp` |
| Features | Full (30+ commands) | Subset |
| Context usage | Minimal (runs in shell) | Higher (MCP tool calls) |
| Recommended | Yes | Fallback |

The plugin will guide you through setup on first use.

## Development

### Testing the install flow

```bash
./scripts/test-install.sh
```

Launches Claude Code in an isolated environment (temp project + clean config dir) so you can test plugin installation without affecting your real setup. Follow the on-screen prompts to install and verify skills load correctly.

## License

MIT
