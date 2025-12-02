# Claude Code Development Agents & Commands

A collection of specialized Claude Code agents and slash commands designed to streamline development workflows by automating information gathering from Jira, GitHub, Notion, and Google Drive, plus integration with Gemini for large-scale codebase analysis.

## Overview

This repository contains mythologically-named agents designed to streamline development workflows. These agents work proactively with Claude Code, automatically triggering when relevant keywords are mentioned. They include pure information collectors and orchestrators that coordinate comprehensive PR reviews and development workflows.

Additionally, this repository includes slash commands that extend Claude Code's capabilities with external tools like Gemini CLI for analyzing large codebases.

## Quick Start

### Plugin Installation (Recommended)

Each agent, command, and skill is a separate plugin. Install only what you need:

```bash
# Add the marketplace
/plugin marketplace add emiperez95/claude-agents

# Install individual plugins
/plugin install atlas-jira-analyst          # Jira issue analyzer
/plugin install apollo-jira-scribe          # Jira ticket creator
/plugin install heimdall-pr-guardian        # PR status monitor
/plugin install hermes-pr-courier           # PR content collector
/plugin install minerva-notion-oracle       # Notion searcher
/plugin install clio-docs-oracle            # Google Drive reader
/plugin install hephaestus-workspace-forge  # Workspace manager
/plugin install gemini-command              # Gemini CLI integration
/plugin install jira-status-command         # Jira board status
/plugin install athena-pr-reviewer          # Multi-LLM PR reviewer
```

### Alternative: Symlink Installation (for developers)

For development or offline use, the symlink installer provides hot-reload on restart:

```bash
git clone https://github.com/emiperez95/claude-agents.git
cd claude-agents
./install-agents.sh
```

This installs ALL agents, commands, and skills at once via symlinks.

Restart your Claude Code terminal. The agents will automatically activate when you mention relevant keywords.

## Agents

### 🏛️ Atlas Jira Analyst
Extracts comprehensive context from Jira issues including acceptance criteria, comments, and epic details.

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

## Skills

### ⚖️ Athena PR Reviewer
Multi-LLM PR review skill that orchestrates 8 parallel reviewers:
- **Gemini** + **Codex**: General code review
- **6 Claude specialists**: Comments, tests, errors, types, general quality, simplification

Features confidence scoring (0-100), consensus boosting (2+ reviewers = priority bump), and requirement validation against Jira tickets.

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

Install via Claude Code's plugin system. Each component is a separate plugin:

```bash
# Add the marketplace first
/plugin marketplace add emiperez95/claude-agents

# Then install the plugins you need
/plugin install <plugin-name>
```

Available plugins:
| Plugin | Description |
|--------|-------------|
| `atlas-jira-analyst` | Jira issue context extractor |
| `apollo-jira-scribe` | Jira ticket creator/updater |
| `heimdall-pr-guardian` | PR status and comments monitor |
| `hermes-pr-courier` | PR content collector |
| `minerva-notion-oracle` | Notion workspace searcher |
| `clio-docs-oracle` | Google Drive document reader |
| `hephaestus-workspace-forge` | Git worktree and tmux manager |
| `gemini-command` | Gemini CLI for codebase analysis |
| `jira-status-command` | Jira sprint board status |
| `athena-pr-reviewer` | Multi-LLM PR review skill |

To uninstall:
```bash
/plugin uninstall <plugin-name>
```

### Symlink Installation (for developers)

For development with hot-reload capability:
```bash
# Normal installation (fails if agents/commands already exist)
./install-agents.sh

# Force installation (overwrites existing agents/commands)
./install-agents.sh --force
```

The installer auto-discovers plugins and creates symbolic links from the global Claude directories (`~/.claude/agents/`, `~/.claude/commands/`, `~/.claude/skills/`) to your local copies. Changes are immediately available after restarting Claude Code.

To uninstall:
```bash
./uninstall-agents.sh
```

This removes only the symbolic links to these agents, commands, and skills, leaving other files untouched.

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
│   └── marketplace.json              # Lists all 10 plugins
├── agents/
│   ├── atlas-jira-analyst/
│   │   ├── .claude-plugin/plugin.json
│   │   └── agents/atlas-jira-analyst.md
│   ├── apollo-jira-scribe/
│   │   ├── .claude-plugin/plugin.json
│   │   └── agents/apollo-jira-scribe.md
│   ├── ... (5 more agents)
├── commands/
│   ├── gemini/
│   │   ├── .claude-plugin/plugin.json
│   │   └── commands/gemini.md
│   ├── jira-status/
│   │   ├── .claude-plugin/plugin.json
│   │   └── commands/jira-status.md
├── skills/
│   └── athena-pr-reviewer/
│       ├── .claude-plugin/plugin.json
│       └── skills/athena-pr-reviewer/
│           ├── SKILL.md
│           ├── prompts/
│           └── scripts/
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
