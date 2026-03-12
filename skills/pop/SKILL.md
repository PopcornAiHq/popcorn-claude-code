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

## Step 3: Auto-generate context

If the user **provided context** in their `/pop` invocation (natural language text), use it as-is for `--context`. Skip this step.

If no context was provided, **generate one automatically** from local changes:

**If this is a git repo:**

```bash
# Changes since last deploy (or all changes if first deploy)
git log --oneline <commit_hash>..HEAD 2>/dev/null
git diff --name-only <commit_hash> HEAD 2>/dev/null
git diff --name-only 2>/dev/null
```

If no `commit_hash` baseline exists (first deploy), use:
```bash
git log --oneline -5 2>/dev/null
```

**Summarize** the changes into a short one-liner (same quality bar as a good commit message):
- Describe the **intent**, not just "modified 3 files"
- Good: "Add dark mode toggle, update footer styling"
- Good: "Fix responsive layout on mobile, add loading spinner"
- Bad: "Updated index.html and styles.css"
- Bad: "Various changes"

Use this generated summary as the `--context` value.

## Step 4: Deploy via CLI

```bash
popcorn --json pop [--name NAME] --context "description"
```

The CLI handles everything: tarball creation, S3 upload, VM deploy, `.popcorn.local.json` management, and `.gitignore` updates.

Output is JSON:
- Success: `{"conversation_id":"...","site_name":"...","version":3,"commit_hash":"..."}`
- Error: CLI exits non-zero with error message

### Update local state after deploy

After a successful deploy, `.popcorn.local.json` is updated by the CLI with the new `commit_hash`. This becomes the baseline for the next deploy's change detection.

## Step 5: Fetch site URL

After a successful deploy, fetch the channel info to get the site URL:

```bash
popcorn --json info '#<site_name>'
```

The response includes channel metadata. Look for a `site_url`, `url`, or `website` field. If the info response contains a URL, use it. If not available, omit the URL from the output (don't guess or construct one).

## Step 6: Report result

- **Success:** "Published to #`<site_name>` (v`<version>`)" followed by the site URL if available
- **First deploy:** mention the new site was created
- **Failure:** report the error from the JSON output
