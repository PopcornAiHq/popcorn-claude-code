---
name: messages
description: Pull recent channel messages into context. USER-TRIGGERED ONLY — never invoke pre-emptively. For general message reading, use the CLI directly (popcorn message list).
allowed-tools: Bash
userTriggered: true
---

# /popcorn:messages — Pull Channel Context

Loads recent messages from a Popcorn channel into the current session so the developer can iterate based on team feedback.

## Step 1: Resolve channel

### User specified a channel

If the user provided a `#channel-name` or bare name after `/messages`, use it directly.

### Check `.popcorn.local.json`

```bash
cat .popcorn.local.json 2>/dev/null
```

If the file exists, use the `default_target` to find the channel's `site_name`. Tell the user: "Reading messages from #`<site_name>`."

### No file, no target

Tell the user: "No linked channel found. Provide a channel name (e.g. `#my-app`), or run `/popcorn:pop` first to publish this project."

## Step 2: Fetch messages

### CLI path (preferred)

```bash
POPCORN_AGENT=1 popcorn message list '#<channel-name>' --limit 25
```

Parse the response envelope — messages are in `.data`. If the CLI is not installed or auth fails, run setup first:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

Then retry.

### MCP path (fallback)

If the CLI is unavailable, use the MCP tool:

```
read_messages(conversation_id="<conversation_id>", limit=25)
```

The `conversation_id` comes from `.popcorn.local.json` or from resolving the channel name via `get_channel`.

## Step 3: Present to the developer

Summarize the recent conversation concisely:
- What feedback or requests were made
- Any specific files or features mentioned
- Action items or change requests

Format as a scannable list, not a wall of text. The developer can now iterate on the code and `/popcorn:pop` to publish the next version.
