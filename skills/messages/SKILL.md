---
name: messages
description: Pull recent channel conversation into context for iteration
allowed-tools: Bash
---

# /popcorn:messages — Pull Channel Context

Loads recent messages from the linked Popcorn app channel into the current session, so the developer can iterate based on team feedback and then `/popcorn:pop` again.

## Flow

### Step 0: Verify setup

Run the setup check from the **popcorn** skill (the always-on skill has the bash snippet and fix instructions). Fix anything that returns `false` before continuing.

### Step 1: Read .popcorn.local.json

Look for `.popcorn.local.json` in the repo root.

- **Found** → read the `conversation_id` and `site_name`.
- **Not found** → tell the user: "No `.popcorn.local.json` found. Run `/popcorn:pop` first to publish this project."

### Step 2: Fetch recent messages

Use the Popcorn MCP server to fetch recent messages from the channel, including:
- Message text
- Media attachments (filenames, types)
- Code metadata if present

Prefer MCP over CLI here (exception to the general "CLI first" rule) — MCP returns structured data that stays in context without parsing.

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
