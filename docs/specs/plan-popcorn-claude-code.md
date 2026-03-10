# Implementation Plan: popcorn-claude-code

Reference: [2026-03-10-pop-deploy-design.md](./2026-03-10-pop-deploy-design.md)

## Summary

Update the plugin to use a deterministic deploy script instead of LLM-interpreted instructions.

## Steps

### 1. Create `skills/pop/pop.sh`

The core deploy script. All logic lives here.

```
pop.sh [--channel NAME]
```

**Responsibilities:**
- Source setup check from `skills/popcorn/setup.sh` (or run inline equivalent)
- Read `.popcorn.local.json` if it exists → extract `conversation_id`, `channel`
- If first deploy: infer channel name as `pop-<dirname>` (or use `--channel`)
- Create tarball via `git ls-files` (git repo) or `tar` with exclusions
- Call `popcorn deploy init` (CLI) → get `deploy_id`, `upload_url`, `upload_fields`, `conversation_id`
  - Fallback: use MCP tool `popcorn_deploy_init` if CLI unavailable
- Upload tarball to S3 presigned URL via `curl`
- Call `popcorn deploy confirm` (CLI) → get `version`, `commit_hash`
  - Fallback: use MCP tool `popcorn_deploy_confirm` if CLI unavailable
- Write/update `.popcorn.local.json` with `conversation_id` and `channel`
- Add `.popcorn.local.json` to `.gitignore` if not already present
- Print JSON result on last line:
  - Success: `{"ok":true,"channel":"pop-my-app","version":3,"commit_hash":"a1b2c3d","first_deploy":false}`
  - Failure: `{"ok":false,"error":"...","step":"upload"}`

**MCP fallback pattern:**
```bash
if command -v popcorn &>/dev/null; then
  RESULT=$(popcorn --json deploy init ...)
else
  # Use claude mcp call or direct HTTP to MCP server
  RESULT=$(curl -s "$MCP_URL/tools/popcorn_deploy_init" ...)
fi
```

### 2. Update `skills/pop/SKILL.md`

Replace current multi-step LLM instructions with:

```markdown
## When the user runs /popcorn:pop

Run the deploy script:

    bash "${CLAUDE_PLUGIN_ROOT}/skills/pop/pop.sh"

The last line of output is JSON. Report the result:
- Success: "Published to #<channel> (v<version>)"
- First deploy: also mention the new channel was created
- Failure: report the error and which step failed
```

Remove the agent dispatch pattern — no subagent needed since the script is deterministic.

### 3. Update `allowed-tools` in SKILL.md frontmatter

Change from `Bash, Agent` to just `Bash` since we no longer dispatch a subagent.

### 4. Update CLAUDE.md and README.md

- Document `.popcorn.local.json` convention
- Note that `/popcorn:pop` handles first-time setup automatically
- Remove "coming soon" from README

### 5. Update test harness

Add a `--test-deploy` flag to `scripts/test-install.sh` (or a separate script) that:
- Creates a dummy project with a few files
- Runs `/popcorn:pop`
- Verifies `.popcorn.local.json` was created
- Verifies the channel exists

## Dependencies

- **Blocked on:** `popcorn deploy init` and `popcorn deploy confirm` CLI commands (see plan-popcorn-cli.md)
- **Blocked on:** Backend `/api/app-channels/deploy/*` endpoints (see plan-popcorn-backend.md)
- **Blocked on:** MCP tools `popcorn_deploy_init` and `popcorn_deploy_confirm`
