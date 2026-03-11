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

## Step 4: MCP fallback

If the CLI is not available (`setup.sh` reports `cli: false`), fall back to MCP tools. Run these steps in order. **Stop and report the error to the user if any step fails.**

### 4a. Read `.popcorn.local.json`

```bash
if [ -f .popcorn.local.json ]; then
  cat .popcorn.local.json
else
  echo "{}"
fi
```

If it exists, extract `conversation_id` and `site_name`. Otherwise this is a first deploy.

### 4b. Create site (first deploy only)

Use the MCP tool `popcorn_site_create`:

```json
{ "site_name": "pop-<directory-name>" }
```

Returns `conversation_id`. Skip this step if `.popcorn.local.json` already has a `conversation_id`. If this fails (e.g. site name taken), stop and report the error.

### 4c. Get presigned upload URL

Use the MCP tool `popcorn_site_presign`:

```json
{ "site_name": "<site_name>" }
```

Returns `upload_url`, `upload_fields`, `s3_key`. If this fails, stop and report the error.

### 4d. Create and upload tarball

```bash
# Create tarball respecting .gitignore
TARBALL=$(mktemp /tmp/pop-push-XXXXXX)
mv "$TARBALL" "${TARBALL}.tar.gz"
TARBALL="${TARBALL}.tar.gz"

if git rev-parse --is-inside-work-tree &>/dev/null; then
  git ls-files -co --exclude-standard | grep -v '^\.popcorn\.local\.json$' | tar czf "$TARBALL" -T -
else
  tar czf "$TARBALL" --exclude='.git' --exclude='node_modules' --exclude='.popcorn.local.json' .
fi

# Upload to S3 (substitute upload_fields from 4c)
curl -f --show-error -X POST "<upload_url>" \
  -F "key=<s3_key>" \
  -F "Content-Type=application/gzip" \
  -F "policy=<policy>" \
  -F "x-amz-credential=<credential>" \
  -F "x-amz-algorithm=<algorithm>" \
  -F "x-amz-date=<date>" \
  -F "x-amz-signature=<signature>" \
  -F "file=@${TARBALL};type=application/gzip"

rm -f "$TARBALL"
```

If the curl upload fails (non-2xx response), stop and report the S3 error. Do not proceed to step 4e.

### 4e. Trigger deploy

Use the MCP tool `popcorn_site_pull`:

```json
{
  "site_name": "<site_name>",
  "s3_key": "<s3_key from 4c>",
  "conversation_id": "<conversation_id>",
  "context": "<context message if provided>"
}
```

Returns `version` and `commit_hash`. If this fails, report the error but note that files were uploaded — retrying just this step may work.

### 4f. Write `.popcorn.local.json`

```bash
cat > .popcorn.local.json << JSONEOF
{
  "conversation_id": "<conversation_id>",
  "site_name": "<site_name>"
}
JSONEOF
```

Add to `.gitignore` if not already there:

```bash
grep -q '\.popcorn\.local\.json' .gitignore 2>/dev/null || echo '.popcorn.local.json' >> .gitignore
```

## Step 5: Report result

- **Success:** "Published to #`<site_name>` (v`<version>`)"
- **First deploy:** mention the new site was created
- **Failure:** report the error from the JSON output
