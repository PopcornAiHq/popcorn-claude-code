# popcorn-claude-code

Work on your Popcorn trackers from [Claude Code](https://claude.ai/code).

[Popcorn](https://www.popcorn.ai/) is an AI tracker — it reads across email,
messages and files, catching every update and decision, and updates itself
rather than waiting for someone to maintain it. Each channel is one tracker.

What a channel tracks is defined by an **app bundle**: tables holding what it
keeps, flows doing the updating, schedules and webhooks catching updates as they
arrive, and an `AGENT.md` shaping how it talks. This plugin lets Claude Code read
and change that bundle.

## Install

In Claude Code:

```
/plugin marketplace add PopcornAiHq/popcorn-claude-code
/plugin install popcorn@popcorn
```

> Tip: Enable auto-update for this marketplace in `/plugin` → Marketplaces to stay current.

## What's Included

- **popcorn** skill — loads from what you ask for: a `#channel`, a tracker, or a change to what a channel tracks. Sets up CLI + MCP, routes commands, and keeps the agent honest about what Popcorn can and can't do.
- `/popcorn:template` — author, validate, publish and debug a channel template: the `app fork` → `checkout` → edit → `template check` → `app publish` loop. Requires the CLI; the MCP path cannot publish bundles.

## CLI vs MCP

This plugin works with either transport:

| | CLI | MCP |
|---|---|---|
| Install | Auto-installed on first use | Auto-configured on first use |
| Updates | Auto-updates itself (or `popcorn upgrade`) | Server-side (transparent) |
| Features | Full (30+ commands) | 6 tools (conversations only) |
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
