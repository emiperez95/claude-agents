# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository is a **private workspace** for developing and managing Claude Code plugins (agents, commands, and skills). It combines:

- **Private plugins** (root level): Personal plugins not intended for public distribution
- **Public plugins** (cc-toolkit submodule): Shareable plugins distributed via the Claude Code marketplace

## Repository Structure

```
03-agents/                          # Private workspace (this repo)
├── cc-toolkit/                     # Public submodule → github.com/emiperez95/cc-toolkit
│   ├── agents/*/agents/*.md        # Public agents (nested plugin format)
│   ├── commands/*/commands/*.md    # Public commands (nested plugin format)
│   ├── skills/*/skills/*/SKILL.md  # Public skills (nested plugin format)
│   └── .claude-plugin/marketplace.json
├── agents/                         # Private agents (flat files)
├── commands/                       # Private commands (flat files)
│   └── jira-status.md
├── skills/                         # Private skills (folders with SKILL.md)
├── install-agents.sh               # Installs from both sources
└── uninstall-agents.sh
```

## Plugin Inventory

### Public Plugins (cc-toolkit)
Distributed via `/plugin marketplace add emiperez95/cc-toolkit`

| Type | Name | Description |
|------|------|-------------|
| Agent | atlas-jira-analyst | Fetches Jira issue information |
| Agent | apollo-jira-scribe | Creates and updates Jira tickets |
| Agent | clio-docs-oracle | Reads Google Drive files |
| Agent | heimdall-pr-guardian | Monitors PR status and comments |
| Agent | hermes-pr-courier | Collects PR content and metadata |
| Agent | minerva-notion-oracle | Searches Notion workspaces |
| Command | gemini | Large codebase analysis via Gemini CLI |
| Command | codex | OpenAI Codex CLI with local and cloud execution |
| Command | memory-compact | Compact and reorganize Claude Code memory files |
| Skill | athena-pr-reviewer | Multi-LLM PR reviewer (8 parallel reviewers) |
| Skill | athena-pr-reviewer-lite | Claude-only PR reviewer (6 reviewers) |
| Skill | harvest-timesheet | Automate Harvest timesheet from Google Calendar |

### Private Plugins (root level)
Personal use only, not distributed

| Type | Name | Description |
|------|------|-------------|
| Command | jira-status | Shows Jira board with session indicators |

### External Plugins (managed in other projects)

| Type | Name | Location | Description |
|------|------|----------|-------------|
| Agent | janus-wt-portal | `/Users/emilianoperez/Projects/00-Personal/hive/.claude/agents/` | Proactive worktree management via hive wt |

## Installation and Management

```bash
# Install all plugins (private + public)
./install-agents.sh

# Force reinstall
./install-agents.sh --force

# Uninstall
./uninstall-agents.sh

# Verify installation shows both sources
ls -la ~/.claude/agents/
ls -la ~/.claude/commands/
ls -la ~/.claude/skills/
```

## Working with Submodule

```bash
# Update cc-toolkit to latest
cd cc-toolkit && git pull origin main && cd ..

# Make changes to public plugins
cd cc-toolkit
# ... edit files ...
git add -A && git commit -m "Change description" && git push

# Update parent to track new cc-toolkit commit
cd ..
git add cc-toolkit && git commit -m "Update cc-toolkit submodule"
```

## Promoting/Demoting Plugins

**Promote** (private → public):
```bash
mv agents/my-agent cc-toolkit/agents/
cd cc-toolkit && git add -A && git commit -m "Add my-agent" && git push
cd .. && git add -A && git commit -m "Promoted my-agent to cc-toolkit"
```

**Demote** (public → private):
```bash
mv cc-toolkit/agents/my-agent agents/
cd cc-toolkit && git add -A && git commit -m "Remove my-agent" && git push
cd .. && git add -A && git commit -m "Demoted my-agent to private"
```

## Plugin Architecture

### Plugin Structure
Each plugin follows this format:

```
<type>/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
└── <type>/
    └── <name>.md            # Definition (or SKILL.md in folder for skills)
```

