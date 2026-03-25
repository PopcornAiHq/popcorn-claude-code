# Plan: Plugin MCP Deploy Path

Plugin changes to enable conversational deploys via MCP + scripts, without the CLI or pop skill. Depends on backend plan (`plan-mcp-deploy-tools.md`) being implemented first.

## Goal

Two paths to the same outcome:

```
Path 1: /pop skill (developer)          Path 2: Conversational (anyone)
──────────────────────────────           ────────────────────────────────
User types /pop                          "publish this" / "share with team"
Skill activates                          Agent handles via CLI skill routing
CLI: popcorn pop                         Terminal → CLI, otherwise → MCP + script
Full guided workflow                     Simpler, more hand-holding
Git-aware (diff, commit, push)           Deploy what's on disk
```

### Environment determines the path

```
┌─────────────────────────┐     ┌──────────────────────────┐
│ Terminal (Claude Code)  │     │ Non-terminal (Cowork)    │
│                         │     │                          │
│ CLI preferred           │     │ MCP is the primary path  │
│ MCP as fallback only    │     │ CLI likely unavailable   │
│ if CLI install fails    │     │                          │
└─────────────────────────┘     └──────────────────────────┘
```

---

## Phase 1: Remove messages skill

The messages skill is redundant — the agent can gather channel context via CLI (`popcorn list-messages`) or MCP (`read_messages`).

**Changes:**
- Delete `skills/messages/SKILL.md` and `skills/messages/` directory
- Update CLAUDE.md: remove from structure tree and skills section
- Update CLI skill: remove `/popcorn:messages` references

**Not blocked on backend work — can ship now.**

---

## Phase 2: Add upload script

**New file:** `scripts/pop-upload.sh`

Designed for an AI agent to call — accepts structured input via a JSON file (not CLI args), outputs structured JSON, handles errors cleanly.

```
Usage:  bash "${CLAUDE_PLUGIN_ROOT}/scripts/pop-upload.sh" <config_file>
Input:  Path to JSON config file written by the agent
Output: JSON on stdout: {"ok": true, "size_bytes": 12345}
        or: {"ok": false, "error": "description"}
Exit:   0 on success, 1 on failure
```

### Config file format

The agent writes a temp JSON file with the upload parameters from `get_channel`:

```json
{
  "upload_url": "https://s3.amazonaws.com/...",
  "upload_fields": {
    "key": "workspace/sites/myapp/versions/uuid.tar.gz",
    "Content-Type": "application/gzip",
    "policy": "...",
    "x-amz-signature": "..."
  },
  "project_dir": "/path/to/project"
}
```

`project_dir` is optional, defaults to cwd.

### Script internals

```
1. Read + validate config JSON (jq)
2. Collect files
   ├─ Git repo: git ls-files (respects .gitignore)
   └─ Non-git: find with default excludes (node_modules, .env, __pycache__, .git, etc.)
3. Apply .popcornignore if present (client-side, saves upload bandwidth)
4. Create tarball → temp file
5. Upload via curl multipart form-data POST
   ├─ Iterate upload_fields → -F "key=value" for each
   └─ Append -F "file=@tarball"
6. Clean up temp files (tarball + config)
7. Output JSON result
```

### Why a config file (not CLI args)

- Presigned POST fields contain long base64 policy strings and signatures
- Shell escaping is fragile — an agent generating `curl -F "policy=eyJ..."` risks truncation or quoting bugs
- JSON file is what the agent naturally produces from the MCP response
- The agent writes the file, passes the path, script reads it — clean handoff

### Dependencies

- `jq` — for parsing config JSON. Available on macOS (Homebrew), most Linux. Script should check and fail clearly if missing.
- `curl` — for upload. Universal.
- `tar` — for tarball. Universal.
- `git` — optional, for `git ls-files`. Falls back to `find` if not a git repo.

---

## Phase 3: Update CLI skill

Add MCP deploy path to `skills/cli/SKILL.md`.

### New section: "Deploy path selection"

```
| Environment              | User says /pop | User says "publish this" |
|--------------------------|----------------|--------------------------|
| Terminal + CLI available | Pop skill      | popcorn pop via CLI      |
| Terminal + no CLI        | Pop skill      | MCP + pop-upload.sh      |
| Non-terminal (Cowork)   | Pop skill      | MCP + pop-upload.sh      |
```

The pop skill always uses the CLI (it runs setup.sh which installs it). For conversational requests, prefer CLI in the terminal, fall back to MCP + script.

### New section: "MCP deploy flow"

Step-by-step for the agent when using MCP instead of CLI:

```
1. mcp: whoami                            → verify auth
2. Read .popcorn.local.json               → existing channel?
3. mcp: get_channel(channel)              → details + presigned upload URL
     (if no .popcorn.local.json, ask user for channel name or create new)
4. Write config JSON with upload params   → temp file
5. bash: pop-upload.sh <config_file>      → tarball + upload
6. mcp: update_channel(channel, s3_key,   → trigger deploy
        context, commit_hash?)
7. Write .popcorn.local.json              → from response local_json
8. Report: channel name, version, URL
```

### Script path reference

```
Upload script: bash "${CLAUDE_PLUGIN_ROOT}/scripts/pop-upload.sh" <config_file>
```

---

## Phase 4: Update CLAUDE.md

- Update structure tree (remove messages/, add docs/, add pop-upload.sh)
- Update skills section (remove messages)
- Add brief note about MCP deploy path as alternative to CLI

---

## Conversational UX notes

Non-technical users won't type `/pop`. They'll say things like:
- "publish this"
- "share this with the team"
- "put this on popcorn"
- "deploy the latest version"

The agent detects deploy intent and follows the path selection logic.

| Concern | Pop skill (developer) | Conversational (anyone) |
|---------|----------------------|-------------------------|
| Git state | Commits, pulls, checks unpushed | Deploys what's on disk |
| Context | Auto-generated from git diff | Ask user "what changed?" or generic |
| Channel name | Inferred or user-specified | Ask if first deploy |
| Error recovery | Structured (retry, delete config) | Explain simply, offer to retry |

---

## File changes summary

```
DELETE  skills/messages/SKILL.md
DELETE  skills/messages/
ADD     scripts/pop-upload.sh
EDIT    skills/cli/SKILL.md         (add MCP deploy path, remove /messages refs)
EDIT    CLAUDE.md                   (structure tree, skills section)
```

---

## Dependencies

- **Blocked on:** Backend MCP tools (`get_channel`, `update_channel`) — plan-mcp-deploy-tools.md
- **Not blocked:** Phase 1 (remove messages skill) — can ship now
