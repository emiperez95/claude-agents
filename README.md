# Claude Code Plugin Workspace

Private development workspace for Claude Code plugins. Combines private plugins with a public marketplace distribution via submodule.

## Structure

```
.
├── cc-toolkit/              # Public submodule → github.com/emiperez95/cc-toolkit
├── agents/                  # Private agents (flat .md files)
│   └── hephaestus-workspace-forge.md
├── commands/                # Private commands (flat .md files)
│   └── jira-status.md
├── skills/                  # Private skills (folders with SKILL.md)
└── install-agents.sh        # Installs both private + public
```

## Installation (for this workspace)

```bash
# Install all plugins (private + public)
./install-agents.sh --force

# Uninstall
./uninstall-agents.sh
```

## Public Marketplace

Others can install the public plugins via:
```bash
/plugin marketplace add emiperez95/cc-toolkit
```

See [cc-toolkit/README.md](cc-toolkit/README.md) for public plugin documentation.

---

## Private Plugins

### Hephaestus Workspace Forge (Agent)
Orchestrates development environment setup:
- Manages git worktrees via `cs-wt` command (Clear Session project)
- Manages tmux/sesh sessions via `sesh-cmd` command

### Jira Status (Command)
Returns focused sprint board status with tickets grouped by actionable sections:
- Shows sesh/tmux session indicator (✓/-) for each ticket
- Supports letter indexing for quick reference
- Auto-switches to existing sessions or creates worktrees

---

## All Available Plugins

| Type | Name | Location | Description |
|------|------|----------|-------------|
| Agent | atlas-jira-analyst | public | Fetches Jira issue information |
| Agent | apollo-jira-scribe | public | Creates and updates Jira tickets |
| Agent | clio-docs-oracle | public | Reads Google Drive files |
| Agent | heimdall-pr-guardian | public | Monitors PR status and comments |
| Agent | hermes-pr-courier | public | Collects PR content and metadata |
| Agent | minerva-notion-oracle | public | Searches Notion workspaces |
| Agent | **hephaestus-workspace-forge** | private | Manages worktrees and sessions |
| Command | gemini | public | Large codebase analysis via Gemini CLI |
| Command | **jira-status** | private | Jira board with session indicators |
| Skill | athena-pr-reviewer | public | Multi-LLM PR reviewer (8 reviewers) |
| Skill | athena-pr-reviewer-lite | public | Claude-only PR reviewer (6 reviewers) |

## Workflow

### Promote a plugin (private → public)
```bash
mv agents/my-agent.md cc-toolkit/agents/my-agent/agents/my-agent.md
# Add plugin.json, commit in cc-toolkit, push
# Update submodule reference in parent
```

### Demote a plugin (public → private)
```bash
mv cc-toolkit/agents/my-agent/agents/my-agent.md agents/
# Commit in cc-toolkit, push
# Update submodule reference in parent
```

## Requirements

```bash
gh auth status         # GitHub CLI
acli jira auth status  # Atlassian CLI
rclone listremotes     # Google Drive (should show gdrive:)
gemini --version       # Gemini CLI (optional)
```

## Related Files

- [CLAUDE.md](CLAUDE.md) - Instructions for Claude Code when working in this repo
- [AGENTS.md](AGENTS.md) - Detailed agent documentation
- [AGENT_ARCHITECTURE.md](AGENT_ARCHITECTURE.md) - Design principles

## License

MIT
