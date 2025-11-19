#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

echo "Claude Agents & Commands Uninstaller"
echo "====================================="
echo ""

# Check if global directories exist
agents_dir_exists=false
commands_dir_exists=false

if [[ -d "$GLOBAL_AGENTS_DIR" ]]; then
    agents_dir_exists=true
    echo "Global agents directory: $GLOBAL_AGENTS_DIR"
fi

if [[ -d "$GLOBAL_COMMANDS_DIR" ]]; then
    commands_dir_exists=true
    echo "Global commands directory: $GLOBAL_COMMANDS_DIR"
fi

if [[ "$agents_dir_exists" == false ]] && [[ "$commands_dir_exists" == false ]]; then
    echo -e "${RED}Error: No global directories found.${NC}"
    echo "Nothing to uninstall."
    exit 1
fi

echo ""

# Check which agents exist
existing_agents=()
if [[ "$agents_dir_exists" == true ]]; then
    for agent in "${AGENTS[@]}"; do
        if [[ -e "$GLOBAL_AGENTS_DIR/$agent" ]]; then
            existing_agents+=("$agent")
        fi
    done
fi

# Check which commands exist
existing_commands=()
if [[ "$commands_dir_exists" == true ]]; then
    for command in "${COMMANDS[@]}"; do
        if [[ -e "$GLOBAL_COMMANDS_DIR/$command" ]]; then
            existing_commands+=("$command")
        fi
    done
fi

# Handle no files found
if [[ ${#existing_agents[@]} -eq 0 ]] && [[ ${#existing_commands[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No agents or commands found to uninstall.${NC}"
    exit 0
fi

# Uninstall agents
agents_success=0
agents_fail=0

if [[ ${#existing_agents[@]} -gt 0 ]]; then
    echo "Uninstalling agents..."
    for agent in "${existing_agents[@]}"; do
        global_path="$GLOBAL_AGENTS_DIR/$agent"

        # Remove the agent symlink
        if rm -f "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Removed: $agent${NC}"
            ((agents_success++))
        else
            echo -e "${RED}  ✗ Failed to remove: $agent${NC}"
            ((agents_fail++))
        fi
    done
fi

# Uninstall commands
commands_success=0
commands_fail=0

if [[ ${#existing_commands[@]} -gt 0 ]]; then
    echo ""
    echo "Uninstalling commands..."
    for command in "${existing_commands[@]}"; do
        global_path="$GLOBAL_COMMANDS_DIR/$command"

        # Remove the command symlink
        if rm -f "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Removed: $command${NC}"
            ((commands_success++))
        else
            echo -e "${RED}  ✗ Failed to remove: $command${NC}"
            ((commands_fail++))
        fi
    done
fi

echo ""
echo "Uninstall Summary"
echo "================="

if [[ ${#existing_agents[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successfully uninstalled: $agents_success agents${NC}"
    if [[ $agents_fail -gt 0 ]]; then
        echo -e "${RED}Failed to uninstall: $agents_fail agents${NC}"
    fi
fi

if [[ ${#existing_commands[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successfully uninstalled: $commands_success commands${NC}"
    if [[ $commands_fail -gt 0 ]]; then
        echo -e "${RED}Failed to uninstall: $commands_fail commands${NC}"
    fi
fi

total_fail=$((agents_fail + commands_fail))
if [[ $total_fail -eq 0 ]]; then
    echo ""
    echo "All agents and commands have been successfully removed!"
    echo "Restart your Claude Code terminal to reflect the changes."
fi

if [[ $total_fail -gt 0 ]]; then
    exit 1
fi