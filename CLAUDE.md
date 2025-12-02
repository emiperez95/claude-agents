# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains seven specialized Claude Code agents and one skill for automating workflows and information gathering from Jira, GitHub, Notion, Google Drive, and local development environments. Most agents are pure information collectors that return structured data without opinions or analysis, plus the Athena PR Reviewer skill for comprehensive multi-LLM code reviews.

It also includes slash commands for extending Claude Code's capabilities with external tools.

## Installation and Management Commands

```bash
# Install agents and commands (creates symbolic links to global Claude directory)
./install-agents.sh

# Force install (overwrites existing agents and commands)
./install-agents.sh --force

# Uninstall agents and commands (removes symbolic links only)
./uninstall-agents.sh

# Verify installation
ls -la ~/.claude/agents/ | grep -E "(atlas|apollo|heimdall|hermes|minerva|hephaestus|clio)"
ls -la ~/.claude/commands/ | grep -E "(gemini|jira-status)"
ls -la ~/.claude/skills/ | grep -E "athena"
```

## Agent Architecture

### Plugin Structure
Each agent, command, and skill is packaged as a separate plugin for selective installation:

```
agents/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
└── agents/
    └── <agent-name>.md      # Agent definition

commands/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json
└── commands/
    └── <command-name>.md

skills/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    └── <skill-name>/
        └── SKILL.md
```

### Agent Structure
Each agent `.md` file follows this format:
- **Frontmatter**: YAML configuration with name, description, tools, model
- **Description field**: Must include "PROACTIVELY USED" for automatic triggering
- **Prompt**: Defines agent personality and data collection instructions
- **Output format**: LLM-optimized structured text (not JSON)

### Key Design Principles
1. **Pure Information Gathering**: Agents collect and structure data without analysis or opinions
2. **Proactive Triggering**: Agents activate automatically on keyword mentions
3. **Comment ID Extraction**: All PR agents must extract comment/review IDs for responding/resolving
4. **Model Optimization**: Using Sonnet model for cost efficiency (Opus for complex orchestration)

### Skill Architecture (Athena)
The Athena PR Reviewer skill uses a different pattern than agents:
1. **Data gathering**: Runs `gather-context.sh` to collect PR, Jira, guidelines, blame, prior comments
2. **Parallel reviews**: Launches 8 reviewers simultaneously:
   - Background bash script runs Gemini + Codex
   - 6 Task tool calls run Claude specialists in parallel
3. **Aggregation**: Combines findings, applies confidence filtering and consensus boosting
4. **Synthesis**: Produces actionable review with prioritized items

Example flow:
```
User: "review PR 123"
  ↓
Claude: Invokes athena-pr-reviewer skill
  ↓
Skill: Runs gather-context.sh (parallel data collection)
  ↓
Skill: Launches 8 parallel reviews (1 bash + 6 Task calls)
  ↓
Claude: Aggregates findings, applies confidence/consensus rules
  ↓
Claude: Outputs actionable review summary
```

### Agent Capabilities

**Atlas Jira Analyst** (`atlas-jira-analyst.md`)
- Extracts Jira issue IDs from git branches
- Fetches comprehensive issue context including epic details
- Returns structured data without analysis
- Read-only Jira operations

**Apollo Jira Scribe** (`apollo-jira-scribe.md`)
- Creates new Jira tickets with specified fields
- Transitions tickets between workflow states (To Do → In Progress → Done)
- Moves tickets to sprints via custom field updates
- Executes write operations and returns confirmation
- Pure execution agent without analysis

**Heimdall PR Guardian** (`heimdall-pr-guardian.md`)  
- Monitors PR status for user's own PRs
- Fetches three types of comments: general, review comments on code, review summaries
- Must use `gh api repos/:owner/:repo/pulls/[PR]/comments` for code review comments
- Extracts comment IDs and review IDs

**Hermes PR Courier** (`hermes-pr-courier.md`)
- Collects PR content for any PR
- Categorizes files by type (frontend/backend/tests/docs)
- Calculates PR size (XS/S/M/L/XL)

