# Claude Code Agent Development Learnings

## Date: 2025-08-29

### Orchestration Patterns

#### ❌ Two-Phase Orchestration (Inefficient)
- **Pattern**: Agent outputs commands → Claude executes → Returns all data to agent → Agent synthesizes
- **Problem**: Massive context passing defeats purpose of lightweight orchestrators
- **Learning**: Agents become context holders rather than decision makers

#### ✅ Single-Phase Orchestration (Fire-and-Forget)
- **Pattern**: Agent outputs commands + synthesis instructions → Claude executes and synthesizes directly
- **Benefits**: 
  - No context passing back to agent
  - Orchestrators can use cheaper models (Sonnet vs Opus)
  - True separation of concerns
- **Implementation**: Use `=== ORCHESTRATION REQUIRED ===` blocks with synthesis instructions

### Agent Limitations

#### Agents Cannot Call Other Agents
- **Discovery**: Agents don't have access to the Task tool
- **Tested**: Created test-orchestrator to verify
- **Workaround**: Command-output pattern where agents output instructions for Claude to execute

#### Orchestrators Are Not Data Processors
- **Principle**: Orchestrators should only route/decide, not process results
- **Implementation**: Output commands then exit immediately
- **Benefit**: Enables cheaper, faster orchestration

### Triggering Issues

#### PROACTIVELY USED Pattern
- **Working Format**: Must use exact phrase "PROACTIVELY USED" in all caps
- **Not Working**: "Use proactively" (lowercase) doesn't trigger
- **Mystery**: Even with correct format, some agents don't trigger as expected (Athena case)

#### Description Length Impact
- **Hypothesis**: Very long descriptions with examples might interfere with triggering
- **Test**: Reduced Athena from 1000+ chars to 150 chars
- **Result**: Still didn't trigger reliably
- **Unknown**: Root cause of why some agents trigger and others don't

### Installation & Management

#### Symbolic Links Strategy
- **Pattern**: Local agents in `agents/` → symlinked to `~/.claude/agents/`
- **Benefit**: Edit local files, changes immediately reflected globally
- **No Restart Needed**: For file content changes (prompt updates)
- **Restart Needed**: For new agents or description changes

#### Manual vs Auto-Discovery
- **Current**: Manually list agents in install script
- **Pro**: Explicit control, prevents accidental installations
- **Con**: Must update installer for each new agent
- **Decision**: Keep manual for safety and documentation

### Model Selection

#### Orchestrators Can Use Sonnet
- **Before**: Thought complex agents needed Opus
- **After**: Single-phase orchestrators just route, can use Sonnet
- **Savings**: Significant cost reduction for orchestration

#### Data Gatherers Use Sonnet
- **Pattern**: Pure information collectors work fine with Sonnet
- **Examples**: Atlas, Hermes, Heimdall all use Sonnet successfully

### Testing Patterns

#### Test Agents Are Valuable
- **Example**: test-orchestrator helped prove architectural limitations
- **Practice**: Create test agents to verify patterns before full implementation
- **Cleanup**: Keep test agents in repo but exclude from installer

### Unsolved Mysteries

1. **Why doesn't Athena trigger on "review PR" despite correct format?**
   - Has "PROACTIVELY USED"
   - Has simple description
   - Other agents with similar patterns work
   - Workaround: Call by name explicitly

2. **Is there a character limit for descriptions?**
   - Some long descriptions work (heimdall)
   - Some short ones don't (athena)
   - No clear pattern identified

3. **Does agent load order matter?**
   - Unknown if alphabetical order affects triggering
   - Unknown if conflicts between similar triggers exist

## Future Experiments

- [ ] Test if agent file naming affects triggering
- [ ] Test if removing other agents helps Athena trigger
- [ ] Test if specific keywords are reserved/conflicting
- [ ] Create minimal test case for triggering issues
- [ ] Document CLAUDE.md alternatives for repo-agnostic patterns

## Best Practices Discovered

1. **Keep orchestrators simple** - Just routing logic, no data processing
2. **Use clear block markers** - `=== ORCHESTRATION REQUIRED ===` for commands
3. **Test patterns with minimal agents** - Before building complex ones
4. **Document synthesis instructions** - Don't assume Claude knows what to do
5. **Version control everything** - Including test agents and failed experiments

---
*This diary tracks our experiments and learnings with Claude Code agent development. Update whenever we discover new patterns or encounter unexpected behavior.*