# CLAUDE.md — popcorn-claude-code

Popcorn plugin for Claude Code — read channels and change what they track.

## This repository is public

`PopcornAiHq/popcorn-claude-code` is public, and it ships to a marketplace —
every reader of this tree is outside Popcorn. Internal-only references must not
be written here: issue-tracker ids (in tracked files — see below), the private
sibling repos by name, symbols and deploy topology from the private backend,
real workspace or channel ids, and employee email addresses.

**Cite behaviour, never the thing that proves it.** "Creating a new app type is
a server-side change with its own review" belongs here; the backend symbol it is
registered in and the internal tool it is released from do not. A sentence that
needs the citation to make sense is under-written — say the thing.

Ids in examples are placeholders, never copied from a live system:
`<conversation-id>`, `<workspace-id>`, `my-workspace`, `#my-app`.

This cuts directly against the conventions of the private repos next door, which
encourage citing `KEW-NNNN`, PR numbers and source paths as durable references in
code and docs. That is correct there. Do not carry it across a `cd`. `popcorn-cli` is the one
sibling that is itself public, so a link into it resolves for a reader and is
fine.

`dev/check-public-repo.sh` enforces the mechanical part, as a pre-commit hook,
as its own CI job, and as `make check`. It catches an id, a repo name or a
symbol; it cannot catch a paragraph that describes internal architecture, so the
judgement above is still yours.

**Ticket ids may go in commit messages and pull requests.** A Linear id is
allowed in a commit message, a PR title or description, and a branch name —
that is what Linear's GitHub integration reads to link and close the issue,
and a bare id discloses nothing the change itself does not. Every other
category above still applies there. To close the issue when the PR merges, put
a closing magic word and the id in the **PR description** — `Fixes KEW-NNNN`
(`closes`, `resolves`, `completes`, `implements` work too); `Part of KEW-NNNN`
or `Refs KEW-NNNN` links without closing. The script scans tracked files only,
so it neither blocks nor checks messages.

**Audit with `git ls-files`, not `ls`, `grep -r` or `find`.** Those walk
gitignored scratch (`docs/` is ignored here) and over-report, in the direction
that manufactures false alarms.

Removing something from `HEAD` does not unpublish it. Commit messages and merged
diffs are already public — this repo's history carries tracker ids and internal
names that the scrub could not reach. The check exists to stop the next one, not
to repair the last.

## Structure

```
popcorn-claude-code/
├── skills/
│   ├── popcorn/
│   │   ├── SKILL.md       ← CLI + MCP routing, setup, guardrails (see "not always on")
│   │   └── setup.sh       ← Deterministic setup: CLI install, auth, MCP
│   └── bundle/
│       └── SKILL.md       ← /popcorn:bundle — edit and publish a channel's app bundle
├── .claude-plugin/
│   ├── plugin.json         ← Plugin manifest
│   └── marketplace.json    ← Marketplace listing
├── dev/                        ← Dev-only tooling (not used at runtime)
│   ├── test-install.sh         ← Isolated env for testing plugin install flow
│   ├── check-version-bump.sh   ← Pre-commit hook: warns on missing version bump
│   └── check-public-repo.sh    ← Pre-commit + CI: no internal-only references
├── .github/workflows/ci.yml    ← Runs check-public-repo.sh on push and PR
├── Makefile                    ← make bump v=X.Y.Z, make check
├── .pre-commit-config.yaml     ← version bump reminder + public-repo check
├── CLAUDE.md
├── README.md
└── LICENSE
```

## Skills

**popcorn** (description-triggered, like every other skill):
- Routes agent to CLI (preferred) or MCP tools (fallback)
- Installs CLI and MCP on first use via setup.sh
- Command discovery via `popcorn commands`
- MCP tool reference (whoami, get_channel, post_message, read_messages, search, react)
- Behavioral constraints (quote channels, confirm before sending, JSON envelope parsing)
- Capability boundary: resolve a `#name` against `channel list` / `app list`
  before answering, and read `flow activities` rather than the agent's own tool
  list when deciding whether something is buildable
