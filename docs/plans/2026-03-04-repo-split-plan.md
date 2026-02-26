# Repo Split Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split popcorn-devkit into two repos: `popcorn-cli` (PyPI package) and `popcorn-claude-code` (Claude Code plugin).

**Architecture:** Create a new `popcorn-cli` repo with flat single-package layout (no workspace). Transform this repo into a lightweight Claude Code plugin with skills only.

**Tech Stack:** Python 3.10+, hatchling, PyPI, Claude Code plugin system

**Design doc:** `docs/plans/2026-03-04-repo-split-design.md`

---

## Phase 1: Create popcorn-cli Repo

### Task 1: Initialize the popcorn-cli repo

**Files:**
- Create: `../popcorn-cli/` (new repo, sibling directory)

**Step 1: Create the repo and initialize git**

```bash
mkdir -p ../popcorn-cli
cd ../popcorn-cli
git init
```

**Step 2: Create .gitignore**

Copy from current repo:

```
__pycache__/
*.py[cod]
*.egg-info/
dist/
build/
.eggs/
*.egg
.venv/
node_modules/
.mypy_cache/
.ruff_cache/
.pytest_cache/
.coverage
htmlcov/
.worktrees/
```

**Step 3: Create LICENSE**

Copy `LICENSE` from `popcorn-devkit/LICENSE` (MIT, Copyright 2025 Popcorn).

**Step 4: Commit**

```bash
git add .gitignore LICENSE
git commit -m "chore: initialize repo"
```

---

### Task 2: Create pyproject.toml for flat single-package

**Files:**
- Create: `../popcorn-cli/pyproject.toml`

**Step 1: Write pyproject.toml**

This merges root workspace config (ruff, pytest, mypy) + core deps + cli metadata into one file. Key changes from current:
- No `[tool.uv.workspace]` or `[tool.uv.sources]`
- `popcorn-core` is no longer a dependency — it's an internal package
- CLI dependencies (`httpx`, `pyjwt`) are listed directly
- `pythonpath` and `mypy_path` point to `src/` (flat layout)
- Hatch builds both `popcorn_core` and `popcorn_cli` from `src/`

```toml
[project]
name = "popcorn-cli"
version = "0.2.0"
description = "Command-line interface for Popcorn messaging"
license = "MIT"
requires-python = ">=3.10"
authors = [{ name = "Popcorn", email = "support@popcorn.ai" }]
keywords = ["popcorn", "messaging", "cli"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Environment :: Console",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Topic :: Communications :: Chat",
]
dependencies = [
    "httpx>=0.27",
    "pyjwt>=2.0",
]

[project.scripts]
popcorn = "popcorn_cli.cli:main"

[project.urls]
Homepage = "https://popcorn.ai"
Repository = "https://github.com/PopcornAiHq/popcorn-cli"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/popcorn_core", "src/popcorn_cli"]

[dependency-groups]
dev = [
    "ruff>=0.9",
    "mypy>=1.11",
    "pytest>=8.0",
    "pytest-cov>=6.0",
    "pre-commit>=4.0",
    "respx>=0.22",
]

# ── Ruff ─────────────────────────────────────────────────────────────
[tool.ruff]
target-version = "py310"
line-length = 100

[tool.ruff.lint]
select = [
    "E",     # pycodestyle errors
    "W",     # pycodestyle warnings
    "F",     # pyflakes
    "I",     # isort
    "UP",    # pyupgrade
    "B",     # flake8-bugbear
    "SIM",   # flake8-simplify
    "N",     # pep8-naming
    "RUF",   # ruff-specific
]
ignore = [
    "E501",   # line length — handled by formatter
    "SIM108", # ternary — not always clearer
    "N802",   # function name lowercase — we have do_GET in HTTP handler
    "UP007",  # X | Y union syntax — keep Optional for 3.10 compat
]

[tool.ruff.lint.isort]
known-first-party = ["popcorn_core", "popcorn_cli"]

# ── Pytest ───────────────────────────────────────────────────────────
[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["src"]
addopts = "-ra -q"

# ── Mypy ─────────────────────────────────────────────────────────────
[tool.mypy]
python_version = "3.10"
warn_return_any = true
warn_unused_configs = true
check_untyped_defs = true
strict_equality = true
mypy_path = ["src"]
```

**Step 2: Commit**

```bash
git add pyproject.toml
git commit -m "feat: add pyproject.toml for flat single-package layout"
```

---

### Task 3: Copy source code into flat layout

