---
name: messages
description: Pull recent channel conversation into context for iteration. USER-TRIGGERED ONLY — never invoke pre-emptively. For general message reading, use the CLI directly (popcorn list-messages).
allowed-tools: Bash
userTriggered: true
---

# /popcorn:messages — Pull Channel Context

Loads recent messages from the linked Popcorn app channel into the current session, so the developer can iterate based on team feedback and then `/popcorn:pop` again.

## Step 1: Read .popcorn.local.json

Look for `.popcorn.local.json` in the repo root.

- **Found** → read the `conversation_id` and `site_name`.
- **Not found** → tell the user: "No linked channel found. Provide a channel name (e.g. `#my-app`) to read messages from, or run `/popcorn:pop` first to publish this project."  Wait for the user to provide a channel before proceeding.

## Step 2: Fetch recent messages

```bash
popcorn --json list-messages '#<site_name>' --limit 20
```

Parse the response envelope — messages are in `.data.messages`. If the CLI is not installed or auth fails, run `bash "${CLAUDE_PLUGIN_ROOT}/skills/cli/setup.sh"` to fix it, then retry.

## Step 3: Present to the developer

Summarize the recent conversation concisely:
- What feedback/requests were made
- Any specific files or features mentioned
- Action items or change requests

The developer can now iterate on the code and run `/popcorn:pop` to publish the next version.