- Checkout recognition: a directory holding `.popcorn-app.json` is a checked-out
  app bundle, and an edit to a file in it ships nothing until `template check`
  and `app publish` have run. This lives in the `description` because no
  phrasing of the request will name a channel — the signal is the working
  directory, and the marker filename reaches context through tool output

### Invented frontmatter fields do nothing

This plugin carried two frontmatter fields Claude Code does not implement:
`alwaysApply: true` on the popcorn skill and `userTriggered: true` on the four
user-triggered skills that existed then. Both are gone. `alwaysApply` is a **Cursor** convention — it is all over
`.cursor/rules/*.mdc` in other people's repos — and it appears in no Claude Code
documentation and no other skill on any machine we have checked. Borrowing it
here bought nothing and cost a real guarantee.

Claude Code loads skills by progressive disclosure: the `name` and `description`
are in context from the start, the SKILL.md body only once something triggers
it. There is no "apply this always" switch, so **the description is the only
load-bearing surface for anything the agent must know before it decides what to
do.**

Removing `userTriggered` changed nothing at the time, because each of those
skills also stated `USER-TRIGGERED ONLY — never invoke pre-emptively` in its
**description** — prose hoping the model complied. That prose is gone too, in
favour of the real field, `disable-model-invocation: true`.

The rule that survives both changes: if something must hold before the skill is
invoked, it goes in the `description`; anything that only matters once the agent
is already working on Popcorn belongs in the body.

### Why the skill is `bundle` and not `template`

`template` collided four ways inside the skill itself: the `templates/`
subdirectory of Jinja bodies, the prompt templates in `prompts/`, the
`template:` key inside flow YAML, and "channel template" for the whole thing.
It also named the loop after its smallest step — `app fork`, `app checkout` and
`app publish` are three `app` commands against one `template check`.

`bundle` was chosen over `app` because of the flag below. `disable-model-invocation`
keeps the description out of the model's listing entirely, so the name is read
only by a person scanning the slash-command picker. That rules out matching the
CLI's internal vocabulary for its own sake: nobody types `/popcorn:app` and
knows what they will get. The description is the surface that sells the command
to a user, so it leads with the outcome — change what a channel tracks — rather
than with the artifact.

### `disable-model-invocation: true` is real, and it is not prose

On `bundle`, the one user-triggered skill left. Unlike `alwaysApply`, this one is
implemented, and the check that separates the two is worth repeating before
anyone adds a third field: **read it out of the installed binary, not out of a
doc that might describe a different product.** `claude plugin validate --strict`
does not help here — it passes a SKILL.md carrying `alwaysApply` just as happily
as one carrying a real field, so it cannot tell you which is which.

What the runtime actually does with the flag:

- It is in the parser's known-field list, beside `user-invocable`, `when_to_use`
  and `paths`. `alwaysApply` is not, and never was.
- The skill is **filtered out of the listing sent to the model** — the eligibility
  predicate requires `!disableModelInvocation`. So the descriptions of those
  skills no longer reach the model at all, which is what frees listing budget and stops
  them diluting the popcorn skill's triggers. It is also why the `USER-TRIGGERED
  ONLY` prose was removed rather than kept: it addressed a reader that no longer
  sees it, while still being read by users in the slash-command list, where an
  instruction aimed at the model is noise.
- A Skill-tool invocation is refused outright unless the user typed the command
  **this turn**. The refusal is a hard gate, not a preference, and its own message
  tells the model not to replicate the workflow by other means.

That last point cuts wider than "the model won't auto-invoke": a **nested** skill
invocation is also refused, since it is a Skill-tool call the user did not type.
Nothing in this plugin nests `bundle` — the popcorn skill works the bundle
loop in-line rather than routing to a skill — so there is no path to break.
Anything added later that wants to call it from another skill will not be able
to.

The authoring eval runs are the evidence. Across three runs, including
one that checked out and published a bundle, the body of the popcorn skill never
loaded once: `setup.sh` appears in those transcripts only inside the
`/popcorn:bundle` body after that skill was explicitly invoked. Everything
this file described as always-on — setup, routing, the `#channel` quoting rule,
the JSON-envelope rule — was invisible in every run. Adding guidance to that
body changed no behaviour at all; moving the trigger conditions into the
description changed it completely, which is why the description is now long.

