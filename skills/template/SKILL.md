---
name: template
description: Author, validate, install and debug a Popcorn channel-template bundle (tables + flows + schedules + webhooks) using the popcorn CLI. USER-TRIGGERED ONLY — never invoke pre-emptively.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
userTriggered: true
---

# /popcorn:template — Author a channel template

A **channel template** turns an empty Popcorn channel into an application: a
manifest declaring tables/schedules/webhooks, plus one YAML file per flow.
This skill drives the whole loop — write, validate, install, run, inspect, fix.

## Step 0: Ensure the CLI is ready

Run setup from the **plugin root**:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

The last line is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.
This skill needs `cli` and `auth` true — the MCP path cannot import bundles.
If either is false, stop and tell the user what failed.

Then confirm the CLI is recent enough to have the template commands:

```bash
popcorn flow --help
```

`flow activities`, `flow validate`, and `flow import --dry-run` must all be
present (popcorn-cli ≥ 0.13.0). If they are missing, tell the user to upgrade
and stop.

## The rule that matters most

**The server is the authority, not your memory.** Never write an activity
name, argument, or output field from recall. Fetch them:

```bash
popcorn flow activities --tier foundation            # names + one-line docs
popcorn flow activities --json                       # full arg/result schemas
popcorn flow validate <file>.yaml --channel <id>     # is this reference real?
```

If you are unsure whether something exists, run the command. A hallucinated
activity name fails at install; a hallucinated *output field* often fails much
later, at runtime, in production.

## Step 1: Understand the goal, then read the guide

Ask what the template should do if it is not clear — what state it holds, what
triggers it (webhook / schedule / agent / message), what it posts.

Then **read the authoring guide before writing YAML**. If the user has
popcorn-cli checked out it is at `docs/TEMPLATE_AUTHORING.md`; otherwise fetch
it:

```
https://github.com/PopcornAiHq/popcorn-cli/blob/main/docs/TEMPLATE_AUTHORING.md
```

The complete worked example is `examples/alerttracker/` in the same repo. Copy
its shape rather than inventing one.

## Step 2: Scaffold

```
mytemplate/
├── manifest.yaml       tables, channel_parameters, scalars, schedules, webhooks
├── AGENT.md            notes injected into the channel agent's prompt
├── README.md           human docs
├── <flow>.yaml         one per flow; identity is the `name:` inside, not the filename
└── fixtures/*.json     sample payloads — MUST be .json, never .yaml
```

Non-obvious things to get right the first time:

- **Fixtures must be `.json`.** Any `.yaml` in the bundle is installed as a
  flow.
- **A manifest with no `app_type:` CLEARS the channel's app_type.** Only
  install an untyped bundle into a dedicated channel. Warn the user explicitly
  before the first install.
- **Never put flow-written runtime state under `scalars:`** — it UPSERTs on
  every install and would reset the live channel.
- **`schedules:` replaces wholesale**; `webhooks:` is create-if-missing.
- Use `<channel-conversation-id>` in schedule inputs so the bundle stays
  portable.

## Step 3: Write flows against the real constraints

These are the limits authors trip over. They are not style advice — each one
is a hard failure.

| Constraint | What to do instead |
|---|---|
| `when:` is exactly one `==`/`!=`. No `<`, `>`, `&&`, `||` | Put real predicates in `list_rows`' `filter`, which supports `$lt $gte $in $exists $contains` |
| No arithmetic anywhere, including dates | Never design a counter — use a `merge: concat` string column. For time windows, have the caller pass a timestamp, or spend one `agent.transform` and use its output only as a filter operand |
| A reference path cannot contain a space | A column read as `$row.X` must be named space-free. Columns only written or filtered may keep spaces |
| `$inputs.<object>.field` is statically unreachable | Get a typed shape first via `agent.transform` + `output_schema` |
| Arrays index with dots | `$steps.x.output.ids.0`, never `ids[0]` |
| No `on_error` means up to 4 attempts | Non-idempotent steps need `retry: 0` |
| A missing key is a hard `ReferenceError`, and `on_error` **cannot** rescue it — resolution precedes invocation | Guarantee presence upstream: `required` in an `output_schema`, or `$exists: true` in the query that produced the rows |

### When you use `agent.transform`

It will **invent data rather than fail**. A required `output_schema` is a
formatting contract, not a validation gate. Always:

1. Add a `recognized: {type: boolean}` field and a `workflow.fail` guard on it.
2. Put **every property you dereference** in `required:` — an optional one may
   simply be absent, and a missing key is a hard `ReferenceError`.
3. Keep the prompt consistent with the schema. Telling the model to blank a
   field whose `enum` excludes `""` makes it reason aloud and break JSON.

## Step 4: Validate, then preflight

```bash
popcorn flow validate . --channel <id>            # every flow, fast
popcorn flow import . --channel <id> --dry-run    # whole-bundle preflight
```

Read the dry-run output to the user before installing — especially **flows to
DELETE**, since install prunes anything the bundle no longer covers, and the
`app_type` warning.

## Step 5: Install and actually run it

```bash
popcorn flow import . --channel <id>
```

**Validation will not catch your real bugs.** Every defect found while
building the reference bundle passed `flow validate` cleanly, because they
were runtime semantics: a merge policy overwriting a timestamp, an LLM
inventing a row, an optional field going missing, a write to an undeclared
column. Always exercise the flow and read a row back.

```bash
popcorn flow run <flow-name-or-uuid> --channel <id> --wait
popcorn flow runs list --channel <id>
popcorn flow runs get <workflow-id> --channel <id> --include-errors
popcorn table rows <table> --channel <id>
popcorn table schema <table> --channel <id>
```

Note: `flow run` accepts a name or a UUID and defaults `conversation_id` from
`--channel` (popcorn-cli >= 0.16.0). Pass `--inputs` only for the flow's own
arguments; an explicit `conversation_id` there still wins.

For webhook-fed bundles:

```bash
popcorn webhook list <id>                          # copyable URL
curl -X POST <url> -H 'Content-Type: application/json' -d @fixtures/sample.json
```

Posting the **same body twice does not test merge logic** — the webhook layer
dedupes identical deliveries and no flow runs at all. Vary the body while
keeping the identity fields.

## Step 6: Debug

Work from evidence, in this order:

1. `flow runs list --channel <id> --status failed` — find the failed run.
2. `flow runs get <wid> --include-errors` — shows the terminal failure with
   its cause chain and each activity failure. It names the **activity**, not
   the DSL step id; the step id is not exposed by the API.
3. `table rows` / `table schema` — did the write land where you think? A
   column written under an undeclared name succeeds silently.
4. If a run *Completed* but the data is wrong, suspect merge policy or an LLM
   step, not references.

`start_flow` is asynchronous: a parent that launches a child reports Completed
immediately. Always check the **child's** run.

## Gotchas worth stating out loud to the user

- A freshly created channel is **not resolvable by `#name` for ~5 minutes**.
  Use the conversation UUID right after `channel create`.
- Installing an untyped bundle clears `app_type`.
- Re-import is idempotent, but `schedules:` replaces wholesale.
- Table changes are additive — a "rename" adds a column and orphans the old
  one, and every write site must be renamed too.

## Scope

Do not offer to register the bundle in the backend repo's template registry —
that is a separate, backend-side promotion. This skill installs by import
only.
