#!/usr/bin/env python3
"""
Claude Code Agent Web Dashboard
A web interface for viewing and analyzing Claude Code agents.
"""

from flask import Flask, render_template, jsonify, send_file
import json
from pathlib import Path
from utils import AgentParser, TokenCounter, AgentValidator
import plotly.graph_objs as go
import plotly.utils

app = Flask(__name__)
app.config['TEMPLATES_AUTO_RELOAD'] = True

# Initialize utilities
parser = AgentParser()
counter = TokenCounter()
validator = AgentValidator()


@app.route('/')
def index():
    """Main dashboard page."""
    agents = parser.get_all_agents()
    
    # Enhance agent data with tokens and installation status
    for agent in agents:
        tokens = counter.analyze_agent_tokens(agent)
        installation = validator.check_installation_status(agent['name'])
        agent['tokens'] = tokens
        agent['installed'] = installation['installed']
        agent['installation_details'] = installation['details']
        # Ensure category is present
        if 'category' not in agent:
            agent['category'] = 'Unknown'
    
    return render_template('dashboard.html', agents=agents)


@app.route('/api/agents')
def api_agents():
    """API endpoint to get all agents data."""
    agents = parser.get_all_agents()
    
    # Prepare data for JSON response
    result = []
    for agent in agents:
        tokens = counter.analyze_agent_tokens(agent)
        installation = validator.check_installation_status(agent['name'])
        
        context_percentage = (tokens['full_content_tokens'] / 200000) * 100
        
        result.append({
            'name': agent['name'],
            'category': agent.get('category', 'Unknown'),
            'model': agent['model'],
            'color': agent.get('color', 'default'),
            'tools': agent['tools'],
            'tool_count': len(agent['tools']),
            'mcp_tools': len(agent['mcp_tools']),
            'standard_tools': len(agent['standard_tools']),
            'description': agent['description'],
            'description_tokens': tokens['description_tokens'],
            'body_tokens': tokens['body_tokens'],
            'total_tokens': tokens['full_content_tokens'],
            'context_percentage': round(context_percentage, 3),
            'installed': installation['installed'],
            'installation_details': installation['details']
        })
    
    return jsonify(result)


@app.route('/api/agent/<name>')
def api_agent_detail(name):
    """API endpoint to get specific agent details."""
    agent = parser.get_agent_by_name(name)
    
    if not agent:
        return jsonify({'error': 'Agent not found'}), 404
    
    tokens = counter.analyze_agent_tokens(agent)
    validation = validator.validate_agent_structure(agent)
    installation = validator.check_installation_status(agent['name'])
    
    # Calculate cost estimates
    costs = {}
    for model in ['claude-3-opus', 'claude-3-sonnet', 'claude-3-haiku']:
        costs[model] = counter.estimate_cost(tokens['full_content_tokens'], model)
    
    return jsonify({
        'agent': agent,
        'tokens': tokens,
        'validation': validation,
        'installation': installation,
        'costs': costs
    })


@app.route('/api/stats')
def api_stats():
    """API endpoint for aggregate statistics."""
    agents = parser.get_all_agents()
    tools_summary = parser.get_tools_summary()
    
    # Calculate statistics
    total_tokens = 0
    model_distribution = {}
    token_distribution = []
    
    for agent in agents:
        tokens = counter.analyze_agent_tokens(agent)
        total_tokens += tokens['full_content_tokens']
        token_distribution.append({
            'name': agent['name'],
            'tokens': tokens['full_content_tokens']
        })
        
        model = agent.get('model', 'unknown')
        model_distribution[model] = model_distribution.get(model, 0) + 1
    
    # Validation summary
    validation_results = validator.validate_all_agents(agents)
    
    # Most used tools
    tool_usage_sorted = sorted(
        tools_summary['tool_usage'].items(),
        key=lambda x: len(x[1]),
        reverse=True
    )[:10]
    
    context_percentage = (total_tokens / 200000) * 100 if total_tokens else 0
    
    return jsonify({
        'agent_count': len(agents),
        'total_tokens': total_tokens,
        'average_tokens': total_tokens // len(agents) if agents else 0,
        'context_percentage': round(context_percentage, 2),
        'model_distribution': model_distribution,
        'token_distribution': token_distribution,
        'validation_summary': {
            'valid': validation_results['valid'],
            'invalid': validation_results['invalid'],
            'warnings': validation_results['warnings'],
            'installed': validation_results['installed'],
            'not_installed': validation_results['not_installed']
        },
        'tools_summary': {
            'total_unique': tools_summary['total_unique_tools'],
            'mcp_count': len(tools_summary['mcp_tools']),
            'standard_count': len(tools_summary['standard_tools']),
            'top_tools': [{'tool': t[0], 'count': len(t[1])} for t in tool_usage_sorted]
        }
    })


