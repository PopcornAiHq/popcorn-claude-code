#!/usr/bin/env bash
set -euo pipefail

# Popcorn setup — installs CLI, authenticates, and adds MCP server.
# Can be run standalone or invoked by the popcorn skill.
# Outputs JSON status on the last line for machine consumption.

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

CLI=false
AUTH=false
MCP=false
CHANGED=false

# Step 1: CLI
if command -v popcorn &>/dev/null; then
  CLI=true
  echo -e "${DIM}CLI: found at $(command -v popcorn)${RESET}"
else
  REPO="git+https://github.com/PopcornAiHq/popcorn-cli.git"
  echo -e "${YELLOW}Installing popcorn-cli...${RESET}"
  if command -v uv &>/dev/null; then
    uv tool install "$REPO" 2>&1 && CLI=true
  elif command -v pipx &>/dev/null; then
    pipx install "$REPO" 2>&1 && CLI=true
  elif command -v pip &>/dev/null; then
    pip install "$REPO" 2>&1 && CLI=true
  else
    echo -e "No package installer found (tried uv, pipx, pip)."
    echo -e "Install one of them, then run: uv tool install $REPO"
  fi
  if [ "$CLI" = true ]; then
    CHANGED=true
    echo -e "${GREEN}CLI: installed${RESET}"
  fi
fi

# Step 2: Auth + workspace (only if CLI available)
if [ "$CLI" = true ]; then
  # Refresh PATH in case CLI was just installed
  export PATH="$HOME/.local/bin:$PATH"

  if popcorn whoami &>/dev/null; then
    AUTH=true
    echo -e "${DIM}Auth: logged in${RESET}"
  else
    echo -e "${BOLD}Opening browser for Popcorn login...${RESET}"
    if popcorn auth login; then
      CHANGED=true

      if popcorn whoami &>/dev/null; then
        AUTH=true
        echo -e "${GREEN}Auth: logged in${RESET}"
      else
        # Auth token is valid but current workspace is stale/invalid
        echo -e "${YELLOW}Current workspace is invalid — checking available workspaces...${RESET}"
        WS_LIST=$(popcorn workspace list 2>/dev/null || true)
        WS_COUNT=$(echo "$WS_LIST" | grep -c 'id:' || true)

        if [ "$WS_COUNT" -eq 1 ]; then
          WS_ID=$(echo "$WS_LIST" | head -1 | sed 's/.*id: //' | tr -d ') ')
          WS_NAME=$(echo "$WS_LIST" | head -1 | sed 's/ (id:.*//' | sed 's/^[[:space:]]*//')
          echo -e "Switching to workspace: ${BOLD}${WS_NAME}${RESET}"
          if popcorn workspace switch "$WS_ID" &>/dev/null && popcorn whoami &>/dev/null; then
            AUTH=true
            echo -e "${GREEN}Auth: switched to ${WS_NAME}${RESET}"
          else
            echo -e "Could not switch workspace. Run: popcorn workspace switch <id>"
          fi
        elif [ "$WS_COUNT" -gt 1 ]; then
          echo -e "${YELLOW}Multiple workspaces available:${RESET}"
          echo "$WS_LIST"
          echo -e "Switch with: ${BOLD}popcorn workspace switch <id>${RESET}"
        else
          echo -e "No workspaces found. Check your Popcorn account."
        fi
      fi
    else
      echo -e "Auth: login failed — run manually: popcorn auth login"
    fi
  fi
fi

# Step 3: MCP (always, user-scope — CLI handles deploys, MCP enables conversational features)
if claude mcp list 2>/dev/null | grep -q 'popcorn'; then
  MCP=true
  echo -e "${DIM}MCP: configured${RESET}"
else
  echo -e "${YELLOW}Adding Popcorn MCP server (user-scope)...${RESET}"
  if claude mcp add popcorn --transport http --scope user https://mcp.popcorn.ai/mcp 2>&1; then
    MCP=true
    CHANGED=true
    echo -e "${GREEN}MCP: added (restart Claude Code to activate)${RESET}"
  else
    echo -e "MCP: failed — run manually: claude mcp add --scope user popcorn --transport http https://mcp.popcorn.ai/mcp"
  fi
fi

# Step 4: Update check (skip if auto-update is enabled)
PLUGIN_DIR="$HOME/.claude/plugins/marketplaces/popcorn"
AUTO_UPDATE=$(python3 -c "
import json, pathlib
s = json.loads(pathlib.Path(pathlib.Path.home() / '.claude' / 'settings.json').read_text())
print(s.get('extraKnownMarketplaces',{}).get('popcorn',{}).get('autoUpdate', False))
" 2>/dev/null || echo "False")

if [ "$AUTO_UPDATE" != "True" ]; then
  LOCAL_V=$(python3 -c "import json; print(json.load(open('$PLUGIN_DIR/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "")
  REMOTE_V=$(curl -sf --max-time 3 "https://raw.githubusercontent.com/PopcornAiHq/popcorn-claude-code/main/.claude-plugin/plugin.json" | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "")

  if [ -n "$LOCAL_V" ] && [ -n "$REMOTE_V" ] && [ "$LOCAL_V" != "$REMOTE_V" ]; then
    echo -e "${YELLOW}Update available: v${LOCAL_V} → v${REMOTE_V}${RESET}"
    echo -e "${DIM}Enable auto-update: /plugin → Marketplaces → popcorn → Enable auto-update${RESET}"
  fi
fi

# Summary
echo ""
if [ "$CLI" = true ] && [ "$AUTH" = true ] && [ "$MCP" = true ]; then
  if [ "$CHANGED" = true ]; then
    echo -e "${GREEN}${BOLD}Setup complete.${RESET}"
  else
    echo -e "${DIM}Everything already configured.${RESET}"
  fi
else
  echo -e "${YELLOW}${BOLD}Setup incomplete — see errors above.${RESET}"
fi

# Machine-readable output on last line
printf '{"cli":%s,"auth":%s,"mcp":%s}\n' "$CLI" "$AUTH" "$MCP"
