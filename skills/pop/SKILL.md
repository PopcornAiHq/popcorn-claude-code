---
name: pop
description: Publish your project to a Popcorn channel
allowed-tools: Bash
userTriggered: true
---

# /popcorn:pop — Publish to Popcorn

Publish local project files to a Popcorn app channel. The workspace VM pulls the tarball, unpacks, commits, and serves the site.

This command should "just work" — handle setup, context generation, and error recovery automatically. The user should go from zero to a live site in one invocation.

## Step 1: Ensure CLI is ready

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

The last line is JSON. If `cli` or `auth` is `false` after the script runs, stop and tell the user what failed — don't proceed to deploy.

## Step 2: Check channel link

Check if `.popcorn.local.json` exists in the repo root.

- **Exists** → read `conversation_id` and `site_name`. Proceed to Step 3.
- **Missing, but this isn't the first deploy** → the file may have been deleted or the user switched branches. Try to find the existing channel:

```bash
# Default channel name is pop-<directory-name>, or the user may have specified --name
popcorn --json info '#pop-<directory-name>'
```

If the channel exists, tell the user: "Found existing channel #`<name>`. Deploy to this channel?" If they confirm, proceed — the CLI will recreate `.popcorn.local.json` on deploy. If they decline, proceed as a fresh deploy (new channel).

If no existing channel is found, this is a first deploy. Proceed normally.

## Step 3: Extract parameters

From the user's free-form text (everything after `/pop`), infer:

- **name** — a site name, if the user mentioned one (optional). If not provided, the CLI defaults to `pop-<directory-name>`.
- **context** — a description of what changed, if the user described it (optional). Will be auto-generated in Step 4 if not provided.

The user may provide both, one, or neither in any natural phrasing. Examples:

```
/popcorn:pop                                     → defaults for both
/popcorn:pop my-app                              → --name my-app
/popcorn:pop added dark mode                     → --context "Added dark mode"
/popcorn:pop deploy my-app with the new sidebar  → --name my-app --context "New sidebar"
```

Don't be rigid — interpret intent. When ambiguous, prefer treating text as context over name (context is more useful).

## Step 4: Ensure clean git state (git repos only)

Check if this is a git repo (`git rev-parse --git-dir 2>/dev/null`). If it's **not a git repo**, skip this step entirely.

If it is a git repo, ensure all work is committed and up to date before deploying:

1. **Uncommitted changes?** Check `git status --porcelain`. If there are staged or unstaged changes, commit them. Use the conversation context to write a meaningful commit message.
2. **Behind remote?** If the branch has an upstream (`git rev-parse --abbrev-ref @{upstream} 2>/dev/null`), pull to ensure local is up to date (`git pull`).
3. **Note unpushed commits** — check `git log @{upstream}..HEAD --oneline 2>/dev/null`. If there are unpushed commits, remember this for Step 7 (don't block the deploy).

This ensures the deployed version includes the latest work.

## Step 5: Auto-generate context

If the user already provided context text, use it as-is for `--context`. Skip this step.

If no context was provided, generate one automatically.

### Git repos

**Read the deploy baseline:** If `.popcorn.local.json` exists (meaning a previous deploy happened), fetch the last deployed commit hash from the server:

```bash
popcorn --json status
```

Parse `.data.commit_hash` from the response — this is the baseline for diffing.

**Gather changes:**

```bash
# If commit_hash baseline exists (subsequent deploy):
git log --oneline <commit_hash>..HEAD
git diff --name-only <commit_hash> HEAD

# If no baseline (first deploy) or status failed:
git log --oneline -5
```

**No changes detected?** If git log and diff return empty since the last deploy's `commit_hash`, tell the user: "No local changes detected since the last deploy. Do you still want to redeploy?" If they decline, stop. If they confirm, proceed with a context like "Redeploy without local changes".

**Summarize** into a short one-liner (same quality bar as a good commit message):
- Describe the **intent**, not just file names
- Good: "Add dark mode toggle, update footer styling"
- Bad: "Updated index.html and styles.css"
- Bad: "Various changes"

### Non-git projects

No change detection is available. Use a generic context:
- First deploy: "Initial deploy"
- Subsequent deploys: "Update deploy" (or ask the user what changed)

## Step 6: Deploy

```bash
popcorn --json pop [--name NAME] --context "description"
```

The CLI handles: tarball creation, S3 upload, VM deploy, `.popcorn.local.json` management, `.gitignore` updates.

**Do not create or modify `.popcorn.local.json` yourself.** The CLI owns this file — it writes `conversation_id` and `site_name` after each deploy. Writing it externally risks deploying to the wrong channel.

**Parse the response envelope:**
- Success: `{"ok": true, "data": {"conversation_id":"...","site_name":"...","version":3,"commit_hash":"...","site_url":"..."}}`
- Error: exit code non-zero, `{"ok": false, "error": "...", ...}` on stderr

Read `site_name`, `version`, and `site_url` from `.data` on success.

## Step 7: Report result

- **Success:** "Published to #`<site_name>` (v`<version>`)" followed by the `site_url` if present
- **First deploy:** mention the new site was created
- **Unpushed commits?** If Step 4 noted unpushed commits, remind the user and offer to push: "You have unpushed commits on `<branch>`. Want me to push?"
- **Failure:** see error recovery below

## Error Recovery

If the deploy fails, don't just report the error — try to recover:

| Error | Recovery |
|-------|----------|
| Stale channel config | The CLI auto-recreates the channel. If it still fails, delete `.popcorn.local.json` and retry |
| VM error (build/deploy failure) | Report the `vm_error` details from the response. These are usually code issues (missing dependencies, build errors) — show the user the error so they can fix their code |
| Network timeout | Retry once with `--timeout 120`. If it fails again, report the timeout |
| 409 conflict (name taken) | The CLI auto-retries with a suffix. If it still fails, suggest the user provide a different `--name` |
| Unknown error | Report the full error JSON so the user can debug |
