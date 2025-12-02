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

echo "Running Gemini + Codex reviews in parallel..."
echo "Work dir: ${WORK_DIR}"
echo "---"

# Run Gemini and Codex in parallel
{
    # Gemini Review
    ASDF_NODEJS_VERSION=22.20.0 gemini -p "You are a senior code reviewer. Review this PR against the requirements.

@${WORK_DIR}/context.md
@${WORK_DIR}/diff.patch

IGNORE: approval status, rebase needs.
LOW PRIORITY: merge conflicts (note if present, but focus on code quality).

For each finding specify: file, line, severity (Critical/High/Medium/Low), confidence (0-100), description, suggested fix.

Output as structured markdown." > "${WORK_DIR}/reviews/gemini.md" 2>/dev/null &
    GEMINI_PID=$!

    # Codex Review
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

    # Wait for both
    wait $GEMINI_PID && echo "✓ Gemini review complete" || echo "✗ Gemini review failed"
    wait $CODEX_PID && echo "✓ Codex review complete" || echo "✗ Codex review failed"
}

echo "---"
echo "Reviews saved to:"
ls -la "${WORK_DIR}/reviews/"
