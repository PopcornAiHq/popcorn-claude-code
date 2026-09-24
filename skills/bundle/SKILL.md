---
name: bundle
description: Change what a Popcorn channel tracks — its tables, flows, schedules, webhooks, prompts and code. Forks the app bundle, checks it out as editable files, then validates and publishes. For an app the channel already runs; requires the popcorn CLI.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
disable-model-invocation: true
---

# /popcorn:bundle — Change what a channel tracks

An **app bundle** is what makes a channel a tracker: a manifest declaring
tables, schedules and webhooks, one YAML file per flow, and the prompts, copy
and code those flows use. This skill drives the loop that changes one —
check out, edit, validate, publish, run, inspect, fix. Editing an app that
exists needs no backend deploy. Creating a brand-new app type does, and is out
of scope (see Scope).

**This skill does not teach the bundle format.** docs.popcorn.ai does, and it
is kept in step with the platform; a restatement here would drift from it.
What lives here is the part the docs cannot own: which command to run when,
what to check before trusting a result, and when to ask the user versus act.

## Step 0: Ensure the CLI is ready

Run setup from the **plugin root**:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/popcorn/setup.sh"
```

The last line is JSON: `{"cli":true/false,"auth":true/false,"mcp":true/false}`.
This skill needs `cli` and `auth` true — the MCP path cannot publish bundles.
If either is false, stop and tell the user what failed.

**Prefix every command in this skill with `POPCORN_AGENT=1`.** It injects
`--json`, `--quiet` and `--no-color`. Without it the CLI prints for humans, and
the `.data.*` fields this skill tells you to read are not there to read. The
commands below leave the prefix off for readability; add it anyway.

```bash
POPCORN_AGENT=1 popcorn --version
```

This skill is written against popcorn-cli **0.52.0 or later**. On anything
older, tell the user to run `popcorn upgrade` and stop.

## Where the authoring rules live

**Read these before writing YAML**, and prefer them to anything you remember.
Every page is served as `text/markdown`, so `curl -s <url>` brings it whole —
a fetch tool that summarises pages drops exactly the details that matter:

| Need | Read |
|---|---|
| Index of every page, one paragraph each | `https://docs.popcorn.ai/llms.txt` |
| The whole authoring loop: bundle layout, manifest keys, flow grammar, tables, traps | `https://docs.popcorn.ai/guides/template-authoring.md` |
| A bundle's `states:` section | `https://docs.popcorn.ai/guides/states-authoring.md` |
| What install does to each manifest key | `https://docs.popcorn.ai/concepts/manifest-keys.md` |
| Where a value belongs: `scalars:`, `default_scalars:`, or neither | `https://docs.popcorn.ai/concepts/scalar-tiers.md` |
| Fork lines, publish and apply, versions | `https://docs.popcorn.ai/concepts/fork-line.md`, `…/publish-and-apply.md`, `…/bundle-version.md` |
| An activity's arguments and results | `https://docs.popcorn.ai/reference/activities.md` — and the CLI, below |

`llms.txt` lists the rest of the concept pages. The guide says where it and the
tools disagree, the tool is right — so treat a clash as a docs bug, not a reason
to route around the check.

**The server is the authority on activities, not your memory.** Never write an
activity name, argument or output field from recall. Fetch them:

```bash
popcorn flow activities --tier foundation            # names + one-line docs
popcorn flow activities --name <wire.name>           # one activity's schema
popcorn flow validate <file>.yaml                    # is this reference real?
```

A hallucinated activity name fails at publish; a hallucinated *output field*
often fails much later, at runtime, in production.

## Step 1: Understand the goal, then check out what exists

Ask what the change should do if it is not clear — what state it holds, what
triggers it (webhook / schedule / agent / message), what it posts.

```bash
popcorn app list --channel '#chan'      # .data.channel = what THIS channel runs
popcorn app lines                       # this workspace's fork lines
popcorn app fork --channel '#chan'      # this workspace's own fork line
popcorn app checkout --channel '#chan'  # the fork line's head, as editable files
```