### Agent Definition Format
- **Frontmatter**: YAML with name, description, tools, model
- **Description**: Must include "PROACTIVELY USED" for auto-triggering
- **Prompt**: Data collection instructions
- **Output**: LLM-optimized structured text

### Key Design Principles
1. **Pure Information Gathering**: Agents collect data without analysis
2. **Proactive Triggering**: Activate on keyword mentions
3. **Model Optimization**: Sonnet for cost efficiency, Opus for orchestration

## Agent Capabilities

### Public Agents (cc-toolkit)

**Atlas Jira Analyst** - Extracts Jira issue IDs from branches, fetches comprehensive context including epic details

**Apollo Jira Scribe** - Creates tickets, transitions states, moves to sprints

**Heimdall PR Guardian** - Monitors PR status, fetches comments (general, code review, summaries)

**Hermes PR Courier** - Collects PR content, categorizes files, calculates size

**Minerva Notion Oracle** - Searches Notion workspaces via MCP tools

**Clio Docs Oracle** - Reads Google Drive files via rclone CLI

### Private Agents

### Skills

**Athena PR Reviewer** - Orchestrates 8 parallel reviewers (Gemini + Codex + 6 Claude specialists)

**Athena PR Reviewer Lite** - 6 Claude specialists only, no external dependencies

**Key Features:**
- Annotated diff with explicit line numbers for accurate references
- Verification step to filter hallucinated findings
- Rejected findings saved to `rejected.md` for manual review

> **Sync Guidance**: When modifying athena-pr-reviewer, reflect applicable changes to athena-pr-reviewer-lite. The lite version excludes Gemini and Codex reviewers but shares the same Claude reviewer prompts and orchestration logic.

**Harvest Timesheet** - Automates monthly Harvest timesheet from Google Calendar meetings

**Key Features:**
- Reads Google Calendar meetings via Chrome DevTools MCP
- Categorizes meetings (project, other, ignored) with growing memory
- Fills Harvest weekly grid with calculated hours
- Config + learned categorizations stored in `~/.claude/harvest-timesheet.local.md`
- Handles login detection for both Google Calendar and Harvest

## CLI Reference

### GitHub CLI (PR agents)
```bash
gh api repos/:owner/:repo/pulls/[PR]/comments  # Code review comments
gh pr view [PR] --comments                      # General comments
gh pr view [PR] --json reviews,latestReviews   # Review summaries
```

### Atlassian CLI (Jira agents)
```bash
acli jira workitem view ISSUE-123 --fields *all --json
acli jira workitem create --summary "Title" --project "PROJ" --type "Story" --json
acli jira workitem transition --key "PROJ-123" --status "In Progress" --json
```

### rclone (Drive agent)
```bash
rclone config                                  # Setup: name 'gdrive', scope read-only
rclone backend copyid gdrive: {FILE_ID} /tmp/  # Download
```

### Gemini CLI
```bash
gemini -p "@src/ Analyze architecture"         # @ includes files/dirs
```

### Codex CLI
```bash
codex exec "Your prompt here"                  # Local execution
codex exec --full-auto "Fix lint errors"       # Skip approvals
codex cloud exec --env ENV --attempts 3 "msg"  # Parallel cloud execution
```

## Testing Triggers

After `./install-agents.sh --force`, restart terminal and test:

- "Check PR comments" → heimdall-pr-guardian
- "Get context for PROJ-123" → atlas-jira-analyst
- "Create a ticket" → apollo-jira-scribe
- "Review PR #789" → athena-pr-reviewer skill
- "Find API docs in Notion" → minerva-notion-oracle
- "Read this Google Doc" → clio-docs-oracle
- "/gemini @src/ overview" → gemini command
- "/codex review this approach" → codex command
- "/harvest-timesheet" or "fill my timesheet" → harvest-timesheet skill
- "/memory-compact" → memory-compact command

## Requirements

```bash
# Required
gh auth status                    # GitHub CLI
acli jira auth status            # Atlassian CLI

# Optional (for specific plugins)
rclone listremotes               # Should show gdrive:
gemini --version                 # Gemini CLI
codex --version                  # Codex CLI
```
