---
name: sesh-prune
description: Prune hive worktrees for completed or out-of-sprint Jira tickets
argument-hint: "[PROJECT]"
---

# Worktree Pruning

Identify and remove hive worktrees that are no longer needed based on Jira ticket status or merged PR status.

## Deletion Criteria

**Worktrees with Jira ticket:**
- **My ticket AND Done** - Work is complete
- **Other's ticket AND (Product Review OR Done)** - Review work is complete
- **Not in current sprint** - Stale worktree from previous sprints

**Worktrees without Jira ticket:**
- **Branch has merged PR** - Work is complete

## Execution

Run this bash command to identify worktrees to prune:

```bash
#!/bin/bash
PROJECT="${1:-CSD}"

# Detect hive project key by matching current directory to project paths
HIVE_PROJECT=$(hive project list 2>/dev/null | awk -v cwd="$PWD" '
  NR>2 && NF>0 {
    path = $NF
    gsub(/^~/, ENVIRON["HOME"], path)
    if (path == cwd) { print $1; exit }
  }')
if [ -z "$HIVE_PROJECT" ]; then
  echo "No hive project found for current directory: $PWD"
  exit 1
fi

# Get current user's display name
CURRENT_USER=$(acli jira workitem search --jql "project = $PROJECT AND assignee = currentUser()" --json --limit 1 2>/dev/null | jq -r '.[0].fields.assignee.displayName // empty')
if [ -z "$CURRENT_USER" ]; then
  CURRENT_USER="__NO_MATCH__"
fi

# Get hive worktrees (skip header lines, extract branch and path)
WT_LIST=$(hive wt list "$HIVE_PROJECT" 2>/dev/null | awk 'NR>2 && NF>=4 {split($1,a,"/"); print a[2] "|" $NF}')

# Get all tickets in open sprints (to check what's NOT in sprint)
SPRINT_TICKETS=$(acli jira workitem search \
  --jql "project = $PROJECT AND sprint in openSprints()" \
  --json --paginate 2>/dev/null)

# Detect GitHub repo from git remote
GH_REPO=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/')

# Process: find worktrees to prune
RESULT=$(echo "$WT_LIST" | while IFS='|' read -r BRANCH WT_PATH; do
  [ -z "$BRANCH" ] && continue

  # Extract ticket key from branch name (e.g., CSD-1234)
  TICKET=$(echo "$BRANCH" | grep -oE "${PROJECT}-[0-9]+" | head -1)

  if [ -n "$TICKET" ]; then
    # Worktree HAS ticket key - check Jira status
    TICKET_DATA=$(echo "$SPRINT_TICKETS" | jq -r --arg key "$TICKET" '.[] | select(.key == $key)')

    if [ -z "$TICKET_DATA" ]; then
      # Not in sprint - prune it
      echo "$BRANCH|$TICKET|Not in sprint"
    else
      # In sprint - check status and assignee
      STATUS=$(echo "$TICKET_DATA" | jq -r '.fields.status.name')
      ASSIGNEE=$(echo "$TICKET_DATA" | jq -r '.fields.assignee.displayName // ""')

      if [ "$ASSIGNEE" = "$CURRENT_USER" ] && [ "$STATUS" = "Done" ]; then
        echo "$BRANCH|$TICKET|Done (my ticket)"
      elif [ "$ASSIGNEE" != "$CURRENT_USER" ]; then
        if [ "$STATUS" = "Product Review" ] || [ "$STATUS" = "Done" ]; then
          echo "$BRANCH|$TICKET|$STATUS (other's ticket)"
        fi
      fi
    fi
  else
    # Worktree has NO ticket key - check for merged PR
    if [ -n "$GH_REPO" ]; then
      MERGED_PR=$(gh pr list --repo "$GH_REPO" --state merged --head "$BRANCH" --json number 2>/dev/null)
      if [ -n "$MERGED_PR" ] && [ "$MERGED_PR" != "[]" ]; then
        echo "$BRANCH|$BRANCH|Merged PR (no ticket)"
      fi
    fi
  fi
done)

# Output results
if [ -z "$RESULT" ]; then
  echo "No worktrees to prune."
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

echo "# Worktrees to Prune ($COUNT)"
echo ""

if [ -n "$MY_DONE" ]; then
  MY_COUNT=$(echo "$MY_DONE" | wc -l | tr -d ' ')
  echo "## My tickets - Done ($MY_COUNT)"
  while IFS='|' read -r branch ticket reason; do
    CHAR=$(printf "\\$(printf '%03o' $((65 + IDX)))")
    echo "$CHAR. $branch ($ticket)"
    IDX=$((IDX + 1))
  done <<< "$MY_DONE"
  echo ""
fi

if [ -n "$OTHERS" ]; then
  OTHERS_COUNT=$(echo "$OTHERS" | wc -l | tr -d ' ')
  echo "## Other's tickets - Product Review/Done ($OTHERS_COUNT)"
  while IFS='|' read -r branch ticket reason; do
    CHAR=$(printf "\\$(printf '%03o' $((65 + IDX)))")
    echo "$CHAR. $branch ($ticket)"
    IDX=$((IDX + 1))
  done <<< "$OTHERS"
  echo ""
fi

if [ -n "$NOT_IN_SPRINT" ]; then
  SPRINT_COUNT=$(echo "$NOT_IN_SPRINT" | wc -l | tr -d ' ')
  echo "## Not in sprint ($SPRINT_COUNT)"
  while IFS='|' read -r branch ticket reason; do
    CHAR=$(printf "\\$(printf '%03o' $((65 + IDX)))")
    echo "$CHAR. $branch ($ticket)"
    IDX=$((IDX + 1))
  done <<< "$NOT_IN_SPRINT"
  echo ""
fi

if [ -n "$MERGED_PR" ]; then
  MERGED_COUNT=$(echo "$MERGED_PR" | wc -l | tr -d ' ')
  echo "## Merged PR - no ticket ($MERGED_COUNT)"
  while IFS='|' read -r branch _ reason; do
    CHAR=$(printf "\\$(printf '%03o' $((65 + IDX)))")
    echo "$CHAR. $branch"
    IDX=$((IDX + 1))
  done <<< "$MERGED_PR"
  echo ""
fi

echo "---"
echo "Enter 'y' to delete all, or specify letters (e.g., 'A,C,E') to delete specific worktrees."
```

## Usage Examples

```
/sesh-prune           # Uses default project CSD
/sesh-prune OTHER     # Use different project
```

## What This Returns

- Lists worktrees grouped by reason with letter indices (A, B, C...)
- Groups: My tickets - Done, Other's tickets, Not in sprint, Merged PR (no ticket)
- Prompts user to enter 'y' to delete all or specify letters (e.g., 'A,C,E') to delete specific worktrees

## Post-Output Instructions

When the user responds:
- **'y'**: Delete all listed worktrees using `hive wt delete <hive-project> <branch> --force` for each
- **Letters (e.g., 'A,C,E')**: Delete only the specified worktrees

The branch name is the first field in each listed line (before the parenthetical ticket). The hive project key was detected at the start of the script.

## Requirements

- `acli` CLI must be authenticated (`acli jira auth status`)
- `gh` CLI must be authenticated (`gh auth status`)
- `hive` for worktree management (full cleanup: hooks, tmux, git worktree, registry)
