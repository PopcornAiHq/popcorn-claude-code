---
name: template
description: Author, validate, publish and debug a Popcorn channel-template bundle (tables + flows + schedules + webhooks) using the popcorn CLI — the app fork/checkout/publish loop for an app that already exists. USER-TRIGGERED ONLY — never invoke pre-emptively.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
userTriggered: true
---

# /popcorn:template — Author a channel template

A **channel template** turns an empty Popcorn channel into an application: a
manifest declaring tables/schedules/webhooks, plus one YAML file per flow.
This skill drives the whole loop — check out, edit, validate, publish, run,
inspect, fix. Editing an app that exists needs no backend deploy; creating a
brand-new app type does, and is out of scope (see Scope).

## Step 0: Ensure the CLI is ready

Run setup from the **plugin root**:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

The last line is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.
This skill needs `cli` and `auth` true — the MCP path cannot publish bundles.
If either is false, stop and tell the user what failed.

Then confirm the CLI is recent enough to have the authoring commands:

```bash
popcorn flow --help
popcorn app --help
```

`flow activities`, `flow validate`, `template check`, and the `app`
family (`fork`, `checkout`, `publish`, `apply`, `status`) must all be present
— popcorn-cli ≥ 0.20.0. If they are missing, tell the user to upgrade
(`popcorn upgrade`) and stop.

**`popcorn flow import` no longer installs anything.** It survives only as a
tombstone that prints where bundles come from now. If you find yourself
reaching for it, you are on the wrong path — see "How a bundle actually gets
installed" below.

## How a bundle actually gets installed

Two paths, and picking the wrong one wastes the session.

**Editing an app that already exists — the CLI loop.** This is almost always
what the user wants, and it needs no deploy:

```bash
popcorn app list --channel '#chan'      # what does this channel run?
popcorn app fork --channel '#chan'      # this workspace's own fork line
popcorn app checkout --channel '#chan'  # the bound version, as editable files
# ... edit, and BUMP version: in manifest.yaml
popcorn template check ./<app>
popcorn app publish ./<app> --changelog "what changed"
popcorn app status ./<app>              # has the install landed?
```

`fork` first, always: a publish lands on a fork line the workspace **owns**, so
publishing from a channel still bound to the shared product version is refused.
Tell the user what forking means before you run it — their channel stops
tracking the product line and starts tracking their own.

**Creating a new app type — a backend PR, not this skill.** A genuinely new
`app_type` has to be checked into popcorn-backend's `CHANNEL_TEMPLATES`,
deployed, and published from the intranet. There is no client-side path. If
that is what the user needs, say so plainly and stop rather than improvising.

Three things to state out loud before publishing:

- **`version:` in `manifest.yaml` must advance every publish.** The CLI refuses
  a reused or lower number locally.
- **A publish is not scoped to the channel you tested on.** Every other channel
  on the same fork line catches up on its own nightly auto-update tick.
- **One fork line per (workspace, app)** — no parallel experiments without
  `app fork --name <line>`.

If an app the user says exists is missing from `app list`, suspect **release
tracks** before anything else: the list is filtered to the workspace's track
(alpha/beta/stable, default stable), an app released only to alpha is invisible
to a stable workspace, and the API deliberately says nothing about why. Ask;
do not debug.

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

## Step 2: Scaffold, or check out what exists

If the channel already runs the app, do **not** scaffold — check it out and
edit the real thing, so your diff is against what is actually installed:

```bash
popcorn app fork --channel '#chan' && popcorn app checkout --channel '#chan'
```

A scaffold from scratch is for a bundle that will become a new app type via a
backend PR. Either way the shape is the same:

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

## Step 4: Validate offline

Two checks, neither subsuming the other:

```bash
popcorn flow validate . --channel <id>   # every flow — are the references real?
popcorn template check ./<app>           # does the bundle hold together?
```

`flow validate` is the authority on any single reference. `template check` is
offline and answers a different question — cross-file agreement, writes to
undeclared columns, a schedule naming a flow that is not there, a fixture named
`.yaml` that would install as a flow. Run both, and get them clean before
publishing: everything `template check` reports passes `flow validate` cleanly.

```bash
popcorn template check ./<app> --strict  # warnings fail too — the CI form
```

## Step 5: Publish, then actually run it

```bash
popcorn app publish ./<app> --changelog "what changed"
popcorn app status ./<app>
```

Publishing starts the install that moves this channel onto the new version;
`app status` is how you tell whether it has landed. If `status` says the
channel is still on the old version, wait — do not re-publish.

Then check the channel is actually wired up, which is a different question from
whether the bundle is valid:

```bash
popcorn channel-config show --channel <id> --strict
```

That diffs every `$channel.*` reference the flows make against what the channel
has. `--strict` exits non-zero on the three findings that break a run — a
referenced parameter that is not set, a declared integration that is not
connected, and a connected account whose provider contradicts a declaration.
The two `unused_*` findings are informational. Fix with:

```bash
popcorn channel-config params set --channel <id> tone=crisp
popcorn channel-config accounts                       # your account ids
popcorn channel-config integrations set --channel <id> --name mail \
  --integration-id <id>
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
`--channel`. Pass `--inputs` only for the flow's own arguments; an explicit
`conversation_id` there still wins. (Step 0 already gated the CLI version, so
per-command version notes are not repeated here.)

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
- Re-publishing the identical tree is a no-op that still re-runs the install,
  but `schedules:` replaces wholesale on every install.
- Table changes are additive — a "rename" adds a column and orphans the old
  one, and every write site must be renamed too.
- Forking is visible to the user's whole workspace: their channel leaves the
  product line for a fork line only they own, and it will not pick up upstream
  product updates the way it did before.

## Scope

**This skill edits apps that exist.** It forks, checks out, publishes and
debugs — the loop under "How a bundle actually gets installed".

Do not offer to register a bundle in the backend repo's `CHANNEL_TEMPLATES`,
deploy the backend, or publish from the intranet. Creating a new app type is a
backend-side change with its own review, and improvising it from here produces
a bundle nobody can install. Say what the path is and hand it back.