`.data.channel` from `app list` is the binding — `null` means the channel runs
no bundle at all, and there is nothing to fork. `.data.apps` beside it is every
app the workspace's release track can see, which is a different question.
`app list` and `app lines` both work without `--channel` when all you need is
the workspace view.

**If an app the user says exists is missing from `app list`, suspect release
tracks first** — an app released only to alpha is invisible to a stable
workspace, and the API deliberately says nothing about why. Ask; do not debug.

**Fork first, and say what it means before you run it** (interactive sessions):
the channel stops tracking the shared product line and starts tracking the
workspace's own, it no longer picks up product updates the way it did, and a
fork line cannot be deleted. A publish is refused from a channel still on the
product version, so there is no way round this step.

A bare `app fork` adopts the workspace's existing line when there is exactly
one, and asks first. Through Bash that question cannot be answered, so it comes
back as `Refusing to prompt in non-interactive mode`, after a line on stderr
naming the line it would adopt. Tell the user which line that is, then rerun
with `--name '<line>'`. `app lines` shows the candidates up front.

**The worked example is the checkout.** `app checkout` hands you the real,
complete bundle at the head of the channel's fork line, comments and all. It is
more current than any file in any repo — do not go looking for a reference copy
of a bundle elsewhere first. Read the files you are about to change before
changing them.

**Do not scaffold a bundle for a channel that already runs one.** Check it out
and edit the real thing, so the diff is against what is installed.

Before the first install of a bundle with no `app_type:` in its manifest, warn
the user explicitly: an untyped manifest clears the channel's app type. Only
install one into a dedicated channel.

## Step 2: Edit, then validate offline

Two checks, neither subsuming the other. Run both and get them clean before
publishing:

```bash
popcorn flow validate .                  # every flow — are the references real?
popcorn template check ./<app> --strict  # does the bundle hold together?
```

Inside a checkout both take the channel from the baseline; elsewhere pass
`--channel <id>` to `flow validate`.

**Read the warnings, not the exit status.** A path the format does not
recognise — a `fixtures/` directory, a flow under `flows/`, a nested prompt —
is a `path-not-published` *warning*, so a plain `template check` exits 0 and
`app publish` then succeeds without that path. `--strict` is what turns it
into a failure, which is why it is the form above.

## Step 3: Publish

```bash
popcorn app publish ./<app> --bump patch -m "what changed" --yes
popcorn app status ./<app>               # has the install landed?
```

- **`version:` must advance every publish.** `--bump patch|minor|major` writes
  it for you, off the fork line's head, only once the publish is accepted.
  Editing `version:` by hand also works; do one or the other, not both.
- **`--yes` is there because the CLI cannot prompt through Bash.** The decision
  to publish is yours to make under the rule below — the flag only stops the
  CLI from refusing a question nobody can answer.
- **A publish is not scoped to the channel you tested on.** Every other
  channel on the same fork line catches up on its own. `app publish` reports
  `other_channels_converging` — the count of channels besides this one that it
  reaches. Quote the number rather than describing the risk in the abstract;
  `0` means nobody else is affected, and saying so is more useful than a
  warning.
- **If `app status` says the channel is still behind, wait — do not
  re-publish.** The install converges on its own. `app apply` is the retry for
  an install that did not land, not a step in the loop.

### Whether to ask, when nobody is there to answer

> A condensed copy of this rule lives in `skills/popcorn/SKILL.md`, which
> is the skill a model can actually reach — this one is user-triggered.
> Change both together.

**Interactive session: say those things first, then publish.** A fork changes
what the user's whole workspace tracks, and they should hear it before it
happens rather than after.

**Non-interactive: decide, act, and report.** When there is no one to answer —
`claude -p`, a headless run, `POPCORN_AGENT=1`, any context where your output is
not being read by a person mid-task — a question is not caution. It ends the
task in a state nobody asked for.

