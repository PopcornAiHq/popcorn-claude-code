# `/popcorn:pop` Deploy Flow — Design Spec

## Overview

A deterministic deploy flow that packages local project files and publishes them to a Popcorn app channel via the backend API + S3. The workspace VM pulls the tarball, unpacks, commits, and serves the site.

Three projects involved:

```
popcorn-claude-code          popcorn-cli / MCP           popcorn-backend              workspace VM
┌──────────────────┐    ┌──────────────────────┐    ┌──────────────────────┐    ┌──────────────────┐
│ skills/pop/      │    │ popcorn deploy       │    │ /api/app-channels/   │    │ /deploy          │
│   pop.sh         │───→│   (CLI command)      │───→│   deploy/init        │───→│ pull, unpack,    │
│   SKILL.md       │    │   OR MCP tool        │    │   deploy/confirm     │    │ commit, serve    │
└──────────────────┘    └──────────────────────┘    └──────────────────────┘    └──────────────────┘
```

## Flow

```
pop.sh
  │
  ├─ 1. Setup check (reuse setup.sh)
  │
  ├─ 2. Read .popcorn.local.json
  │     → conversation_id + channel (or null if first deploy)
  │
  ├─ 3. Infer channel name if first deploy
  │     → "pop-<directory-name>" unless --channel provided
  │
  ├─ 4. Create tarball
  │     → git ls-files (if git repo) or tar with exclusions
  │     → exclude: .git/, node_modules/, .popcorn.local.json
  │
  ├─ 5. CLI: popcorn deploy init
  │     → POST /api/app-channels/deploy/init
  │     → receive: deploy_id, upload_url, upload_fields, conversation_id
  │
  ├─ 6. Upload tarball to S3 presigned URL
  │
  ├─ 7. CLI: popcorn deploy confirm
  │     → POST /api/app-channels/deploy/confirm
  │     → receive: conversation_id, channel, version, commit_hash
  │
  ├─ 8. Write/update .popcorn.local.json
  │
  └─ 9. Print result JSON on last line
```

## API Contract

### `POST /api/app-channels/deploy/init`

```json
// Request
{
  "conversation_id": "469755aa-..." | null,
  "channel_name": "pop-my-app"
}

// Response
{
  "deploy_id": "dep_abc123",
  "upload_url": "https://s3.amazonaws.com/...",
  "upload_fields": { "key": "...", "policy": "...", ... },
  "conversation_id": "469755aa-...",
  "s3_key": "deploys/dep_abc123.tar.gz"
}
```

- First deploy (`conversation_id` is null): backend creates the channel, returns new `conversation_id`.
- Returning deploy: backend validates the `conversation_id` exists.

### `POST /api/app-channels/deploy/confirm`

```json
// Request
{
  "deploy_id": "dep_abc123"
}

// Response
{
  "conversation_id": "469755aa-...",
  "channel": "pop-my-app",
  "version": 3,
  "commit_hash": "a1b2c3d...",
  "first_deploy": true
}
```

Backend tells the VM to pull tarball from S3, unpack, commit. Returns version from VM's `popcorn.json`.

### VM endpoint: `POST /deploy`

```json
// Request (from backend)
{
  "site_name": "pop-my-app",
  "s3_key": "deploys/dep_abc123.tar.gz",
  "deploy_id": "dep_abc123"
}

// Response
{
  "version": 3,
  "commit_hash": "a1b2c3d..."
}
```

VM pulls tarball from S3, unpacks into site directory, runs `auto_commit_site()`.

## Local File: `.popcorn.local.json`

```json
{
  "conversation_id": "469755aa-...",
  "channel": "pop-my-app"
}
```

- Written by `pop.sh` after successful deploy
- Should be gitignored (script adds to `.gitignore` on first deploy)
- Minimal — just a pointer to the channel

## VM File: `popcorn.json`

Unchanged from Ben's spec. Managed entirely by the VM:

```json
{
  "name": "pop-my-app",
  "version": 3,
  "created_by": "user_abc123",
  "created_at": "2026-03-01T12:00:00Z",
  "last_modified": "2026-03-06T15:30:00Z"
}
```

## Tarball Creation

```bash
if git rev-parse --is-inside-work-tree &>/dev/null; then
  git ls-files -co --exclude-standard | tar czf "$TARBALL" -T -
else
  tar czf "$TARBALL" --exclude='.git' --exclude='node_modules' \
    --exclude='.popcorn.local.json' .
fi
```

## MCP Fallback

When the CLI is unavailable, the same flow should work via MCP tools:

- `popcorn_deploy_init` — equivalent to `popcorn deploy init`
- `popcorn_deploy_confirm` — equivalent to `popcorn deploy confirm`
- Tarball upload to S3 presigned URL via HTTP (MCP or curl)

The `pop.sh` script tries CLI first, falls back to MCP tools if CLI is missing. The MCP server needs two new tools matching the deploy endpoints.

## Error Handling

Each step checks the previous step's exit code. On failure:

```json
{"ok": false, "error": "Upload failed: 403 Forbidden", "step": "upload"}
```

The LLM reads the last line and reports to the user.

## Scope

### In scope
- `pop.sh` deterministic script
- `SKILL.md` update (just invokes pop.sh)
- CLI `popcorn deploy init` and `popcorn deploy confirm` commands
- MCP `popcorn_deploy_init` and `popcorn_deploy_confirm` tools
- Backend `POST /api/app-channels/deploy/init` and `deploy/confirm`
- VM `POST /deploy` endpoint
- `.popcorn.local.json` management

### Out of scope
- GitHub sync (separate feature, opt-in)
- In-channel editing (Path 2 — VM agent handles independently)
- Channel deletion / cleanup
