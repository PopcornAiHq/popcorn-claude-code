---
name: pop
description: Publish your project to a Popcorn channel
allowed-tools: Bash
---

# /popcorn:pop — Publish to Popcorn

Publish local project files to a Popcorn app channel. The workspace VM pulls the tarball, unpacks, commits, and serves the site.

## Step 1: Verify setup

Run the setup check from the **popcorn** skill:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

The last line is JSON: `{"cli":true,"auth":true,"mcp":true}`. If `cli` or `auth` is `false`, the setup script auto-installs missing components. If it still reports `false`, tell the user what failed (the script prints instructions).

## Step 2: Extract parameters

From the user's message, extract:

- **name** — explicit site name (optional). If not provided, the CLI defaults to `pop-<directory-name>`.
- **context** — description of what changed (optional). Examples: "Added dark mode", "Fixed mobile layout".

**Parsing rules:**
- Single token that looks like a slug (lowercase, hyphens, no spaces) → site name
- Multiple words that read as natural language → context
- Use `-` separator to provide both: text before is name, after is context

```
/popcorn:pop                                     → defaults
/popcorn:pop my-app                              → --name my-app
/popcorn:pop added dark mode                     → --context "Added dark mode"
/popcorn:pop my-app - redesigned landing page    → --name my-app --context "Redesigned landing page"
```

## Step 3: Deploy via CLI

```bash
popcorn --json pop [--name NAME] [--context "description"]
```

The CLI handles everything: tarball creation, S3 upload, VM deploy, `.popcorn.local.json` management, and `.gitignore` updates.

Output is JSON:
- Success: `{"conversation_id":"...","site_name":"...","version":3,"commit_hash":"..."}`
- Error: CLI exits non-zero with error message

## Step 4: Report result

- **Success:** "Published to #`<site_name>` (v`<version>`)"
- **First deploy:** mention the new site was created
- **Failure:** report the error from the JSON output
