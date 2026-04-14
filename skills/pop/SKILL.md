---
name: pop
description: Deploy/publish local project files to a Popcorn channel. USER-TRIGGERED ONLY — never invoke pre-emptively. For general deploy requests, use the CLI directly (popcorn site deploy).
allowed-tools: Bash
userTriggered: true
---

# /popcorn:pop — Publish to Popcorn

Publish local project files to a Popcorn app channel. The workspace VM pulls the tarball, unpacks, commits, and serves the site. Popcorn supports **all project types**: static sites, build-step sites (React, Vite, Next.js), and full-stack server apps (Node.js/Express, Python/Flask).

This command should "just work" — handle setup, context generation, and error recovery automatically. The user should go from zero to a live site in one invocation.

## Step 1: Ensure CLI is ready

Run setup from the **plugin root** (not this skill's directory):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

The last line is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.

- If `cli` and `auth` are both `true` → proceed with the CLI deploy flow below.
- If `cli` is `false` but `mcp` is `true` → use the MCP path in Step 6 below. Target resolution (Step 2), parameter extraction (Step 3), and context generation (Step 5) are the same for both paths.
- If both `cli` and `mcp` are `false` → stop and tell the user what failed.

## Step 2: Resolve target channel

Determine where to deploy using these sources, in priority order:

### 1. User specified a target channel (see Step 3)

A `#channel-name` or bare name with clear intent → look it up:

```bash
POPCORN_AGENT=1 popcorn channel info '#<channel-name>'
```

- **Found** → use it, no confirmation needed.
- **Not found** → proceed as a new deploy using the channel name as the positional `name` argument.

### 2. Check for existing deploy targets

```bash
POPCORN_AGENT=1 popcorn site targets
```

Response: `{"ok": true, "data": {"targets": [...], "default": "target-name"}}`.

Each target has: `name` (the `--target` flag value), `site_name`, `workspace_id`, `workspace_name`.

- **Single target** → tell the user: "Last deploy went to #`<site_name>`. Deploy there again?" If they confirm, use `--target <name>`. If they decline, proceed as a fresh deploy.
- **Multiple targets** → list them and ask: "You have deploy targets: `<a>` (workspace X), `<b>` (workspace Y). Which one, or create a new one?"
- **No targets** → first deploy. Proceed normally.

### 3. No targets, no user input

Try the default channel name:

```bash
POPCORN_AGENT=1 popcorn channel info '#pop-<directory-name>'
```

If found → ask: "Found existing channel #`<name>`. Deploy to this channel?"
If not found → first deploy. Proceed normally.

## Step 3: Extract parameters

From the user's free-form text (everything after `/pop`), infer:

- **target channel** — an existing channel to deploy to. Identified by a `#` prefix (e.g., `#my-channel`). A bare name also works when the user's intent is clearly to target an existing channel (e.g., "deploy to my-channel"). Strip the `#` prefix before lookup.
- **name** — a site name for a new deploy, if the user mentioned one (optional). If not provided, the CLI defaults to `pop-<directory-name>`. **Ignored when a target channel is specified** — the existing channel's name is used instead.
- **context** — a description of what changed, if the user described it (optional). Will be auto-generated in Step 4 if not provided.

The user may provide any combination in natural phrasing. Examples:

```
/popcorn:pop                                     → defaults for everything
/popcorn:pop my-app                              → site name "my-app" (new deploy)
/popcorn:pop added dark mode                     → context "Added dark mode"
/popcorn:pop deploy my-app with the new sidebar  → site name "my-app", context "New sidebar"
/popcorn:pop #my-channel                         → target existing #my-channel
/popcorn:pop #my-channel added dark mode         → target #my-channel, context "Added dark mode"
```

Don't be rigid — interpret intent. When ambiguous between name and context, prefer context (more useful). When ambiguous between name and target channel, prefer target channel if the token has a `#` prefix.

## Step 4: Ensure clean git state (git repos only)

Check if this is a git repo (`git rev-parse --git-dir 2>/dev/null`). If it's **not a git repo**, skip this step entirely.

If it is a git repo, ensure all work is committed and up to date before deploying:

1. **Uncommitted changes?** Check `git status --porcelain`. If there are staged or unstaged changes, commit them. Use the conversation context to write a meaningful commit message.
2. **Behind remote?** If the branch has an upstream (`git rev-parse --abbrev-ref @{upstream} 2>/dev/null`), pull to ensure local is up to date (`git pull`).
3. **Note unpushed commits** — check `git log @{upstream}..HEAD --oneline 2>/dev/null`. If there are unpushed commits, remember this for Step 7 (don't block the deploy).

This ensures the deployed version includes the latest work.

## Step 5: Resolve context

- **User provided context** → use `--context "their text"`
- **No context provided** → use `--context-from-git` (the CLI auto-generates context from git commits since last deploy, or falls back to "Initial deploy" for non-git/first deploys)

## Step 6: Deploy

### CLI path (preferred)

All commands use agent mode (`POPCORN_AGENT=1`) which auto-injects `--json`, `--quiet`, `--no-color`. Never pass `--json` manually.

**New deploy** (first time, no existing target):

```bash
POPCORN_AGENT=1 popcorn site deploy --context-from-git
# With a custom channel name:
POPCORN_AGENT=1 popcorn site deploy my-app --context-from-git
```

**Existing deploy** (target from `site targets`):

```bash
# --target value = the "name" field from site targets output
POPCORN_AGENT=1 popcorn site deploy --target <name> --context-from-git
```

**With explicit context** (user described what changed):

```bash
POPCORN_AGENT=1 popcorn site deploy --target <name> --context "Add dark mode toggle"
```

**With workspace override** (target's workspace differs from current):

```bash
# --workspace accepts name or UUID
POPCORN_AGENT=1 popcorn --workspace Camino site deploy --target <name> --context-from-git
```

The CLI handles: tarball creation, S3 upload, and VM deploy. It writes `.popcorn.local.json` automatically after deploy.

**Parse the response envelope:**
- Success: `{"ok": true, "data": {"conversation_id":"...","site_name":"...","version":3,"commit_hash":"...","subdomain":"...","site_url":"..."}}`
- Error: exit code non-zero, `{"ok": false, "error": "...", ...}` on stderr

Read `site_name` and `version` from `.data` on success.

**Save to memory:** After a successful deploy, save or update a memory recording the deploy context — version, commit hash, and what changed. The file (`.popcorn.local.json`) handles target resolution; memory handles change context for future diff generation.

### MCP path (fallback — when CLI is unavailable)

Fetch the `pop` prompt from the Popcorn MCP server and follow its
instructions entirely. The prompt contains the complete MCP deploy
workflow including GitHub-based and S3-based deploy paths.

After a successful deploy, persist state to `.popcorn.local.json` so subsequent deploys resolve the target automatically. Read the existing file first (if any), then upsert:

```json
{
  "version": 2,
  "default_target": "<site_name>",
  "targets": {
    "<site_name>": {
      "workspace_id": "<from whoami>",
      "workspace_name": "<from whoami>",
      "conversation_id": "<channel ID from deploy response>",
      "site_name": "<from deploy response>",
      "deployed_at": "<ISO timestamp>"
    }
  }
}
```

**Upsert rule:** Match existing targets by `(workspace_id, site_name)`. If found, update in place. If new, add with `site_name` as key. Always set `default_target` to the deployed target.

## Step 7: Report result

- **Success:** "Published to #`<site_name>` (v`<version>`) — `<site_url>`" where `site_url` is from the deploy response `.data.site_url` (e.g. `https://pop-test--my-ws.popcorn.ing`)
- **First deploy:** mention the new site was created
- **Build in progress?** If the deploy response includes a `verify_task_id` or the site isn't ready yet, you can stream build progress:
  ```bash
  POPCORN_AGENT=1 popcorn site trace '#<site_name>' --watch
  ```
  Each NDJSON line is a build/deploy step. Report progress: "Building..." → "Installing deps..." → "Live."
- **Unpushed commits?** If Step 4 noted unpushed commits, remind the user and offer to push: "You have unpushed commits on `<branch>`. Want me to push?"
- **Failure:** see error recovery below

## Error Recovery

If the deploy fails, don't just report the error — try to recover:

| Error | Recovery |
|-------|----------|
| Workspace mismatch ("belongs to workspace X") | The error message includes a `--workspace` suggestion. Re-run with `--workspace <name-or-id>` before `site deploy` |
| Stale channel config | The CLI auto-recreates the channel. If it still fails, retry with a fresh name |
| VM error (build/deploy failure) | Report the `vm_error` details from the response. These are usually code issues (missing dependencies, build errors) — show the user the error so they can fix their code |
| Network timeout | Retry once with `--timeout 120`. If it fails again, report the timeout |
| 409 conflict (name taken) | The CLI auto-retries with a suffix. If it still fails, suggest the user provide a different name |
| Unknown error | Report the full error JSON so the user can debug |
