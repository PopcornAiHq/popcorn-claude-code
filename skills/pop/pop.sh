#!/usr/bin/env bash
set -euo pipefail

# pop.sh — Publish local project files to a Popcorn app channel.
# Wraps `popcorn --json deploy push` — the CLI handles tarball, upload, and
# deploy internally. Outputs JSON result on the last line.
#
# Usage: pop.sh [--channel NAME] [--context "description"]

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

_die() {
  echo -e "${RED}Error: $1${RESET}" >&2
  python3 -c "import json,sys; print(json.dumps({'error':sys.argv[1],'detail':sys.argv[2]}))" "$2" "$1"
  exit 1
}

# --- Check dependencies ---

if ! command -v python3 &>/dev/null; then
  echo '{"error":"missing_dependency","detail":"python3 not found"}' >&2
  exit 1
fi

if ! command -v popcorn &>/dev/null; then
  _die "popcorn CLI not found. Run setup first." "cli_not_found"
fi

if ! popcorn whoami &>/dev/null; then
  _die "not authenticated. Run: popcorn auth login" "not_authenticated"
fi

# --- Parse arguments ---

CHANNEL=""
CONTEXT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --channel)
      [[ $# -lt 2 ]] && _die "--channel requires a value" "invalid_args"
      CHANNEL="$2"; shift 2 ;;
    --context)
      [[ $# -lt 2 ]] && _die "--context requires a value" "invalid_args"
      CONTEXT="$2"; shift 2 ;;
    *)
      # Treat first positional arg as channel name
      if [ -z "$CHANNEL" ]; then
        CHANNEL="$1"
      else
        _die "unknown argument: $1" "invalid_args"
      fi
      shift ;;
  esac
done

# --- Determine site name ---

LOCAL_JSON=".popcorn.local.json"

if [ -z "$CHANNEL" ] && [ -f "$LOCAL_JSON" ]; then
  CHANNEL=$(python3 -c "import json; print(json.load(open('$LOCAL_JSON')).get('site_name',''))" 2>&1) || \
    _die "failed to parse $LOCAL_JSON" "config_parse_failed"
fi

if [ -z "$CHANNEL" ]; then
  CHANNEL="pop-$(basename "$(pwd)")"
fi

echo -e "${DIM}Site: $CHANNEL${RESET}"

# --- Build CLI command ---

CMD=(popcorn --json deploy push --channel "$CHANNEL")
if [ -n "$CONTEXT" ]; then
  CMD+=(--context "$CONTEXT")
fi

# --- Run deploy ---

echo -e "${BOLD}Publishing...${RESET}"

if RESULT=$("${CMD[@]}" 2>&1); then
  # CLI may emit progress text before JSON; extract only the last line
  RESULT_LINE=$(echo "$RESULT" | tail -1)

  if ! PARSED=$(echo "$RESULT_LINE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('version','?'))
print(d.get('site_name',''))
print(d.get('conversation_id',''))
" 2>&1); then
    echo -e "${RED}Warning: could not parse deploy result${RESET}" >&2
    echo -e "${DIM}Raw output: $RESULT_LINE${RESET}" >&2
    echo "$RESULT_LINE"
    exit 0
  fi

  VERSION=$(echo "$PARSED" | sed -n '1p')
  SITE=$(echo "$PARSED" | sed -n '2p')
  CONV_ID=$(echo "$PARSED" | sed -n '3p')
  [ -z "$SITE" ] && SITE="$CHANNEL"

  # Persist local state for returning deploys
  if [ -n "$CONV_ID" ] && [ -n "$SITE" ]; then
    python3 -c "
import json
json.dump({'conversation_id':'$CONV_ID','site_name':'$SITE'}, open('$LOCAL_JSON','w'), indent=2)
print()
" 2>/dev/null || true
    # Add to .gitignore if needed
    grep -q '\.popcorn\.local\.json' .gitignore 2>/dev/null || echo '.popcorn.local.json' >> .gitignore
  fi

  echo -e "${GREEN}${BOLD}Published to #${SITE} (v${VERSION})${RESET}"
  echo "$RESULT_LINE"
else
  EXIT_CODE=$?
  LAST_LINE=$(echo "$RESULT" | tail -1)

  # Check if last line is valid JSON; if so, pass through
  if echo "$LAST_LINE" | python3 -c "import sys,json; json.load(sys.stdin)" &>/dev/null; then
    echo -e "${RED}Deploy failed${RESET}" >&2
    echo "$LAST_LINE"
  else
    echo -e "${RED}Deploy failed${RESET}" >&2
    echo "$RESULT" >&2
    python3 -c "import json,sys; print(json.dumps({'error':'deploy_failed','detail':sys.argv[1]}))" \
      "$(echo "$RESULT" | tail -1)"
  fi
  exit "$EXIT_CODE"
fi