**Files:**
- Create: `../popcorn-cli/src/popcorn_core/` (all files from `packages/core/src/popcorn_core/`)
- Create: `../popcorn-cli/src/popcorn_cli/` (all files from `packages/cli/src/popcorn_cli/`)

**Step 1: Copy source files**

```bash
mkdir -p ../popcorn-cli/src
cp -r packages/core/src/popcorn_core ../popcorn-cli/src/
cp -r packages/cli/src/popcorn_cli ../popcorn-cli/src/
```

**Step 2: Remove `__pycache__` directories**

```bash
find ../popcorn-cli/src -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
```

**Step 3: Update popcorn_core `__init__.py`**

The current `__init__.py` uses `importlib.metadata.version("popcorn-core")`. Since `popcorn-core` is no longer a separate package, change it to use `popcorn-cli`:

In `../popcorn-cli/src/popcorn_core/__init__.py`, change:
```python
__version__ = version("popcorn-core")
```
to:
```python
__version__ = version("popcorn-cli")
```

**Step 4: Update popcorn_cli `__init__.py`**

Similarly, if it references `popcorn-cli` already, keep it. Verify it reads:
```python
__version__ = version("popcorn-cli")
```

**Step 5: Commit**

```bash
cd ../popcorn-cli
git add src/
git commit -m "feat: add source code (core + cli) in flat layout"
```

---

### Task 4: Copy tests

**Files:**
- Create: `../popcorn-cli/tests/` (all files from `tests/`)

**Step 1: Copy test files**

```bash
cp -r tests ../popcorn-cli/
rm -rf ../popcorn-cli/tests/__pycache__ 2>/dev/null || true
```

**Step 2: Commit**

```bash
cd ../popcorn-cli
git add tests/
git commit -m "feat: add tests"
```

---

### Task 5: Add Makefile and pre-commit config

**Files:**
- Create: `../popcorn-cli/Makefile`
- Create: `../popcorn-cli/.pre-commit-config.yaml`

**Step 1: Write Makefile**

Adapted from current — remove workspace paths, remove `bump` references to plugin/package.json files, remove `packages/mcp/src` from typecheck:

```makefile
.PHONY: install fmt lint typecheck test check clean

# ── Setup ────────────────────────────────────────────────────────────

install:  ## Install package + dev deps
	uv sync
	uv run pre-commit install

# ── Code quality ─────────────────────────────────────────────────────

fmt:  ## Format code
	uv run ruff format .

lint:  ## Lint code (with auto-fix)
	uv run ruff check --fix .

typecheck:  ## Type-check with mypy
	uv run mypy src/popcorn_core src/popcorn_cli

test:  ## Run tests
	uv run pytest $(if $(p),$(p),tests/)

test-cov:  ## Run tests with coverage
	uv run pytest --cov=popcorn_core --cov=popcorn_cli \
		--cov-report=term-missing tests/

check: lint typecheck test  ## Run all checks (lint + typecheck + test)

# ── Version ──────────────────────────────────────────────────────────

bump:  ## Bump version: make bump v=0.2.0
	@[ "$(v)" ] || { echo "Usage: make bump v=X.Y.Z"; exit 1; }
	@echo "Bumping to $(v) ..."
	@sed -i '' 's/^version = ".*"/version = "$(v)"/' pyproject.toml
	@uv lock -q
	@echo "Done — $(v)"

# ── Cleanup ──────────────────────────────────────────────────────────

clean:  ## Remove caches
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .mypy_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .ruff_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name '*.egg-info' -exec rm -rf {} + 2>/dev/null || true

# ── Help ─────────────────────────────────────────────────────────────

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
```

**Step 2: Copy .pre-commit-config.yaml**

Copy as-is from `popcorn-devkit/.pre-commit-config.yaml`.

**Step 3: Commit**

```bash
cd ../popcorn-cli
git add Makefile .pre-commit-config.yaml
git commit -m "chore: add Makefile and pre-commit config"
```

---

### Task 6: Verify popcorn-cli builds and tests pass

**Step 1: Install dependencies**

```bash
cd ../popcorn-cli
uv sync
```

**Step 2: Run linter**

```bash
uv run ruff check .
```

Expected: PASS (no errors)

**Step 3: Run formatter check**

```bash
uv run ruff format --check .
```

Expected: PASS

**Step 4: Run tests**

```bash
uv run pytest tests/ -v
```

Expected: All tests pass. If any imports fail (e.g., `from popcorn_core import ...`), the flat `src/` layout with `pythonpath = ["src"]` in pyproject.toml should handle it. Fix any import path issues.

**Step 5: Run typecheck**

