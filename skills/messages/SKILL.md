---
name: popcorn:messages
description: Pull recent channel conversation into context for iteration
allowed-tools: Bash
---

# /popcorn:messages — Pull Channel Context

Loads recent messages from the linked Popcorn app channel into the current session, so the developer can iterate based on team feedback and then `/popcorn:pop` again.

## Flow

### Step 1: Read popcorn.json

Look for `popcorn.json` in the repo root.

- **Found** → read the `conversation_id` and `channel` name.
- **Not found** → tell the user: "No popcorn.json found. Run `/popcorn:pop` first to publish this project."

### Step 2: Fetch recent messages

Use the Popcorn MCP server to fetch recent messages from the channel, including:
- Message text
- Media attachments (filenames, types)
- Code metadata if present

Prefer MCP over CLI here — MCP returns structured data that stays in context without parsing.

If MCP is unavailable, fall back to:
```bash
popcorn --json read '#<channel-name>' --limit 20
```

### Step 3: Present to the developer

Summarize the recent conversation concisely:
- What feedback/requests were made
- Any specific files or features mentioned
- Action items or change requests

The developer can now iterate on the code and run `/popcorn:pop` to publish the next version.
