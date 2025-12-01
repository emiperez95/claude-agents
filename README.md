# Claude Code Development Agents & Commands

A collection of specialized Claude Code agents and slash commands designed to streamline development workflows by automating information gathering from Jira, GitHub, Notion, and Google Drive, plus integration with Gemini for large-scale codebase analysis.

## Overview

This repository contains mythologically-named agents designed to streamline development workflows. These agents work proactively with Claude Code, automatically triggering when relevant keywords are mentioned. They include pure information collectors and orchestrators that coordinate comprehensive PR reviews and development workflows.

Additionally, this repository includes slash commands that extend Claude Code's capabilities with external tools like Gemini CLI for analyzing large codebases.

## Quick Start

### Plugin Installation (Recommended)
```bash
/plugin marketplace add emilianoperez/agent-workflow
/plugin install agent-workflow
```

### Alternative: Symlink Installation
```bash
git clone https://github.com/emilianoperez/agent-workflow.git
cd agent-workflow
./install-agents.sh
```

Restart your Claude Code terminal. The agents will automatically activate when you mention relevant keywords.

## Agents

### 🏛️ Atlas Jira Analyst
Extracts comprehensive context from Jira issues including acceptance criteria, comments, and epic details.

### ⚖️ Athena PR Reviewer
Orchestrates comprehensive PR reviews by coordinating Jira requirements, PR content, and status checks to provide actionable review insights.

### 🛡️ Heimdall PR Guardian  
Monitors your pull request status, tracking comments, CI/CD checks, approvals, and merge blockers.

### 📬 Hermes PR Courier
Collects PR content including file changes, commit history, and linked issues for any pull request.

### 🦉 Minerva Notion Oracle
Searches and retrieves content from Notion workspaces including documentation, meeting notes, and project information.

### 📜 Clio Docs Oracle
Reads and retrieves content from Google Drive links including Docs, Sheets, PDFs, and other files using rclone CLI.

### ⚒️ Hephaestus Workspace Forge
Orchestrates development environment setup including git worktrees and tmux/sesh session management.

### 🖊️ Apollo Jira Scribe
Creates Jira tickets, transitions workflow states, and assigns tickets to sprints.

For detailed information about each agent, see [AGENTS.md](AGENTS.md).

## Slash Commands

### 🔮 Gemini CLI Integration
Leverages Gemini's massive context window for large codebase analysis. Use `/gemini @src/ <your question>` to analyze entire directories, verify feature implementations, or understand project-wide architecture.

**Example usage:**
```bash
/gemini @src/ Has dark mode been implemented?
/gemini @src/ @tests/ Analyze test coverage
/gemini @./ Give me an overview of this project
```

## Installation

### Plugin Installation (Recommended)
Install via Claude Code's plugin system:
```bash
/plugin marketplace add emilianoperez/agent-workflow
/plugin install agent-workflow
```

To uninstall:
```bash
/plugin uninstall agent-workflow
```

### Symlink Installation (Alternative)
For development or offline use:
```bash
# Normal installation (fails if agents/commands already exist)
./install-agents.sh

# Force installation (overwrites existing agents/commands)
./install-agents.sh --force
```

The installer creates symbolic links from the global Claude directories (`~/.claude/agents/`, `~/.claude/commands/`, `~/.claude/skills/`) to your local copies, ensuring any updates you make are immediately available globally.

To uninstall:
```bash
./uninstall-agents.sh
```

This removes only the symbolic links to these agents and commands, leaving other files untouched.

## Requirements

- Claude Code installed and configured
- GitHub CLI (`gh`) for PR-related agents
- Atlassian CLI (`acli`) for Jira agents
- Notion MCP tools configured for Notion agent
- rclone CLI for Google Drive agent
- Gemini CLI for Gemini command (optional)
- Unix-like environment (macOS, Linux)

## Configuration

The agents are configured to use:
- **Model**: Sonnet for data gathering, Opus for complex orchestration
- **Proactive Mode**: Automatically triggers on relevant keywords
- **Output Format**: LLM-optimized structured text

## Project Structure

```
.
├── .claude-plugin/
│   ├── plugin.json           # Plugin manifest
│   └── marketplace.json      # Marketplace config
├── agents/
│   ├── atlas-jira-analyst.md
│   ├── apollo-jira-scribe.md
│   ├── athena-pr-reviewer.md
│   ├── heimdall-pr-guardian.md
│   ├── hermes-pr-courier.md
│   ├── minerva-notion-oracle.md
│   ├── clio-docs-oracle.md
│   └── hephaestus-workspace-forge.md
├── commands/
│   ├── gemini.md
│   └── jira-status.md
├── skills/
│   └── athena-pr-reviewer/   # Multi-LLM PR review skill
├── install-agents.sh
├── uninstall-agents.sh
├── README.md
├── AGENTS.md
└── CLAUDE.md
```

## Troubleshooting

### Agents not triggering
- Ensure you've restarted Claude Code after installation
- Check that the agent files exist in `~/.claude/agents/`
- Verify the symbolic links are correctly pointing to your local files

### Installation fails
- Check that `~/.claude/agents/` directory exists
- Ensure you have write permissions to the global agents directory
- Use `--force` flag if agents already exist

### PR agents not working
- Verify `gh` CLI is installed and authenticated: `gh auth status`
- Ensure you're in a git repository with an associated PR

### Jira agents not working
- Check that Atlassian CLI is installed: `acli jira auth status`
- Verify you have access to the Jira instance

### Gemini command not working
- Install Gemini CLI if not already installed
- Configure API key for Gemini CLI
- Verify installation: `gemini --version`

## Contributing

Feel free to customize these agents for your specific needs. The agents are written in Markdown with YAML frontmatter and can be easily modified.

## License

MIT