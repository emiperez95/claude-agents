#!/bin/bash
# gather-context.sh - Parallel data gathering for PR review
# Usage: ./gather-context.sh <PR_NUMBER> [JIRA_TICKET]

set -e

PR_NUM="${1:?Usage: gather-context.sh <PR_NUMBER> [JIRA_TICKET]}"
JIRA_TICKET="${2:-}"
WORK_DIR="/tmp/athena-review-${PR_NUM}"

# Create work directory
mkdir -p "${WORK_DIR}/reviews"

# If no Jira ticket provided, try to extract from PR or branch
if [[ -z "$JIRA_TICKET" ]]; then
    # Try from PR title/branch
    JIRA_TICKET=$(gh pr view "$PR_NUM" --json title,headRefName --jq '[.title, .headRefName] | join(" ")' 2>/dev/null | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)
fi

echo "PR: #${PR_NUM}"
echo "Jira: ${JIRA_TICKET:-not found}"
echo "Work dir: ${WORK_DIR}"
echo "---"

# Run data gathering in parallel
{
    # PR metadata
    gh pr view "$PR_NUM" --json title,body,author,baseRefName,headRefName,files,commits,reviews,comments,state,mergeable,url \
        > "${WORK_DIR}/pr.json" 2>/dev/null &
    PR_PID=$!

    # PR diff
    gh pr diff "$PR_NUM" > "${WORK_DIR}/diff.patch" 2>/dev/null &
    DIFF_PID=$!

    # Jira context (if ticket found)
    if [[ -n "$JIRA_TICKET" ]]; then
        acli jira workitem view "$JIRA_TICKET" --fields '*all' --json \
            > "${WORK_DIR}/jira.json" 2>/dev/null &
        JIRA_PID=$!

        # Get epic if linked
        EPIC_KEY=$(acli jira workitem view "$JIRA_TICKET" --json 2>/dev/null | jq -r '.fields.parent.key // .fields.customfield_10014 // empty' || true)
        if [[ -n "$EPIC_KEY" ]]; then
            acli jira workitem view "$EPIC_KEY" --fields '*all' --json \
                > "${WORK_DIR}/epic.json" 2>/dev/null &
            EPIC_PID=$!
        fi
    fi

    # Wait for all background jobs
    wait $PR_PID && echo "✓ PR metadata" || echo "✗ PR metadata failed"
    wait $DIFF_PID && echo "✓ PR diff" || echo "✗ PR diff failed"

    if [[ -n "$JIRA_TICKET" ]]; then
        wait $JIRA_PID && echo "✓ Jira ticket" || echo "✗ Jira ticket failed"
        if [[ -n "${EPIC_PID:-}" ]]; then
            wait $EPIC_PID && echo "✓ Epic context" || echo "✗ Epic context failed"
        fi
    fi
}

# Create combined context file
cat > "${WORK_DIR}/context.md" << 'CONTEXT_EOF'
# PR Review Context

## PR Metadata
CONTEXT_EOF

if [[ -f "${WORK_DIR}/pr.json" ]]; then
    cat "${WORK_DIR}/pr.json" >> "${WORK_DIR}/context.md"
fi

cat >> "${WORK_DIR}/context.md" << 'CONTEXT_EOF'

## Jira Requirements
CONTEXT_EOF

if [[ -f "${WORK_DIR}/jira.json" ]]; then
    cat "${WORK_DIR}/jira.json" >> "${WORK_DIR}/context.md"
else
    echo "No Jira ticket found" >> "${WORK_DIR}/context.md"
fi

if [[ -f "${WORK_DIR}/epic.json" ]]; then
    cat >> "${WORK_DIR}/context.md" << 'CONTEXT_EOF'

## Epic Context
CONTEXT_EOF
    cat "${WORK_DIR}/epic.json" >> "${WORK_DIR}/context.md"
fi

echo "---"
echo "Context written to: ${WORK_DIR}/context.md"
echo "Diff written to: ${WORK_DIR}/diff.patch"
ls -la "${WORK_DIR}/"
