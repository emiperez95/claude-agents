# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains eight specialized Claude Code agents for automating workflows and information gathering from Jira, GitHub, Notion, Google Drive, and local development environments. Most agents are pure information collectors that return structured data without opinions or analysis, plus orchestrator agents for comprehensive PR reviews and development workflow automation.

## Installation and Management Commands

```bash
# Install agents (creates symbolic links to global Claude directory)
./install-agents.sh

# Force install (overwrites existing agents)
./install-agents.sh --force

# Uninstall agents (removes symbolic links only)
./uninstall-agents.sh

# Verify installation
ls -la ~/.claude/agents/ | grep -E "(atlas|apollo|heimdall|hermes|athena|minerva|hephaestus|clio)"
```

## Agent Architecture

### Agent Structure
Each agent in `agents/` directory follows this format:
- **Frontmatter**: YAML configuration with name, description, tools, model
- **Description field**: Must include "PROACTIVELY USED" for automatic triggering
- **Prompt**: Defines agent personality and data collection instructions
- **Output format**: LLM-optimized structured text (not JSON)

### Key Design Principles
1. **Pure Information Gathering**: Agents collect and structure data without analysis or opinions
2. **Proactive Triggering**: Agents activate automatically on keyword mentions
3. **Comment ID Extraction**: All PR agents must extract comment/review IDs for responding/resolving
4. **Model Optimization**: Using Sonnet model for cost efficiency (Opus for complex orchestration)

### Orchestration Protocol
When an agent outputs an `=== ORCHESTRATION REQUIRED ===` block:
1. **Parse the commands**: Extract the Task tool invocations listed
2. **Execute in parallel**: Run all Task commands in a single message with multiple tool calls
3. **Collect results**: Gather outputs from all invoked agents
4. **Return for synthesis**: Re-invoke the orchestrating agent with `"SYNTHESIS: [combined results]"`

Example orchestration flow:
```
User: "review PR 123"
  ↓
Claude: Invokes athena-pr-reviewer
  ↓
Athena: Outputs "=== ORCHESTRATION REQUIRED ===" with agent commands
  ↓
Claude: Executes all Task commands in parallel
  ↓
Claude: Re-invokes athena with "SYNTHESIS: [results]"
  ↓
Athena: Performs final review synthesis
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

**Athena PR Reviewer** (`athena-pr-reviewer.md`)
- Orchestrates comprehensive PR reviews
- Uses command-output pattern to coordinate other agents
- Compares implementation against Jira requirements
- Provides actionable review recommendations

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
# Choose: n (new remote) → name it 'gdrive' → select Google Drive → use defaults → authenticate in browser

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
The installer creates symbolic links from the global directory to local agents:
- Global directory: `~/.claude/agents/` (may be symlinked to another location)
- Local agents: `./agents/`
- Changes to local files immediately affect global agents

### Testing Agent Triggers
After installation, restart Claude Code terminal and test with:
- "Check PR comments" → should trigger heimdall-pr-guardian
- "Get context for PROJ-123" → should trigger atlas-jira-analyst
- "Create a ticket for new feature" → should trigger apollo-jira-scribe
- "Move PROJ-123 to In Progress" → should trigger apollo-jira-scribe
- "What's in PR #456" → should trigger hermes-pr-courier
- "Review PR #789" → should trigger athena-pr-reviewer
- "Find our API documentation" → should trigger minerva-notion-oracle
- "Read this Google Doc link" → should trigger clio-docs-oracle
- "Get content from Drive attachment" → should trigger clio-docs-oracle
- "Create a worktree for CSD-2345" → should trigger hephaestus-workspace-forge
- "Add a tmux session for my project" → should trigger hephaestus-workspace-forge

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

# Check Atlassian MCP tools (for Jira agents - legacy)
# Should be configured in Claude Code settings

# Check Notion MCP tools (for Notion agent)
# Should be configured in Claude Code settings

# Verify agent symlinks
readlink ~/.claude/agents/atlas-jira-analyst.md
readlink ~/.claude/agents/apollo-jira-scribe.md
readlink ~/.claude/agents/heimdall-pr-guardian.md
readlink ~/.claude/agents/hermes-pr-courier.md
readlink ~/.claude/agents/athena-pr-reviewer.md
readlink ~/.claude/agents/hephaestus-workspace-forge.md
readlink ~/.claude/agents/minerva-notion-oracle.md
readlink ~/.claude/agents/clio-docs-oracle.md
```