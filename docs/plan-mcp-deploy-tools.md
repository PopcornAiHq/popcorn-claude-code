# Plan: MCP Tool Consolidation (Backend)

Backend changes to consolidate MCP tools around channel read/write operations and enable CLI-less deploys. Most deploy infrastructure already exists — presigned URL generation (`SiteService.s3_presign`) and publish (`SiteService.s3_pull`) are implemented in the API layer.

## Tool changes overview

```
Current (8 tools)        Proposed (7 tools)        Change
─────────────────        ──────────────────        ──────
whoami                   whoami                    (same)
inbox                                              DROP
get_conversation                                   REPLACE → get_channel
search                   search                    (same)
read_messages            read_messages             (same)
send_message                                       REPLACE → post_message
edit_message                                       DROP (no current need)
react                    react                     (same)
                         get_channel               NEW (read op)
                         update_channel            NEW (write op)
                         post_message              NEW (replaces send + edit)
```

Net: 8 → 7 tools

---

## Channel tools: read + write

The core abstraction is **channels** (conversations). Two operations cover everything:

```
get_channel      → read: details, members, site status, presigned URLs
update_channel   → write: create if not exists, push updates (deploy)
```

### `get_channel` (read)

Returns channel details + site status + presigned URL(s) for S3 operations. Replaces `get_conversation` and absorbs site status and upload URL generation into a single read.

```python
@mcp.tool()
@mcp_error_handler
async def get_channel(
    channel: str,
) -> str:
    """
    Get channel details. For app channels with a site, also returns
    site status and a presigned upload URL.

    Args:
        channel: Channel name (e.g. "#my-app") or conversation ID

    Returns:
        conversation_id, name, members, unread_count,
        site (if app channel): { site_name, version, commit_hash, site_url, status },
        upload (if app channel): { url, fields, s3_key, expires_at }
    """
```

**Why bundle upload URL into read?** The agent calls `get_channel` to understand the channel before acting. If it's a site channel, the presigned URL comes for free — no extra round-trip. If the agent doesn't need it, it ignores it. URL expires in 1 hour, which is plenty for a single deploy flow.

**Existing code to reuse:**
- `get_conversation` tool logic → `services/mcp/tools/details.py`
- `SiteService.s3_presign()` → `lib/app_channels/services/site_service.py:86-106`
- VM site status → `popcorn.json` version info

---

### `update_channel` (write)

Creates a channel if it doesn't exist, and/or pushes updates to an app channel. Currently only works for channels with `site_name` in metadata (app channels).

```python
@mcp.tool()
@mcp_error_handler
async def update_channel(
    channel: str | None = None,
    name: str | None = None,
    s3_key: str | None = None,
    context: str | None = None,
    commit_hash: str | None = None,
) -> str:
    """
    Create or update a channel. For app channels, triggers a deploy.

    Args:
        channel: Existing channel name or ID. Omit to create new.
        name: Channel name (used when creating new channel)
        s3_key: S3 key from get_channel upload URL (triggers deploy)
        context: Deploy description (shown in channel notification)
        commit_hash: Source commit hash (optional, for tracking)

    Returns:
        conversation_id, name, site_name,
        deploy (if s3_key provided): { version, site_url },
        local_json: { ... }  ← client writes to .popcorn.local.json verbatim
    """
```

**Flow:**
```
channel provided?
├─ Yes → resolve to conversation_id
│        s3_key provided?
│        ├─ Yes → SiteService.s3_pull() → deploy + return result
│        └─ No  → return channel info (no-op update, future: metadata edits)
└─ No  → create conversation with site_name (from name param)
          s3_key provided?
          ├─ Yes → deploy immediately after creation
          └─ No  → return new channel info
```

**`local_json` in response:** Server owns the format — agent writes verbatim to `.popcorn.local.json`. Prevents format drift between CLI and MCP paths.

**Existing code to reuse:**
- `SiteService.s3_pull()` → `lib/app_channels/services/site_service.py:108-166`
- `POST /conversations/publish` → `services/api/conversations.py:1129-1178`
- Conversation creation → `lib/core/services/conversations.py:137-227`

---

## Message tools

### `post_message` (replaces `send_message` + `edit_message`)

Simplified interface: `conversation_id` for new messages, `message_id` for thread replies.

```python
@mcp.tool()
@mcp_error_handler
async def post_message(
    content: str,
    conversation_id: str | None = None,
    message_id: str | None = None,
    filename: str | None = None,
) -> str:
    """
    Post a message to a channel or reply to a thread.

    Args:
        content: Message text (markdown), or file content if filename set
        conversation_id: Post new message to this channel
        message_id: Reply in this message's thread
        filename: Upload content as this file (e.g. "report.md")

    Provide conversation_id for a new message, or message_id for a thread reply.
    """
```

**Notes:**
- Exactly one of `conversation_id` or `message_id` should be provided
- `message_id` resolves to the thread — server looks up the conversation
- `edit_message` is dropped. No current need. Can be added later as an optional param if needed.
- `filename` enables file attachments (same as current `send_message`)

---

## Drop: `inbox`

The CLI skill bans inbox usage ("NEVER use inbox to find files or messages"). Returns notifications from ALL channels — a foot-gun for agents. Users who need notifications can use the CLI `popcorn inbox`.

**Files:** `services/mcp/tools/notifications.py`, remove `register_notification_tools` from `__init__.py`

---

## Drop: `edit_message`

No current need. If needed later, can return as an optional `edit_message_id` param on `post_message`.

---

## Upload format note

The existing presigned URL uses **multipart form-data POST** (not PUT):

```
POST {upload_url}
Content-Type: multipart/form-data

Fields from upload.fields + file attachment
```

The `upload.fields` dict from `get_channel` contains all required form fields (key, Content-Type, policy, signature, etc.). The plugin's upload script must use `curl -F` (form), not `curl -T` (PUT).

---

## Final tool set

```
Tool              │ Type     │ Purpose
──────────────────┼──────────┼──────────────────────────────────
whoami            │ identity │ Current user + workspace
search            │ read     │ Find channels, DMs, users, messages
get_channel       │ read     │ Channel details + site status + upload URL
read_messages     │ read     │ Message history + threads
post_message      │ write    │ New message or thread reply
update_channel    │ write    │ Create channel / deploy to app channel
react             │ write    │ Add/remove reaction
```

7 tools. Clean read/write separation.

---

## Implementation order

1. `get_channel` (replaces `get_conversation`, adds site status + presigned URL)
2. `update_channel` (create + deploy)
3. `post_message` (replaces `send_message`)
4. Drop `inbox`, `edit_message`, `send_message`, `get_conversation`

Steps 1-2 are the critical path for enabling MCP deploys. Steps 3-4 are cleanup.
