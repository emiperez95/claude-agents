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

Execute Gemini, Codex, and Claude reviews in parallel:

**Gemini Review:**
```bash
ASDF_NODEJS_VERSION=22.20.0 gemini -p "You are a senior code reviewer. Review this PR against the requirements.

@${WORK_DIR}/context.md
@${WORK_DIR}/diff.patch

IGNORE: approval status, rebase needs.
LOW PRIORITY: merge conflicts (note if present, but focus on code quality).

For each finding specify: file, line, severity (Critical/High/Medium/Low), description, suggested fix.

Output as structured markdown." > "${WORK_DIR}/reviews/gemini.md"
```

**Codex Review:**
```bash
codex exec "You are a senior code reviewer. Review this PR against the requirements.

Read context.md for Jira requirements and PR metadata.
Read diff.patch for the actual code changes.

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

Output as structured markdown." \
  -C "${WORK_DIR}" \
  --skip-git-repo-check \
  -o "${WORK_DIR}/reviews/codex.md"
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

Read all three review files and combine findings:

**Priority Boost Rule:** Items flagged by 2+ reviewers get bumped up one severity level.

| Reviewers | Original | Final Severity |
|-----------|----------|----------------|
| 3/3       | High     | Critical       |
| 2/3       | High     | Critical       |
| 3/3       | Medium   | High           |
| 2/3       | Medium   | High           |
| 1/3       | High     | High (no boost)|

Deduplicate similar findings, noting which reviewer(s) flagged each: [Gemini], [Codex], [Claude].

### 5. Synthesize Actionable Items

Present combined review to user:

```markdown
# PR Review: {PR_TITLE} (#{PR_NUM})

## Requirements Status
| Requirement | Status | Notes |
|-------------|--------|-------|

## Action Items

### Critical (consensus)
- [ ] file:line - issue - fix [Gemini + Codex + Claude] (3/3)

### High Priority
- [ ] file:line - issue - fix [Gemini + Codex] ← boosted (2/3)
- [ ] file:line - issue - fix [Claude]

### Medium Priority
- [ ] file:line - issue - fix [Codex]

### Suggestions
- improvements

## Review Sources
- Gemini: ${WORK_DIR}/reviews/gemini.md
- Codex: ${WORK_DIR}/reviews/codex.md
- Claude: ${WORK_DIR}/reviews/claude.md

## Recommendation: APPROVE / REQUEST_CHANGES
```

## Examples

**User:** "Review PR 456"
- Detect PR 456, find linked Jira ticket
- Gather context via script (parallel CLI calls)
- Run Gemini + Codex + Claude reviews in parallel
- Aggregate findings, boost items flagged by 2+ reviewers
- Present actionable summary

**User:** "Review CSD-123"
- Find PR linked to CSD-123
- Gather context including acceptance criteria
- 3 parallel reviews against requirements
- Present findings with reviewer attribution

**User:** "Review this branch"
- Get PR from current branch
- Extract Jira from branch name if needed
- Full 3-reviewer workflow
