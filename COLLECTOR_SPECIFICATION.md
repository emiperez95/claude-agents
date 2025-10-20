# Collector Agent Specification

## Overview

Collectors are specialized agents that retrieve and structure data from external sources. They act as pure information pipelines without adding interpretation or analysis.

## Core Principle: "Show Your Work"

Collectors must return ALL data they fetch and process, not just conclusions. The parent agent needs the full evidence chain to make informed decisions.

## Fundamental Rules

### What Collectors ARE
- **Data Retrievers** - Fetch information from specific sources
- **Structure Providers** - Format data for optimal LLM consumption
- **Traversal Executors** - Follow relationships within defined depths
- **Error Reporters** - Transparently communicate failures

### What Collectors ARE NOT
- **Not Decision Makers** - They don't choose what data is "important"
- **Not Filters** - They don't remove "irrelevant" information
- **Not Translators** - They structure but don't interpret meaning
- **Not Advisors** - They don't suggest what to do with the data

## Traversal Logic: Default + Override

### Two-Layer Rule

**Layer 1: Default Behavior (Always)**
- Built into each Collector's prompt as non-negotiable defaults
- Executed regardless of user input
- Defines standard traversal depth (typically 2 levels)

**Layer 2: Keyword Enhancement (Optional)**
- Additional traversal triggered by specific keywords
- Extends beyond default behavior
- Can override depth limits when explicitly requested

### Example Implementation

```markdown
## Data Collection Rules

### DEFAULT BEHAVIOR (Always Execute):
- Fetch the requested issue
- IF issue has epicLink → ALWAYS fetch the epic
- IF epic exists → fetch all stories in epic (basic fields)
- Include all comments and acceptance criteria

### KEYWORD ENHANCEMENTS (When Detected):
- "with subtasks" / "include subtasks" → fetch all subtasks
- "full epic" / "complete epic" → fetch epic stories with full details
- "with program" / "program context" → fetch program level (exception to depth limit)
- "related issues" / "linked issues" → fetch issue links
- "with history" / "include history" → fetch changelog
```

## Data Collection Boundaries

### Allowed Operations

✅ **Smart Aggregation Within Source**
```
GOOD: 
- Fetch story PROJ-123
- See it has epic PROJ-100
- Fetch epic PROJ-100  
- Fetch other stories in epic
- Return ALL of it structured
```

✅ **Calculation for Retrieval (not Analysis)**
```
ALLOWED:
- Calculate "last week" = dates between X and Y
- Use that to query API
- Return all items from that query
```

✅ **Complete Context**
- If you looked at it, include it
- Every field from every entity fetched
- Full text of descriptions, comments, criteria
- All related entities within traversal depth

### Prohibited Operations

❌ **Hidden Processing**
```
BAD: "Based on my analysis of 15 comments..."
GOOD: [Show all 15 comments in full]
```

❌ **Lossy Summarization**
```
BAD: "The epic contains 5 stories about authentication"
GOOD: [List all 5 stories with their complete details]
```

❌ **Internal Filtering**
```
BAD: "The relevant fields are X, Y, Z"
GOOD: [Show all fields, let parent decide relevance]
```

## Output Format Standards

### 1. Hierarchical Structure
```markdown
# PRIMARY ENTITY: [Type and ID]
[Primary entity data]

## RELATED LEVEL 1: [Relationship Type]
[Related data from default traversal]

### ENHANCED DATA: [If keyword triggered]
[Additional data from keyword requests]
```

### 2. Field Presentation
```markdown
## ISSUE DETAILS
ID: PROJ-123
Title: [Full title text]
Status: In Progress
Type: Story
Created: 2024-01-15T10:30:00Z
Updated: 2024-01-20T14:45:00Z
Reporter: @john.doe
Assignee: @jane.smith

## DESCRIPTION
[Full description text preserved exactly]
```

### 3. Lists and Counts
```markdown
## COMMENTS (12 total)
### Comment 1
Author: @reviewer1
Date: 2024-01-19T09:00:00Z
Text: [Full comment text]
```

