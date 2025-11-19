#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory (where this script is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOCAL_AGENTS_DIR="${SCRIPT_DIR}/agents"
LOCAL_COMMANDS_DIR="${SCRIPT_DIR}/commands"

# Global directories
GLOBAL_AGENTS_DIR="$HOME/.claude/agents"
GLOBAL_COMMANDS_DIR="$HOME/.claude/commands"

# Our agents
AGENTS=(
    "atlas-jira-analyst.md"
    "apollo-jira-scribe.md"
    "athena-pr-reviewer.md"
    "heimdall-pr-guardian.md"
    "hermes-pr-courier.md"
    "hephaestus-workspace-forge.md"
    "minerva-notion-oracle.md"
    "clio-docs-oracle.md"
)

# Our commands
COMMANDS=(
    "gemini.md"
)

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

echo "Claude Agents & Commands Installer"
echo "==================================="
echo ""

# Check if local directories exist
if [[ ! -d "$LOCAL_AGENTS_DIR" ]]; then
    echo -e "${RED}Error: Local agents directory not found at $LOCAL_AGENTS_DIR${NC}"
    exit 1
fi

if [[ ! -d "$LOCAL_COMMANDS_DIR" ]]; then
    echo -e "${YELLOW}Warning: Local commands directory not found at $LOCAL_COMMANDS_DIR${NC}"
    echo "Skipping commands installation..."
    LOCAL_COMMANDS_DIR=""
fi

# Create global directories if they don't exist
if [[ ! -d "$GLOBAL_AGENTS_DIR" ]]; then
    echo "Creating global agents directory at $GLOBAL_AGENTS_DIR"
    mkdir -p "$GLOBAL_AGENTS_DIR"
fi

if [[ -n "$LOCAL_COMMANDS_DIR" ]] && [[ ! -d "$GLOBAL_COMMANDS_DIR" ]]; then
    echo "Creating global commands directory at $GLOBAL_COMMANDS_DIR"
    mkdir -p "$GLOBAL_COMMANDS_DIR"
fi

echo "Local agents directory: $LOCAL_AGENTS_DIR"
echo "Global agents directory: $GLOBAL_AGENTS_DIR"
if [[ -n "$LOCAL_COMMANDS_DIR" ]]; then
    echo "Local commands directory: $LOCAL_COMMANDS_DIR"
    echo "Global commands directory: $GLOBAL_COMMANDS_DIR"
fi
echo ""

# Check if agents already exist
existing_agents=()
for agent in "${AGENTS[@]}"; do
    if [[ -e "$GLOBAL_AGENTS_DIR/$agent" ]]; then
        existing_agents+=("$agent")
    fi
done

# Check if commands already exist
existing_commands=()
if [[ -n "$LOCAL_COMMANDS_DIR" ]]; then
    for command in "${COMMANDS[@]}"; do
        if [[ -e "$GLOBAL_COMMANDS_DIR/$command" ]]; then
            existing_commands+=("$command")
        fi
    done
fi

# Handle existing files
has_existing=false
if [[ ${#existing_agents[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Found existing agents in global directory:${NC}"
    for agent in "${existing_agents[@]}"; do
        echo "  - $agent"
    done
    echo ""
    has_existing=true
fi

if [[ ${#existing_commands[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Found existing commands in global directory:${NC}"
    for command in "${existing_commands[@]}"; do
        echo "  - $command"
    done
    echo ""
    has_existing=true
fi

if [[ "$has_existing" == true ]]; then
    if [[ "$FORCE" == false ]]; then
        echo -e "${RED}Error: Files already exist in global directories.${NC}"
        echo "Use --force flag to overwrite existing files:"
        echo "  ./install-agents.sh --force"
        exit 1
    else
        echo -e "${YELLOW}Force flag detected. Removing existing files...${NC}"
        for agent in "${existing_agents[@]}"; do
            rm -f "$GLOBAL_AGENTS_DIR/$agent"
            echo "  Removed agent: $agent"
        done
        for command in "${existing_commands[@]}"; do
            rm -f "$GLOBAL_COMMANDS_DIR/$command"
            echo "  Removed command: $command"
        done
        echo ""
    fi
fi

# Install agents as file-level symbolic links
echo "Installing agents as file-level symbolic links..."
agents_success=0
agents_fail=0

for agent in "${AGENTS[@]}"; do
    local_path="$LOCAL_AGENTS_DIR/$agent"
    global_path="$GLOBAL_AGENTS_DIR/$agent"

    if [[ ! -f "$local_path" ]]; then
        echo -e "${RED}  ✗ $agent - Local file not found${NC}"
        ((agents_fail++))
        continue
    fi

    # Create file-level symbolic link
    if ln -s "$local_path" "$global_path" 2>/dev/null; then
        echo -e "${GREEN}  ✓ $agent${NC}"
        ((agents_success++))
    else
        echo -e "${RED}  ✗ $agent - Failed to create symbolic link${NC}"
        ((agents_fail++))
    fi
done

# Install commands as file-level symbolic links
commands_success=0
commands_fail=0

if [[ -n "$LOCAL_COMMANDS_DIR" ]] && [[ ${#COMMANDS[@]} -gt 0 ]]; then
    echo ""
    echo "Installing commands as file-level symbolic links..."

    for command in "${COMMANDS[@]}"; do
        local_path="$LOCAL_COMMANDS_DIR/$command"
        global_path="$GLOBAL_COMMANDS_DIR/$command"

        if [[ ! -f "$local_path" ]]; then
            echo -e "${RED}  ✗ $command - Local file not found${NC}"
            ((commands_fail++))
            continue
        fi

        # Create file-level symbolic link
        if ln -s "$local_path" "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $command${NC}"
            ((commands_success++))
        else
            echo -e "${RED}  ✗ $command - Failed to create symbolic link${NC}"
            ((commands_fail++))
        fi
    done
fi

echo ""
echo "Installation Summary"
echo "==================="
echo -e "${GREEN}Successfully installed: $agents_success agents${NC}"
if [[ $agents_fail -gt 0 ]]; then
    echo -e "${RED}Failed to install: $agents_fail agents${NC}"
fi

if [[ -n "$LOCAL_COMMANDS_DIR" ]]; then
    echo -e "${GREEN}Successfully installed: $commands_success commands${NC}"
    if [[ $commands_fail -gt 0 ]]; then
        echo -e "${RED}Failed to install: $commands_fail commands${NC}"
    fi
fi

total_fail=$((agents_fail + commands_fail))
if [[ $total_fail -eq 0 ]]; then
    echo ""
    echo "All agents and commands have been successfully linked!"
    echo ""
    echo "Note: Files are installed as file-level symlinks."
    echo "You can manually add other files to ~/.claude/agents/ or ~/.claude/commands/ if needed."
    echo "Restart your Claude Code terminal to load the new agents and commands."
fi

if [[ $total_fail -gt 0 ]]; then
    exit 1
fi