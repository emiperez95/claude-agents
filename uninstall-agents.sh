#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Global agents directory (now a real directory, not a symlink)
GLOBAL_AGENTS_DIR="$HOME/.claude/agents"

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

echo "Claude Agents Uninstaller"
echo "========================"
echo ""

# Check if global agents directory exists
if [[ ! -d "$GLOBAL_AGENTS_DIR" ]]; then
    echo -e "${RED}Error: Global agents directory not found at $GLOBAL_AGENTS_DIR${NC}"
    echo "Nothing to uninstall."
    exit 1
fi

echo "Global agents directory: $GLOBAL_AGENTS_DIR"
echo ""

# Check which agents exist
existing_agents=()
for agent in "${AGENTS[@]}"; do
    if [[ -e "$GLOBAL_AGENTS_DIR/$agent" ]]; then
        existing_agents+=("$agent")
    fi
done

# Handle no agents found
if [[ ${#existing_agents[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No agents found to uninstall.${NC}"
    exit 0
fi

# Uninstall agents
echo "Uninstalling agents..."
success_count=0
fail_count=0

for agent in "${existing_agents[@]}"; do
    global_path="$GLOBAL_AGENTS_DIR/$agent"

    # Remove the agent symlink
    if rm -f "$global_path" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Removed: $agent${NC}"
        ((success_count++))
    else
        echo -e "${RED}  ✗ Failed to remove: $agent${NC}"
        ((fail_count++))
    fi
done

echo ""
echo "Uninstall Summary"
echo "================="
echo -e "${GREEN}Successfully uninstalled: $success_count agents${NC}"
if [[ $fail_count -gt 0 ]]; then
    echo -e "${RED}Failed to uninstall: $fail_count agents${NC}"
else
    echo ""
    echo "All agents have been successfully removed!"
    echo "Restart your Claude Code terminal to reflect the changes."
fi

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi