#!/bin/sh
# Pre-commit hook: warn if files that ship to users are staged but the version
# wasn't bumped.
#
# The marketplace serves this whole repo, and a version bump is what pushes an
# update to every installed copy. The paths excluded below are read only by
# people working on the repo, so changing them alone ships nothing and needs no
# bump. Everything else counts as shipped, so a new directory the runtime loads
# (hooks/, agents/, ...) needs a bump without anyone remembering to add it here.

staged_source=$(git diff --cached --name-only -- . \
    ':(exclude)CLAUDE.md' \
    ':(exclude)dev/' \
    ':(exclude).github/' \
    ':(exclude).pre-commit-config.yaml' \
    ':(exclude)Makefile' \
    ':(exclude).gitignore')
staged_version=$(git diff --cached --name-only -- '.claude-plugin/plugin.json' '.claude-plugin/marketplace.json')

if [ -n "$staged_source" ] && [ -z "$staged_version" ]; then
    echo ""
    echo "⚠  Files that ship to users changed but version was not bumped:"
    echo "$staged_source" | sed 's/^/     /'
    echo "   Did you forget?  (see Versioning in CLAUDE.md)"
    echo ""
fi
