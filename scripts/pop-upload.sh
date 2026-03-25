#!/usr/bin/env bash
set -euo pipefail

# Upload project files to Popcorn via presigned S3 URL.
# Designed for AI agent usage — structured JSON input/output.
#
# Usage: bash pop-upload.sh <config_file>
#
# Config file (JSON):
#   {
#     "upload_url": "https://s3.amazonaws.com/...",
#     "upload_fields": { "key": "...", "Content-Type": "...", ... },
#     "project_dir": "/path/to/project"   (optional, defaults to cwd)
#   }
#
# Output (stdout): {"ok": true, "size_bytes": 12345}
# Errors (stderr): descriptive message
# Exit: 0 success, 1 failure

json_ok()    { printf '{"ok":true,"size_bytes":%d}\n' "$1"; }
json_fail()  { printf '{"ok":false,"error":"%s"}\n' "$1" >&2; exit 1; }

# --- Validate inputs ---

CONFIG="${1:-}"
[ -z "$CONFIG" ] && json_fail "Usage: pop-upload.sh <config_file>"
[ -f "$CONFIG" ] || json_fail "Config file not found: $CONFIG"

command -v jq  &>/dev/null || json_fail "jq is required but not installed"
command -v curl &>/dev/null || json_fail "curl is required but not installed"
command -v tar  &>/dev/null || json_fail "tar is required but not installed"

UPLOAD_URL=$(jq -r '.upload_url // empty' "$CONFIG")
[ -z "$UPLOAD_URL" ] && json_fail "upload_url missing from config"

PROJECT_DIR=$(jq -r '.project_dir // empty' "$CONFIG")
[ -z "$PROJECT_DIR" ] && PROJECT_DIR="$(pwd)"
[ -d "$PROJECT_DIR" ] || json_fail "Project directory not found: $PROJECT_DIR"

# --- Create tarball ---

TARBALL=$(mktemp /tmp/popcorn-upload-XXXXXX.tar.gz)
cleanup() { rm -f "$TARBALL"; }
trap cleanup EXIT

cd "$PROJECT_DIR"

if git rev-parse --git-dir &>/dev/null; then
  # Git repo: use git ls-files (respects .gitignore)
  git ls-files -z | tar czf "$TARBALL" --null -T -
else
  # Non-git: tar with sensible excludes
  tar czf "$TARBALL" \
    --exclude=node_modules \
    --exclude=.git \
    --exclude=.env \
    --exclude='.env.*' \
    --exclude=__pycache__ \
    --exclude=.DS_Store \
    --exclude='*.pyc' \
    --exclude=.next \
    --exclude=dist \
    --exclude=build \
    .
fi

SIZE=$(wc -c < "$TARBALL" | tr -d ' ')

# --- Upload via presigned POST ---

CURL_ARGS=(-s --fail-with-body -X POST)

# Build -F args from upload_fields
while IFS='=' read -r key value; do
  CURL_ARGS+=(-F "$key=$value")
done < <(jq -r '.upload_fields | to_entries[] | "\(.key)=\(.value)"' "$CONFIG")

CURL_ARGS+=(-F "file=@$TARBALL")
CURL_ARGS+=("$UPLOAD_URL")

if ! RESPONSE=$(curl "${CURL_ARGS[@]}" 2>&1); then
  json_fail "Upload failed: $RESPONSE"
fi

json_ok "$SIZE"
