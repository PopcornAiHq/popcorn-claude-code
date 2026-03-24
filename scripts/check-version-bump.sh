#!/bin/sh
# Pre-commit hook: warn if source files are staged but version wasn't bumped.

staged_source=$(git diff --cached --name-only -- 'skills/' 'README.md' 'CLAUDE.md')
staged_version=$(git diff --cached --name-only -- '.claude-plugin/plugin.json' '.claude-plugin/marketplace.json')

if [ -n "$staged_source" ] && [ -z "$staged_version" ]; then
    echo ""
    echo "⚠  Source files changed but version was not bumped."
    echo "   Did you forget?  (make bump v=X.Y.Z)"
    echo ""
fi
