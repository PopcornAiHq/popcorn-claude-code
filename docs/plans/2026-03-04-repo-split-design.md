# Repo Split Design: popcorn-cli + popcorn-claude-code

**Date:** 2026-03-04
**Status:** Approved

## Context

popcorn-devkit is a monorepo containing the Popcorn CLI, core library, and agent plugin (skills + manifests). The CLI and plugin serve different audiences with different install paths and release cadences. Splitting them improves clarity and keeps the plugin lightweight.

## Decision

Split into two repos:

- **popcorn-cli** — standalone CLI tool, published to PyPI
- **popcorn-claude-code** — Claude Code plugin (skills only)

## popcorn-cli Repo

```
popcorn-cli/
├── src/
│   ├── popcorn_core/            ← Internal: auth, client, config, resolve, operations, errors
│   └── popcorn_cli/             ← CLI: argparse, handlers, formatting
├── tests/
├── pyproject.toml               ← Single package: name=popcorn-cli
├── Makefile                     ← fmt, lint, typecheck, test, check
├── .pre-commit-config.yaml
├── LICENSE
├── README.md
└── CHANGELOG.md
```

### Packaging

- **PyPI name:** `popcorn-cli`
- **Entry point:** `popcorn = "popcorn_cli.cli:main"`
- **Install:** `pip install popcorn-cli` (or `pipx install popcorn-cli`)
- **Dependencies:** `httpx>=0.27`, `pyjwt>=2.0`
- **Build system:** hatchling
- **Python:** >=3.10

### Key changes from current

- `popcorn_core` is an internal package (not a separate PyPI distribution)
- Single `pyproject.toml`, single version, single release
- `bin/popcorn` shell wrapper removed — pip handles PATH
- uv workspace structure removed — flat single-package layout

## popcorn-claude-code Repo

```
popcorn-claude-code/
├── skills/
│   ├── popcorn/
│   │   └── SKILL.md             ← Always-on: setup detection + Popcorn knowledge
│   └── pop/
│       └── SKILL.md             ← Placeholder slash command (coming soon)
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── CLAUDE.md
├── README.md
└── LICENSE
```

### Scope

- **Claude Code only** — no Cursor, Pi, or Codex manifests
- **No Python code** — pure skills and plugin config
- **No build tooling** — no pyproject.toml, Makefile, or pre-commit

### What gets removed from current repo

| Removed | Destination |
|---------|-------------|
| `packages/core/` | popcorn-cli `src/popcorn_core/` |
| `packages/cli/` | popcorn-cli `src/popcorn_cli/` |
| `tests/` | popcorn-cli `tests/` |
| `bin/popcorn` | Replaced by pip entry point |
| `.cursor-plugin/` | Dropped |
| `package.json` | Dropped |
| `pyproject.toml` | Moved to popcorn-cli |
| `Makefile` | Moved to popcorn-cli |
| `.pre-commit-config.yaml` | Moved to popcorn-cli |
| `uv.lock` | Dropped |
| `CONTRIBUTING.md` | Moved to popcorn-cli |

## Skill Design: `popcorn` (always-on)

Single transport-agnostic skill replacing the current `popcorn-cli` skill. Renamed from `popcorn-cli` to `popcorn` since it covers both CLI and MCP usage.

### Frontmatter

```yaml
name: popcorn
description: Popcorn messaging — setup, CLI reference, and best practices
alwaysApply: true
allowed-tools: Bash
```

### Sections

1. **Setup Detection** — agent checks for CLI/MCP on first Popcorn action
2. **CLI Reference** — full command syntax, recipes, patterns
3. **MCP Mode** — brief guidance for MCP transport users
4. **Constraints** — behavioral rules (quote channels, no inbox for files, etc.)

## Setup Flow

```
On first Popcorn-related action:

  which popcorn
    ├─ found → CLI mode, proceed
    └─ not found
         ├─ prior decline in CLAUDE.md / memory?
         │    └─ yes → check MCP, use if available
         └─ no prior decline
              → recommend: pip install popcorn-cli
                   ├─ user accepts → install + popcorn auth login
                   └─ user declines
                        → offer MCP: claude mcp add popcorn \
                             --transport http https://mcp.popcorn.ai/mcp
                        → save preference to agent memory
```

### Key behaviors

- **Always recommend CLI first** — even if MCP is already configured (unless user previously declined)
- **Respect prior decisions** — if user declined CLI and saved to memory/CLAUDE.md, skip straight to MCP
- **Auto-configure MCP** — run `claude mcp add` with user confirmation, don't just print instructions
- **Auth after CLI install** — guide user through `popcorn auth login`

## Skill Design: `pop` (slash command)

Placeholder. Not yet implemented. Skill file exists with `disable-model-invocation: true` and a "coming soon" message.

## Naming Convention

Per [Claude Code plugin marketplace docs](https://code.claude.com/docs/en/plugin-marketplaces), names are kebab-case identifiers. Reserved names include `claude-code-marketplace`, `claude-code-plugins`, etc.

The ecosystem convention is product-descriptive names:

| What | Name |
|------|------|
| GitHub repo | `PopcornAiHq/popcorn-claude-code` |
| Marketplace name (in marketplace.json) | `popcorn` |
| Plugin name (in plugins array) | `popcorn` |
| Install command | `/plugin install popcorn@popcorn` |

The repo name is developer-facing only. Users interact via the marketplace/plugin names.

## Plugin Manifests

### plugin.json

```json
{
  "name": "popcorn",
  "description": "Popcorn messaging integration for Claude Code",
  "version": "0.3.0",
  "author": {
    "name": "Popcorn",
    "email": "support@popcorn.ai"
  },
  "repository": "https://github.com/PopcornAiHq/popcorn-claude-code"
}
```

### marketplace.json

```json
{
  "name": "popcorn",
  "owner": {
    "name": "Popcorn",
    "email": "support@popcorn.ai"
  },
  "plugins": [
    {
      "name": "popcorn",
      "source": "./",
      "description": "Popcorn messaging — read channels, send updates, and publish projects",
      "category": "productivity"
    }
  ]
}
```

## Migration Notes

- Current `popcorn-devkit` GitHub repo becomes `popcorn-claude-code` (rename or new repo)
- New `popcorn-cli` repo created fresh
- Plugin marketplace entry updated to point to new repo URL
- Existing plugin users will need to re-install from new repo (or marketplace handles redirect)
