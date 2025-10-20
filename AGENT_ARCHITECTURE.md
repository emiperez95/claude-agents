# Agent Architecture: Two-Tier System

## Overview

This repository implements a two-tier agent architecture designed to optimize context usage, enable parallelization, and maintain clear separation of concerns. The system consists of two distinct agent types: **Collectors** and **Orchestrators**.

## Core Philosophy

The architecture separates information gathering from decision-making, allowing each agent to excel at its specific role while minimizing context overhead for the parent Claude instance.

## Agent Types

### 1. Collectors (Information Gathering Layer)

Collectors are specialized agents that retrieve and structure data from external sources. They act as pure information pipelines without adding interpretation or analysis.

#### Definition
A Collector is an agent that:
- Fetches data from specific sources (APIs, CLIs, documents)
- Structures information for optimal LLM consumption
- Returns raw, unprocessed data
- Never provides opinions, analysis, or recommendations

#### Key Characteristics
- **Stateless**: Each invocation is independent
- **Deterministic**: Same input produces same data structure
- **Parallel-friendly**: Multiple collectors can run simultaneously
- **Context-efficient**: Minimizes token usage by avoiding analysis
- **Error-transparent**: Reports failures without attempting recovery

#### Input/Output Contract
- **Input**: Specific identifiers (PR number, Jira ID, search query)
- **Output**: Structured text optimized for LLM parsing (not JSON)
- **Errors**: Clear status codes with minimal explanation

#### Current Collectors
- `atlas-jira-analyst`: Fetches Jira issue data, epics, and requirements
- `heimdall-pr-guardian`: Collects PR status, comments, and CI/CD state
- `hermes-pr-courier`: Gathers PR content, files, and commit history
- `minerva-notion-oracle`: Retrieves Notion workspace content

#### Example Collector Behavior
```
User: "Get PR #123 status"
Collector Output:
# PULL REQUEST STATUS: #123
Status: BLOCKED
Comments: 7 unresolved
CI Checks: 2 of 5 failing
Approvals: 1 of 2 received
[Raw data continues...]
```

### 2. Orchestrators (Coordination Layer)

Orchestrators are lightweight decision-makers that determine execution flow and coordinate multiple agents without processing data themselves.

#### Definition
An Orchestrator is an agent that:
- Parses user intent to identify required data sources
- Outputs executable commands for agent invocation
- Provides synthesis instructions for the parent agent
- Operates in fire-and-forget mode (single phase)

#### Key Characteristics
- **Minimal input**: Requires only enough context to make routing decisions
- **Command output**: Returns structured agent invocation instructions
- **No data processing**: Never analyzes or synthesizes information
- **Single-phase**: No callbacks or multi-round interactions
- **Synthesis delegation**: Provides instructions for parent agent to process results

#### Input/Output Contract
- **Input**: User request with minimal context
- **Output**: `ORCHESTRATION REQUIRED` block with commands and synthesis instructions
- **Execution**: Parent agent runs commands and performs synthesis

#### Current Orchestrators
- `athena-pr-reviewer`: Coordinates comprehensive PR review workflows

#### Example Orchestrator Behavior
```
User: "Review PR #123"
Orchestrator Output:
=== ORCHESTRATION REQUIRED ===
AGENTS TO EXECUTE:
1. Task: atlas-jira-analyst
   Prompt: "Get context for PROJ-123"
2. Task: hermes-pr-courier
   Prompt: "What's in PR #123"
3. Task: heimdall-pr-guardian
   Prompt: "Check status of PR #123"

SYNTHESIS INSTRUCTIONS:
1. Compare Jira requirements with implementation
2. Identify missing requirements
3. Check for blocking issues
[Instructions continue...]
=== END ORCHESTRATION ===
```

## Interaction Patterns

### Pattern 1: Direct Collector Invocation
```
User → Claude → Collector → Claude → User
```
Used when user needs specific data from a single source.

### Pattern 2: Orchestrated Multi-Collector
```
User → Claude → Orchestrator → Claude → [Collectors in parallel] → Claude → User
```
Used for complex tasks requiring multiple data sources.

### Pattern 3: Nested Orchestration (Future)
```
User → Claude → Orchestrator₁ → Claude → Orchestrator₂ → Claude → Collectors → Claude → User
```
For highly complex workflows with conditional logic.

## Design Principles

### 1. Separation of Concerns
- Collectors gather, Orchestrators coordinate, Claude synthesizes
- No agent performs multiple roles
- Clear boundaries between data and decisions

### 2. Context Efficiency
- Collectors reduce raw data to structured format
- Orchestrators use minimal input for routing
- Parent agent receives only necessary information

### 3. Parallelization
- Multiple collectors can run simultaneously
- No inter-agent dependencies during execution
- Orchestrators enable batch processing

### 4. Transparency
- Collectors present data without filtering
- Orchestrators show exact commands to execute
- Error states are clearly communicated

### 5. Composability
- Agents can be combined in various patterns
- New collectors can be added without changing orchestrators
- Orchestrators can be chained for complex workflows

## Implementation Guidelines

### For Collectors

1. **Never interpret data** - Present facts only
2. **Preserve verbatim content** - Don't paraphrase or summarize
3. **Structure for scanning** - Use consistent headers and formatting
4. **Handle errors gracefully** - Report failures without recovery attempts
5. **Optimize for LLMs** - Use readable text, not JSON

### For Orchestrators

1. **Parse intent quickly** - Identify required agents from user input
2. **Output commands only** - Don't perform any data operations
3. **Provide clear synthesis instructions** - Tell parent what to do with results
4. **Exit immediately** - Fire-and-forget execution model
5. **Handle ambiguity** - Provide fallback instructions when intent unclear

## Benefits

### 1. Reduced Context Usage
- Parent agent doesn't process raw API responses
- Collectors compress data into structured format
- Orchestrators use minimal tokens for routing

### 2. Improved Parallelization
- Multiple data sources fetched simultaneously
- No sequential dependencies between collectors
- Faster overall execution time

### 3. Better Error Handling
- Each agent handles its specific error domain
- Failures are isolated to individual collectors
- Orchestrators provide fallback paths

### 4. Easier Maintenance
- Single responsibility makes agents simpler
- Clear contracts enable independent updates
- New agents can be added without system changes

### 5. Enhanced Scalability
- Can add unlimited collectors for new data sources
- Orchestrators can coordinate any number of agents
- System grows without increasing complexity

## Future Enhancements

### 1. Conditional Orchestration
Allow orchestrators to specify conditional execution:
```
IF jira_ticket_exists THEN
  Execute: atlas-jira-analyst
ELSE
  Skip requirements validation
```

### 2. Nested Orchestration
Enable orchestrators to call other orchestrators for complex workflows.

### 3. Collector Caching
Add time-based caching to reduce API calls for frequently accessed data.

### 4. Type Validation
Implement formal type checking for agent inputs/outputs.

### 5. Performance Metrics
Track execution time and token usage per agent type.

## Conclusion

The two-tier architecture of Collectors and Orchestrators provides a scalable, efficient system for agent-based information processing. By maintaining strict separation between data gathering and coordination, the system achieves optimal context usage while enabling powerful parallel workflows.