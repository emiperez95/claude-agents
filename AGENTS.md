# Agent Documentation

Detailed documentation for the three Claude Code development agents.

## Atlas Jira Analyst

### Purpose
Atlas carries the weight of project knowledge, extracting and analyzing Jira tickets, epics, and related stories. It compiles comprehensive requirements documentation to ensure developers have full context before starting work.

### Trigger Phrases (Proactive)
The agent automatically activates when you mention:
- Jira issue IDs (e.g., "PROJ-1234")
- "What should I implement for..."
- "Get the Jira details"
- "What's the context for this feature"
- Working on a feature branch with a Jira ID

### Capabilities
- Extracts issue ID from git branch names
- Retrieves issue description, title, and acceptance criteria
- Collects all comments with special attention to decisions and clarifications
- Fetches parent epic context and related stories
- Gathers Definition of Done
- Links to Confluence documentation

### Input Formats
```bash
# Explicit issue ID
"Get context for PROJ-1234"

# From current branch
"What's the Jira context for this branch?"

# General request
"I need to understand what to implement"
```

### Output Format
```
# JIRA ISSUE: [ISSUE-ID] - [Title]

## SUMMARY
[Clear description of what needs to be done]

## METADATA
Type: Story
Status: In Progress
Priority: High
...

## ACCEPTANCE CRITERIA
1. [Criterion 1]
2. [Criterion 2]

## KEY DECISIONS AND CLARIFICATIONS
- [@user]: "Important clarification"
...
```

### Example Usage
```
User: "I need to understand what I should implement for PROJ-567"
Assistant: [Invokes atlas-jira-analyst to gather full Jira context]
```

---

## Heimdall PR Guardian

### Purpose
Heimdall stands watch at the bridge to merge, monitoring pull request status including comments, CI/CD checks, approvals, and merge blockers. Returns raw status data without analysis.

### Trigger Phrases (Proactive)
The agent automatically activates when you mention:
- "PR status"
- "PR comments" / "check comments" / "review comments"
- "What's blocking my PR"
- "PR approvals"
- "Merge readiness"
- "PR feedback"

### Capabilities
- Detects PR from current branch or accepts PR number/URL
- Fetches all types of comments (general, review, code-specific)
- Extracts comment IDs for responding/resolving
- Monitors CI/CD check status with failure logs
- Tracks approvals and review requests
- Identifies merge blockers

### Input Formats
```bash
# PR number
"Check status of PR #123"

# Full URL
"Get comments for https://github.com/org/repo/pull/456"

# Current branch
"What's blocking my PR?"
```

### Output Format
```
# PULL REQUEST STATUS: #123 - [Title]

## COMMENTS STATUS
Total Comments: 10 (3 resolved, 7 unresolved)

### UNRESOLVED COMMENTS REQUIRING ACTION:
1. @reviewer (2 days ago): "Comment text"
   - Comment ID: 1234567890
   - Review ID: 9876543210
   - File: src/app.js:42
   - Has replies: Yes (2)
   
## CI/CD STATUS
Required Checks: 3 of 5 passing

### FAILING CHECKS:
- build-test: FAILED
  [Error logs]

## ACTION REQUIRED
1. Respond to 4 comments
2. Fix 2 failing checks
...
```

### Example Usage
```
User: "Check the comments on my PR"
Assistant: [Invokes heimdall-pr-guardian to gather PR status and comments]
```

---

## Hermes PR Courier

### Purpose
Hermes swiftly delivers comprehensive information about pull requests, collecting metadata, file changes, commit history, and linked issues without adding interpretation or opinions.

### Trigger Phrases (Proactive)
The agent automatically activates when you mention:
- "What's in PR #..."
- "Get PR details"
- "Show me the files changed"
- "PR changes"
- Reviewing PRs
- Documenting changes for release notes

### Capabilities
- Fetches PR metadata (title, description, author, timestamps)
- Collects file changes with addition/deletion counts
- Categorizes files by type (frontend/backend/tests/docs/etc.)
- Analyzes commit history and types
- Links to related issues
- Calculates PR size (XS/S/M/L/XL)

### Input Formats
```bash
# PR number
"What's in PR #789"

# Full URL
"Get details for https://github.com/org/repo/pull/321"

# With repository context
"Show me org/repo#456"
```

### Output Format
```
# PULL REQUEST: #1234 - [Title]

## METADATA
Author: @username
State: OPEN
Branch: feature → main
Labels: [bug, high-priority]

## CHANGE SUMMARY
Total Changes: 570 lines (+450, -120) across 15 files
PR Size: MEDIUM

## FILES CHANGED BY CATEGORY

### Frontend (5 files, +200 -50 lines)
- src/components/Button.tsx (+45, -10)
...

## COMMITS (5 total)
1. feat: add Button component
   - SHA: abc123d
   - Type: feature

## LINKED ISSUES
Closes: #456 - "Issue title"
```

### Example Usage
```
User: "What's in PR #1234?"
Assistant: [Invokes hermes-pr-courier to gather PR content information]
```

---

## Customization

### Modifying Trigger Phrases
Edit the `description` field in each agent's frontmatter to add or modify trigger phrases. Include "PROACTIVELY USED" followed by the phrases.

### Changing Output Format
Modify the output format section in each agent's prompt. Keep it structured and LLM-optimized for best results.

### Switching Models
Change `model: sonnet` to `model: opus` in the frontmatter for more complex reasoning (higher cost).

### Adding Tools
Add tool names to the `tools:` list in the frontmatter. Ensure the tools are available in your Claude Code environment.

## Tips for Effective Usage

1. **Let agents work proactively**: Don't explicitly ask to use agents; just mention the keywords
2. **Use parallel execution**: Multiple agents can run simultaneously for different tasks
3. **Chain agent outputs**: Use one agent's output as context for another
4. **Keep agents updated**: Pull latest changes and re-run installer for updates

## Common Patterns

### Starting New Feature Work
```
"I'm starting work on PROJ-123, check if there's a PR already"
→ Triggers both atlas-jira-analyst and heimdall-pr-guardian
```

### Code Review Preparation
```
"Review PR #456 and get the Jira context"
→ Triggers hermes-pr-courier and atlas-jira-analyst
```

### Checking PR Readiness
```
"Is my PR ready to merge? Check comments and status"
→ Triggers heimdall-pr-guardian
```