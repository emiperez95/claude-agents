import os
from pathlib import Path
from typing import Dict, List, Any, Optional


class AgentValidator:
    """Validate agent files and check installation status."""
    
    def __init__(self, agents_dir: str = "../agents"):
        self.agents_dir = Path(agents_dir)
        self.claude_agents_dir = Path.home() / ".claude" / "agents"
    
    def validate_agent_structure(self, agent_data: Dict[str, Any]) -> Dict[str, Any]:
        """Validate that an agent has all required fields."""
        required_fields = ['name', 'description', 'tools', 'model']
        optional_fields = ['color']
        
        validation = {
            'valid': True,
            'errors': [],
            'warnings': []
        }
        
        # Check required fields
        for field in required_fields:
            if field not in agent_data or not agent_data[field]:
                validation['valid'] = False
                validation['errors'].append(f"Missing required field: {field}")
        
        # Validate model
        valid_models = ['opus', 'sonnet', 'haiku']
        if agent_data.get('model') not in valid_models:
            validation['warnings'].append(
                f"Unknown model: {agent_data.get('model')}. Expected one of {valid_models}"
            )
        
        # Check description length
        desc_length = len(agent_data.get('description', ''))
        if desc_length < 10:
            validation['warnings'].append("Description is very short")
        elif desc_length > 1000:
            validation['warnings'].append("Description is very long (>1000 chars)")
        
        # Check for PROACTIVELY USED keyword
        if 'PROACTIVELY USED' not in agent_data.get('description', ''):
            validation['warnings'].append(
                "Description missing 'PROACTIVELY USED' keyword for auto-triggering"
            )
        
        # Validate tools
        if not agent_data.get('tools'):
            validation['errors'].append("No tools specified")
            validation['valid'] = False
        
        return validation
    
    def check_installation_status(self, agent_name: str) -> Dict[str, Any]:
        """Check if an agent is installed (has symlink in ~/.claude/agents/)."""
        agent_filename = f"{agent_name}.md"
        symlink_path = self.claude_agents_dir / agent_filename
        source_path = self.agents_dir / agent_filename
        
        status = {
            'installed': False,
            'symlink_exists': False,
            'symlink_valid': False,
            'symlink_path': str(symlink_path),
            'source_path': str(source_path),
            'details': ''
        }
        
        if not self.claude_agents_dir.exists():
            status['details'] = "Claude agents directory doesn't exist"
            return status
        
        if symlink_path.exists():
            status['symlink_exists'] = True
            
            if symlink_path.is_symlink():
                # Check if symlink points to correct location
                try:
                    target = os.readlink(symlink_path)
                    target_path = Path(target)
                    
                    if target_path.exists():
                        status['symlink_valid'] = True
                        status['installed'] = True
                        status['details'] = f"Installed (linked to {target})"
                    else:
                        status['details'] = f"Broken symlink (points to {target})"
                except:
                    status['details'] = "Error reading symlink"
            else:
                status['details'] = "File exists but is not a symlink"
        else:
            status['details'] = "Not installed"
        
        return status
    
    def validate_all_agents(self, agents: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Validate all agents and return summary."""
        results = {
            'total': len(agents),
            'valid': 0,
            'invalid': 0,
            'warnings': 0,
            'installed': 0,
            'not_installed': 0,
            'details': []
        }
        
        for agent in agents:
            # Validate structure
            validation = self.validate_agent_structure(agent)
            
            # Check installation
            installation = self.check_installation_status(agent['name'])
            
            agent_result = {
                'name': agent['name'],
                'valid': validation['valid'],
                'errors': validation['errors'],
                'warnings': validation['warnings'],
                'installed': installation['installed'],
                'installation_details': installation['details']
            }
            
            results['details'].append(agent_result)
            
            # Update counters
            if validation['valid']:
                results['valid'] += 1
            else:
                results['invalid'] += 1
            
            if validation['warnings']:
                results['warnings'] += 1
            
            if installation['installed']:
                results['installed'] += 1
            else:
                results['not_installed'] += 1
        
        return results