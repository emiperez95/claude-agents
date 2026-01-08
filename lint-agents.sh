#!/bin/bash

# lint-agents.sh - Validate agent/command YAML frontmatter
# Usage: ./lint-agents.sh [--quiet] [file1.md file2.md ...]
# If no files specified, validates all agents and commands

# Don't use set -e as it breaks arithmetic expressions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUIET=false
ERRORS=0
VALIDATED=0

# Parse flags
while [[ "$1" == --* ]]; do
    case "$1" in
        --quiet|-q) QUIET=true; shift ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

# Python validation script (inline)
validate_yaml() {
    local file="$1"
    python3 << EOF
import sys
import yaml
import re

file_path = """$file"""

try:
    with open(file_path, 'r') as f:
        content = f.read()
except Exception as e:
    print(f"ERROR: Cannot read file: {e}")
    sys.exit(1)

# Check for frontmatter delimiters
if not content.startswith('---'):
    print("ERROR: File must start with '---' (YAML frontmatter)")
    sys.exit(1)

# Extract frontmatter
parts = content.split('---', 2)
if len(parts) < 3:
    print("ERROR: Missing closing '---' for frontmatter")
    sys.exit(1)

frontmatter = parts[1]

# Parse YAML
try:
    data = yaml.safe_load(frontmatter)
except yaml.YAMLError as e:
    # Extract line number if available
    if hasattr(e, 'problem_mark'):
        mark = e.problem_mark
        print(f"ERROR: Invalid YAML at line {mark.line + 2}, column {mark.column + 1}")
        print(f"  {e.problem}")
        # Show context
        lines = frontmatter.split('\n')
        if mark.line < len(lines):
            line_content = lines[mark.line]
            print(f"  Line: {line_content[:80]}{'...' if len(line_content) > 80 else ''}")
    else:
        print(f"ERROR: Invalid YAML: {e}")
    sys.exit(1)

if not isinstance(data, dict):
    print("ERROR: Frontmatter must be a YAML mapping")
    sys.exit(1)

# Check required fields
required = ['name', 'description']
missing = [f for f in required if f not in data or not data[f]]
if missing:
    print(f"ERROR: Missing required fields: {', '.join(missing)}")
    sys.exit(1)

# Check for common YAML pitfalls in description
desc = data.get('description', '')
if ': ' in desc:
    # Find potential problematic colons (word: followed by text that looks like a value)
    # This is a heuristic - not all colons are problems
    matches = re.findall(r'\b(\w+): (\w)', desc)
    for match in matches:
        # Skip common safe patterns like URLs (http: https:) or time (10:30)
        word = match[0].lower()
        if word not in ['http', 'https', 'mailto', 'tel', 'ftp']:
            print(f"WARNING: Description contains '{match[0]}: {match[1]}...' - may cause YAML parsing issues")
            print(f"  Consider removing the colon or quoting the entire description")

# Validate tools field if present
if 'tools' in data:
    tools = data['tools']
    if not isinstance(tools, str):
        print("ERROR: 'tools' field must be a comma-separated string")
        sys.exit(1)

# Validate name format
name = data.get('name', '')
if not re.match(r'^[a-z][a-z0-9-]*$', name):
    print(f"WARNING: Name '{name}' should be lowercase with hyphens only")

print("OK")
sys.exit(0)
EOF
}

# Discover files to validate
discover_files() {
    local files=()

    # Private agents
    for f in "$SCRIPT_DIR"/agents/*.md; do
        [[ -f "$f" ]] && files+=("$f")
    done

    # Public agents (cc-toolkit)
    for plugin_dir in "$SCRIPT_DIR"/cc-toolkit/agents/*/; do
        for f in "$plugin_dir"/agents/*.md; do
            [[ -f "$f" ]] && files+=("$f")
        done
    done

    # Private commands
    for f in "$SCRIPT_DIR"/commands/*.md; do
        [[ -f "$f" ]] && files+=("$f")
    done

    # Public commands (cc-toolkit)
    for plugin_dir in "$SCRIPT_DIR"/cc-toolkit/commands/*/; do
        for f in "$plugin_dir"/commands/*.md; do
            [[ -f "$f" ]] && files+=("$f")
        done
    done

    echo "${files[@]}"
}

# Main validation
if [[ $# -gt 0 ]]; then
    FILES=("$@")
else
    FILES=($(discover_files))
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "No files to validate"
    exit 0
fi

[[ "$QUIET" == false ]] && echo "Validating ${#FILES[@]} files..."
[[ "$QUIET" == false ]] && echo ""

for file in "${FILES[@]}"; do
    name=$(basename "$file")
    result=$(validate_yaml "$file" 2>&1)
    status=$?

    if [[ $status -eq 0 ]]; then
        ((VALIDATED++))
        if [[ "$QUIET" == false ]]; then
            if [[ "$result" == "OK" ]]; then
                echo -e "${GREEN}✓${NC} $name"
            else
                # Has warnings
                echo -e "${YELLOW}⚠${NC} $name"
                echo "$result" | grep -v "^OK$" | sed 's/^/    /'
            fi
        fi
    else
        ((ERRORS++))
        echo -e "${RED}✗${NC} $name"
        echo "$result" | sed 's/^/    /'
    fi
done

[[ "$QUIET" == false ]] && echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Validation failed: $ERRORS error(s), $VALIDATED passed${NC}"
    exit 1
else
    echo -e "${GREEN}Validation passed: $VALIDATED file(s)${NC}"
    exit 0
fi
