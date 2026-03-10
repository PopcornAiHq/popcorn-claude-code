# Implementation Plan: popcorn-cli

Reference: [2026-03-10-pop-deploy-design.md](./2026-03-10-pop-deploy-design.md)

## Summary

Add `popcorn deploy init` and `popcorn deploy confirm` commands to the CLI. These are thin wrappers around the new backend API endpoints.

## Steps

### 1. Add `deploy` subcommand group

**File:** `src/popcorn_cli/cli.py`

Add to `build_parser()`:

```
popcorn deploy init [--conversation-id ID] [--channel-name NAME]
popcorn deploy confirm <deploy_id>
```

### 2. Add `deploy_init` operation

**File:** `src/popcorn_core/operations.py`

```python
def deploy_init(
    client: APIClient,
    conversation_id: str | None,
    channel_name: str,
) -> dict[str, Any]:
    """Initialize a deploy — get presigned S3 URL for tarball upload."""
    return client.post(
        "/api/app-channels/deploy/init",
        data={
            "conversation_id": conversation_id,
            "channel_name": channel_name,
        },
    )
```

**Returns:** `{ deploy_id, upload_url, upload_fields, conversation_id, s3_key }`

### 3. Add `deploy_confirm` operation

**File:** `src/popcorn_core/operations.py`

```python
def deploy_confirm(
    client: APIClient,
    deploy_id: str,
) -> dict[str, Any]:
    """Confirm tarball uploaded, trigger VM pull and commit."""
    return client.post(
        "/api/app-channels/deploy/confirm",
        data={"deploy_id": deploy_id},
    )
```

**Returns:** `{ conversation_id, channel, version, commit_hash, first_deploy }`

### 4. Add CLI handlers

**File:** `src/popcorn_cli/cli.py`

```python
def cmd_deploy_init(args):
    client = _get_client(args)
    resp = operations.deploy_init(
        client,
        conversation_id=getattr(args, "conversation_id", None),
        channel_name=args.channel_name,
    )
    _output(args, resp, ...)

def cmd_deploy_confirm(args):
    client = _get_client(args)
    resp = operations.deploy_confirm(client, args.deploy_id)
    _output(args, resp, ...)
```

**Human-readable output for `deploy init`:**
```
Deploy initialized: dep_abc123
Upload URL ready. Upload your tarball, then run:
  popcorn deploy confirm dep_abc123
```

**Human-readable output for `deploy confirm`:**
```
Deployed to #pop-my-app (v3)
Commit: a1b2c3d
```

### 5. Add `deploy upload` convenience command (optional)

A convenience command that combines tarball creation + S3 upload:

```
popcorn deploy upload <deploy_id> <tarball_path>
```

This uploads the tarball to the presigned URL from the init step. Useful standalone, and `pop.sh` can use it instead of raw `curl`.

**File:** `src/popcorn_core/operations.py`

```python
def deploy_upload(upload_url: str, upload_fields: dict, tarball_path: str) -> None:
    """Upload tarball to S3 presigned URL."""
    # Same pattern as existing upload_file() but for deploy tarballs
    ...
```

### 6. Add `deploy` command to help categories

**File:** `src/popcorn_cli/cli.py`

Add a new section in the help output:

```
Deploy:
  deploy init       Initialize a deploy (get upload URL)
  deploy confirm    Confirm upload, trigger deploy
  deploy upload     Upload tarball to presigned URL
```

### 7. Tests

**File:** `tests/test_deploy.py` (new)

- `test_deploy_init` — mock API call, verify request body
- `test_deploy_confirm` — mock API call, verify response parsing
- `test_deploy_upload` — mock S3 upload, verify multipart form

## Dependencies

- Existing: `APIClient` for authenticated requests
- Existing: `httpx` for S3 upload (same pattern as `upload_file`)
- **Blocked on:** Backend `/api/app-channels/deploy/*` endpoints

## Notes

- `--json` flag should work for all deploy commands (structured output for `pop.sh`)
- Auth token refresh should work transparently (existing `APIClient` handles this)
- The deploy commands don't create tarballs — that's `pop.sh`'s responsibility. The CLI is a thin API client.