**Athena PR Reviewer** (`skills/athena-pr-reviewer/`)
- Multi-LLM skill that orchestrates 8 parallel reviewers
- Uses Gemini + Codex for general review, 6 Claude specialists for focused analysis
- Includes confidence scoring (0-100) and consensus boosting
- Gathers context: PR diff, Jira requirements, CLAUDE.md guidelines, git blame, prior comments

**Minerva Notion Oracle** (`minerva-notion-oracle.md`)
- Searches and retrieves content from Notion workspaces
- Fetches documentation, meeting notes, and project information
- Uses Notion MCP tools for workspace access

**Clio Docs Oracle** (`clio-docs-oracle.md`)
- Reads Google Drive files from shared links
- Exports Google Docs to text, Google Sheets to CSV
- Downloads PDFs and other file types
- Uses rclone CLI with Google OAuth 2.0 authentication
- Processes Drive attachments from Jira tickets
- Actively maintained tool with auto token refresh

**Hephaestus Workspace Forge** (`hephaestus-workspace-forge.md`)
- Orchestrates development environment setup and workflow automation
- Manages git worktrees for Clear Session project (cs-wt command)
- Manages tmux/sesh sessions for any project (sesh-cmd command)
- Uses Haiku model for cost-effective command execution

## Slash Commands

### Gemini CLI Integration (`commands/gemini.md`)
- Leverages Gemini's massive context window for large codebase analysis
- Uses `gemini -p` with `@` syntax for file/directory inclusion
- Ideal for architecture reviews, feature verification, pattern detection
- Complements Claude Code's execution capabilities with Gemini's analysis capacity
- Invoked via `/gemini` slash command

**Usage examples:**
```bash
/gemini @src/ Has dark mode been implemented?
/gemini @src/ @tests/ Analyze test coverage
/gemini @./ Give me an overview of this project
```

**When to use:**
- Analyzing entire codebases or large directories
- Working with files totaling more than 100KB
- Verifying if features/patterns are implemented across the codebase
- Understanding project-wide architecture

### Jira Board Status (`commands/jira-status.md`)
- Returns focused sprint board status with tickets grouped by actionable sections
- Pre-processes data with jq to minimize token usage (follows code execution optimization pattern)
- Shows sesh/tmux session indicator (✓/-) for each ticket
- Supports letter indexing (A, B, C...) for easy ticket reference
- Invoked via `/jira-status` slash command

**Usage examples:**
```bash
/jira-status           # Default project (CSD)
/jira-status PROJ      # Specific project
```

**What it returns:**
- **In Progress (My Work)**: Your current work
- **Ready For Review (To Review)**: Others' tickets to review
- **Has Review (My PRs)**: Your PRs that have been reviewed
- **To Do**: All unstarted tickets
- **Sesh column**: ✓ if session exists, - otherwise

