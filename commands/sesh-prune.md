---
name: sesh-prune
description: Prune sesh sessions for completed or out-of-sprint Jira tickets
argument-hint: "[PROJECT]"
---

# Sesh Session Pruning

Identify and remove sesh sessions that are no longer needed based on Jira ticket status or merged PR status.

## Deletion Criteria

**Sessions with Jira ticket:**
- **My ticket AND Done** - Work is complete
- **Other's ticket AND (Product Review OR Done)** - Review work is complete
- **Not in current sprint** - Stale session from previous sprints

**Sessions without Jira ticket:**
- **Branch has merged PR** - Work is complete

## Execution

Run this bash command to identify sessions to prune:

```bash
#!/bin/bash
PROJECT="${1:-CSD}"

# Get current user's display name
CURRENT_USER=$(acli jira workitem search --jql "project = $PROJECT AND assignee = currentUser()" --json --limit 1 2>/dev/null | jq -r '.[0].fields.assignee.displayName // empty')
if [ -z "$CURRENT_USER" ]; then
  CURRENT_USER="__NO_MATCH__"
fi

# Get all sesh sessions
SESH_LIST=$(sesh-cmd list 2>/dev/null || echo "")

# Get all tickets in open sprints (to check what's NOT in sprint)
SPRINT_TICKETS=$(acli jira workitem search \
  --jql "project = $PROJECT AND sprint in openSprints()" \
  --json --paginate 2>/dev/null)

# Process: find sessions to prune
RESULT=$(echo "$SESH_LIST" | while read -r session; do
  # Extract ticket key from session name (e.g., CSD-1234)
  TICKET=$(echo "$session" | grep -oE "${PROJECT}-[0-9]+" | head -1)

  if [ -n "$TICKET" ]; then
    # Session HAS ticket key - check Jira status
    TICKET_DATA=$(echo "$SPRINT_TICKETS" | jq -r --arg key "$TICKET" '.[] | select(.key == $key)')

    if [ -z "$TICKET_DATA" ]; then
      # Not in sprint - prune it
      echo "$session|$TICKET|Not in sprint"
    else
      # In sprint - check status and assignee
      STATUS=$(echo "$TICKET_DATA" | jq -r '.fields.status.name')
      ASSIGNEE=$(echo "$TICKET_DATA" | jq -r '.fields.assignee.displayName // ""')

      if [ "$ASSIGNEE" = "$CURRENT_USER" ] && [ "$STATUS" = "Done" ]; then
        echo "$session|$TICKET|Done (my ticket)"
      elif [ "$ASSIGNEE" != "$CURRENT_USER" ]; then
        if [ "$STATUS" = "Product Review" ] || [ "$STATUS" = "Done" ]; then
          echo "$session|$TICKET|$STATUS (other's ticket)"
        fi
      fi
    fi
  else
    # Session has NO ticket key - check for merged PR
    WORKTREE_PATH=$(echo "$session" | sed 's/.*→ *//' | sed 's/\x1b\[[0-9;]*m//g')

    if [ -d "$WORKTREE_PATH" ]; then
      BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current 2>/dev/null)

      if [ -n "$BRANCH" ]; then
        MERGED_PR=$(gh pr list --repo wyeworks/clear-session --state merged --head "$BRANCH" --json number 2>/dev/null)
        if [ -n "$MERGED_PR" ] && [ "$MERGED_PR" != "[]" ]; then
          echo "$session|$BRANCH|Merged PR (no ticket)"
        fi
      fi
    fi
  fi
done)

# Output results
if [ -z "$RESULT" ]; then
  echo "No sessions to prune."
  exit 0
fi

# Group results by reason category
MY_DONE=$(echo "$RESULT" | grep "|Done (my ticket)$" || true)
OTHERS=$(echo "$RESULT" | grep -E "\|(Product Review|Done) \(other's ticket\)$" || true)
NOT_IN_SPRINT=$(echo "$RESULT" | grep "|Not in sprint$" || true)
MERGED_PR=$(echo "$RESULT" | grep "|Merged PR (no ticket)$" || true)

COUNT=$(echo "$RESULT" | wc -l | tr -d ' ')

# Track letter index across all groups
IDX=0

echo "# Sessions to Prune ($COUNT)"
echo ""

if [ -n "$MY_DONE" ]; then
  MY_COUNT=$(echo "$MY_DONE" | wc -l | tr -d ' ')
  echo "## My tickets - Done ($MY_COUNT)"
  while IFS='|' read -r session ticket reason; do
    SESSION_NAME=$(echo "$session" | sed 's/ \x1b\[0;36m→.*//' | sed 's/ →.*//')
    CHAR=$(printf "\\$(printf '%03o' $((65 + IDX)))")
    echo "$CHAR. $SESSION_NAME ($ticket)"
    IDX=$((IDX + 1))
  done <<< "$MY_DONE"
  echo ""
fi

if [ -n "$OTHERS" ]; then
  OTHERS_COUNT=$(echo "$OTHERS" | wc -l | tr -d ' ')
  echo "## Other's tickets - Product Review/Done ($OTHERS_COUNT)"
  while IFS='|' read -r session ticket reason; do
    SESSION_NAME=$(echo "$session" | sed 's/ \x1b\[0;36m→.*//' | sed 's/ →.*//')
    CHAR=$(printf "\\$(printf '%03o' $((65 + IDX)))")
    echo "$CHAR. $SESSION_NAME ($ticket)"
    IDX=$((IDX + 1))
  done <<< "$OTHERS"
  echo ""
fi

if [ -n "$NOT_IN_SPRINT" ]; then
  SPRINT_COUNT=$(echo "$NOT_IN_SPRINT" | wc -l | tr -d ' ')
  echo "## Not in sprint ($SPRINT_COUNT)"
  while IFS='|' read -r session ticket reason; do
    SESSION_NAME=$(echo "$session" | sed 's/ \x1b\[0;36m→.*//' | sed 's/ →.*//')
    CHAR=$(printf "\\$(printf '%03o' $((65 + IDX)))")
    echo "$CHAR. $SESSION_NAME ($ticket)"
    IDX=$((IDX + 1))
  done <<< "$NOT_IN_SPRINT"
  echo ""
fi

if [ -n "$MERGED_PR" ]; then
  MERGED_COUNT=$(echo "$MERGED_PR" | wc -l | tr -d ' ')
  echo "## Merged PR - no ticket ($MERGED_COUNT)"
  while IFS='|' read -r session branch reason; do
    SESSION_NAME=$(echo "$session" | sed 's/ \x1b\[0;36m→.*//' | sed 's/ →.*//')
    CHAR=$(printf "\\$(printf '%03o' $((65 + IDX)))")
    echo "$CHAR. $SESSION_NAME ($branch)"
    IDX=$((IDX + 1))
  done <<< "$MERGED_PR"
  echo ""
fi

echo "---"
echo "Enter 'y' to delete all, or specify letters (e.g., 'A,C,E') to delete specific sessions."
```

## Usage Examples

```
/sesh-prune           # Uses default project CSD
/sesh-prune OTHER     # Use different project
```

## What This Returns

- Lists sessions grouped by reason with letter indices (A, B, C...)
- Groups: My tickets - Done, Other's tickets, Not in sprint, Merged PR (no ticket)
- Prompts user to enter 'y' to delete all or specify letters (e.g., 'A,C,E') to delete specific sessions

## Post-Output Instructions

When the user responds:
- **'y'**: Delete all listed sessions using `sesh-cmd remove "<session>" --force` for each
- **Letters (e.g., 'A,C,E')**: Delete only the specified sessions

## Requirements

- `acli` CLI must be authenticated (`acli jira auth status`)
- `gh` CLI must be authenticated (`gh auth status`)
- `sesh-cmd` for session management
