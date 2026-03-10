---
name: pop
description: Publish your project to a Popcorn channel
allowed-tools: Bash, Agent
---

# /popcorn:pop — Publish to Popcorn

When the user runs `/pop`, dispatch the entire flow to a subagent using the Agent tool with `subagent_type: "general-purpose"`. Pass the full prompt below as the agent's task.

Do NOT run the steps yourself — the subagent handles everything autonomously.

## Agent Prompt

You are publishing this project to a Popcorn app channel. Follow these steps in order. Stop and report back if any step fails.

### Principles

- `/pop` should feel like one action. Handle setup invisibly on first run.
- Infer, don't interrupt. Minimize prompts.
- GitHub is never involved. Files go to Popcorn's VM. No branches, no pushes.

### popcorn.json Schema

Stored in the repo root. Tracks the link between local project and Popcorn channel.

```json
{
  "conversation_id": "<channel UUID>",
  "channel": "pop-<project-name>",
  "workspace_id": "<workspace-id>",
  "workspace_name": "<workspace-name>",
  "created_at": "<ISO 8601 timestamp>",
  "updated_at": "<ISO 8601 timestamp>"
}
```

### Step 1: Verify setup

Run these checks silently. Only prompt if something needs user action.

1. `which popcorn` — if missing, install: `uv tool install git+https://github.com/PopcornAiHq/popcorn-cli.git`
2. `popcorn whoami` — if not authenticated, run `popcorn auth login`
3. `claude mcp list` — if "popcorn" not found, run `claude mcp add popcorn --transport http https://mcp.popcorn.ai/mcp` and tell the user to restart Claude Code.

After first run, this step is instant.

### Step 2: Check for popcorn.json

Look for `popcorn.json` in the repo root.

- **Found** → returning publish. Read the conversation_id and channel name.
- **Not found** → first-time publish. Infer a channel name: `pop-<directory-name>` (e.g., project in `my-app/` → `#pop-my-app`).

### Step 3: Send files to Popcorn's VM

> **TBD:** The CLI command or MCP tool to upload files to Popcorn's VM does not exist yet. When available, the flow is:

Zip all project files (respecting .gitignore if present) and send to Popcorn via CLI or MCP.

**First time (new):**
- Create a repo on Popcorn's VM, commit as v0.
- Create the app channel (`#pop-<name>`).
- Notify the workspace that a new app channel was created.

**Returning:**
- Send files to the existing repo on Popcorn's VM, committed as the next version.
- Notify the channel with a summary of what changed.

### Step 4: Write popcorn.json

**First time:** Create `popcorn.json` with the schema above. Get `workspace_id` and `workspace_name` from `popcorn --json whoami`. Set `conversation_id` from the channel created in Step 3. Set `created_at` and `updated_at` to now.

**Returning:** Update `updated_at` only.

### Step 5: Confirm

Report to the developer: "Published to #pop-<name>."

If first time, mention the new channel was created. If returning, include a brief summary of changes.
