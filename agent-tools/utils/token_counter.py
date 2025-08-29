import tiktoken
from typing import Dict, Any


class TokenCounter:
    """Count tokens in text using OpenAI's tiktoken library."""
    
    def __init__(self, model: str = "cl100k_base"):
        """Initialize with the tokenizer for the specified model.
        
        Args:
            model: The encoding model to use. Options:
                   - "cl100k_base" for GPT-4, GPT-3.5-turbo, text-embedding-ada-002
                   - "p50k_base" for Codex models
                   - "r50k_base" for GPT-3 models
        """
        try:
            self.encoder = tiktoken.get_encoding(model)
        except:
            # Fallback to cl100k_base if model not found
            self.encoder = tiktoken.get_encoding("cl100k_base")
    
    def count_tokens(self, text: str) -> int:
        """Count the number of tokens in a text string."""
        if not text:
            return 0
        tokens = self.encoder.encode(text)
        return len(tokens)
    
    def analyze_agent_tokens(self, agent_data: Dict[str, Any]) -> Dict[str, int]:
        """Analyze token counts for different parts of an agent."""
        return {
            'description_tokens': self.count_tokens(agent_data.get('description', '')),
            'body_tokens': self.count_tokens(agent_data.get('body', '')),
            'full_content_tokens': self.count_tokens(agent_data.get('full_content', '')),
            'name_tokens': self.count_tokens(agent_data.get('name', '')),
            'tools_text_tokens': self.count_tokens(', '.join(agent_data.get('tools', [])))
        }
    
    def estimate_cost(self, token_count: int, model: str = "gpt-4") -> Dict[str, float]:
        """Estimate API costs based on token count.
        
        Returns costs in USD for different models.
        Prices as of 2024 (may need updating).
        """
        pricing = {
            'gpt-4': {'input': 0.03, 'output': 0.06},  # per 1K tokens
            'gpt-4-32k': {'input': 0.06, 'output': 0.12},
            'gpt-3.5-turbo': {'input': 0.0015, 'output': 0.002},
            'claude-3-opus': {'input': 0.015, 'output': 0.075},
            'claude-3-sonnet': {'input': 0.003, 'output': 0.015},
            'claude-3-haiku': {'input': 0.00025, 'output': 0.00125}
        }
        
        if model not in pricing:
            return {'error': 'Unknown model'}
        
        # Calculate costs (prices are per 1K tokens)
        input_cost = (token_count / 1000) * pricing[model]['input']
        output_cost = (token_count / 1000) * pricing[model]['output']
        
        return {
            'input_cost': round(input_cost, 6),
            'output_cost': round(output_cost, 6),
            'total_cost': round(input_cost + output_cost, 6),
            'model': model,
            'tokens': token_count
        }
    
    def format_token_size(self, token_count: int) -> str:
        """Format token count with appropriate sizing label."""
        if token_count < 100:
            return f"{token_count} tokens (tiny)"
        elif token_count < 500:
            return f"{token_count} tokens (small)"
        elif token_count < 2000:
            return f"{token_count} tokens (medium)"
        elif token_count < 8000:
            return f"{token_count} tokens (large)"
        else:
            return f"{token_count} tokens (very large)"
    
    def calculate_context_percentage(self, token_count: int, context_limit: int = 200000) -> float:
        """Calculate percentage of context window used.
        
        Args:
            token_count: Number of tokens
            context_limit: Total context window size (default 200k for Claude)
        
        Returns:
            Percentage of context used (0-100)
        """
        return (token_count / context_limit) * 100