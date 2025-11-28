---
description: Get full Jira board status with tickets grouped by column
argument-hint: "[PROJECT] (optional, defaults to CSD)"
---

# Jira Board Status

Get a focused view of your actionable work in the active sprint:
- **In Progress**: Your current work
- **Ready For Review**: Others' tickets you may need to review
- **Has Review**: Your PRs that have been reviewed
- **To Do**: All unassigned/available work

## Execution

Run this bash command to fetch board status:

```bash
#!/bin/bash
PROJECT="${1:-CSD}"

# Get current user's display name
CURRENT_USER=$(acli jira workitem search --jql "project = $PROJECT AND assignee = currentUser()" --json --limit 1 2>/dev/null | jq -r '.[0].fields.assignee.displayName // empty')

if [ -z "$CURRENT_USER" ]; then
  CURRENT_USER="__NO_MATCH__"
fi

acli jira workitem search \
  --jql "project = $PROJECT AND sprint in openSprints() ORDER BY status ASC, updated DESC" \
  --json --paginate 2>/dev/null | jq -r --arg user "$CURRENT_USER" '

[
  # In Progress - only my tickets
  (map(select(.fields.status.name == "In Progress" and .fields.assignee.displayName == $user)) |
   if length > 0 then {
     status: "In Progress (My Work)",
     show_assignee: false,
     tickets: map({key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end)})
   } else empty end),

  # Ready For Review - only others (for me to review)
  (map(select(.fields.status.name == "Ready For Review" and ((.fields.assignee.displayName // "") == $user | not))) |
   if length > 0 then {
     status: "Ready For Review (To Review)",
     show_assignee: true,
     tickets: map({key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), assignee: (.fields.assignee.displayName // "Unassigned")})
   } else empty end),

  # Has Review - only my tickets
  (map(select(.fields.status.name == "Has review" and .fields.assignee.displayName == $user)) |
   if length > 0 then {
     status: "Has Review (My PRs)",
     show_assignee: false,
     tickets: map({key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end)})
   } else empty end),

  # To Do - all tickets
  (map(select(.fields.status.name == "To Do")) |
   if length > 0 then {
     status: "To Do",
     show_assignee: true,
     tickets: map({key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), assignee: (.fields.assignee.displayName // "Unassigned")})
   } else empty end)
] |

.[] |
if .show_assignee then
  "## \(.status) (\(.tickets | length))\n| Key | Summary | Assignee |\n|-----|---------|----------|\n" +
  (.tickets | map("| \(.key) | \(.summary) | \(.assignee) |") | join("\n")) + "\n"
else
  "## \(.status) (\(.tickets | length))\n| Key | Summary |\n|-----|---------|" +
  (.tickets | map("\n| \(.key) | \(.summary) |") | join("")) + "\n"
end
'
```

## Usage Examples

**Default project (CSD):**
```
/jira-status
```

**Specific project:**
```
/jira-status PROJ
```

## What This Returns

- **In Progress (My Work)**: Tickets assigned to you currently in progress
- **Ready For Review (To Review)**: Others' tickets waiting for code review
- **Has Review (My PRs)**: Your tickets that have received reviews
- **To Do**: All tickets not yet started (for picking up work)

## Requirements

- `acli` CLI must be authenticated (`acli jira auth status`)
- User must have access to the specified project
