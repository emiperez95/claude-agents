# Claude Code Development Agents

A collection of specialized Claude Code agents designed to streamline development workflows by automating information gathering from Jira and GitHub.

## Overview

This repository contains three mythologically-named agents that act as pure information collectors, gathering and structuring data from various sources without providing opinions or analysis. These agents are designed to work proactively with Claude Code, automatically triggering when relevant keywords are mentioned.

## Quick Start

1. Clone this repository
2. Run the installer:
   ```bash
   ./install-agents.sh
   ```
3. Restart your Claude Code terminal
4. The agents will now automatically activate when you mention relevant keywords

## Agents

### 🏛️ Atlas Jira Analyst
Extracts comprehensive context from Jira issues including acceptance criteria, comments, and epic details.

### 🛡️ Heimdall PR Guardian  
Monitors your pull request status, tracking comments, CI/CD checks, approvals, and merge blockers.

### 📬 Hermes PR Courier
Collects PR content including file changes, commit history, and linked issues for any pull request.

For detailed information about each agent, see [AGENTS.md](AGENTS.md).

## Installation

### Install Agents
```bash
# Normal installation (fails if agents already exist)
./install-agents.sh

# Force installation (overwrites existing agents)
./install-agents.sh --force
```

The installer creates symbolic links from the global Claude agents directory to your local copies, ensuring any updates you make are immediately available globally.

### Uninstall Agents
```bash
./uninstall-agents.sh
```

This removes only the symbolic links to these three agents, leaving other agents untouched.

## Requirements

- Claude Code installed and configured
- GitHub CLI (`gh`) for PR-related agents
- Atlassian MCP tools configured for Jira agent
- Unix-like environment (macOS, Linux)

## Configuration

The agents are configured to use:
- **Model**: Sonnet (cost-optimized for information gathering tasks)
- **Proactive Mode**: Automatically triggers on relevant keywords
- **Output Format**: LLM-optimized structured text

## Project Structure

```
.
├── agents/
│   ├── atlas-jira-analyst.md
│   ├── heimdall-pr-guardian.md
│   └── hermes-pr-courier.md
├── install-agents.sh
├── uninstall-agents.sh
├── README.md
└── AGENTS.md
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

### Jira agent not working
- Check that Atlassian MCP tools are configured
- Verify you have access to the Jira instance

## Contributing

Feel free to customize these agents for your specific needs. The agents are written in Markdown with YAML frontmatter and can be easily modified.

## License

MIT