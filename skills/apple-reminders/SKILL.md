---
name: apple-reminders
description: Access to Apple Reminders. PROACTIVELY USED when the user wants to see, add, complete, edit, move, or delete reminders or tasks. macOS only.
allowed-tools:
  - Bash
---

# Apple Reminders

Quick, scriptable access to Apple Reminders. All access goes through one bundled CLI that talks to EventKit **in-process** (not AppleScript), so every operation is ~50–150ms even on lists with hundreds of items.

## The CLI

```
R="$HOME/.claude/skills/apple-reminders/bin/reminders"
```

Always invoke this wrapper (not `reminders-bin`). It auto-compiles the Swift source on first use or after edits and ad-hoc signs it, then execs the native binary. **The very first call on a machine compiles the binary (~3–5s) — that's expected, not a hang; every later call is instant (~0.1s).** **Every command prints a single JSON object to stdout** (`{"ok":true,...}` or `{"ok":false,"error":"..."}`). Parse it; then present results to the user as a clean, readable list — never dump raw JSON at them.

### Commands

| Command | What it does |
|---|---|
| `$R lists` | All lists with open (incomplete) counts + the default list |
| `$R list [flags]` | Query reminders (incomplete by default) |
| `$R get <id>` | One reminder by id |
| `$R add <title...> [flags]` | Create a reminder |
| `$R done <id> [<id>...]` | Mark complete (also `undone` to un-complete) |
| `$R edit <id> [flags]` | Modify a reminder |
| `$R rm <id> [<id>...]` | Delete |
| `$R help` | Usage JSON (no permission needed) |

**`list` flags:** `--list NAME` (restrict to one list), `--search TEXT` (title/notes substring), `--due overdue|today|week`, `--all` (include completed), `--limit N`.

**`add` flags:** `--list NAME` (default: default list), `--due ISO`, `--allday`, `--notes TEXT`, `--priority none|low|medium|high`.

**`edit` flags:** `--title`, `--due ISO|clear`, `--notes`, `--priority`, `--list NAME` (move to another list).

## How to operate it efficiently

**1. Dates are your job to convert.** The CLI only accepts ISO 8601. Convert natural language ("tomorrow at 3pm", "next Monday", "in 2 hours") into ISO *before* calling. Pass **local wall-clock time with no timezone suffix** — the CLI reads it in the user's local timezone:

```bash
$R add "Call the dentist" --due 2026-07-19T15:00:00 --list Reminders
```

- `2026-07-19T15:00:00` → 3pm local. `2026-07-19` (date only) → all-day.
- Output `due` fields come back in **UTC** (`...Z`) — convert back to local when telling the user.
- Need to compute a relative date? Use `date`, e.g. tomorrow 9am: `date -v+1d -v9H -v0M -v0S "+%Y-%m-%dT%H:%M:%S"`.
- A timed `--due` also sets an alarm, so the reminder actually notifies.

**2. Mutations need ids — always query first.** `done`, `edit`, and `rm` take the reminder `id` (a UUID like `6AD75CD9-...`). Never guess one. Run `list`/`get`, take the `id` from the JSON, then act:

```bash
# "mark the milk reminder done"
$R list --list Groceries --search milk      # → grab .reminders[].id
$R done 6AD75CD9-DA1A-4D0F-84E1-21846B5D5701
```

If a query returns several matches, show them to the user and confirm which one before mutating.

**3. Read narrowly.** Default `list` returns only incomplete items, sorted by due date (undated last). Add `--all` only when the user asks about completed/history. Combine `--list`, `--search`, `--due` to keep results small.

**4. Destructive ops.** `rm` is permanent (no undo). Confirm with the user before deleting anything you didn't just create. `done` is safe and reversible via `undone`.

## Common recipes

```bash
$R lists                                   # overview + counts
$R list --due today                        # what's due today (all lists)
$R list --due overdue --limit 20           # overdue backlog
$R list --list Chores                       # one list, open items
$R add "Buy avocados" --list Groceries      # quick capture
$R add "Renew passport" --due 2026-08-01 --priority high --notes "photo + form"
$R edit <id> --due clear                    # remove a due date
$R edit <id> --list "Japan's ToDoList"      # move between lists
$R done <id1> <id2>                          # complete several at once
```

## First run & permissions

Two things happen only on a fresh machine, and **neither is a hung process** — wait them out, don't kill the command:

1. **First invocation compiles the binary** (~3–5s). Subsequent calls skip this.
2. **The first command that touches data triggers a one-time macOS prompt:** **"apple-reminders-cli would like to access your Reminders" → Allow.** This prompt *blocks the command until the user responds*, so that first call can sit for a while. If the user denies it, the CLI returns `{"ok":false,"error":"Reminders access not granted..."}`; tell them to enable it in **System Settings › Privacy & Security › Reminders**.

## Known limitations (Apple API, not fixable here)

- **No sections within a list.** Neither EventKit nor AppleScript exposes Reminders "sections" — the CLI works at list + reminder granularity only.
- **No `flagged`.** EventKit doesn't expose the flag state.
- **macOS only.** Requires `swiftc` (Xcode Command Line Tools) for the one-time build.
