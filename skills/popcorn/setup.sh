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
  echo -e "${YELLOW}Installing popcorn-cli...${RESET}"
  if uv tool install git+https://github.com/PopcornAiHq/popcorn-cli.git 2>&1; then
    CLI=true
    CHANGED=true
    echo -e "${GREEN}CLI: installed${RESET}"
  else
    echo -e "CLI: install failed — install manually: uv tool install git+https://github.com/PopcornAiHq/popcorn-cli.git"
  fi
fi

# Step 2: Auth (only if CLI available)
if [ "$CLI" = true ]; then
  # Refresh PATH in case CLI was just installed
  export PATH="$HOME/.local/bin:$PATH"

  if popcorn whoami &>/dev/null; then
    AUTH=true
    echo -e "${DIM}Auth: logged in${RESET}"
  else
    echo -e "${BOLD}Opening browser for Popcorn login...${RESET}"
    if popcorn auth login; then
      AUTH=true
      CHANGED=true
      echo -e "${GREEN}Auth: logged in${RESET}"
    else
      echo -e "Auth: login failed — run manually: popcorn auth login"
    fi
  fi
fi

# Step 3: MCP
MCP_FILE="$HOME/.claude.json"
if [ -f "$MCP_FILE" ] && grep -q '"popcorn"' "$MCP_FILE" 2>/dev/null; then
  MCP=true
  echo -e "${DIM}MCP: configured${RESET}"
else
  echo -e "${YELLOW}Adding Popcorn MCP server...${RESET}"
  if claude mcp add popcorn --transport http https://mcp.popcorn.ai/mcp 2>&1; then
    MCP=true
    CHANGED=true
    echo -e "${GREEN}MCP: added (restart Claude Code to activate)${RESET}"
  else
    echo -e "MCP: failed — run manually: claude mcp add popcorn --transport http https://mcp.popcorn.ai/mcp"
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