Two observed failures, both quoted verbatim:

- Validated clean, bumped 0.3.0 to 0.4.0, then *"Before publishing, let me
  confirm with you. Do you want me to: 1. Publish this now"*. Nothing shipped.
- Published successfully, verified the change against a live webhook, then spent
  its last turn on *"I'd like to delete both — confirm and I'll proceed"*, about
  two test rows it had created itself. The user never got told what changed.

So in that mode: do the thing, then report. Publishing, and cleaning up test
data you created, are both decisions you are equipped to make — quote the
`other_channels_converging` count for the first, and just tidy up after
yourself for the second. **Finish on the summary of what changed, never on a
question.** State judgement calls as decisions taken.

Genuine blockers still stop you: `template check` failing, a fork you cannot
create, a request that needs an app type that does not exist. But "this has
consequences someone might want to weigh" is not a blocker — it is a line in
the result.

## Step 4: Check the wiring, then actually run it

A valid bundle and a wired-up channel are different questions:

```bash
popcorn channel-config show --channel <id> --strict
```

That diffs every `$channel.*` reference the flows make against what the channel
has, and `--strict` exits non-zero on the findings that break a run. Fix with:

```bash
popcorn channel-config params set --channel <id> tone=crisp
popcorn channel-config accounts                       # your account ids
popcorn channel-config integrations set --channel <id> --name mail \
  --integration-id <id>
```

**Validation will not catch the real bugs.** The defects that matter are
runtime semantics — a merge policy overwriting a timestamp, an LLM inventing a
row, an optional field going missing — and they pass every check. Always
exercise the flow and read a row back:

```bash
popcorn flow run <flow-name> --channel <id> --wait
popcorn flow runs list --channel <id>
popcorn flow runs get <workflow-id> --channel <id> --include-errors
popcorn table rows <table> --channel <id>
```

`flow run` takes the flow's **name** — the `name:` inside its YAML, as
`flow list` shows it — not an id. It defaults `conversation_id` from
`--channel`; pass `--inputs` only for the flow's own arguments.

For webhook-fed bundles:

```bash
popcorn webhook list <id>
popcorn webhook send <webhook-name> @../payloads/sample.json --channel <id>
```

To create a webhook that starts a flow, name the flow:
`webhook create --action-mode trigger_workflow --trigger-flow-name <flow-name>`.

Keep sample payloads outside the bundle directory — inside it they are either
installed as a flow or left behind. **Sending the same body twice does not test
merge logic**: identical deliveries are dropped before any flow runs. Vary the
body while keeping the identity fields.

A freshly created channel is **not resolvable by `#name` for a few minutes**.
Use the conversation UUID right after `channel create`.

## Step 5: Debug

Work from evidence, in this order:

1. `flow runs list --channel <id> --status failed` — find the failed run.
2. `flow runs get <wid> --include-errors` — the terminal failure with its cause
   chain. It names the **activity**, not the DSL step id.
3. `table rows` / `table schema` — did the write land where you think? A
   column written under an undeclared name succeeds silently.
4. If a run *Completed* but the data is wrong, suspect merge policy or an LLM
   step, not references.

A flow that starts another with `start_flow` reports Completed immediately.
Always check the **child's** run.

## Say these out loud to the user

- Forking moves the channel onto a line only this workspace owns, visibly to
  the whole workspace, and a fork line cannot be deleted.
- A publish reaches every channel on the line — give the
  `other_channels_converging` count.
- Table changes are additive: a "rename" adds a column and orphans the old one,
  and every write site must be renamed too.
- A manifest with no `app_type:` clears the channel's app type on install.

## Scope

**This skill edits apps that exist.** It forks, checks out, publishes and
debugs.

Do not offer to register a new app type yourself. That is a server-side
change with its own review, and improvising it from here produces a bundle
nobody can install. Say what the path is and hand it back.