```bash
uv run mypy src/popcorn_core src/popcorn_cli
```

Expected: PASS (may have same warnings as current repo)

**Step 6: Verify entry point works**

```bash
uv run popcorn --version
uv run popcorn --help
```

Expected: Shows version 0.2.0 and help text.

**Step 7: Commit any fixes**

If any adjustments were needed, commit them:

```bash
git add -A
git commit -m "fix: adjust imports for flat package layout"
```

---

### Task 7: Create README for popcorn-cli

**Files:**
- Create: `../popcorn-cli/README.md`

**Step 1: Write README**

Focus on installation and basic usage. Keep it short — the skill in the plugin handles detailed reference.

```markdown
# popcorn-cli

Command-line interface for [Popcorn](https://popcorn.ai) messaging.

## Install

```bash
pip install popcorn-cli
```

Or with pipx:

```bash
pipx install popcorn-cli
```

## Setup

```bash
popcorn auth login    # Authenticate with Popcorn
popcorn --help        # See all commands
```

## Quick Start

```bash
popcorn read '#general' --limit 5     # Read recent messages
popcorn send '#general' "Hello!"      # Send a message
popcorn inbox --unread                 # Check notifications
popcorn search messages "query"        # Search messages
```

## License

MIT
```

**Step 2: Commit**

```bash
cd ../popcorn-cli
git add README.md
git commit -m "docs: add README"
```

---

## Phase 2: Transform popcorn-devkit into popcorn-claude-code

### Task 8: Rewrite the `popcorn` skill (was `popcorn-cli`)

**Files:**
- Delete: `skills/popcorn-cli/SKILL.md`
- Create: `skills/popcorn/SKILL.md`

This is the biggest content task. The new skill has four sections: setup detection, CLI reference, MCP mode, and constraints.

**Step 1: Create `skills/popcorn/SKILL.md`**

```markdown
---
name: popcorn
description: Popcorn messaging — setup, CLI reference, and best practices
alwaysApply: true
allowed-tools: Bash
---

# Popcorn

## Setup

Before using any Popcorn feature, check if the CLI or MCP server is available.

### Detection

Run this check silently (don't narrate it to the user):

1. Check if the user's CLAUDE.md or agent memory says "skip CLI install" or similar.
   - If yes, skip to **MCP Mode** below.

2. Run `which popcorn` (or `command -v popcorn`).
   - If found → use **CLI mode**. Proceed to CLI Reference below.

3. If CLI not found, ask the user:

> Popcorn CLI is not installed. The CLI gives you full access to channels, messaging, search, and more — all without using context on MCP tool calls.
>
> **Option 1 (recommended):** Install the CLI
> ```bash
> pip install popcorn-cli
> popcorn auth login
> ```
>
> **Option 2:** Use the MCP server instead (lighter setup, fewer features)
>
> Which would you prefer?

4. If the user chooses CLI:
   - Run `pip install popcorn-cli` (with user confirmation)
   - Run `popcorn auth login`
   - Proceed to CLI Reference below.

5. If the user declines CLI:
   - Run `claude mcp add popcorn --transport http https://mcp.popcorn.ai/mcp` (with user confirmation)
   - Save to agent memory: "User prefers MCP over CLI for Popcorn"
   - Proceed to MCP Mode below.

---

## CLI Reference

### Critical Rules

1. **Always use `'#channel-name'`** — quote the `#` to prevent shell glob expansion. The CLI resolves names to UUIDs automatically. Never search for a channel UUID first.
2. **NEVER use `inbox` to find files or messages in a channel.** Always use `popcorn --json read '#channel-name'`. The inbox returns notifications from ALL channels and WILL give you the wrong result.
3. **Run `popcorn --help` first** — do this once per session to see available commands before guessing.

### Global Flags

These go before OR after the subcommand:

```
--json          Raw JSON output (use for parsing)
--version       Print version
--workspace ID  Override workspace
-e, --env NAME  Use a specific profile
--no-color      Disable color output
```

### Recipes

#### Read Messages

```bash
popcorn --json read '#channel-name' --limit 10
popcorn --json read '#channel-name' --thread <message_id>   # thread replies
```

#### Download a File

When asked to download a file from a channel, follow these steps exactly:

```bash
# Step 1: Read the channel (NEVER use inbox)
popcorn --json read '#channel-name' --limit 20 | python3 -c "
import json, sys
for m in json.load(sys.stdin)['messages']:
    for p in m['content']['parts']:
        if p['type'] == 'media':
            print(f\"{p['filename']}  key={p['url']}\")
"

# Step 2: Download using the file key from step 1
popcorn download '<file_key>' -o ./filename.ext
```

