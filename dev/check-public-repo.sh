#!/bin/sh
# Pre-commit hook and CI check: this repository is PUBLIC.
#
# Internal-only references must not land in it — issue-tracker ids, the names of
# the private sibling repos, symbols and topology from the private backend, and
# real record ids. A scrub removed the ones that had accumulated; nothing but
# memory was holding that in place, and the private sibling repos' own
# conventions actively encourage writing them, so an engineer or agent moving
# between checkouts reintroduces them while believing they are following house
# style. This fails instead of remembering. The rule, and what to write instead,
# is in CLAUDE.md ("This repository is public").
#
# Scans the INDEX (`git grep --cached`), which is both what a commit is about to
# contain and, in a CI checkout, the whole tracked tree — so the hook and the CI
# job are one command with one scope. Scanning the index rather than only the
# staged paths is deliberate: a hook that sees a single file cannot tell you the
# tree already contains a violation.
#
# Usage: dev/check-public-repo.sh   (no arguments, in either context)

set -eu

# Skip this file: it necessarily contains the patterns it searches for.
self=':(exclude)dev/check-public-repo.sh'

# Each line is "<what it is>|<extended regex>". Only the first "|" separates
# them, so a regex may contain alternations. Deliberately narrow — a pattern
# that cries wolf gets switched off, which is worse than one that misses.
#
# The repo-name pattern must not fire on `popcorn-cli`, which is public and
# referenced throughout the skills as an install source and a docs URL.
#
# Every uuid is banned outright rather than exempting a synthetic shape: unlike
# the CLI repo, nothing here has fixtures, and the skills already write ids as
# `<conversation-id>`-style placeholders. A uuid in this tree is a real one.
found=0

while IFS='|' read -r label regex; do
    [ -n "$label" ] || continue

    set +e
    hits=$(git grep --cached -nIE -e "$regex" -- "$self")
    status=$?
    set -e

    case "$status" in
        0)
            found=1
            echo ""
            echo "✖  $label in a public repo:"
            printf '%s\n' "$hits" | sed 's/^/     /'
            ;;
        1) ;;  # no match — the success case
        *)
            echo "✖  git grep failed (exit $status) scanning for $label" >&2
            exit "$status"
            ;;
    esac
done <<'PATTERNS'
issue-tracker id|KEW-[0-9]+
private repo name|popcorn-(backend|client)|plugin-evals
private backend symbol|CHANNEL_TEMPLATES
internal deploy topology|[Ii]ntranet
backend source path|(^|[^/[:alnum:]_.-])(lib|services)/[a-z_]+/[a-z_/]*\.py
real record id|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}
PATTERNS

if [ "$found" -eq 1 ]; then
    cat <<'MSG'

   This repository is public, and every reader of it is outside Popcorn. Cite
   behaviour ("a new app type is registered server-side"), never the ticket,
   private repo or internal symbol that proves it. Write ids as placeholders:
   <conversation-id>, <workspace-id>.

   See CLAUDE.md — "This repository is public".
MSG
    exit 1
fi
