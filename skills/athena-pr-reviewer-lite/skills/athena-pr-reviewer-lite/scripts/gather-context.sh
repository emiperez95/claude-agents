#!/bin/bash
# gather-context.sh - Parallel data gathering for PR review
# Usage: ./gather-context.sh <PR_NUMBER> [JIRA_TICKET]

set -e

PR_NUM="${1:?Usage: gather-context.sh <PR_NUMBER> [JIRA_TICKET]}"
JIRA_TICKET="${2:-}"
WORK_DIR="/tmp/athena-review-${PR_NUM}"

# Create work directory
mkdir -p "${WORK_DIR}/reviews"

echo "PR: #${PR_NUM}"
echo "Work dir: ${WORK_DIR}"
echo "---"

# Phase 1: Get PR metadata first (needed for file list and Jira extraction)
echo "Fetching PR metadata..."
gh pr view "$PR_NUM" --json title,body,author,baseRefName,headRefName,files,commits,reviews,comments,state,mergeable,url \
    > "${WORK_DIR}/pr.json" 2>/dev/null && echo "✓ PR metadata" || echo "✗ PR metadata failed"

# Extract file list for blame and prior comments
CHANGED_FILES=$(jq -r '.files[].path' "${WORK_DIR}/pr.json" 2>/dev/null || true)
echo "${CHANGED_FILES}" > "${WORK_DIR}/files.txt"

# Extract Jira ticket if not provided
if [[ -z "$JIRA_TICKET" ]]; then
    JIRA_TICKET=$(jq -r '[.title, .headRefName] | join(" ")' "${WORK_DIR}/pr.json" 2>/dev/null | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)
fi
echo "Jira: ${JIRA_TICKET:-not found}"
echo "Files changed: $(echo "$CHANGED_FILES" | wc -l | tr -d ' ')"
echo "---"

# Phase 2: Run everything else in parallel
echo "Gathering context in parallel..."
{
    # PR diff
    gh pr diff "$PR_NUM" > "${WORK_DIR}/diff.patch" 2>/dev/null &
    DIFF_PID=$!

    # CLAUDE.md project guidelines (find all in repo)
    find . -name "CLAUDE.md" -type f -exec echo "=== {} ===" \; -exec cat {} \; \
        > "${WORK_DIR}/guidelines.md" 2>/dev/null &
    GUIDELINES_PID=$!

    # Git blame for changed files (using pre-fetched file list)
    {
        while IFS= read -r file; do
            if [[ -n "$file" ]] && [[ -f "$file" ]]; then
                echo "=== $file ==="
                git blame --date=short "$file" 2>/dev/null | head -50
            fi
        done < "${WORK_DIR}/files.txt"
    } > "${WORK_DIR}/blame.md" 2>/dev/null &
    BLAME_PID=$!

    # Prior PR comments on same files (using pre-fetched file list)
    {
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                PRIOR_PRS=$(gh pr list --state merged --search "$file" --limit 3 --json number,title,url 2>/dev/null)
                if [[ -n "$PRIOR_PRS" ]] && [[ "$PRIOR_PRS" != "[]" ]]; then
                    echo "=== Prior PRs touching: $file ==="
                    echo "$PRIOR_PRS" | jq -r '.[] | "PR #\(.number): \(.title)"'
                    # Get comments from those PRs
                    echo "$PRIOR_PRS" | jq -r '.[].number' | while read -r pr_num; do
                        COMMENTS=$(gh pr view "$pr_num" --json reviews,comments --jq '[.reviews[].body, .comments[].body] | join("\n---\n")' 2>/dev/null)
                        if [[ -n "$COMMENTS" ]]; then
                            echo "--- Comments from PR #$pr_num ---"
                            echo "$COMMENTS" | head -100
                        fi
                    done
                fi
            fi
        done < "${WORK_DIR}/files.txt"
    } > "${WORK_DIR}/prior-comments.md" 2>/dev/null &
    PRIOR_PID=$!

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
    wait $DIFF_PID && echo "✓ PR diff" || echo "✗ PR diff failed"
    wait $GUIDELINES_PID && echo "✓ CLAUDE.md guidelines" || echo "✗ CLAUDE.md not found"
    wait $BLAME_PID && echo "✓ Git blame" || echo "✗ Git blame failed"
    wait $PRIOR_PID && echo "✓ Prior PR comments" || echo "✗ Prior PR comments failed"

    if [[ -n "$JIRA_TICKET" ]]; then
        wait $JIRA_PID && echo "✓ Jira ticket" || echo "✗ Jira ticket failed"
        if [[ -n "${EPIC_PID:-}" ]]; then
            wait $EPIC_PID && echo "✓ Epic context" || echo "✗ Epic context failed"
        fi
    fi
}

# Phase 3: Create combined context file
echo "---"
echo "Assembling context.md..."

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

if [[ -f "${WORK_DIR}/guidelines.md" ]] && [[ -s "${WORK_DIR}/guidelines.md" ]]; then
    cat >> "${WORK_DIR}/context.md" << 'CONTEXT_EOF'

## Project Guidelines (CLAUDE.md)
CONTEXT_EOF
    cat "${WORK_DIR}/guidelines.md" >> "${WORK_DIR}/context.md"
fi

if [[ -f "${WORK_DIR}/blame.md" ]] && [[ -s "${WORK_DIR}/blame.md" ]]; then
    cat >> "${WORK_DIR}/context.md" << 'CONTEXT_EOF'

## Git Blame (Historical Context)
CONTEXT_EOF
    cat "${WORK_DIR}/blame.md" >> "${WORK_DIR}/context.md"
fi

if [[ -f "${WORK_DIR}/prior-comments.md" ]] && [[ -s "${WORK_DIR}/prior-comments.md" ]]; then
    cat >> "${WORK_DIR}/context.md" << 'CONTEXT_EOF'

## Prior PR Comments (Past Feedback)
CONTEXT_EOF
    cat "${WORK_DIR}/prior-comments.md" >> "${WORK_DIR}/context.md"
fi

echo "---"
echo "✓ Context written to: ${WORK_DIR}/context.md"
echo "✓ Diff written to: ${WORK_DIR}/diff.patch"
echo "---"
ls -la "${WORK_DIR}/"
