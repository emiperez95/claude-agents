---
name: jira-status
description: Get full Jira board status with tickets grouped by column
argument-hint: "<PROJECT>"
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
PROJECT="${1:-}"
if [[ -z "$PROJECT" ]]; then
  echo "Usage: /jira-status PROJECT"
  echo "Example: /jira-status CSD"
  exit 1
fi

# Get current user's display name
CURRENT_USER=$(acli jira workitem search --jql "project = $PROJECT AND assignee = currentUser()" --json --limit 1 2>/dev/null | jq -r '.[0].fields.assignee.displayName // empty')

if [ -z "$CURRENT_USER" ]; then
  CURRENT_USER="__NO_MATCH__"
fi

# Get list of tmux sessions for session indicator
TMUX_LIST=$(tmux list-sessions -F '#{session_name}' 2>/dev/null || echo "")

acli jira workitem search \
  --jql "project = $PROJECT AND sprint in openSprints() ORDER BY status ASC, updated DESC" \
  --json --paginate 2>/dev/null | jq -r --arg user "$CURRENT_USER" --arg sessions "$TMUX_LIST" '

[
  # In Progress - only my tickets
  (map(select(.fields.status.name == "In Progress" and .fields.assignee.displayName == $user)) |
   if length > 0 then {
     status: "In Progress (My Work)",
     show_assignee: false,
     tickets: map(.key as $k | {key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), session: (if ($sessions | contains($k)) then "✓" else "-" end)})
   } else empty end),

  # Ready For Review - only others (for me to review)
  (map(select(.fields.status.name == "Ready For Review" and ((.fields.assignee.displayName // "") == $user | not))) |
   if length > 0 then {
     status: "Ready For Review (To Review)",
     show_assignee: true,
     tickets: map(.key as $k | {key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), assignee: (.fields.assignee.displayName // "Unassigned"), session: (if ($sessions | contains($k)) then "✓" else "-" end)})
   } else empty end),

  # Has Review - only my tickets
  (map(select(.fields.status.name == "Has review" and .fields.assignee.displayName == $user)) |
   if length > 0 then {
     status: "Has Review (My PRs)",
     show_assignee: false,
     tickets: map(.key as $k | {key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), session: (if ($sessions | contains($k)) then "✓" else "-" end)})
   } else empty end),

  # To Do - all tickets
  (map(select(.fields.status.name == "To Do")) |
   if length > 0 then {
     status: "To Do",
     show_assignee: true,
     tickets: map(.key as $k | {key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), assignee: (.fields.assignee.displayName // "Unassigned"), session: (if ($sessions | contains($k)) then "✓" else "-" end)})
   } else empty end)
] |

.[] |
if .show_assignee then
  "## \(.status) (\(.tickets | length))\n| Key | Summary | Assignee | Session |\n|-----|---------|----------|---------|\n" +
  (.tickets | map("| \(.key) | \(.summary) | \(.assignee) | \(.session) |") | join("\n")) + "\n"
else
  "## \(.status) (\(.tickets | length))\n| Key | Summary | Session |\n|-----|---------|--------|\n" +
  (.tickets | map("| \(.key) | \(.summary) | \(.session) |") | join("\n")) + "\n"
end
'
```

## Usage Examples

```
/jira-status PROJ
/jira-status CSD
```

## What This Returns

- **In Progress (My Work)**: Tickets assigned to you currently in progress
- **Ready For Review (To Review)**: Others' tickets waiting for code review
- **Has Review (My PRs)**: Your tickets that have received reviews
- **To Do**: All tickets not yet started (for picking up work)
- **Session column**: Shows ✓ if a tmux session exists for the ticket, - otherwise

## Presentation Instructions

When presenting results to the user, add letter indices (A, B, C, ...) to each ticket continuously across all sections. This allows the user to reference tickets by letter (e.g., "tell me about C" or "start working on F").

Example output format:
```
## In Progress (My Work) (2)
| # | Key | Summary | Session |
|---|-----|---------|---------|
| A | PROJ-123 | Feature X | ✓ |
| B | PROJ-456 | Bug fix Y | - |

## Ready For Review (To Review) (1)
| # | Key | Summary | Assignee | Session |
|---|-----|---------|----------|---------|
| C | PROJ-789 | Feature Z | Juan | ✓ |
```

## Session Switching

When the user references a letter (e.g., "switch to A", "go to G", or just "A"):

### If the ticket has a session (✓)

Switch to that session:

```bash
# Find the tmux session containing the ticket ID and switch to it
SESSION=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -m1 'TICKET-ID')
if [ -n "$SESSION" ]; then
  tmux switch-client -t "$SESSION"
fi
```

Replace `TICKET-ID` with the actual ticket key (e.g., PROJ-123).

### If the ticket has no session (-)

Use the janus-wt-portal agent to create a worktree. The type and prompt depend on ticket ownership:

**For tickets in "Ready For Review (To Review)"** (others' work you need to review):
```
Task tool with subagent_type="janus-wt-portal"
Prompt: "Create a review worktree for TICKET-ID with --auto-approve --prompt 'Review TICKET-ID, gather all information required and make a plan'"
```

**For tickets in "In Progress", "Has Review", or "To Do"** (your work or available work):
```
Task tool with subagent_type="janus-wt-portal"
Prompt: "Create a worktree for TICKET-ID with --auto-approve --prompt 'Work on TICKET-ID, gather all information required and make a plan'"
```

The `--prompt` flag tells `hive wt new` to send a startup message to Claude in the new session. The agent will create a git worktree for the ticket branch using `hive wt`.

## Requirements

- `acli` CLI must be authenticated (`acli jira auth status`)
- `tmux` for session indicator
- User must have access to the specified project
