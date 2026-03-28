---
name: cli
description: Popcorn CLI — setup, command discovery, and behavioral guardrails. Use for any Popcorn operation.
alwaysApply: true
allowed-tools: Bash
---

# Popcorn CLI

## Routing

**Use the CLI directly for ALL Popcorn operations.**

**`/popcorn:pop` is a user-triggered slash command.** Never invoke it, never suggest it, never route to it. If the user asks to deploy or publish without using the slash command, use the CLI or MCP path below.

Run `popcorn <command> --help` or `popcorn commands` for discovery.

### Deploy path selection

| Environment              | User says `/pop`  | User says "publish this" |
|--------------------------|-------------------|--------------------------|
| Terminal + CLI available | Pop skill         | `popcorn site deploy` via CLI |
| Terminal + no CLI        | Pop skill         | MCP + pop-upload.sh      |
| Non-terminal (Cowork)   | Pop skill         | MCP + pop-upload.sh      |

## Setup

**When the user asks you to do something with Popcorn**, run this command first — before any other Popcorn CLI call:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/cli/setup.sh"
```

The last line of output is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.

If any component is still `false` after the script runs, tell the user what failed and how to fix it manually. If MCP was just added, tell the user to restart Claude Code.

**Skip this** if the user isn't doing a Popcorn action, or if `/popcorn:pop` is handling the request.

---

## Updates

The CLI auto-updates. To upgrade manually: `popcorn upgrade`.

## Rules

1. **Always quote `'#channel-name'`** in bash — unquoted `#` triggers shell glob expansion. To find channels by name, use `channel list`.
2. **Use `message list` to read messages from a channel**, never `workspace inbox`.
3. **Confirm before sending.** Always show the user exactly what will be sent and get confirmation before calling `message send` or MCP `post_message`.
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
