import os
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Any
import re


class AgentParser:
    """Parse Claude Code agent markdown files to extract metadata and content."""
    
    def __init__(self, agents_dir: str = "../agents"):
        self.agents_dir = Path(agents_dir)
        if not self.agents_dir.exists():
            raise ValueError(f"Agents directory not found: {self.agents_dir}")
        # Global agents directory
        self.global_agents_dir = Path.home() / ".claude" / "agents"
    
    def parse_agent_file(self, filepath: Path) -> Dict[str, Any]:
        """Parse a single agent markdown file."""
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Split frontmatter and body
        parts = content.split('---', 2)
        if len(parts) < 3:
            raise ValueError(f"Invalid agent file format: {filepath}")
        
        # Parse YAML frontmatter - try to handle complex strings
        frontmatter = self._parse_frontmatter_safely(parts[1])
        body = parts[2].strip()
        
        # Parse tools list
        tools = []
        if 'tools' in frontmatter:
            tools_str = frontmatter['tools']
            if isinstance(tools_str, str):
                tools = [t.strip() for t in tools_str.split(',')]
            elif isinstance(tools_str, list):
                tools = tools_str
        
        # Categorize tools
        mcp_tools = [t for t in tools if t.startswith('mcp__')]
        standard_tools = [t for t in tools if not t.startswith('mcp__')]
        
        # Determine agent category
        name = frontmatter.get('name', filepath.stem)
        category = self.get_agent_category(name)
        
        return {
            'name': name,
            'description': frontmatter.get('description', ''),
            'model': frontmatter.get('model', 'unknown'),
            'color': frontmatter.get('color', 'default'),
            'category': category,
            'tools': tools,
            'mcp_tools': mcp_tools,
            'standard_tools': standard_tools,
            'tool_count': len(tools),
            'body': body,
            'full_content': content,
            'filepath': str(filepath),
            'filename': filepath.name
        }
    
    def _parse_frontmatter_safely(self, frontmatter_text: str) -> Dict[str, Any]:
        """Safely parse YAML frontmatter, handling complex description fields."""
        # First try standard YAML parsing
        try:
            return yaml.safe_load(frontmatter_text)
        except yaml.YAMLError:
            pass
        
        # If that fails, parse manually
        result = {}
        lines = frontmatter_text.strip().split('\n')
        current_key = None
        current_value = []
        
        for line in lines:
            # Check if this is a new key
            if ':' in line and not line.startswith(' '):
                # Save previous key-value if exists
                if current_key:
                    value = '\n'.join(current_value).strip()
                    # Clean up escaped characters
                    value = value.replace('\\n', '\n')
                    result[current_key] = value
                
                # Parse new key-value
                parts = line.split(':', 1)
                current_key = parts[0].strip()
                if len(parts) > 1:
                    current_value = [parts[1].strip()]
                else:
                    current_value = []
            else:
                # Continue value from previous line
                if current_key:
                    current_value.append(line)
        
        # Save last key-value
        if current_key:
            value = '\n'.join(current_value).strip()
            value = value.replace('\\n', '\n')
            result[current_key] = value
        
        return result
    
    def get_agent_category(self, agent_name: str) -> str:
        """Determine the category of an agent based on its name and purpose."""
        # Define agent categories
        orchestrators = ['athena-pr-reviewer']
        information_gatherers = [
            'atlas-jira-analyst',
            'heimdall-pr-guardian', 
            'hermes-pr-courier',
            'minerva-notion-oracle'
        ]
        
        if agent_name in orchestrators:
            return 'Orchestrator'
        elif agent_name in information_gatherers:
            return 'Information Gatherer'
        else:
            # No category for other agents
            return ''
    
    def get_all_agents(self) -> List[Dict[str, Any]]:
        """Parse all agent files in the agents directory."""
        agents = []
        
        for filepath in self.agents_dir.glob('*.md'):
            try:
                agent_data = self.parse_agent_file(filepath)
                agents.append(agent_data)
            except Exception as e:
                print(f"Error parsing {filepath}: {e}")
                continue
        
        return sorted(agents, key=lambda x: x['name'])
    
    def get_agent_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Get a specific agent by name."""
        for agent in self.get_all_agents():
            if agent['name'] == name or agent['filename'] == f"{name}.md":
                return agent
        return None
    
    def get_tools_summary(self) -> Dict[str, Any]:
        """Get summary of all tools used across agents."""
        all_tools = set()
        tool_usage = {}
        
        agents = self.get_all_agents()
        
        for agent in agents:
            for tool in agent['tools']:
                all_tools.add(tool)
                if tool not in tool_usage:
                    tool_usage[tool] = []
                tool_usage[tool].append(agent['name'])
        
        # Find tools used by multiple agents
        shared_tools = {tool: agents for tool, agents in tool_usage.items() 
                       if len(agents) > 1}
        
        return {
            'total_unique_tools': len(all_tools),
            'tool_usage': tool_usage,
            'shared_tools': shared_tools,
            'mcp_tools': [t for t in all_tools if t.startswith('mcp__')],
            'standard_tools': [t for t in all_tools if not t.startswith('mcp__')]
        }
    
    def get_all_global_agents(self) -> List[Dict[str, Any]]:
        """Parse all agent files in the global Claude agents directory."""
        agents = []
        
        if not self.global_agents_dir.exists():
            return agents
        
        for filepath in self.global_agents_dir.glob('*.md'):
            try:
                agent_data = self.parse_agent_file(filepath)
                # Mark as global agent
                agent_data['source'] = 'global'
                agent_data['source_dir'] = str(self.global_agents_dir)
                agents.append(agent_data)
            except Exception as e:
                print(f"Error parsing {filepath}: {e}")
                continue
        
        return sorted(agents, key=lambda x: x['name'])