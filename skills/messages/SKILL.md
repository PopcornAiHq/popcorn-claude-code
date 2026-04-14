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

### Check for existing deploy targets

```bash
POPCORN_AGENT=1 popcorn site targets
```

If there's a `default` target, use its `site_name`. Tell the user: "Reading messages from #`<site_name>`."

### No targets found

Tell the user: "No linked channel found. Provide a channel name (e.g. `#my-app`), or run `/popcorn:pop` first to publish this project."

## Step 2: Fetch messages

### CLI path (preferred)

**Recent messages:**

```bash
POPCORN_AGENT=1 popcorn message list '#<channel-name>' --limit 25
```

**Targeted search** (when looking for specific feedback):

```bash
POPCORN_AGENT=1 popcorn message search 'login button' --limit 10
```

Use search when the user asks about a specific topic — it's more useful than reading the last 25 messages.

**Pagination:** Check `.data.pagination.next` in the response. If non-null, it contains flags for the next page:

```bash
# First page:
POPCORN_AGENT=1 popcorn message list '#<channel-name>' --limit 25
# If .data.pagination.next is {"before": "msg-abc-123"}:
POPCORN_AGENT=1 popcorn message list '#<channel-name>' --limit 25 --before msg-abc-123
```

Offer to load more when pagination indicates additional messages.

Parse the response envelope — messages are in `.data.messages`. If the CLI is not installed or auth fails, run setup first:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

Then retry.

### MCP path (fallback)

If the CLI is unavailable, use the MCP tool:

```
read_messages(conversation_id="<conversation_id>", limit=25)
```

The `conversation_id` comes from `site targets` output or from resolving the channel name via `get_channel`.

## Step 3: Present to the developer

Summarize the recent conversation concisely:
- What feedback or requests were made
- Any specific files or features mentioned
- Action items or change requests

Format as a scannable list, not a wall of text. The developer can now iterate on the code and `/popcorn:pop` to publish the next version.
