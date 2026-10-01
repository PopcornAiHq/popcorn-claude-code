---
name: popcorn
description: "Popcorn integration — CLI, MCP tools, setup, and behavioral guardrails. Popcorn is an AI tracker: each channel is a tracker that updates itself, reading across email, messages and files to catch every update and decision. What a channel tracks is defined by an app bundle (tables, flows, schedules, webhooks) authored as a channel template. TRIGGER whenever a request names a '#channel-name', or mentions a Popcorn channel, workspace, tracker, app, bundle or template; asks to publish a bundle, post or read messages; asks to change what a channel does, records or notifies; OR asks whether some automation is possible at all — a '#name' is a Popcorn channel rather than Slack, and Popcorn's own 'flow activities' catalog decides what is buildable, never the set of tools this harness happens to expose. ALSO TRIGGER on the working directory, whatever the request says — a directory containing '.popcorn-app.json' is a checked-out Popcorn app bundle, and editing a file in it ships nothing until 'popcorn app validate' and 'popcorn app publish' have run."
allowed-tools: Bash, mcp__popcorn__get_workspace, mcp__popcorn__get_user, mcp__popcorn__list_workspace_members, mcp__popcorn__list_channels, mcp__popcorn__get_channel, mcp__popcorn__list_channel_members, mcp__popcorn__list_messages, mcp__popcorn__read_message, mcp__popcorn__search_messages, mcp__popcorn__send_message, mcp__popcorn__add_reaction, mcp__popcorn__remove_reaction, mcp__popcorn__list_app_bundle_files, mcp__popcorn__read_app_bundle_file, mcp__popcorn__fork_app_bundle, mcp__popcorn__install_app_bundle
---

# Popcorn

Popcorn is an **AI tracker**. It reads across email, messages and files,
catching every update and decision, and it updates itself rather than waiting to
be edited. People talk to it in the channel like a member of the team, and it
keeps records of what happened.

A channel *is* one tracker. What makes it one is an **app bundle**:

| Bundle piece | What it is to the user |
|---|---|
| tables | what the tracker holds, and the records it can show later |
| flows | the updating it does for itself |
| schedules and webhooks | how an update reaches it without anyone typing |
| `AGENT.md` | how it talks in the channel |

Bundles are authored as **channel templates** and published to the channel. That
loop is the whole of what this skill covers.

## Setup

**When the user asks you to do something with Popcorn**, run this first — before any other Popcorn operation:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

The last line of output is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.

If any component is still `false` after the script runs, tell the user what failed and how to fix it manually. If MCP was just added, tell the user to restart Claude Code.

**Troubleshooting:** If setup passes but operations fail, run `POPCORN_AGENT=1 popcorn doctor` for structured diagnostics. Check `.data.issues[]` — empty means healthy. Issues include auth token expiry, workspace state, API reachability, and config permissions.

**Skip this** if the user isn't doing a Popcorn action.

## Routing

**Use the CLI for all operations when available.** Fall back to MCP tools only when the CLI is not installed or in non-terminal environments (e.g. Cowork).

Run `popcorn <command> --help` or `popcorn commands` for CLI discovery.

## Before you tell the user something is impossible

Two ways this goes wrong, both from answering without looking.

**A `#name` in a request is probably a Popcorn channel.** Not Slack, not
decoration. Resolve it before concluding anything about it:

```bash
POPCORN_AGENT=1 popcorn channel list '<name>'          # does it exist?
POPCORN_AGENT=1 popcorn app list --channel '#<name>'   # does it run an app bundle?
```

Read **`.data.channel`** from that second one — it is what this channel runs,
and `null` means it runs no bundle. Do not read `.data.apps` for this: that is
every app available to the workspace's release track, so it is a long list even
for a channel bound to nothing.

A channel running an app bundle has tables, flows, schedules and webhooks you
can read and change. The loop is `popcorn app fork` → `app checkout` → edit →
`popcorn app validate` → `app publish`. A directory already holding a
`.popcorn-app.json` is a checkout partway through that loop — the baseline
names the app version and channel it came from — so an edit to a file in it
has changed nothing the channel runs until
`app validate` and `app publish` have gone through. Use those
commands directly when the user asks for a change to what a channel does;
`/popcorn:bundle` covers the same ground in more depth but is user-triggered,
so never invoke or suggest it.

### Finish the loop — do not end on a question nobody can answer

**Non-interactive: decide, act, and report.** When there is no one to answer —
`claude -p`, a headless run, `POPCORN_AGENT=1`, any context where your output is
not being read by a person mid-task — a question is not caution. It ends the
task in a state nobody asked for, with a correct edit sitting in a file the
channel never reads.

