# Gemini CLI for Large Codebase Analysis

Use the Gemini CLI to analyze large codebases or multiple files that might exceed Claude's context limits. Leverage Google Gemini's massive context window for comprehensive codebase analysis.

## File and Directory Inclusion Syntax

Use the `@` syntax to include files and directories in Gemini prompts. Paths are relative to the current working directory:

### Examples

**Single file:**
```bash
gemini -p "@src/main.py Explain this file's purpose and structure"
```

**Multiple files:**
```bash
gemini -p "@package.json @src/index.js Analyze the dependencies used in the code"
```

**Entire directory:**
```bash
gemini -p "@src/ Summarize the architecture of this codebase"
```

**Multiple directories:**
```bash
gemini -p "@src/ @tests/ Analyze test coverage for the source code"
```

**Current directory:**
```bash
gemini -p "@./ Give me an overview of this entire project"
```

**All files flag:**
```bash
gemini --all_files -p "Analyze the project structure and dependencies"
```

## Common Use Cases

**Feature verification:**
```bash
gemini -p "@src/ @lib/ Has dark mode been implemented? Show relevant files and functions"
```

**Authentication check:**
```bash
gemini -p "@src/ @middleware/ Is JWT authentication implemented? List auth-related endpoints"
```

**Pattern detection:**
```bash
gemini -p "@src/ Are there React hooks handling WebSocket connections? List with file paths"
```

**Error handling audit:**
```bash
gemini -p "@src/ @api/ Is proper error handling implemented for all API endpoints?"
```

**Security review:**
```bash
gemini -p "@src/ @api/ Are SQL injection protections implemented? Show input sanitization"
```

**Test coverage:**
```bash
gemini -p "@src/payment/ @tests/ Is the payment module fully tested? List test cases"
```

**Architecture analysis:**
```bash
gemini -p "@src/ @lib/ Explain the overall architecture and key design patterns"
```

**Dependency mapping:**
```bash
gemini -p "@src/ Map out all module dependencies and their relationships"
```

## When to Use This Skill

Invoke this skill when:
- Analyzing entire codebases or large directories
- Comparing multiple large files
- Understanding project-wide patterns or architecture
- Current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if features, patterns, or security measures are implemented
- Checking for coding patterns across the entire codebase
- User explicitly requests using Gemini for analysis

## Execution Instructions

1. Construct the appropriate `gemini -p` command with `@` syntax for files/directories
2. Use the Bash tool to execute the command
3. Capture and return Gemini's analysis
4. Summarize key findings if output is very long
5. Provide actionable insights based on Gemini's response

## Important Notes

- Paths in `@` syntax are relative to current working directory
- This is read-only analysis - no `--yolo` flag needed
- Gemini's context window can handle entire codebases
- Be specific in prompts for accurate results
- File contents are included directly in Gemini's context

## Requirements

- Gemini CLI must be installed: `npm install -g @google/gemini-cli`
- Authenticate with Google account (runs automatically on first use)
- Verify installation: `gemini --version`
