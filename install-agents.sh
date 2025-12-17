#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (where this script is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Global directories
GLOBAL_AGENTS_DIR="$HOME/.claude/agents"
GLOBAL_COMMANDS_DIR="$HOME/.claude/commands"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
GLOBAL_HOOKS_DIR="$HOME/.claude/hooks"

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

# Skills to exclude from local installation (marketplace-only)
EXCLUDE_SKILLS=("athena-pr-reviewer-lite")

is_excluded_skill() {
    local skill_name="$1"
    for excluded in "${EXCLUDE_SKILLS[@]}"; do
        if [[ "$skill_name" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

echo "Claude Agents & Commands Installer"
echo "==================================="
echo ""

# Auto-discover agents, commands, and skills from both:
# 1. Private (flat structure): agents/*.md, commands/*.md, skills/*/SKILL.md
# 2. Public (plugin structure): cc-toolkit/agents/*/agents/*.md, etc.

discover_agents() {
    local agents=()

    # Private: flat files in agents/
    for agent_file in "$SCRIPT_DIR"/agents/*.md; do
        if [[ -f "$agent_file" ]]; then
            agents+=("$agent_file")
        fi
    done

    # Public: nested plugin structure in cc-toolkit/
    if [[ -d "$SCRIPT_DIR/cc-toolkit/agents" ]]; then
        for plugin_dir in "$SCRIPT_DIR"/cc-toolkit/agents/*/; do
            if [[ -d "$plugin_dir/agents" ]]; then
                for agent_file in "$plugin_dir"/agents/*.md; do
                    if [[ -f "$agent_file" ]]; then
                        agents+=("$agent_file")
                    fi
                done
            fi
        done
    fi

    echo "${agents[@]}"
}

discover_commands() {
    local commands=()

    # Private: flat files in commands/
    for command_file in "$SCRIPT_DIR"/commands/*.md; do
        if [[ -f "$command_file" ]]; then
            commands+=("$command_file")
        fi
    done

    # Public: nested plugin structure in cc-toolkit/
    if [[ -d "$SCRIPT_DIR/cc-toolkit/commands" ]]; then
        for plugin_dir in "$SCRIPT_DIR"/cc-toolkit/commands/*/; do
            if [[ -d "$plugin_dir/commands" ]]; then
                for command_file in "$plugin_dir"/commands/*.md; do
                    if [[ -f "$command_file" ]]; then
                        commands+=("$command_file")
                    fi
                done
            fi
        done
    fi

    echo "${commands[@]}"
}

discover_skills() {
    local skills=()

    # Private: skills/*/SKILL.md (folder with SKILL.md inside)
    for skill_dir in "$SCRIPT_DIR"/skills/*/; do
        if [[ -d "$skill_dir" ]] && [[ -f "$skill_dir/SKILL.md" ]]; then
            skill_name=$(basename "${skill_dir%/}")
            if ! is_excluded_skill "$skill_name"; then
                skills+=("$skill_dir")
            fi
        fi
    done

    # Public: nested plugin structure in cc-toolkit/
    if [[ -d "$SCRIPT_DIR/cc-toolkit/skills" ]]; then
        for plugin_dir in "$SCRIPT_DIR"/cc-toolkit/skills/*/; do
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
    fi

    echo "${skills[@]}"
}

discover_hooks() {
    local hooks=()

    # Private: hooks/ directory at root
    if [[ -d "$SCRIPT_DIR/hooks" ]]; then
        for hook_file in "$SCRIPT_DIR"/hooks/*.sh; do
            if [[ -f "$hook_file" ]]; then
                hooks+=("$hook_file")
            fi
        done
    fi

    # Public: hooks in plugin directories (cc-toolkit/*/hooks/ or cc-toolkit/skills/*/hooks/)
    if [[ -d "$SCRIPT_DIR/cc-toolkit" ]]; then
        # Check for hooks in skill plugins
        for plugin_dir in "$SCRIPT_DIR"/cc-toolkit/skills/*/; do
            if [[ -d "$plugin_dir/hooks" ]]; then
                for hook_file in "$plugin_dir"/hooks/*.sh; do
                    if [[ -f "$hook_file" ]]; then
                        hooks+=("$hook_file")
                    fi
                done
            fi
        done
        # Check for hooks in agent plugins
        for plugin_dir in "$SCRIPT_DIR"/cc-toolkit/agents/*/; do
            if [[ -d "$plugin_dir/hooks" ]]; then
                for hook_file in "$plugin_dir"/hooks/*.sh; do
                    if [[ -f "$hook_file" ]]; then
                        hooks+=("$hook_file")
                    fi
                done
            fi
        done
    fi

    echo "${hooks[@]}"
}

# Discover all plugins
AGENT_PATHS=($(discover_agents))
COMMAND_PATHS=($(discover_commands))
SKILL_PATHS=($(discover_skills))
HOOK_PATHS=($(discover_hooks))

echo -e "${BLUE}Sources:${NC}"
echo "  Private: $SCRIPT_DIR/{agents,commands,skills,hooks}/ (flat)"
echo "  Public:  $SCRIPT_DIR/cc-toolkit/ (plugin format)"
echo ""
echo "Discovered ${#AGENT_PATHS[@]} agents, ${#COMMAND_PATHS[@]} commands, ${#SKILL_PATHS[@]} skills, ${#HOOK_PATHS[@]} hooks"
echo ""

# Create global directories if they don't exist
mkdir -p "$GLOBAL_AGENTS_DIR" "$GLOBAL_COMMANDS_DIR" "$GLOBAL_SKILLS_DIR" "$GLOBAL_HOOKS_DIR"

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

existing_hooks=()
for hook_path in "${HOOK_PATHS[@]}"; do
    hook_name=$(basename "$hook_path")
    if [[ -e "$GLOBAL_HOOKS_DIR/$hook_name" ]]; then
        existing_hooks+=("$hook_name")
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

if [[ ${#existing_hooks[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Found existing hooks in global directory:${NC}"
    for hook in "${existing_hooks[@]}"; do
        echo "  - $hook"
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
        for hook in "${existing_hooks[@]}"; do
            rm -f "$GLOBAL_HOOKS_DIR/$hook"
            echo "  Removed hook: $hook"
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
    # Indicate source (private or public)
    if [[ "$agent_path" == *"/cc-toolkit/"* ]]; then
        source_label="public"
    else
        source_label="private"
    fi

    if ln -s "$agent_path" "$global_path" 2>/dev/null; then
        echo -e "${GREEN}  ✓ $agent_name${NC} ($source_label)"
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
        # Indicate source (private or public)
        if [[ "$command_path" == *"/cc-toolkit/"* ]]; then
            source_label="public"
        else
            source_label="private"
        fi

        if ln -s "$command_path" "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $command_name${NC} ($source_label)"
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
        # Indicate source (private or public)
        if [[ "$skill_path" == *"/cc-toolkit/"* ]]; then
            source_label="public"
        else
            source_label="private"
        fi

        if ln -s "$skill_path" "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $skill_name${NC} ($source_label)"
            ((skills_success++))
        else
            echo -e "${RED}  ✗ $skill_name - Failed to create symbolic link${NC}"
            ((skills_fail++))
        fi
    done
fi

# Install hooks as file-level symbolic links AND register in settings.json
hooks_success=0
hooks_fail=0

if [[ ${#HOOK_PATHS[@]} -gt 0 ]]; then
    echo ""
    echo "Installing hooks as file-level symbolic links..."

    for hook_path in "${HOOK_PATHS[@]}"; do
        hook_name=$(basename "$hook_path")
        global_path="$GLOBAL_HOOKS_DIR/$hook_name"
        # Indicate source (private or public)
        if [[ "$hook_path" == *"/cc-toolkit/"* ]]; then
            source_label="public"
        else
            source_label="private"
        fi

        if ln -s "$hook_path" "$global_path" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $hook_name${NC} ($source_label)"
            ((hooks_success++))
        else
            echo -e "${RED}  ✗ $hook_name - Failed to create symbolic link${NC}"
            ((hooks_fail++))
        fi
    done

    # Register hooks in settings.json for local dev
    # (Plugin marketplace installs use hooks/hooks.json automatically)
    echo ""
    echo "Registering hooks in settings.json..."
    SETTINGS_FILE="$HOME/.claude/settings.json"

    for hook_path in "${HOOK_PATHS[@]}"; do
        hook_name=$(basename "$hook_path")
        global_hook_path="$GLOBAL_HOOKS_DIR/$hook_name"

        # Check if this hook is already registered
        if grep -q "$hook_name" "$SETTINGS_FILE" 2>/dev/null; then
            echo -e "${YELLOW}  ⊘ $hook_name already registered${NC}"
        else
            # Add PermissionRequest hook entry using jq
            if command -v jq &>/dev/null; then
                # Create the hook entry
                tmp_file=$(mktemp)
                jq --arg cmd "$global_hook_path" '
                  .hooks.PermissionRequest //= [] |
                  .hooks.PermissionRequest += [{
                    "hooks": [{
                      "type": "command",
                      "command": $cmd
                    }]
                  }]
                ' "$SETTINGS_FILE" > "$tmp_file" && mv "$tmp_file" "$SETTINGS_FILE"
                echo -e "${GREEN}  ✓ $hook_name registered in settings.json${NC}"
            else
                echo -e "${YELLOW}  ⚠ jq not installed - manually add hook to settings.json:${NC}"
                echo "    PermissionRequest: $global_hook_path"
            fi
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

echo -e "${GREEN}Successfully installed: $hooks_success hooks${NC}"
if [[ $hooks_fail -gt 0 ]]; then
    echo -e "${RED}Failed to install: $hooks_fail hooks${NC}"
fi

total_fail=$((agents_fail + commands_fail + skills_fail + hooks_fail))
if [[ $total_fail -eq 0 ]]; then
    echo ""
    echo "All agents, commands, skills, and hooks have been successfully linked!"
    echo ""
    echo "Note: Agents, commands, and hooks are file-level symlinks, skills are folder-level symlinks."
    echo "Changes to local files are immediately reflected after restarting Claude Code."
    echo ""
    echo "Restart your Claude Code terminal to load the new agents, commands, skills, and hooks."
fi

if [[ $total_fail -gt 0 ]]; then
    exit 1
fi