So publish rather than asking whether to publish, and clean up test data you
created yourself rather than asking whether to. Quote the
`other_channels_converging` count `app publish` returns instead of describing
the blast radius in the abstract. **Finish on the summary of what changed,
never on a question**, and state judgement calls as decisions taken.

```bash
POPCORN_AGENT=1 popcorn app publish ./<app> --bump patch -m "what changed" --yes
```

**Always pass `--yes` to `app publish`.** Newer CLIs ask before publishing,
and this shell cannot answer, so the question comes back as a refusal. On a
CLI that does not ask, the flag does nothing. The rule above decides whether
to publish; the flag only stops the CLI asking a question nobody can answer.

**Then branch on `.data.install.state` from `popcorn app status` — never
re-publish to unstick an install.** `installing` / `retrying`: wait, then
re-check. `failed` / `skipped` / `behind`: follow `.data.install.retry_hint`,
which on a fork-line channel is `popcorn app apply`. For `failed`, also read
`.data.install.error_code`: only `invalid_manifest`, `invalid_schedule` and
`bundle_rejected` (or no code) are fixed by editing the head and publishing;
`internal` is a platform failure to report with `workflow_id`, never to publish
over. `locked`: app updates must
be unlocked by a channel or workspace admin before `app apply` can move it.
`current`: done. `live: false` means a running install would not show, so
re-check before acting on `failed` or `behind`. `skills/bundle/SKILL.md` has the
full table.

Genuine blockers still stop you: `app validate` failing, a fork you cannot
create, a request needing an app type that does not exist. "This has
consequences someone might want to weigh" is not a blocker — it is a line in
the result.

Interactive sessions are the other half of this: say what a fork or publish
changes *before* running it, then run it. `skills/bundle/SKILL.md` carries
the full version of this rule with the observed failures quoted; this copy
exists because that skill is user-triggered and unreachable from here.

**Popcorn's catalog decides what is buildable — your own tool list does not.**

```bash
POPCORN_AGENT=1 popcorn flow activities --tier foundation
```

"I have no tool for X" and "Popcorn cannot do X" are different claims, and
reporting the first as the second is wrong in both directions: it refuses work
the platform supports, and it presents a guess about your harness as a platform
limit. Check the catalog, then answer from it — and if the capability genuinely
is not there, say which one is missing and name Popcorn as the thing that lacks
it, so the user can tell a real gap from a temporary one.

## CLI

The CLI auto-updates. To upgrade manually: `popcorn upgrade`.

### Rules

1. **Always quote `'#channel-name'`** in bash — unquoted `#` triggers shell glob expansion. To find channels by name, use `channel list`.
2. **Use `message list` to read channel messages**, not `workspace inbox`. Use `workspace inbox --unread` only for triaging unread notifications across all channels.
3. **Confirm before sending in an interactive session.** Show the user exactly what will be sent and get confirmation before calling `message send` or `send_message`. When no one is there to answer (the non-interactive case under "Finish the loop" above), send it and report what you sent. Prefixing your own commands with `POPCORN_AGENT=1` (rule 4) does not make a session non-interactive; whether a person is reading mid-task does.
4. **Agent mode:** Prefix all CLI commands with `POPCORN_AGENT=1`. This auto-injects `--json`, `--quiet`, and `--no-color`, and suppresses upgrade prompts. You never need to pass `--json` manually.
   ```bash
   POPCORN_AGENT=1 popcorn channel info '#my-channel'
   POPCORN_AGENT=1 popcorn message list '#my-channel' --limit 25
   ```
5. **JSON envelope** — all CLI JSON output uses an envelope: `{"ok": true, "data": ...}` on success, `{"ok": false, "error": ...}` on stderr for errors. Parse `.data` from success responses.

### Commands with side effects worth knowing

Arguments for every command are in `https://docs.popcorn.ai/reference/cli.md`
and `popcorn <command> --help`; these are the ones whose behaviour matters
before you run them.

| Command | What it does |
|---|---|
| `app status --channel '#my-app'` | Read-only. Whether the last publish landed: branch on `.data.install.state`, as above |
| `app apply --channel '#my-app'` | Moves a fork-line channel to its line's head. The retry, not a loop step |
| `schedule list` / `schedule get <ref> --channel '#my-app'` | Read-only. A channel's live schedules and their run counters |
| `schedule trigger <slug\|flow-id\|schedule-id> --channel '#my-app' [--overlap-policy P]` | **A write that starts a real run** of a declared schedule now, with its stored inputs — it posts, sends and writes whatever that flow does. Needs popcorn-cli 0.58.0 or later |

