---
name: athena-pr-reviewer
description: PROACTIVELY USED when reviewing a PR, branch, or Jira story. Handles code review against requirements and provides actionable feedback.
---

# Athena PR Reviewer

## Instructions

### 1. Detect PR Target

Parse user input to identify the PR:

- **Direct PR reference** (`PR 123`, `#123`): Extract number directly
- **Jira ticket** (`PROJ-123`): Run `gh pr list --search "PROJ-123" --json number --jq '.[0].number'`
- **Current branch**: Run `gh pr view --json number --jq '.number'`
- **No PR found**: Extract Jira from branch with `git branch --show-current | grep -oE '[A-Z]+-[0-9]+'`

### 2. Gather Data (Script)

Run the gather-context script which collects all data in parallel:

```bash
~/.claude/skills/athena-pr-reviewer/scripts/gather-context.sh ${PR_NUM} ${JIRA_TICKET}
```

This script:
- Creates work directory at `/tmp/athena-review-${PR_NUM}/`
- Fetches in parallel: PR metadata, diff, Jira ticket, epic, CLAUDE.md guidelines, git blame, prior PR comments
- Writes combined context to `${WORK_DIR}/context.md`
- Writes diff to `${WORK_DIR}/diff.patch`

Output files:
- `context.md` - Combined PR + Jira + guidelines + history data
- `diff.patch` - Full PR diff
- `pr.json` - Raw PR metadata
- `jira.json` - Raw Jira ticket data
- `epic.json` - Epic context (if linked)
- `guidelines.md` - All CLAUDE.md files from repo
- `blame.md` - Git blame for changed files (who wrote what, when)
- `prior-comments.md` - Comments from past PRs touching same files

### 3. Run Reviews (All 8 in Parallel)

Execute all 8 reviews simultaneously in a SINGLE message:

**In ONE message, run:**

1. **Bash (background):** Start Gemini + Codex script with `run_in_background: true`
```bash
~/.claude/skills/athena-pr-reviewer/scripts/run-reviews.sh ${WORK_DIR}
```

2. **6 Task calls:** Run all Claude specialists in parallel

This launches all 8 reviews at once:
- Gemini + Codex run in background bash
- 6 Claude agents run as parallel Task calls

**After Claude agents complete:** Use BashOutput to check if Gemini/Codex finished.

Output files:
- `${WORK_DIR}/reviews/gemini.md`
- `${WORK_DIR}/reviews/codex.md`
- `${WORK_DIR}/reviews/claude-*.md` (6 files)

**Claude Specialized Reviews (6 agents)**

Each agent reads its prompt file, then analyzes `${WORK_DIR}/context.md` and `${WORK_DIR}/diff.patch`.

```
Task: general-purpose
Prompt: "Read ~/.claude/skills/athena-pr-reviewer/prompts/comment-analyzer.md for instructions.
Then read ${WORK_DIR}/context.md and ${WORK_DIR}/diff.patch. Perform the review. Output markdown."
Save to: ${WORK_DIR}/reviews/claude-comments.md

Task: general-purpose
Prompt: "Read ~/.claude/skills/athena-pr-reviewer/prompts/test-analyzer.md for instructions.
Then read ${WORK_DIR}/context.md and ${WORK_DIR}/diff.patch. Perform the review. Output markdown."
Save to: ${WORK_DIR}/reviews/claude-tests.md

Task: general-purpose
Prompt: "Read ~/.claude/skills/athena-pr-reviewer/prompts/error-hunter.md for instructions.
Then read ${WORK_DIR}/context.md and ${WORK_DIR}/diff.patch. Perform the review. Output markdown."
Save to: ${WORK_DIR}/reviews/claude-errors.md

Task: general-purpose
Prompt: "Read ~/.claude/skills/athena-pr-reviewer/prompts/type-reviewer.md for instructions.
Then read ${WORK_DIR}/context.md and ${WORK_DIR}/diff.patch. Perform the review. Output markdown."
Save to: ${WORK_DIR}/reviews/claude-types.md

Task: general-purpose
Prompt: "Read ~/.claude/skills/athena-pr-reviewer/prompts/code-reviewer.md for instructions.
Then read ${WORK_DIR}/context.md and ${WORK_DIR}/diff.patch. Perform the review. Output markdown."
Save to: ${WORK_DIR}/reviews/claude-general.md

Task: general-purpose
Prompt: "Read ~/.claude/skills/athena-pr-reviewer/prompts/simplifier.md for instructions.
Then read ${WORK_DIR}/context.md and ${WORK_DIR}/diff.patch. Perform the review. Output markdown."
Save to: ${WORK_DIR}/reviews/claude-simplify.md
```

### 4. Aggregate Reviews

Read all 8 review files and combine findings:

**Reviewers:**
- Gemini (general)
- Codex (general)
- Claude: comments, tests, errors, types, general, simplify

**Confidence Filtering:**
- Drop findings with confidence < 80
- Keep findings 50-79 only if flagged by 2+ reviewers

**Priority Boost Rule:** Items flagged by 2+ reviewers get bumped up one severity level.

| Reviewers | Original | Final Severity |
|-----------|----------|----------------|
| 3+        | High     | Critical       |
| 2         | High     | Critical       |
| 3+        | Medium   | High           |
| 2         | Medium   | High           |
| 1         | Any      | No boost       |

Deduplicate similar findings, noting which reviewer(s) flagged each and average confidence.

### 5. Synthesize Actionable Items

Present combined review to user:

```markdown
# PR Review: {PR_TITLE} (#{PR_NUM})

## Requirements Status
| Requirement | Status | Notes |
|-------------|--------|-------|

## Action Items

### Critical (consensus)
- [ ] file:line - issue - fix [Gemini + Codex + Claude-errors] (3+, avg 92%)

### High Priority
- [ ] file:line - issue - fix [Gemini + Claude-tests] ← boosted (2, avg 85%)
- [ ] file:line - issue - fix [Claude-types] (95%)

### Medium Priority
- [ ] file:line - issue - fix [Claude-simplify] (88%)

### Suggestions
- improvements

## Review Sources
- Gemini: ${WORK_DIR}/reviews/gemini.md
- Codex: ${WORK_DIR}/reviews/codex.md
- Claude Comments: ${WORK_DIR}/reviews/claude-comments.md
- Claude Tests: ${WORK_DIR}/reviews/claude-tests.md
- Claude Errors: ${WORK_DIR}/reviews/claude-errors.md
- Claude Types: ${WORK_DIR}/reviews/claude-types.md
- Claude General: ${WORK_DIR}/reviews/claude-general.md
- Claude Simplify: ${WORK_DIR}/reviews/claude-simplify.md

## Recommendation: APPROVE / REQUEST_CHANGES
```

## Examples

**User:** "Review PR 456"
- Detect PR 456, find linked Jira ticket
- Gather context via script (parallel CLI calls)
- Run 8 reviews in parallel (Gemini, Codex, 6 Claude specialists)
- Aggregate findings, boost items flagged by 2+ reviewers
- Present actionable summary

**User:** "Review CSD-123"
- Find PR linked to CSD-123
- Gather context including acceptance criteria
- 8 parallel reviews (general + specialized)
- Present findings with reviewer attribution

**User:** "Review this branch"
- Get PR from current branch
- Extract Jira from branch name if needed
- Full 8-reviewer workflow
