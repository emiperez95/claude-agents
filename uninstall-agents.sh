#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory (where this script is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Global directories
GLOBAL_AGENTS_DIR="$HOME/.claude/agents"
GLOBAL_COMMANDS_DIR="$HOME/.claude/commands"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"

echo "Claude Agents & Commands Uninstaller"
echo "====================================="
echo ""

# Auto-discover agents, commands, and skills from the plugin structure
# Same discovery logic as the installer

discover_agents() {
    local agents=()
    for plugin_dir in "$SCRIPT_DIR"/agents/*/; do
        if [[ -d "$plugin_dir/agents" ]]; then
            for agent_file in "$plugin_dir"/agents/*.md; do
                if [[ -f "$agent_file" ]]; then
                    agents+=("$(basename "$agent_file")")
                fi
            done
        fi
    done
    echo "${agents[@]}"
}

discover_commands() {
    local commands=()
    for plugin_dir in "$SCRIPT_DIR"/commands/*/; do
        if [[ -d "$plugin_dir/commands" ]]; then
            for command_file in "$plugin_dir"/commands/*.md; do
                if [[ -f "$command_file" ]]; then
                    commands+=("$(basename "$command_file")")
                fi
            done
        fi
    done
    echo "${commands[@]}"
}

discover_skills() {
    local skills=()
    for plugin_dir in "$SCRIPT_DIR"/skills/*/; do
        if [[ -d "$plugin_dir/skills" ]]; then
            for skill_dir in "$plugin_dir"/skills/*/; do
                if [[ -d "$skill_dir" ]] && [[ -f "$skill_dir/SKILL.md" ]]; then
                    skills+=("$(basename "${skill_dir%/}")")
                fi
            done
        fi
    done
    echo "${skills[@]}"
}

# Discover all plugins
AGENTS=($(discover_agents))
COMMANDS=($(discover_commands))
SKILLS=($(discover_skills))

echo "Found ${#AGENTS[@]} agents, ${#COMMANDS[@]} commands, ${#SKILLS[@]} skills to check"
echo ""

# Check if global directories exist
agents_dir_exists=false
commands_dir_exists=false
skills_dir_exists=false

if [[ -d "$GLOBAL_AGENTS_DIR" ]]; then
    agents_dir_exists=true
fi

if [[ -d "$GLOBAL_COMMANDS_DIR" ]]; then
    commands_dir_exists=true
fi

if [[ -d "$GLOBAL_SKILLS_DIR" ]]; then
    skills_dir_exists=true
fi

if [[ "$agents_dir_exists" == false ]] && [[ "$commands_dir_exists" == false ]] && [[ "$skills_dir_exists" == false ]]; then
    echo -e "${RED}Error: No global directories found.${NC}"
    echo "Nothing to uninstall."
    exit 1
fi

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

# Check which skills exist
existing_skills=()
if [[ "$skills_dir_exists" == true ]]; then
    for skill in "${SKILLS[@]}"; do
        if [[ -e "$GLOBAL_SKILLS_DIR/$skill" ]]; then
            existing_skills+=("$skill")
        fi
    done
fi

# Handle no files found
if [[ ${#existing_agents[@]} -eq 0 ]] && [[ ${#existing_commands[@]} -eq 0 ]] && [[ ${#existing_skills[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No agents, commands, or skills found to uninstall.${NC}"
    exit 0
fi

# Uninstall agents
agents_success=0
agents_fail=0

if [[ ${#existing_agents[@]} -gt 0 ]]; then
    echo "Uninstalling agents..."
    for agent in "${existing_agents[@]}"; do
        global_path="$GLOBAL_AGENTS_DIR/$agent"

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

        if rm -f "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Removed: $command${NC}"
            ((commands_success++))
        else
            echo -e "${RED}  ✗ Failed to remove: $command${NC}"
            ((commands_fail++))
        fi
    done
fi

# Uninstall skills
skills_success=0
skills_fail=0

if [[ ${#existing_skills[@]} -gt 0 ]]; then
    echo ""
    echo "Uninstalling skills..."
    for skill in "${existing_skills[@]}"; do
        global_path="$GLOBAL_SKILLS_DIR/$skill"

        if rm -rf "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Removed: $skill${NC}"
            ((skills_success++))
        else
            echo -e "${RED}  ✗ Failed to remove: $skill${NC}"
            ((skills_fail++))
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

if [[ ${#existing_skills[@]} -gt 0 ]]; then
    echo -e "${GREEN}Successfully uninstalled: $skills_success skills${NC}"
    if [[ $skills_fail -gt 0 ]]; then
        echo -e "${RED}Failed to uninstall: $skills_fail skills${NC}"
    fi
fi

total_fail=$((agents_fail + commands_fail + skills_fail))
if [[ $total_fail -eq 0 ]]; then
    echo ""
    echo "All agents, commands, and skills have been successfully removed!"
    echo "Restart your Claude Code terminal to reflect the changes."
fi

if [[ $total_fail -gt 0 ]]; then
    exit 1
fi
