#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory (where this script is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOCAL_AGENTS_DIR="${SCRIPT_DIR}/agents"

# Global agents directory
GLOBAL_AGENTS_DIR="$HOME/.claude/agents"
# Real path of the global directory (resolving symlinks)
REAL_GLOBAL_DIR="$(readlink -f "$GLOBAL_AGENTS_DIR" 2>/dev/null || echo "$GLOBAL_AGENTS_DIR")"

# Our agents
AGENTS=(
    "atlas-jira-analyst.md"
    "heimdall-pr-guardian.md"
    "hermes-pr-courier.md"
    "minerva-notion-oracle.md"
)

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" ]]; then
    FORCE=true
fi

echo "Claude Agents Installer"
echo "======================"
echo ""

# Check if local agents directory exists
if [[ ! -d "$LOCAL_AGENTS_DIR" ]]; then
    echo -e "${RED}Error: Local agents directory not found at $LOCAL_AGENTS_DIR${NC}"
    exit 1
fi

# Check if global agents directory exists
if [[ ! -d "$REAL_GLOBAL_DIR" ]]; then
    echo -e "${RED}Error: Global agents directory not found at $GLOBAL_AGENTS_DIR${NC}"
    echo "Please ensure Claude Code is properly installed."
    exit 1
fi

echo "Local agents directory: $LOCAL_AGENTS_DIR"
echo "Global agents directory: $REAL_GLOBAL_DIR"
echo ""

# Check if agents already exist
existing_agents=()
for agent in "${AGENTS[@]}"; do
    if [[ -e "$REAL_GLOBAL_DIR/$agent" ]]; then
        existing_agents+=("$agent")
    fi
done

# Handle existing agents
if [[ ${#existing_agents[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Found existing agents in global directory:${NC}"
    for agent in "${existing_agents[@]}"; do
        echo "  - $agent"
    done
    echo ""
    
    if [[ "$FORCE" == false ]]; then
        echo -e "${RED}Error: Agents already exist in global directory.${NC}"
        echo "Use --force flag to overwrite existing agents:"
        echo "  ./install-agents.sh --force"
        exit 1
    else
        echo -e "${YELLOW}Force flag detected. Removing existing agents...${NC}"
        for agent in "${existing_agents[@]}"; do
            rm -f "$REAL_GLOBAL_DIR/$agent"
            echo "  Removed: $agent"
        done
        echo ""
    fi
fi

# Install agents as symbolic links
echo "Installing agents as symbolic links..."
success_count=0
fail_count=0

for agent in "${AGENTS[@]}"; do
    local_path="$LOCAL_AGENTS_DIR/$agent"
    global_path="$REAL_GLOBAL_DIR/$agent"
    
    if [[ ! -f "$local_path" ]]; then
        echo -e "${RED}  ✗ $agent - Local file not found${NC}"
        ((fail_count++))
        continue
    fi
    
    # Create symbolic link
    if ln -s "$local_path" "$global_path" 2>/dev/null; then
        echo -e "${GREEN}  ✓ $agent${NC}"
        ((success_count++))
    else
        echo -e "${RED}  ✗ $agent - Failed to create symbolic link${NC}"
        ((fail_count++))
    fi
done

echo ""
echo "Installation Summary"
echo "==================="
echo -e "${GREEN}Successfully installed: $success_count agents${NC}"
if [[ $fail_count -gt 0 ]]; then
    echo -e "${RED}Failed to install: $fail_count agents${NC}"
else
    echo ""
    echo "All agents have been successfully linked!"
    echo "Restart your Claude Code terminal to load the new agents."
fi

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi