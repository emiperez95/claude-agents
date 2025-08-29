# Claude Code Agent Manager

A comprehensive tool for managing and analyzing Claude Code agents, providing both CLI and web interfaces for viewing agent metadata, token usage, and installation status.

## Features

- **CLI Tool**: Command-line interface for quick agent management
- **Web Dashboard**: Interactive web interface with visualizations
- **Token Analysis**: Calculate token usage and estimate API costs
- **Tool Analytics**: Analyze tool usage across agents
- **Export Capabilities**: Export agent data to JSON or CSV
- **Installation Tracking**: Monitor which agents are installed via symlinks

## Installation

1. Navigate to the agent-tools directory:
```bash
cd agent-tools
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

## CLI Usage

### List all agents
```bash
python agent-manager.py list
```

Options:
- `--format table` (default): Rich formatted table
- `--format json`: JSON output
- `--format simple`: Simple text output

### View agent details
```bash
python agent-manager.py info <agent-name>

# Example
python agent-manager.py info atlas-jira-analyst
```

### Show statistics
```bash
python agent-manager.py stats
```

### Export data
```bash
python agent-manager.py export --format json
python agent-manager.py export --format csv --output my-agents.csv
```

### Validate agents
```bash
python agent-manager.py validate
```

## Web Dashboard

### Start the dashboard
```bash
python agent-dashboard.py
```

Then open your browser to: http://localhost:5000

### Dashboard Features

1. **Agents Tab**: 
   - Search and filter agents
   - Click on any agent for detailed view
   - See installation status at a glance

2. **Statistics Tab**:
   - Token distribution charts
   - Tool usage visualization
   - Model distribution summary

3. **Tools Tab**:
   - Tool usage matrix
   - See which agents use which tools

### API Endpoints

The dashboard provides several JSON API endpoints:

- `GET /api/agents` - List all agents
- `GET /api/agent/<name>` - Get specific agent details
- `GET /api/stats` - Get aggregate statistics
- `GET /api/visualization/tokens` - Token distribution data
- `GET /api/visualization/tools` - Tool usage data

## Configuration

Edit `config.yaml` to customize:

- Agent directory paths
- Dashboard settings (host, port)
- Token counting model
- Display preferences
- Export settings
- Validation rules

## Agent Data Structure

Each agent provides:
- **Name**: Agent identifier
- **Model**: AI model used (opus, sonnet, haiku)
- **Tools**: List of available tools
- **Description**: Agent purpose and triggers
- **Token Counts**: Description, body, and total tokens
- **Installation Status**: Whether symlink exists in ~/.claude/agents/

## Token Analysis

The tool uses OpenAI's tiktoken library to count tokens accurately. It provides:
- Token counts for different parts of the agent
- Cost estimates for different Claude models
- Size categorization (tiny, small, medium, large, very large)

## Export Formats

### JSON Export
```json
{
  "name": "agent-name",
  "model": "sonnet",
  "tool_count": 10,
  "description_tokens": 250,
  "total_tokens": 1500,
  "installed": true
}
```

### CSV Export
Includes columns for name, model, tools, tokens, and installation status.

## Troubleshooting

### Agent directory not found
Ensure you're running the tools from the `agent-tools` directory and that the `../agents` directory exists.

### Token counting errors
The tool will fall back to the cl100k_base encoder if the specified model is not available.

### Installation status shows "Not Installed"
Check that:
1. ~/.claude/agents/ directory exists
2. Symlinks are properly created using install-agents.sh
3. You have read permissions for the directory

## Development

### Adding new features
1. Utility modules are in `utils/`
2. Web templates are in `templates/`
3. Static assets are in `static/`

### Running in development mode
The Flask app runs in debug mode by default, with auto-reload enabled.

## License

Part of the Claude Code Agents project.