---
name: cli
description: Popcorn CLI — setup, command discovery, and behavioral guardrails. Use for any Popcorn operation.
alwaysApply: true
allowed-tools: Bash
---

# Popcorn CLI

## Routing

**Use the CLI directly for ALL Popcorn operations.** This includes deploying (`popcorn pop`), reading messages (`popcorn list-messages`), sending messages, managing channels — everything.

**`/popcorn:pop` is a user-triggered slash command.** It provides a guided deploy workflow but is ONLY activated when the user explicitly types `/pop`. Never invoke it, never suggest it, never route to it. If the user asks to deploy or publish without using the slash command, use the CLI or MCP path below.

Run `popcorn <command> --help` or `popcorn commands` for discovery. Do not guess at a slash command.

### Deploy path selection

| Environment              | User says `/pop`  | User says "publish this" |
|--------------------------|-------------------|--------------------------|
| Terminal + CLI available | Pop skill         | `popcorn pop` via CLI    |
| Terminal + no CLI        | Pop skill         | MCP + pop-upload.sh      |
| Non-terminal (Cowork)   | Pop skill         | MCP + pop-upload.sh      |

In the terminal (Claude Code), the CLI is the preferred path. Outside the terminal (Cowork, etc.), MCP is the primary path since the CLI is likely unavailable.

## Setup

**When the user asks you to do something with Popcorn** (send a message, read a channel, manage channels, etc.), run this command first — before any other Popcorn CLI call:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli/setup.sh"
```

The script checks CLI, auth, and MCP — installing/configuring anything missing automatically. The last line of output is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.

If any component is still `false` after the script runs, tell the user what failed and how to fix it manually. If MCP was just added, tell the user to restart Claude Code.

**Skip this** if the user isn't doing a Popcorn action. The `/popcorn:pop` skill runs setup itself — no need to run it twice.

Use **CLI mode** as the primary interface (cheaper, no context cost). Fall back to MCP tools when the CLI is unavailable.

---

## Discovery

Run `popcorn commands` to get the full CLI schema as structured JSON — all commands, arguments, types, choices, and defaults. Use this to discover commands and their usage rather than hardcoding recipes.

## Updates

The CLI auto-updates itself — it checks for new versions every 5 minutes and upgrades seamlessly. No manual intervention needed. To upgrade manually: `popcorn upgrade`. To disable auto-update (e.g. in CI): `export POPCORN_NO_UPDATE_CHECK=1`.

## Rules

1. **Always quote `'#channel-name'`** in bash — unquoted `#` triggers shell glob expansion. The CLI resolves names to UUIDs automatically. Never search for a channel UUID first.
2. **NEVER use `inbox` to find files or messages in a channel.** The inbox returns notifications from ALL channels and WILL give you the wrong result. Use `list-messages` or MCP `read_messages` instead.
3. **Confirm before sending.** Always show the user exactly what will be sent and get confirmation before calling `send-message` or MCP `post_message`.
4. **Use `--json` for parsing** — all CLI JSON output uses an envelope: `{"ok": true, "data": ...}` on success, `{"ok": false, "error": ...}` on stderr for errors. Parse `.data` from success responses.

## Message Structure

Messages have `content.parts[]`, each with a `type`:
- **`text`** → `part.text` (markdown string)
- **`media`** → `part.url` (file key for `download`), `part.filename`, `part.mime_type`, `part.size_bytes`

---

## MCP deploy flow

When the CLI is unavailable but MCP tools are connected, use this flow to deploy:

### 1. Verify auth
```
mcp: whoami → confirm user + workspace
```

### 2. Check for existing channel
Read `.popcorn.local.json` in the project root. If it exists, use the `conversation_id` from it. If not, ask the user for a channel name or offer to create a new one.

### 3. Get channel + upload URL
```
mcp: get_channel(channel) → returns details, site status, presigned upload URL
```

If creating a new channel, `update_channel(name="my-app")` first.

### 4. Upload project files

Write a config file with the upload parameters from `get_channel`, then run the upload script:

```bash
# Write config (agent generates this from get_channel response)
cat > /tmp/popcorn-upload-config.json << 'EOF'
{
  "upload_url": "<from get_channel response: upload.url>",
  "upload_fields": { <from get_channel response: upload.fields> },
  "project_dir": "/path/to/project"
}
EOF

# Upload
bash "${CLAUDE_PLUGIN_ROOT}/scripts/pop-upload.sh" /tmp/popcorn-upload-config.json
```

The script outputs `{"ok": true, "size_bytes": ...}` on success or `{"ok": false, "error": "..."}` on stderr on failure.

### 5. Trigger deploy
```
mcp: update_channel(channel, s3_key="<from get_channel: upload.s3_key>", context="description of changes")
```

### 6. Persist + report

Write the `local_json` from the response to `.popcorn.local.json`. Report the channel name, version, and site URL to the user.