`schedule trigger` does not change the schedule: a cadence change is a manifest
edit and a publish. Say what the run will do before triggering it in an
interactive session. `.data.skipped_overlap: true` means it did **not** run,
because one was already in flight (`--overlap-policy allow_all` overrides); a
null `workflow_id` means the run was not seen starting yet, not that it failed.
Follow a started run with `popcorn flow runs get <workflow_id> --channel '#my-app'`.

### Message Structure

Messages have `content.parts[]`, each tagged with a `type`. **There is no
`part.text`** — the text body is `part.content`, and several part types carry no
body at all, so branch on `type` before reading anything off a part.

- **`text`** → `part.content`, rendered according to `part.format`: `plain`,
  `markdown`, or `code` (with `part.language`)
- **`media`** → `part.mime_type`, `part.url`, `part.filename`, `part.size_bytes`
  (all four always present). `url` holds an internal `file_uploads` key, not an
  http URL — pass it to `download`
- **`system`** → `part.content`, injected context rather than anything a person
  typed. No `format`
- **`agentFinalized`** → no body. `part.success` marks the end of an agent turn

Rarer types exist and will appear eventually: `toolCall`, `toolResult`,
`linkPreview`, `integration`, `permission`, `deleted`, `inaccessible`, `s3`. A
loop that assumes every part has a body breaks on the first agent reply it
meets, because a finalized agent turn ends with a bodyless `agentFinalized`.

Every part also carries `id`, `created_at`, `version`, `visibility` and
`attachments` regardless of type.

### Posting markdown needs `format: markdown`

**`foundation.channel.post` defaults to `format: plain`.** Text written with
markdown markup — `**bold**`, headings, lists — renders its asterisks and
hashes literally unless the step says otherwise:

```yaml
- id: announce
  activity: foundation.channel.post
  args:
    channel_id: $inputs.conversation_id
    text: "**Backfill complete** — 3 rows updated"
    format: markdown          # without this the ** ships as literal asterisks
```

This catches people out because it is backwards from the path they know: an
agent writing a reply posts `markdown` by default, and only flows default to
`plain`. Nothing in the authoring loop surfaces it either — `app validate`
passes, the flow runs green, and the message is wrong only on screen. Check
`part.format` in `message list` output after a test run.

`foundation.channel.edit` and `foundation.channel.post_file` take **no `format`
argument at all** and always emit `plain`. A flow that posts markdown and then
refreshes that message with `channel.edit` silently loses the rendering.

## MCP Tools

Use MCP tools when the CLI is not available, or for conversational operations (reading, searching and sending messages, reacting).

The MCP surface covers people, channels, messages and a channel's app bundle. It works on channels only: direct messages are not reachable, and a DM's ID is refused. Changing what a channel *tracks* by editing its bundle is still CLI-only (`/popcorn:bundle`); MCP can read a bundle's files, fork it, and install a version onto a channel.

Each MCP connection is bound to one workspace, chosen when the user connected Popcorn, and every tool response starts with a `Workspace: <name> (<id>)` line. No tool takes or switches a workspace: to use a different one, the user reconnects Popcorn. An ID or `#name` from another workspace comes back as not found.

Read tools take `channel` as an ID or `#name`; a name that matches more than one channel is refused with the candidates' IDs. Write tools take `channel_id`, an ID only. Listings return a page with a total and a `cursor` for the next page; pass it back unchanged with the same arguments.

Writes that are one-way or reach beyond one message (`fork_app_bundle`, `install_app_bundle`) are a dry run by default: the first call changes nothing and shows what would happen. Show that to the user, and call again with `confirm=true` only once they agree.

| Tool | Purpose |
|------|---------|
| `get_workspace` | The workspace this connection is bound to, and your role in it |
| `get_user` | Look up a person by ID, email or username; `"me"` is you |
| `list_workspace_members` | List or filter the people in this workspace |
| `list_channels` | List or filter channels, including public ones you haven't joined |
| `get_channel` | One channel: its type, description, the app it runs and whether that app is up to date |
| `list_channel_members` | Who is in a channel, and their role there |
| `list_messages` | A channel's or thread's messages, newest first, as previews |
| `read_message` | One message in full |
| `search_messages` | Search message text across the workspace or one channel |
| `send_message` | Send a message as you, to a channel or thread |
| `add_reaction` / `remove_reaction` | React to a message, or take your reaction back |
| `list_app_bundle_files` | The files in a channel's app bundle |
| `read_app_bundle_file` | One file from a channel's app bundle |
| `fork_app_bundle` | Give the channel its own copy of its app, permanently (dry run first) |
| `install_app_bundle` | Bring the channel to its app's newest version, or move it to another line (dry run first) |
