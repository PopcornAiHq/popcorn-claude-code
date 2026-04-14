---
name: export
description: Export site files from a Popcorn channel into the local project. USER-TRIGGERED ONLY — never invoke pre-emptively. For general export, use the CLI directly (popcorn site export).
allowed-tools: Bash
userTriggered: true
---

# /popcorn:export — Export from Popcorn

Downloads the latest (or a specific version of) site files from a Popcorn channel into the local project. The inverse of `/popcorn:pop`.

This command should "just work" — resolve the channel, handle safety checks, and extract files automatically.

## Step 1: Ensure CLI is ready

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

The last line is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.

- If `cli` and `auth` are both `true` → proceed.
- Otherwise → stop and tell the user what failed. There is no MCP fallback for export.

## Step 2: Resolve target channel

Same resolution logic as `/popcorn:pop`:

### 1. User specified a target

A `#channel-name` or bare name after `/export` → use it directly.

### 2. Check `.popcorn.local.json`

```bash
cat .popcorn.local.json 2>/dev/null
```

If the file exists and has a `default_target`, use it. Tell the user: "Exporting from #`<site_name>`."

If multiple targets exist, list them and ask which one.

### 3. No file, no target

Tell the user: "No linked channel found. Provide a channel name (e.g. `#my-app`), or run `/popcorn:pop` first to link a channel."

## Step 3: Extract parameters

From the user's free-form text (everything after `/export`), infer:

- **target channel** — a `#channel-name` or bare name
- **version** — a specific version number or commit hash, if the user mentioned one (optional)

Examples:

```
/popcorn:export                              → default target, latest version
/popcorn:export #my-app                      → pull from #my-app
/popcorn:export v3                           → default target, version 3
/popcorn:export #my-app v3                   → pull from #my-app, version 3
/popcorn:export the version before dark mode → ask user to clarify version
```

## Step 4: Safety check

Check for uncommitted changes:

```bash
git status --porcelain 2>/dev/null
```

If there are uncommitted changes, warn the user: "You have uncommitted changes. The export will back up current files to `.popcorn-backup/`. Continue?" If they decline, stop. If they confirm, proceed with `--force`.

If no uncommitted changes or not a git repo, proceed normally.

## Step 5: Export

```bash
POPCORN_AGENT=1 popcorn site export '#<channel-name>' [--version VERSION] --force
```

**Parse the response envelope:**
- Success: `{"ok": true, "data": {"version": 5, "commit_hash": "abc123", "backup": ".popcorn-backup"}}`
- Error: exit code non-zero, `{"ok": false, "error": "..."}` on stderr

## Step 6: Report result

- **Success:** "Exported #`<site_name>` v`<version>` into the project. Backup at `.popcorn-backup/`."
- **Show what changed:** Run `git status --short` or `git diff --stat` to show the user what files were added/modified.
- **Revert option:** "To undo, run `popcorn site export --revert`."
- **Failure:** Report the error and suggest fixes.
