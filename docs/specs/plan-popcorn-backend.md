# Implementation Plan: popcorn-backend

Reference: [2026-03-10-pop-deploy-design.md](./2026-03-10-pop-deploy-design.md)

## Summary

Add two new API endpoints for the deploy flow, plus a new endpoint on the workspace VM for pulling and committing tarballs.

## Steps

### 1. Create deploy model / table

**File:** `lib/app_channels/models/deploy.py` (new module, or add to existing)

```python
class DeployDB(Base):
    deploy_id: str  # PK, generated UUID
    conversation_id: str  # FK to conversation
    workspace_id: str  # FK to workspace
    s3_key: str  # tarball location in S3
    status: str  # "pending_upload" | "uploaded" | "deploying" | "complete" | "failed"
    channel_name: str
    version: int | None  # set after VM commits
    commit_hash: str | None  # set after VM commits
    created_at: datetime
    completed_at: datetime | None
```

### 2. `POST /api/app-channels/deploy/init`

**File:** `services/api/app_channels.py` (new router)

**Logic:**
1. Authenticate request (Bearer token)
2. If `conversation_id` is null → create a new channel via existing conversation service
   - Channel name: `channel_name` from request (e.g. `pop-my-app`)
   - Type: `public_channel`
   - Return new `conversation_id`
3. If `conversation_id` provided → validate it exists and user has access
4. Generate `deploy_id` (UUID)
5. Generate S3 presigned POST URL for `deploys/{deploy_id}.tar.gz`
6. Create `DeployDB` record with status `pending_upload`
7. Return: `deploy_id`, `upload_url`, `upload_fields`, `conversation_id`, `s3_key`

### 3. `POST /api/app-channels/deploy/confirm`

**File:** `services/api/app_channels.py`

**Logic:**
1. Authenticate request
2. Look up `DeployDB` by `deploy_id`, verify ownership
3. Verify tarball exists in S3 (HEAD request)
4. Update deploy status to `deploying`
5. Ensure workspace VM is running (start if needed via `WorkspaceVMService`)
6. Call VM endpoint: `POST http://{vm_ip}/deploy`
   - Body: `{ site_name, s3_key, deploy_id }`
   - VM pulls tarball, unpacks, commits, returns `{ version, commit_hash }`
7. Update deploy record: status `complete`, set `version` and `commit_hash`
8. Post notification to channel (version message with `extra_metadata`)
9. Return: `conversation_id`, `channel`, `version`, `commit_hash`, `first_deploy`

### 4. Register routes

**File:** `services/api/main.py`

Add the new `app_channels` router to the FastAPI app.

### 5. VM endpoint: `POST /deploy`

**File:** `workspace_vm/appchannels/routes.py`

**Logic:**
1. Receive `{ site_name, s3_key, deploy_id }`
2. Download tarball from S3
3. If site doesn't exist → `create_site(site_name)` (creates git repo + `popcorn.json`)
4. Clear site working tree (except `.git/` and `popcorn.json`)
5. Unpack tarball into site directory
6. Call `auto_commit_site()` → returns `(commit_hash, version)`
7. Return `{ version, commit_hash }`

### 6. MCP tools

Add two new tools to the Popcorn MCP server (`https://mcp.popcorn.ai/mcp`):

- **`popcorn_deploy_init`** — same contract as the API endpoint
  - Input: `{ conversation_id, channel_name }`
  - Output: `{ deploy_id, upload_url, upload_fields, conversation_id, s3_key }`

- **`popcorn_deploy_confirm`** — same contract as the API endpoint
  - Input: `{ deploy_id }`
  - Output: `{ conversation_id, channel, version, commit_hash, first_deploy }`

### 7. Database migration

Alembic migration to create the `deploys` table.

## Dependencies

- Existing: `WorkspaceVMService` for VM lifecycle
- Existing: S3 presigned URL generation (from `file_uploads`)
- Existing: `auto_commit_site()` in `workspace_vm/appchannels/sites.py`
- Existing: Conversation creation service

## Considerations

- **Tarball cleanup:** S3 tarballs should have a TTL / lifecycle policy (e.g. delete after 24h)
- **Deploy timeout:** The confirm step should have a timeout for the VM pull+commit (30s?)
- **Concurrency:** Only one deploy at a time per channel — use deploy status to prevent races
- **VM cold start:** If the VM is stopped, starting it adds latency. The init step could pre-warm.
