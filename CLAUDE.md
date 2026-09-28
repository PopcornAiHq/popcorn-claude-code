# CLAUDE.md — popcorn-claude-code

Popcorn plugin for Claude Code: the `popcorn` skill (description-triggered) and
`/popcorn:bundle` (user-triggered). `README.md` covers install and what each does.

## This repository is public

`PopcornAiHq/popcorn-claude-code` is public and ships to a marketplace, so every
reader of this tree is outside Popcorn. Don't write internal-only references
here: issue-tracker ids (in tracked files — see below), the private sibling
repos by name, symbols and deploy topology from the private backend, real
workspace or channel ids, and employee email addresses.

Cite behaviour, not the thing that proves it. "Creating a new app type is a
server-side change with its own review" belongs here; the backend symbol it is
registered in does not. A sentence that needs the citation to make sense is
under-written — say the thing. Ids in examples are placeholders:
`<conversation-id>`, `<workspace-id>`, `my-workspace`, `#my-app`.

This is the opposite of the private repos next door, which cite `KEW-NNNN`, PR
numbers and source paths as durable references. Don't carry that habit across a
`cd`. `popcorn-cli` is itself public, so linking into it is fine.

`dev/check-public-repo.sh` enforces the mechanical part (pre-commit hook, CI job,
`make check`). It catches an id, a repo name or a symbol; it can't catch a
paragraph describing internal architecture, so that judgement is still yours.

Ticket ids may go in commit messages, PR titles and descriptions, and branch
names — Linear's GitHub integration reads them there, and a bare id discloses
nothing the change doesn't. Every other category above still applies. To close
the issue on merge, put `Fixes KEW-NNNN` (or `closes`/`resolves`) in the PR
description; `Refs KEW-NNNN` links without closing. The script scans tracked
files only, so it neither blocks nor checks messages.

Audit with `git ls-files`, not `ls`, `grep -r` or `find` — those walk gitignored
scratch (`docs/` is ignored here) and manufacture false alarms.

Removing something from `HEAD` doesn't unpublish it. History already carries
tracker ids and internal names the scrub couldn't reach; the check stops the
next one, it doesn't repair the last.

## Skill frontmatter: what is load-bearing

Claude Code shows the model each skill's `name` and `description` up front and
loads the body only once the skill triggers. So anything that must hold before
the agent decides what to do goes in the `description`; the body only reaches an
agent already working on Popcorn. Authoring evals showed it: across three runs, the
popcorn skill's body never loaded once, and guidance added there changed nothing
until the trigger conditions moved into the description — which is why that
description is long.

Only use frontmatter fields the runtime implements, and check a new one against
the installed binary rather than a doc that may describe another product. This
plugin once carried `alwaysApply: true` (a Cursor convention) and
`userTriggered: true`; neither does anything in Claude Code. `claude plugin
validate --strict` won't catch this — it passes invented fields and invalid
YAML (as of 2026-09-28, CC 2.1.284) — so parse the frontmatter yourself.

`disable-model-invocation: true` on `bundle` is real, with two consequences:

- The skill is left out of the model's skill listing, so its description is
  read only by people in the slash-command picker. Write it for them, leading
  with the outcome; don't put instructions to the model in it.
- A Skill-tool call is refused unless the user typed the command that turn —
  including a call from another skill. That's why the popcorn skill runs the
  bundle loop in-line and carries a condensed copy of the non-interactive
  publish rule from `skills/bundle/SKILL.md`. Change both copies together.

The skill is `bundle`, not `template`, because "template" already meant four
things inside it (the `templates/` dir, prompt templates, the flow `template:`
key, "channel template"). Not `app`, because nobody types `/popcorn:app` and
knows what they'll get.

`skills/bundle/SKILL.md` deliberately doesn't teach the bundle format — it
points at docs.popcorn.ai. An earlier in-repo copy drifted from the platform and
was wrong in several places, so don't add one back.

## Versioning

Bump `"version"` in both `.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` with every set of changes, and keep them in
sync — drift between the two is the failure that actually bites. Patch by
default, minor for notable features, major only when asked.

How to bump depends on how the change reaches `main`:

- **Via a PR** (this repo squash-merges): edit both version fields by hand and
  commit them with the change. Don't use `make bump` — its separate commit gets
  squashed away and its tag points at a commit that never lands on `main`.
  After the squash lands, tag it: `git tag vX.Y.Z <sha> && git push --tags`.
- **Direct push to `main`**: commit the change first, then `make bump v=X.Y.Z`,
  which rewrites both files, commits `chore: bump version to X.Y.Z` and tags
  `vX.Y.Z`. Then `git push && git push --tags`.

`dev/check-version-bump.sh` (pre-commit) warns, never blocks, when `skills/`,
`README.md` or `CLAUDE.md` is staged without the version files.

## Releasing

What ships is `main`, not a tag. `marketplace.json` declares `"source": "./"`,
so users get this repo's default branch, and the version fields on `main` are
the release.

Tags still matter: the eval harness clones the plugin by tag, so an untagged
release can't be evaluated until someone backfills the tag. Tag every version
that lands on `main`.
