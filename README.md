# popcorn-claude-code

Popcorn messaging plugin for [Claude Code](https://claude.ai/code).

## Install

In Claude Code:

```
/plugin marketplace add PopcornAiHq/popcorn-claude-code
/plugin install popcorn@popcorn
```

> Tip: Enable auto-update for this marketplace in `/plugin` → Marketplaces to stay current.

## What's Included

- **popcorn** skill — always-on integration for Popcorn messaging. Sets up CLI + MCP, provides command routing and guardrails.
- `/popcorn:pop` — publish your project to a Popcorn channel in one command.
- `/popcorn:messages` — pull recent channel messages into context for iteration.

## CLI vs MCP

This plugin works with either transport:

| | CLI | MCP |
|---|---|---|
| Install | Auto-installed on first use | Auto-configured on first use |
| Updates | Auto-updates itself (or `popcorn upgrade`) | Server-side (transparent) |
| Features | Full (30+ commands) | 7 tools (messaging, channels, deploy) |
| Context usage | Minimal (runs in shell) | Higher (MCP tool calls) |
| Recommended | Yes — preferred for all operations | Always available for conversational features |

Both are installed on first use. The plugin prefers CLI when available and falls back to MCP tools.

## Development

### Testing the install flow

```bash
./dev/test-install.sh
```

Launches Claude Code in an isolated environment (temp project + clean config dir) so you can test plugin installation without affecting your real setup.

### Version bumping

```bash
make bump v=X.Y.Z
```

Updates `plugin.json` and `marketplace.json`, commits, ready to push.

## License

MIT