#### Send a Message

Always show the user exactly what will be sent and get confirmation before sending.

```bash
popcorn send '#channel-name' "message text"
popcorn send '#channel-name' "see attached" --file ./report.pdf
popcorn send '#channel-name' "reply" --thread <message_id>
echo "long message" | popcorn send '#channel-name'
```

#### Check Inbox

Use `inbox` ONLY for checking notifications — never to find files or read a specific channel.

```bash
popcorn --json inbox --unread
popcorn --json inbox
```

Present notifications grouped by type: direct mentions → replies → reactions. Use `popcorn --json read <conversation_id>` to read full context.

#### Search

```bash
popcorn --json search channels [query]
popcorn --json search dms [query]
popcorn --json search messages "query"
popcorn --json search users [query]
```

#### Channel Management

```bash
popcorn --json info '#channel-name'
popcorn create "channel-name" [--type public_channel|private_channel|dm|group_dm]
popcorn join '#channel-name'
popcorn leave '#channel-name'
popcorn invite '#channel-name' <user_ids>
popcorn kick '#channel-name' <user_id>
popcorn update '#channel-name' --name "new-name" --description "new desc"
popcorn archive '#channel-name' [--undo]
```

#### Reactions and Edits

```bash
popcorn react '#channel-name' <msg_id> <emoji> [--remove]
popcorn edit '#channel-name' <msg_id> "new content"
popcorn delete '#channel-name' <msg_id>
```

#### Escape Hatch

For API endpoints not covered by named commands:

```bash
popcorn api /api/path
popcorn api /api/path -X POST -d '{"key": "value"}'
popcorn api /api/path -p key=value
```

### Message Structure

Messages have `content.parts[]`, each with a `type`:
- **`text`** → `part.text` (markdown string)
- **`media`** → `part.url` (file key for `download`), `part.filename`, `part.mime_type`, `part.size_bytes`

---

## MCP Mode

When using the Popcorn MCP server instead of the CLI:

- Call Popcorn MCP tools directly — they are self-describing.
- The recipes and message formatting guidance in the CLI Reference section above still apply conceptually (e.g., message structure, quoting channel names, not using inbox to find files).
- MCP provides a subset of CLI functionality. If the user needs features only available in the CLI, recommend installing it.

---

## Tips

- **Quote `'#channel'`** in bash — unquoted `#` triggers glob expansion
- **Use `--json` for parsing** — human-readable output is for display only
- Messages use markdown: `**bold**`, `*italic*`, `` `code` ``
- Conversations accept `#channel-name` or UUID — prefer names
```

**Step 2: Delete old skill directory**

```bash
rm -rf skills/popcorn-cli
```

**Step 3: Commit**

```bash
git add skills/
git commit -m "feat: replace popcorn-cli skill with transport-agnostic popcorn skill"
```

---

### Task 9: Update plugin manifests

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Update plugin.json**

```json
{
  "name": "popcorn",
  "description": "Popcorn messaging integration for Claude Code",
  "version": "0.3.0",
  "author": {
    "name": "Popcorn",
    "email": "support@popcorn.ai"
  },
  "repository": "https://github.com/PopcornAiHq/popcorn-claude-code",
  "license": "MIT",
  "keywords": ["messaging", "popcorn", "communication"]
}
```

Changes: bump version to 0.3.0, add email to author, update repository URL.

**Step 2: Update marketplace.json**

```json
{
  "name": "popcorn",
  "owner": {
    "name": "Popcorn",
    "email": "support@popcorn.ai"
  },
  "metadata": {
    "description": "Popcorn messaging integration for Claude Code",
    "version": "0.3.0"
  },
  "plugins": [
    {
      "name": "popcorn",
      "source": "./",
      "description": "Popcorn messaging — read channels, send updates, and publish projects",
      "author": { "name": "Popcorn" },
      "keywords": ["messaging", "popcorn", "communication"],
      "category": "productivity"
    }
  ]
}
```

Changes: bump version to 0.3.0, update description.

**Step 3: Commit**

```bash
git add .claude-plugin/
git commit -m "chore: update plugin manifests for v0.3.0"
```

---

### Task 10: Remove CLI/build artifacts from plugin repo

**Files:**
- Delete: `packages/` (entire directory)
- Delete: `bin/`
- Delete: `tests/`
- Delete: `pyproject.toml`
- Delete: `Makefile`
- Delete: `.pre-commit-config.yaml`
- Delete: `uv.lock`
- Delete: `package.json`
- Delete: `.cursor-plugin/`
- Delete: `CONTRIBUTING.md`

**Step 1: Remove all files that moved to popcorn-cli or are no longer needed**

```bash
rm -rf packages/ bin/ tests/ .cursor-plugin/
rm -f pyproject.toml Makefile .pre-commit-config.yaml uv.lock package.json CONTRIBUTING.md
```

**Step 2: Update .gitignore**

Replace with a minimal version (no Python build artifacts needed):

```
.worktrees/
```

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove CLI, build tooling, and non-Claude-Code manifests"
```