**/popcorn:bundle** (slash command, user-triggered):
- Edits a channel's app bundle: manifest (tables/schedules/webhooks), one YAML
  file per flow, `strings.yaml`, and the `prompts/`, `templates/` and `code/`
  subdirectories
- Drives the `app fork` → `checkout` → edit → `template check` → `app publish`
  loop, which needs no backend deploy
- **Scope is editing an app that already exists.** Creating a new `app_type`
  is a server-side change; the skill hands that back rather than improvising a
  bundle nobody can install
- CLI only — the MCP path cannot publish bundles. Requires popcorn-cli ≥ 0.52.0
- **Does not teach the bundle format.** It points at docs.popcorn.ai
  (`llms.txt`, the authoring guides, the concept pages) for layout, manifest
  keys and flow grammar, and keeps only command routing, checks and the
  ask-versus-act rule. A copy of the format here drifted from the platform and
  was wrong in several places, so resist adding one back
- Publishes on its own authority when nothing is reading its output mid-task
  (`claude -p`, `POPCORN_AGENT=1`), reporting blast radius from
  `other_channels_converging` rather than asking permission of nobody. The
  fork-consequence warning still comes first in an interactive session

## Dependencies

This plugin has no code dependencies. It provides skills that guide the agent to use either:
- **popcorn-cli** (auto-installed on first use via uv/pipx/pip) — full-featured CLI, preferred in terminal
- **Popcorn MCP server** (`https://mcp.popcorn.ai/mcp`) — always installed, enables conversational features

## Versioning

**Bump the version with every set of changes.** Both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must stay in sync.

- **Patch** (0.7.0 → 0.7.1): default for any change
- **Minor** (0.7.x → 0.8.0): notable feature additions
- **Major** (0.x → 1.x): only when explicitly requested

### Workflow

Which workflow applies depends on how the change reaches `main`.

**Direct push to `main`** — the bump is its own commit, and `make bump` does it:

1. Commit your changes first (do NOT include the version bump in the same commit).
   The pre-commit hook will warn that the version wasn't bumped — that's the
   reminder working, not an error. It warns; it never blocks.
2. `make bump v=X.Y.Z` — rewrites both files, commits `chore: bump version to
   X.Y.Z`, and tags `vX.Y.Z`
3. `git push && git push --tags`

**Via a pull request** — the bump rides in the same commit as the change, and
`make bump` is the wrong tool. This repo squash-merges, so a separate bump
commit gets collapsed into the feature commit regardless, and `make bump`'s tag
would be left pointing at a pre-squash commit that never lands on `main`.
Instead:

1. Edit `"version"` in both `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json` by hand, and stage them alongside your
   change. Staged together, the pre-commit hook is satisfied — it compares the
   staged source set against the staged version files, not commit counts.
2. After the squash lands on `main`, tag it for history:
   `git tag vX.Y.Z && git push --tags`

## Releasing

**What ships is `main`, not the tag.** `marketplace.json` declares
`"source": "./"`, so the plugin resolves from this repo at its default branch —
the `version` fields in the two `.claude-plugin/*.json` files on `main` are the
release. Tags are a human-readable history marker; a missing tag doesn't block
a release, and a tag alone doesn't make one.

The failure that actually bites is the two files drifting out of sync, since
each is bumped separately.
