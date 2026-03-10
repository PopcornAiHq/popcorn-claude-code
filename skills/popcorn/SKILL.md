---
name: popcorn
description: Popcorn messaging — setup, CLI reference, and best practices
alwaysApply: true
allowed-tools: Bash
---

# Popcorn

## Setup

Run these checks silently on first use (don't narrate detection steps to the user):

### Step 1: CLI

Run `which popcorn` (or `command -v popcorn`).

If not found → install:
```bash
uv tool install git+https://github.com/PopcornAiHq/popcorn-cli.git
```

### Step 2: Auth & Workspace

Run `popcorn whoami`.

If not authenticated → run `popcorn auth login`. This opens a browser for the user to log in and select their workspace.

### Step 3: MCP Server

Run `claude mcp list` and look for "popcorn".

If not found → add it:
```bash
claude mcp add popcorn --transport http https://mcp.popcorn.ai/mcp
```

Tell the user they may need to restart Claude Code for the MCP server to take effect.

### Step 4: Ready

Use **CLI mode** as the primary interface (cheaper, no context cost). Fall back to MCP tools when the CLI is unavailable.

---

## CLI Reference

### Critical Rules

1. **Always use `'#channel-name'`** — quote the `#` to prevent shell glob expansion. The CLI resolves names to UUIDs automatically. Never search for a channel UUID first.
2. **NEVER use `inbox` to find files or messages in a channel.** Always use `popcorn --json read '#channel-name'`. The inbox returns notifications from ALL channels and WILL give you the wrong result.
3. **Run `popcorn --help` first** — do this once per session to see available commands before guessing.

### Global Flags

These go before OR after the subcommand:

```
--json          Raw JSON output (use for parsing)
--version       Print version
--workspace ID  Override workspace
-e, --env NAME  Use a specific profile
--no-color      Disable color output
```

### Recipes

#### Read Messages

```bash
popcorn --json read '#channel-name' --limit 10
popcorn --json read '#channel-name' --thread <message_id>   # thread replies
```

#### Download a File

When asked to download a file from a channel, follow these steps exactly:

```bash
# Step 1: Read the channel (NEVER use inbox)
popcorn --json read '#channel-name' --limit 20 | python3 -c "
import json, sys
for m in json.load(sys.stdin)['messages']:
    for p in m['content']['parts']:
        if p['type'] == 'media':
            print(f\"{p['filename']}  key={p['url']}\")
"

# Step 2: Download using the file key from step 1
popcorn download '<file_key>' -o ./filename.ext
```

#### Send a Message

Always show the user exactly what will be sent and get confirmation before sending.

```bash
popcorn send '#channel-name' "message text"
popcorn send '#channel-name' "see attached" --file ./report.pdf
popcorn send '#channel-name' "reply" --thread <message_id>
echo "long message" | popcorn send '#channel-name'
```

#### Check Inbox

Use `inbox` ONLY for checking notifications — never to find files or read a specific channel.

```bash
popcorn --json inbox --unread
popcorn --json inbox
```

Present notifications grouped by type: direct mentions → replies → reactions. Use `popcorn --json read <conversation_id>` to read full context.

#### Search

```bash
popcorn --json search channels [query]
popcorn --json search dms [query]
popcorn --json search messages "query"
popcorn --json search users [query]
```

#### Channel Management

```bash
popcorn --json info '#channel-name'
popcorn create "channel-name" [--type public_channel|private_channel|dm|group_dm]
popcorn join '#channel-name'
popcorn leave '#channel-name'
popcorn invite '#channel-name' <user_ids>
popcorn kick '#channel-name' <user_id>
popcorn update '#channel-name' --name "new-name" --description "new desc"
popcorn archive '#channel-name' [--undo]
```

#### Reactions and Edits

```bash
popcorn react '#channel-name' <msg_id> <emoji> [--remove]
popcorn edit '#channel-name' <msg_id> "new content"
popcorn delete '#channel-name' <msg_id>
```

#### Escape Hatch

For API endpoints not covered by named commands:

```bash
popcorn api /api/path
popcorn api /api/path -X POST -d '{"key": "value"}'
popcorn api /api/path -p key=value
```

### Message Structure

Messages have `content.parts[]`, each with a `type`:
- **`text`** → `part.text` (markdown string)
- **`media`** → `part.url` (file key for `download`), `part.filename`, `part.mime_type`, `part.size_bytes`

---

## MCP Mode

When using the Popcorn MCP server instead of the CLI:

- Call Popcorn MCP tools directly — they are self-describing.
- The recipes and message formatting guidance in the CLI Reference section above still apply conceptually (e.g., message structure, quoting channel names, not using inbox to find files).
- MCP provides a subset of CLI functionality. If the user needs features only available in the CLI, recommend installing it.

---

## Tips

- **Quote `'#channel'`** in bash — unquoted `#` triggers glob expansion
- **Use `--json` for parsing** — human-readable output is for display only
- Messages use markdown: `**bold**`, `*italic*`, `` `code` ``
- Conversations accept `#channel-name` or UUID — prefer names