---

### Task 11: Update CLAUDE.md and README

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

**Step 1: Rewrite CLAUDE.md**

Replace entirely. This is now a skills-only plugin repo:

```markdown
# CLAUDE.md — popcorn-claude-code

Popcorn messaging plugin for Claude Code.

## Structure

```
popcorn-claude-code/
├── skills/
│   ├── popcorn/
│   │   └── SKILL.md       ← Always-on: setup detection + CLI reference + MCP fallback
│   └── pop/
│       └── SKILL.md       ← Slash command: publish project (coming soon)
├── .claude-plugin/
│   ├── plugin.json         ← Plugin manifest
│   └── marketplace.json    ← Marketplace listing
├── CLAUDE.md
├── README.md
└── LICENSE
```

## Skills

**popcorn** (alwaysApply: true):
- Detects whether CLI or MCP is available
- Guides users through setup if neither is found (recommends CLI, falls back to MCP)
- Full CLI command reference and recipes
- Behavioral constraints (quote channels, never use inbox for file search, etc.)

**pop** (slash command):
- Placeholder — not yet implemented

## Dependencies

This plugin has no code dependencies. It provides skills that guide the agent to use either:
- **popcorn-cli** (`pip install popcorn-cli`) — full-featured CLI
- **Popcorn MCP server** (`https://mcp.popcorn.ai/mcp`) — lighter alternative

## Releasing

Update version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, then push.
```

**Step 2: Rewrite README.md**

```markdown
# popcorn-claude-code

Popcorn messaging plugin for [Claude Code](https://claude.ai/code).

## Install

In Claude Code:

```
/plugin marketplace add PopcornAiHq/popcorn-claude-code
/plugin install popcorn@popcorn
```

## What's Included

- **popcorn** skill — always-on reference for Popcorn messaging. Detects CLI/MCP availability and guides setup.
- **pop** slash command — publish your project on Popcorn (coming soon).

## CLI vs MCP

This plugin works with either transport:

| | CLI | MCP |
|---|---|---|
| Install | `pip install popcorn-cli` | `claude mcp add popcorn --transport http https://mcp.popcorn.ai/mcp` |
| Features | Full (30+ commands) | Subset |
| Context usage | Minimal (runs in shell) | Higher (MCP tool calls) |
| Recommended | Yes | Fallback |

The plugin will guide you through setup on first use.

## License

MIT
```

**Step 3: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: rewrite CLAUDE.md and README for plugin-only repo"
```

---

## Phase 3: Verify Both Repos

### Task 12: Verify popcorn-cli repo works end-to-end

**Step 1: Run full check suite**

```bash
cd ../popcorn-cli
make check
```

Expected: lint, typecheck, and tests all pass.

**Step 2: Test pip install in a temp venv**

```bash
cd ../popcorn-cli
python3 -m venv /tmp/test-popcorn
/tmp/test-popcorn/bin/pip install .
/tmp/test-popcorn/bin/popcorn --version
/tmp/test-popcorn/bin/popcorn --help
rm -rf /tmp/test-popcorn
```

Expected: Version shows 0.2.0, help shows all commands.

**Step 3: Commit any fixes**

---

### Task 13: Verify plugin repo is clean

**Step 1: Check that only expected files remain**

```bash
cd /path/to/popcorn-claude-code
find . -not -path './.git/*' -not -path './.git' -not -name '.' | sort
```

Expected files:
```
./.claude-plugin/marketplace.json
./.claude-plugin/plugin.json
./.gitignore
./CLAUDE.md
./LICENSE
./README.md
./docs/plans/2026-03-04-repo-split-design.md
./docs/plans/2026-03-04-repo-split-plan.md
./skills/pop/SKILL.md
./skills/popcorn/SKILL.md
```

**Step 2: Validate plugin**

If Claude Code is available:
```
/plugin validate .
```

**Step 3: Test plugin install locally**

```
/plugin marketplace add ./
/plugin install popcorn@popcorn
```

Verify the `popcorn` skill loads and the setup detection section appears in context.
