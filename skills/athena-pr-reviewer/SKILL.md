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
./scripts/gather-context.sh ${PR_NUM} ${JIRA_TICKET}
```

This script:
- Creates work directory at `/tmp/athena-review-${PR_NUM}/`
- Fetches PR metadata, diff, Jira ticket, and epic context in parallel
- Writes combined context to `${WORK_DIR}/context.md`
- Writes diff to `${WORK_DIR}/diff.patch`

Output files:
- `context.md` - Combined PR + Jira JSON data
- `diff.patch` - Full PR diff
- `pr.json` - Raw PR metadata
- `jira.json` - Raw Jira ticket data
- `epic.json` - Epic context (if linked)

### 3. Run Reviews (Parallel)

Execute Gemini and Claude reviews in parallel:

**Gemini Review:**
```bash
gemini -p "You are a senior code reviewer. Review this PR against the requirements.

@${WORK_DIR}/context.md
@${WORK_DIR}/diff.patch

IGNORE: approval status, rebase needs.
LOW PRIORITY: merge conflicts (note if present, but focus on code quality).

For each finding specify: file, line, severity (Critical/High/Medium/Low), description, suggested fix.

Output as structured markdown." > "${WORK_DIR}/reviews/gemini.md"
```

**Claude Subagent Review:**
```
Task: general-purpose
Prompt: "You are a senior code reviewer. Review this PR against the requirements.

Read ${WORK_DIR}/context.md for Jira requirements and PR metadata.
Read ${WORK_DIR}/diff.patch for the actual code changes.

IGNORE: approval status, rebase needs.
LOW PRIORITY: merge conflicts (note if present, but focus on code quality).

Analyze:
1. Requirements alignment - does code fulfill acceptance criteria?
2. Code quality - patterns, readability, maintainability
3. Potential bugs - edge cases, error handling
4. Security concerns - input validation, auth, data exposure
5. Performance - inefficiencies, N+1 queries
6. Test coverage - are changes tested?

For each finding specify: file, line, severity (Critical/High/Medium/Low), description, suggested fix.

Output as structured markdown."

Save output to: ${WORK_DIR}/reviews/claude.md
```

### 4. Aggregate Reviews

Read both review files and combine findings:

**Priority Boost Rule:** Items flagged by BOTH reviewers get bumped up one severity level.

| Gemini | Claude | Final Severity |
|--------|--------|----------------|
| High   | High   | Critical       |
| Medium | Medium | High           |
| Low    | Low    | Medium         |
| High   | -      | High (no boost)|

Deduplicate similar findings, noting which reviewer(s) flagged each.

### 5. Synthesize Actionable Items

Present combined review to user:

```markdown
# PR Review: {PR_TITLE} (#{PR_NUM})

## Requirements Status
| Requirement | Status | Notes |
|-------------|--------|-------|

## Action Items

### Critical (consensus)
- [ ] file:line - issue - fix [Gemini + Claude]

### High Priority
- [ ] file:line - issue - fix [Gemini + Claude] ← boosted
- [ ] file:line - issue - fix [Gemini]

### Medium Priority
- [ ] file:line - issue - fix [Claude]

### Suggestions
- improvements

## Review Sources
- Gemini: ${WORK_DIR}/reviews/gemini.md
- Claude: ${WORK_DIR}/reviews/claude.md

## Recommendation: APPROVE / REQUEST_CHANGES
```

## Examples

**User:** "Review PR 456"
- Detect PR 456, find linked Jira ticket
- Gather context from all 3 agents in parallel
- Run Gemini + Claude reviews in parallel
- Aggregate findings, boost consensus items
- Present actionable summary

**User:** "Review CSD-123"
- Find PR linked to CSD-123
- Gather context including acceptance criteria
- Parallel reviews against requirements
- Present findings with reviewer attribution

**User:** "Review this branch"
- Get PR from current branch
- Extract Jira from branch name if needed
- Full multi-reviewer workflow
