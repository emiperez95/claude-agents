# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository contains five specialized Claude Code agents for automating information gathering from Jira, GitHub, and Notion. The agents are pure information collectors that return structured data without opinions or analysis, plus an orchestrator agent for comprehensive PR reviews.

## Installation and Management Commands

```bash
# Install agents (creates symbolic links to global Claude directory)
./install-agents.sh

# Force install (overwrites existing agents)
./install-agents.sh --force

# Uninstall agents (removes symbolic links only)
./uninstall-agents.sh

# Verify installation
ls -la ~/.claude/agents/ | grep -E "(atlas|heimdall|hermes|athena|minerva)"
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

### Symbolic Link Management
The installer creates symbolic links from the global directory to local agents:
- Global directory: `~/.claude/agents/` (may be symlinked to another location)
- Local agents: `./agents/`
- Changes to local files immediately affect global agents

### Testing Agent Triggers
After installation, restart Claude Code terminal and test with:
- "Check PR comments" → should trigger heimdall-pr-guardian
- "Get context for PROJ-123" → should trigger atlas-jira-analyst
- "What's in PR #456" → should trigger hermes-pr-courier
- "Review PR #789" → should trigger athena-pr-reviewer
- "Find our API documentation" → should trigger minerva-notion-oracle

## Requirements Verification

Before working with agents:
```bash
# Check GitHub CLI authentication
gh auth status

# Check Atlassian MCP tools (for Jira agent)
# Should be configured in Claude Code settings

# Check Notion MCP tools (for Notion agent)
# Should be configured in Claude Code settings

# Verify agent symlinks
readlink ~/.claude/agents/atlas-jira-analyst.md
readlink ~/.claude/agents/heimdall-pr-guardian.md
readlink ~/.claude/agents/hermes-pr-courier.md
readlink ~/.claude/agents/athena-pr-reviewer.md
readlink ~/.claude/agents/minerva-notion-oracle.md
```