### 4. Traversal Indicators
Show what triggered non-default fetching:
```markdown
## SUBTASKS (Requested via keyword: "with subtasks")
- PROJ-123a: Design UI components
- PROJ-123b: Implement backend API
```

## Error Handling Protocol

### The "Show Everything, Mark Failures" Principle

Always return all successful data, clearly marking what failed.

### Error Marking Format
```markdown
## EPIC: PROJ-100 [ERROR: Failed to fetch]
Error: API timeout after 30 seconds
Attempted: 2024-01-20T10:30:00Z
Impact: Epic details and related stories unavailable

## COMMENTS (Partial - 5 of 12 retrieved)
[ERROR: Comments 6-12 failed to load - API rate limit]
### Comment 1
[Show the 5 that loaded successfully]
```

### Error Categories

| Error Type | Response Format |
|------------|-----------------|
| **Timeout** | `Field: [ERROR: Timeout after 30s]` |
| **Permission Denied** | `Field: [ERROR: Insufficient permissions]` |
| **Not Found** | `Field: [ERROR: Not found or deleted]` |
| **Rate Limited** | `Field: X shown [ERROR: Rate limit, Y more exist]` |
| **Invalid Reference** | `Field: [ERROR: Does not exist]` |
| **API Error** | `[ERROR: API returned XXX - Error message]` |

## Language Patterns

### Correct Collector Language

✅ **Factual Presentations**
- "The following data was retrieved:"
- "Epic contains these stories:"
- "Comments on this PR:"
- "Linked issues found:"
- "Total count: X"

✅ **Structural Markers**
- "## SECTION NAME"
- "### Subsection"
- "- List item"
- Clear hierarchical organization

### Anti-Pattern Language to Avoid

🚩 **Analysis Language**
- "Based on my analysis..."
- "It appears that..."
- "The trend shows..."
- "This suggests..."

🚩 **Summary Statements**
- "In summary..."
- "The main points are..."
- "Key takeaways..."
- "Overall..."

🚩 **Filtering Phrases**
- "The relevant items..."
- "The important parts..."
- "Focusing on..."
- "The critical elements..."

🚩 **Interpretation Words**
- "This means..."
- "Therefore..."
- "Because of this..."
- "This indicates..."

## Practical Examples

### Good Collector Output
```markdown
# JIRA ISSUE: PROJ-123
Title: Implement user authentication
Status: In Progress

## EPIC RELATIONSHIP
Epic: PROJ-100 - Security Framework
(Fetched because issue has epicLink field)

### EPIC DETAILS: PROJ-100
Title: Security Framework Implementation
Stories in Epic: 8 total

### OTHER STORIES IN EPIC:
1. PROJ-120 - OAuth integration
   Status: Done
2. PROJ-121 - Session management  
   Status: In Progress
[... all 8 stories listed ...]

## COMMENTS ON PROJ-123:
[All comments with full text]

## ACCEPTANCE CRITERIA:
[Full text of criteria]
```

### Bad Collector Output
```markdown
# JIRA ISSUE: PROJ-123
This is an authentication story that's part of a larger security initiative 
with 3 related stories currently in progress. The team seems focused on 
security improvements this sprint.
```

## Key Implementation Notes

1. **Information Loss Prevention**: The core problem Collectors solve is preventing information loss between agent and parent. All data processed internally must be returned.

2. **Traversal Depth**: Default 2 levels (e.g., story → epic), configurable via agent prompt instructions, not frontmatter.

3. **Keyword Parsing**: Collectors should recognize keywords in user input to enhance default behavior without replacing it.

4. **Error Transparency**: Partial failures should return partial data with clear error marking, not complete failure.

5. **Format for LLMs**: Output should be structured for machine parsing, not human reading. Use consistent hierarchical markdown.

## Validation Checklist

When reviewing a Collector agent, verify:

- [ ] Returns all fetched data, not summaries
- [ ] No analysis or interpretation language
- [ ] Clear hierarchical structure in output
- [ ] Error states marked but don't block partial data
- [ ] Default behavior defined in prompt
- [ ] Keyword enhancements documented
- [ ] No filtering based on "importance"
- [ ] Complete field preservation
- [ ] Factual language only