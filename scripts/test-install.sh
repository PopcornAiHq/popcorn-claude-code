#!/usr/bin/env bash
set -euo pipefail

# Test harness for popcorn-claude-code plugin installation flow
# Creates an isolated environment, launches Claude Code, and cleans up after.
#
# Usage:
#   ./scripts/test-install.sh            # test plugin install flow
#   ./scripts/test-install.sh --no-cli   # also hides popcorn-cli to test detection/setup flow

NO_CLI=false
TEST_PROJECT=""
TEST_CONFIG=""

for arg in "$@"; do
  case "$arg" in
    --no-cli) NO_CLI=true ;;
  esac
done

cleanup() {
  echo ""
  echo "=== Cleaning up ==="
  rm -rf /tmp/popcorn-plugin-test
  echo "Done."
}
trap cleanup EXIT

# Use fixed paths so --keep dirs get cleaned up on next run
TEST_PROJECT="/tmp/popcorn-plugin-test/project"
TEST_CONFIG="/tmp/popcorn-plugin-test/config"
rm -rf "$TEST_PROJECT" "$TEST_CONFIG"
mkdir -p "$TEST_PROJECT" "$TEST_CONFIG"
git -C "$TEST_PROJECT" init -q

# Add a minimal CLAUDE.md so the session has context
cat > "$TEST_PROJECT/CLAUDE.md" << 'PROJ_MD'
# Plugin Install Test

This is a throwaway project for testing the popcorn-claude-code plugin.

## What to test

1. Install the plugin (see prompt below)
2. Verify the always-on `popcorn` skill loads (check system reminders)
3. Test `/popcorn:pop` and `/popcorn:messages` slash commands
4. Verify CLI install prompt triggers on first use
PROJ_MD

BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

echo ""
echo -e "${DIM}Project dir: $TEST_PROJECT${RESET}"
echo -e "${DIM}Config dir:  $TEST_CONFIG${RESET}"
if [ "$NO_CLI" = true ]; then
  echo -e "${DIM}CLI:         hidden from PATH${RESET}"
fi
echo ""
echo -e "${BOLD}▶ Step 1: Install the plugin${RESET}"
echo ""
echo "    /plugin marketplace add PopcornAiHq/popcorn-claude-code"
echo "    /plugin install popcorn@popcorn"
echo ""
echo -e "${BOLD}▶ Step 2: Verify${RESET}"
echo ""
echo "    - Does the popcorn skill appear in system reminders?"
echo "    - Does /popcorn:pop load?"
echo "    - Does /popcorn:messages load?"
echo ""
echo -e "${DIM}Exit Claude Code to trigger cleanup.${RESET}"
echo ""

cd "$TEST_PROJECT"
if [ "$NO_CLI" = true ]; then
  # Replace the directory containing popcorn with a copy that excludes it
  POPCORN_BIN=$(which popcorn 2>/dev/null || true)
  if [ -n "$POPCORN_BIN" ]; then
    POPCORN_DIR=$(dirname "$POPCORN_BIN")
    SHADOW_BIN=$(mktemp -d -t shadow-bin-XXXX)
    for bin in "$POPCORN_DIR"/*; do
      name=$(basename "$bin")
      [ "$name" = "popcorn" ] && continue
      ln -s "$bin" "$SHADOW_BIN/$name"
    done
    CLEAN_PATH=$(echo "$PATH" | tr ':' '\n' | sed "s|^${POPCORN_DIR}$|${SHADOW_BIN}|" | tr '\n' ':' | sed 's/:$//')
    PATH="$CLEAN_PATH" CLAUDE_CONFIG_DIR="$TEST_CONFIG" claude
    rm -rf "$SHADOW_BIN"
  else
    echo "popcorn not found in PATH — --no-cli has no effect"
    CLAUDE_CONFIG_DIR="$TEST_CONFIG" claude
  fi
else
  CLAUDE_CONFIG_DIR="$TEST_CONFIG" claude
fi
