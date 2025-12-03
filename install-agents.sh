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

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

# Exclude list - these are for marketplace distribution only, not local dev
EXCLUDE_SKILLS=("athena-pr-reviewer-lite")

echo "Claude Agents & Commands Installer"
echo "==================================="
echo ""

# Auto-discover agents, commands, and skills from the new plugin structure
# Structure: agents/<plugin-name>/agents/<agent-name>.md
#            commands/<plugin-name>/commands/<command-name>.md
#            skills/<plugin-name>/skills/<skill-name>/SKILL.md

discover_agents() {
    local agents=()
    for plugin_dir in "$SCRIPT_DIR"/agents/*/; do
        if [[ -d "$plugin_dir/agents" ]]; then
            for agent_file in "$plugin_dir"/agents/*.md; do
                if [[ -f "$agent_file" ]]; then
                    agents+=("$agent_file")
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
                    commands+=("$command_file")
                fi
            done
        fi
    done
    echo "${commands[@]}"
}

is_excluded_skill() {
    local skill_name="$1"
    for excluded in "${EXCLUDE_SKILLS[@]}"; do
        if [[ "$skill_name" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

discover_skills() {
    local skills=()
    for plugin_dir in "$SCRIPT_DIR"/skills/*/; do
        if [[ -d "$plugin_dir/skills" ]]; then
            for skill_dir in "$plugin_dir"/skills/*/; do
                if [[ -d "$skill_dir" ]] && [[ -f "$skill_dir/SKILL.md" ]]; then
                    skill_name=$(basename "${skill_dir%/}")
                    if ! is_excluded_skill "$skill_name"; then
                        skills+=("$skill_dir")
                    fi
                fi
            done
        fi
    done
    echo "${skills[@]}"
}

# Discover all plugins
AGENT_PATHS=($(discover_agents))
COMMAND_PATHS=($(discover_commands))
SKILL_PATHS=($(discover_skills))

echo "Discovered ${#AGENT_PATHS[@]} agents, ${#COMMAND_PATHS[@]} commands, ${#SKILL_PATHS[@]} skills"
echo ""

# Create global directories if they don't exist
mkdir -p "$GLOBAL_AGENTS_DIR" "$GLOBAL_COMMANDS_DIR" "$GLOBAL_SKILLS_DIR"

# Extract basenames for checking existing files
get_basename() {
    basename "$1"
}

# Check for existing files
existing_agents=()
for agent_path in "${AGENT_PATHS[@]}"; do
    agent_name=$(basename "$agent_path")
    if [[ -e "$GLOBAL_AGENTS_DIR/$agent_name" ]]; then
        existing_agents+=("$agent_name")
    fi
done

existing_commands=()
for command_path in "${COMMAND_PATHS[@]}"; do
    command_name=$(basename "$command_path")
    if [[ -e "$GLOBAL_COMMANDS_DIR/$command_name" ]]; then
        existing_commands+=("$command_name")
    fi
done

existing_skills=()
for skill_path in "${SKILL_PATHS[@]}"; do
    # Remove trailing slash and get basename
    skill_name=$(basename "${skill_path%/}")
    if [[ -e "$GLOBAL_SKILLS_DIR/$skill_name" ]]; then
        existing_skills+=("$skill_name")
    fi
done

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

if [[ ${#existing_skills[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Found existing skills in global directory:${NC}"
    for skill in "${existing_skills[@]}"; do
        echo "  - $skill"
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
        for skill in "${existing_skills[@]}"; do
            rm -rf "$GLOBAL_SKILLS_DIR/$skill"
            echo "  Removed skill: $skill"
        done
        echo ""
    fi
fi

# Install agents as file-level symbolic links
echo "Installing agents as file-level symbolic links..."
agents_success=0
agents_fail=0

for agent_path in "${AGENT_PATHS[@]}"; do
    agent_name=$(basename "$agent_path")
    global_path="$GLOBAL_AGENTS_DIR/$agent_name"

    if ln -s "$agent_path" "$global_path" 2>/dev/null; then
        echo -e "${GREEN}  ✓ $agent_name${NC}"
        ((agents_success++))
    else
        echo -e "${RED}  ✗ $agent_name - Failed to create symbolic link${NC}"
        ((agents_fail++))
    fi
done

# Install commands as file-level symbolic links
commands_success=0
commands_fail=0

if [[ ${#COMMAND_PATHS[@]} -gt 0 ]]; then
    echo ""
    echo "Installing commands as file-level symbolic links..."

    for command_path in "${COMMAND_PATHS[@]}"; do
        command_name=$(basename "$command_path")
        global_path="$GLOBAL_COMMANDS_DIR/$command_name"

        if ln -s "$command_path" "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $command_name${NC}"
            ((commands_success++))
        else
            echo -e "${RED}  ✗ $command_name - Failed to create symbolic link${NC}"
            ((commands_fail++))
        fi
    done
fi

# Install skills as folder-level symbolic links
skills_success=0
skills_fail=0

if [[ ${#SKILL_PATHS[@]} -gt 0 ]]; then
    echo ""
    echo "Installing skills as folder-level symbolic links..."

    for skill_path in "${SKILL_PATHS[@]}"; do
        # Remove trailing slash
        skill_path="${skill_path%/}"
        skill_name=$(basename "$skill_path")
        global_path="$GLOBAL_SKILLS_DIR/$skill_name"

        if ln -s "$skill_path" "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $skill_name${NC}"
            ((skills_success++))
        else
            echo -e "${RED}  ✗ $skill_name - Failed to create symbolic link${NC}"
            ((skills_fail++))
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

echo -e "${GREEN}Successfully installed: $commands_success commands${NC}"
if [[ $commands_fail -gt 0 ]]; then
    echo -e "${RED}Failed to install: $commands_fail commands${NC}"
fi

echo -e "${GREEN}Successfully installed: $skills_success skills${NC}"
if [[ $skills_fail -gt 0 ]]; then
    echo -e "${RED}Failed to install: $skills_fail skills${NC}"
fi

total_fail=$((agents_fail + commands_fail + skills_fail))
if [[ $total_fail -eq 0 ]]; then
    echo ""
    echo "All agents, commands, and skills have been successfully linked!"
    echo ""
    echo "Note: Agents and commands are file-level symlinks, skills are folder-level symlinks."
    echo "Changes to local files are immediately reflected after restarting Claude Code."
    echo ""
    echo "Restart your Claude Code terminal to load the new agents, commands, and skills."
fi

if [[ $total_fail -gt 0 ]]; then
    exit 1
fi