**Interactive features:**
- Reference tickets by letter (e.g., "switch to G", "tell me about C")
- Auto-switches to sesh session if one exists
- Creates worktree via hephaestus agent if no session (review worktree for others' PRs)

## Important Implementation Details

### GitHub CLI Commands for PR Agents
```bash
# Get review comments on code (critical for heimdall)
gh api repos/:owner/:repo/pulls/[PR]/comments

# Get general PR comments
gh pr view [PR] --comments

# Get review summaries with states
gh pr view [PR] --json reviews,latestReviews
```

### Atlassian CLI Commands for Jira Agents
```bash
# Read operations (atlas-jira-analyst)
acli jira workitem view ISSUE-123 --fields *all --json
acli jira workitem search --jql "project = PROJ" --json

# Write operations (apollo-jira-scribe)
acli jira workitem create --summary "Title" --project "PROJ" --type "Story" --json
acli jira workitem transition --key "PROJ-123" --status "In Progress" --json
acli jira workitem edit --from-json "ticket.json" --json

# Authentication
acli jira auth status
acli jira auth login --web
```

**Important Notes:**
- Sprint field is a custom field (typically `customfield_10020`, varies by instance)
- Use `--json` flag for structured output
- Use `--generate-json` to discover available fields and custom field IDs

### Google Drive CLI Commands for Document Reader
```bash
# Authentication (one-time setup)
rclone config
# Choose: n (new remote) → name it 'gdrive' → select Google Drive → scope 2 (read-only) → use other defaults → authenticate in browser

# Check if configured
rclone listremotes
# Should show: gdrive:

# Export Google Docs to text
rclone backend copyid gdrive: {FILE_ID} /tmp/output.txt --drive-export-formats txt

# Export Google Sheets to CSV
rclone backend copyid gdrive: {FILE_ID} /tmp/output.csv --drive-export-formats csv

# Download regular files (PDFs, images, etc.)
rclone backend copyid gdrive: {FILE_ID} /tmp/output.pdf
rclone backend copyid gdrive: {FILE_ID} -  # Stream to stdout

# Stream file content (alternative)
rclone cat gdrive:path/to/file
```

**Important Notes:**
- rclone uses Google's official OAuth 2.0 API for secure authentication
- Actively maintained (v1.71.2 in 2025) with 11K+ installs/month
- Tokens auto-refresh automatically - no re-authentication needed
- Google Workspace files (Docs, Sheets) must be exported, not downloaded
- File IDs are extracted from various Drive URL formats
- Credentials stored in `~/.config/rclone/rclone.conf`
- No syncing - downloads only specified files

### Symbolic Link Management
The installer auto-discovers plugins and creates symbolic links:
- Discovers agents from `agents/*/agents/*.md`
- Discovers commands from `commands/*/commands/*.md`
- Discovers skills from `skills/*/skills/*/SKILL.md`
- Creates file-level symlinks for agents and commands
- Creates folder-level symlinks for skills
- Changes to local files immediately affect global installations after restart

### Testing Agent Triggers
After installation, restart Claude Code terminal and test with:
- "Check PR comments" → should trigger heimdall-pr-guardian
- "Get context for PROJ-123" → should trigger atlas-jira-analyst
- "Create a ticket for new feature" → should trigger apollo-jira-scribe
- "Move PROJ-123 to In Progress" → should trigger apollo-jira-scribe
- "What's in PR #456" → should trigger hermes-pr-courier
- "Review PR #789" → should trigger athena-pr-reviewer skill
- "Find our API documentation" → should trigger minerva-notion-oracle
- "Read this Google Doc link" → should trigger clio-docs-oracle
- "Get content from Drive attachment" → should trigger clio-docs-oracle
- "Create a worktree for CSD-2345" → should trigger hephaestus-workspace-forge
- "Add a tmux session for my project" → should trigger hephaestus-workspace-forge

### Testing Commands
After installation, restart Claude Code terminal and test with:
- `/gemini @src/ Analyze the codebase architecture` → should execute gemini command
- `/jira-status` → should return board status for CSD project
- `/jira-status PROJ` → should return board status for specified project

## Requirements Verification

Before working with agents:
```bash
# Check GitHub CLI authentication
gh auth status

# Check Atlassian CLI authentication (for Jira agents)
acli jira auth status

# Check Google Drive CLI authentication (for Drive reader agent)
rclone listremotes
# Should show: gdrive:

# Check Gemini CLI (for Gemini command)
gemini --version

# Check Atlassian MCP tools (for Jira agents - legacy)
# Should be configured in Claude Code settings

# Check Notion MCP tools (for Notion agent)
# Should be configured in Claude Code settings

# Verify agent symlinks
readlink ~/.claude/agents/atlas-jira-analyst.md
readlink ~/.claude/agents/apollo-jira-scribe.md
readlink ~/.claude/agents/heimdall-pr-guardian.md
readlink ~/.claude/agents/hermes-pr-courier.md
readlink ~/.claude/agents/hephaestus-workspace-forge.md
readlink ~/.claude/agents/minerva-notion-oracle.md
readlink ~/.claude/agents/clio-docs-oracle.md

# Verify command symlinks
readlink ~/.claude/commands/gemini.md
readlink ~/.claude/commands/jira-status.md

# Verify skill symlinks
readlink ~/.claude/skills/athena-pr-reviewer
```