@app.route('/api/visualization/tokens')
def api_viz_tokens():
    """Generate token distribution visualization."""
    agents = parser.get_all_agents()
    
    names = []
    description_tokens = []
    body_tokens = []
    
    for agent in agents:
        tokens = counter.analyze_agent_tokens(agent)
        names.append(agent['name'])
        description_tokens.append(tokens['description_tokens'])
        body_tokens.append(tokens['body_tokens'])
    
    # Create stacked bar chart
    fig = go.Figure(data=[
        go.Bar(name='Description', x=names, y=description_tokens),
        go.Bar(name='Body', x=names, y=body_tokens)
    ])
    
    fig.update_layout(
        barmode='stack',
        title='Token Distribution by Agent',
        xaxis_title='Agent',
        yaxis_title='Token Count',
        template='plotly_white'
    )
    
    graphJSON = json.dumps(fig, cls=plotly.utils.PlotlyJSONEncoder)
    return graphJSON


@app.route('/api/visualization/tools')
def api_viz_tools():
    """Generate tools usage visualization."""
    tools_summary = parser.get_tools_summary()
    
    # Get top 15 most used tools
    tool_usage_sorted = sorted(
        tools_summary['tool_usage'].items(),
        key=lambda x: len(x[1]),
        reverse=True
    )[:15]
    
    tools = [t[0] for t in tool_usage_sorted]
    counts = [len(t[1]) for t in tool_usage_sorted]
    
    # Create horizontal bar chart
    fig = go.Figure(data=[
        go.Bar(x=counts, y=tools, orientation='h')
    ])
    
    fig.update_layout(
        title='Most Used Tools Across Agents',
        xaxis_title='Number of Agents Using Tool',
        yaxis_title='Tool Name',
        template='plotly_white',
        height=500
    )
    
    graphJSON = json.dumps(fig, cls=plotly.utils.PlotlyJSONEncoder)
    return graphJSON


@app.route('/export/<format>')
def export_data(format):
    """Export agent data in specified format."""
    agents = parser.get_all_agents()
    
    export_data = []
    for agent in agents:
        tokens = counter.analyze_agent_tokens(agent)
        installation = validator.check_installation_status(agent['name'])
        
        export_data.append({
            'name': agent['name'],
            'model': agent['model'],
            'tool_count': len(agent['tools']),
            'description_tokens': tokens['description_tokens'],
            'total_tokens': tokens['full_content_tokens'],
            'installed': installation['installed']
        })
    
    if format == 'json':
        filepath = Path('exports/dashboard_export.json')
        filepath.parent.mkdir(exist_ok=True)
        with open(filepath, 'w') as f:
            json.dump(export_data, f, indent=2)
        return send_file(str(filepath.absolute()), as_attachment=True)
    
    return jsonify({'error': 'Unsupported format'}), 400


if __name__ == '__main__':
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5001
    print(f"Starting dashboard on http://localhost:{port}")
    app.run(debug=True, host='0.0.0.0', port=port)