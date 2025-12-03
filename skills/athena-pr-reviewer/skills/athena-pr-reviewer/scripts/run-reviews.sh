#!/bin/bash
# run-reviews.sh - Run Gemini and Codex reviews in parallel
# Usage: ./run-reviews.sh <WORK_DIR>

set -e

WORK_DIR="${1:?Usage: run-reviews.sh <WORK_DIR>}"

if [[ ! -d "$WORK_DIR" ]]; then
    echo "Error: Work directory not found: $WORK_DIR"
    exit 1
fi

if [[ ! -f "${WORK_DIR}/context.md" ]] || [[ ! -f "${WORK_DIR}/diff.patch" ]]; then
    echo "Error: context.md or diff.patch not found in $WORK_DIR"
    exit 1
fi

# Create reviews directory
mkdir -p "${WORK_DIR}/reviews"

echo "Running Gemini + Codex reviews in parallel..."
echo "Work dir: ${WORK_DIR}"
echo "---"

# Check for Gemini CLI
GEMINI_AVAILABLE=false
if command -v gemini &>/dev/null; then
    GEMINI_AVAILABLE=true
else
    echo "⚠ Gemini CLI not installed - skipping Gemini review"
    echo "  Install with: npm install -g @google/gemini-cli"
    echo "  Gemini review skipped - CLI not installed" > "${WORK_DIR}/reviews/gemini.md"
fi

# Check for Codex CLI
CODEX_AVAILABLE=false
if command -v codex &>/dev/null; then
    CODEX_AVAILABLE=true
else
    echo "⚠ Codex CLI not installed - skipping Codex review"
    echo "  Install with: npm install -g @openai/codex"
    echo "  Codex review skipped - CLI not installed" > "${WORK_DIR}/reviews/codex.md"
fi

# Run available reviews in parallel
{
    # Gemini Review
    if [[ "$GEMINI_AVAILABLE" == true ]]; then
        gemini -p "You are a senior code reviewer. Review this PR against the requirements.

@${WORK_DIR}/context.md
@${WORK_DIR}/diff.patch

IGNORE: approval status, rebase needs.
LOW PRIORITY: merge conflicts (note if present, but focus on code quality).

For each finding specify: file, line, severity (Critical/High/Medium/Low), confidence (0-100), description, suggested fix.

Output as structured markdown." > "${WORK_DIR}/reviews/gemini.md" 2>/dev/null &
        GEMINI_PID=$!
    fi

    # Codex Review
    if [[ "$CODEX_AVAILABLE" == true ]]; then
        codex exec "You are a senior code reviewer. Review this PR against the requirements.

Read context.md for Jira requirements and PR metadata.
Read diff.patch for the actual code changes.

IGNORE: approval status, rebase needs.
LOW PRIORITY: merge conflicts (note if present, but focus on code quality).

Analyze:
1. Requirements alignment - does code fulfill acceptance criteria?
2. Code quality - patterns, readability, maintainability
3. Potential bugs - edge cases, error handling
4. Security concerns - input validation, auth, data exposure
5. Performance - inefficiencies, N+1 queries
6. Test coverage - are changes tested?

For each finding specify: file, line, severity (Critical/High/Medium/Low), confidence (0-100), description, suggested fix.

Output as structured markdown." \
    -C "${WORK_DIR}" \
    --skip-git-repo-check \
    -o "${WORK_DIR}/reviews/codex.md" 2>/dev/null &
        CODEX_PID=$!
    fi

    # Wait for available reviews
    if [[ "$GEMINI_AVAILABLE" == true ]]; then
        wait $GEMINI_PID && echo "✓ Gemini review complete" || echo "✗ Gemini review failed"
    fi
    if [[ "$CODEX_AVAILABLE" == true ]]; then
        wait $CODEX_PID && echo "✓ Codex review complete" || echo "✗ Codex review failed"
    fi
}

echo "---"
echo "Reviews saved to:"
ls -la "${WORK_DIR}/reviews/"
