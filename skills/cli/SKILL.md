---
name: cli
description: Popcorn CLI — setup, command discovery, and behavioral guardrails. Use for any Popcorn operation not covered by /pop or /messages.
alwaysApply: true
allowed-tools: Bash
---

# Popcorn CLI

## Routing: CLI first, always

**Use the CLI directly for ALL Popcorn operations.** This includes deploying (`popcorn pop`), reading messages (`popcorn list-messages`), sending messages, managing channels — everything.

**`/popcorn:pop` and `/popcorn:messages` are user-triggered slash commands.** They provide guided workflows but are ONLY activated when the user explicitly types `/pop` or `/messages`. Never invoke them, never suggest them, never route to them. If the user asks to deploy or read messages without using the slash command, use the CLI directly.

Run `popcorn <command> --help` or `popcorn commands` for discovery. Do not guess at a slash command.

## Setup

**When the user asks you to do something with Popcorn** (send a message, read a channel, manage channels, etc.), run this command first — before any other Popcorn CLI call:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli/setup.sh"
```

The script checks CLI, auth, and MCP — installing/configuring anything missing automatically. The last line of output is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.

If any component is still `false` after the script runs, tell the user what failed and how to fix it manually. If MCP was just added, tell the user to restart Claude Code.

**Skip this** if the user isn't doing a Popcorn action. The `/popcorn:pop` and `/popcorn:messages` skills run setup themselves — no need to run it twice.

Use **CLI mode** as the primary interface (cheaper, no context cost). Fall back to MCP tools when the CLI is unavailable.

---

## Discovery

Run `popcorn commands` to get the full CLI schema as structured JSON — all commands, arguments, types, choices, and defaults. Use this to discover commands and their usage rather than hardcoding recipes.

## Updates

The CLI auto-updates itself — it checks for new versions every 5 minutes and upgrades seamlessly. No manual intervention needed. To upgrade manually: `popcorn upgrade`. To disable auto-update (e.g. in CI): `export POPCORN_NO_UPDATE_CHECK=1`.

## Rules

1. **Always quote `'#channel-name'`** in bash — unquoted `#` triggers shell glob expansion. The CLI resolves names to UUIDs automatically. Never search for a channel UUID first.
2. **NEVER use `inbox` to find files or messages in a channel.** The inbox returns notifications from ALL channels and WILL give you the wrong result. Use `list-messages` instead.
3. **Confirm before sending.** Always show the user exactly what will be sent and get confirmation before calling `send-message`.
4. **Use `--json` for parsing** — all JSON output uses an envelope: `{"ok": true, "data": ...}` on success, `{"ok": false, "error": ...}` on stderr for errors. Parse `.data` from success responses.

## Message Structure

Messages have `content.parts[]`, each with a `type`:
- **`text`** → `part.text` (markdown string)
- **`media`** → `part.url` (file key for `download`), `part.filename`, `part.mime_type`, `part.size_bytes`
