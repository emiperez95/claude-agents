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

# Build a ticket-key -> session-indicator map from `hive wt list`.
# hive tracks git worktrees plus their associated tmux sessions; STATUS is
# "dead" when the worktree exists but the tmux session is gone, otherwise alive.
# If a ticket has multiple worktrees, alive wins over dead.
HIVE_MAP=$(hive wt list 2>/dev/null | awk -F '[[:space:]]{2,}' '
  BEGIN { COL_WT = 1; COL_STATUS = 3 }
  NR>2 && NF >= COL_STATUS {
    wt = $COL_WT
    status = $COL_STATUS
    if (wt == "") next
    if (match(wt, /[A-Z]+-[0-9]+/)) {
      key = substr(wt, RSTART, RLENGTH)
      if (status != "dead") {
        indicators[key] = "✅"
      } else if (!(key in indicators)) {
        indicators[key] = "💀"
      }
    }
  }
  END { for (k in indicators) print k "=" indicators[k] }
')

acli jira workitem search \
  --jql "project = $PROJECT AND sprint in openSprints() ORDER BY status ASC, updated DESC" \
  --json --paginate 2>/dev/null | jq -r --arg user "$CURRENT_USER" --arg hivemap "$HIVE_MAP" '

# Parse the hive map into a dict: {"CSD-2596": "✅", "CSD-2453": "💀", ...}
($hivemap | split("\n") | map(select(length > 0)) | map(split("=")) | map({key: .[0], value: .[1]}) | from_entries) as $sessions |

[
  # In Progress - only my tickets
  (map(select(.fields.status.name == "In Progress" and .fields.assignee.displayName == $user)) |
   if length > 0 then {
     status: "In Progress (My Work)",
     show_assignee: false,
     tickets: map({key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), session: ($sessions[.key] // "❌")})
   } else empty end),

  # Ready For Review - only others (for me to review)
  (map(select(.fields.status.name == "Ready For Review" and ((.fields.assignee.displayName // "") == $user | not))) |
   if length > 0 then {
     status: "Ready For Review (To Review)",
     show_assignee: true,
     tickets: map({key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), assignee: (.fields.assignee.displayName // "Unassigned"), session: ($sessions[.key] // "❌")})
   } else empty end),

  # Has Review - only my tickets
  (map(select(.fields.status.name == "Has review" and .fields.assignee.displayName == $user)) |
   if length > 0 then {
     status: "Has Review (My PRs)",
     show_assignee: false,
     tickets: map({key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), session: ($sessions[.key] // "❌")})
   } else empty end),

  # To Do - all tickets
  (map(select(.fields.status.name == "To Do")) |
   if length > 0 then {
     status: "To Do",
     show_assignee: true,
     tickets: map({key: .key, summary: (.fields.summary | if length > 50 then .[:47] + "..." else . end), assignee: (.fields.assignee.displayName // "Unassigned"), session: ($sessions[.key] // "❌")})
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
- **Session column** (from `hive wt list`):
  - `✅` — worktree exists and tmux session is alive
  - `💀` — worktree exists but tmux session is dead (needs reattach/respawn)
  - `❌` — no worktree registered in hive

## Presentation Instructions

When presenting results to the user, add letter indices (A, B, C, ...) to each ticket continuously across all sections. This allows the user to reference tickets by letter (e.g., "tell me about C" or "start working on F").

Example output format:
```
## In Progress (My Work) (2)
| # | Key | Summary | Session |
|---|-----|---------|---------|
| A | PROJ-123 | Feature X | ✅ |
| B | PROJ-456 | Bug fix Y | ❌ |

## Ready For Review (To Review) (1)
| # | Key | Summary | Assignee | Session |
|---|-----|---------|----------|---------|
| C | PROJ-789 | Feature Z | Juan | ✅ |
```

## Session Switching

When the user references a letter (e.g., "switch to A", "go to G", or just "A"):

**For tickets in "Ready For Review (To Review)"** (others' work you need to review):
Use the Skill tool to invoke `athena-pr-reviewer-workflow` with args set to the ticket key (e.g., `skill: "athena-pr-reviewer-workflow", args: "CSD-2345"`).
The athena skill will detect the PR from the Jira ticket and perform a full multi-reviewer code review.
This works from the current session regardless of whether a tmux session exists for the ticket.

**For all other tickets ("In Progress", "Has Review", "To Do"):**

### If the ticket has a live session (✅)

Switch to that tmux session:

```bash
# Find the tmux session containing the ticket ID and switch to it
SESSION=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -m1 'TICKET-ID')
if [ -n "$SESSION" ]; then
  tmux switch-client -t "$SESSION"
fi
```

Replace `TICKET-ID` with the actual ticket key (e.g., PROJ-123).

### If the ticket has a dead session (💀)

The worktree exists on disk but its tmux session was killed. Use hive to spawn a fresh session against the existing branch — delegate to janus-wt-portal:

```
Task tool with subagent_type="janus-wt-portal"
Prompt: "Respawn dead session for TICKET-ID using `hive wt new <project> <branch> --existing --auto-approve --prompt 'Resume work on TICKET-ID'`"
```

The `--existing` flag tells `hive wt new` to attach to the existing branch/worktree rather than creating a new one. Confirm with the user before respawning — the old session's in-memory state is gone.

### If the ticket has no worktree (❌)

Use the janus-wt-portal agent to create a worktree. Include the ticket summary so the branch name is descriptive (e.g., `CSD-2576-auth-flow` not just `CSD-2576`).

```
Task tool with subagent_type="janus-wt-portal"
Prompt: "Create a worktree for TICKET-ID TICKET-SUMMARY with --auto-approve --prompt 'Work on TICKET-ID, gather all information required and make a plan'"
```

Replace TICKET-SUMMARY with the actual summary from the table (e.g., "auth flow redesign"). The janus agent will sanitize it into the branch name (lowercase, hyphens).

The `--prompt` flag tells `hive wt new` to send a startup message to Claude in the new session. The agent will create a git worktree for the ticket branch using `hive wt`.

#### Creating multiple worktrees at once

When the user asks to spawn worktrees for several ❌ tickets in one go, **do not launch all janus-wt-portal agents in parallel**. The first worktree creation triggers AWS SSO / credential prompts that need to be resolved interactively — running them in parallel causes them to clobber each other and fail.

Workflow:
1. **Sequential first**: launch one janus-wt-portal agent for the first ticket and wait for it to finish. This warms up AWS credentials.
2. **Parallel rest**: once the first returns successfully, launch the remaining janus-wt-portal agents in parallel (multiple Task tool calls in a single message).

If the first worktree creation fails on AWS auth, stop and surface the error to the user before retrying — don't fire off the parallel batch.

## Requirements

- `acli` CLI must be authenticated (`acli jira auth status`)
- `hive` CLI available (provides `hive wt list` for worktree/session state)
- `tmux` for session switching
- User must have access to the specified project
