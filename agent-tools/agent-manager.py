#!/usr/bin/env python3
"""
Claude Code Agent Manager CLI
A command-line tool for managing and analyzing Claude Code agents.
"""

import click
import json
import csv
from pathlib import Path
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.syntax import Syntax
from rich.layout import Layout
from rich import box
from rich.text import Text
from utils import AgentParser, TokenCounter, AgentValidator

console = Console()


@click.group()
def cli():
    """Claude Code Agent Manager - Manage and analyze your agents."""
    pass


@cli.command()
@click.option('--format', type=click.Choice(['table', 'json', 'simple']), default='table')
def list(format):
    """List all available agents with their metadata."""
    parser = AgentParser()
    counter = TokenCounter()
    validator = AgentValidator()
    
    agents = parser.get_all_agents()
    
    if format == 'json':
        # JSON output
        output = []
        for agent in agents:
            tokens = counter.analyze_agent_tokens(agent)
            installation = validator.check_installation_status(agent['name'])
            output.append({
                'name': agent['name'],
                'model': agent['model'],
                'tools': len(agent['tools']),
                'description_tokens': tokens['description_tokens'],
                'installed': installation['installed']
            })
        console.print_json(data=output)
    
    elif format == 'simple':
        # Simple text output
        for agent in agents:
            tokens = counter.analyze_agent_tokens(agent)
            console.print(f"{agent['name']}: {agent['model']} model, {len(agent['tools'])} tools, {tokens['description_tokens']} tokens")
    
    else:
        # Rich table output
        table = Table(title="Claude Code Agents", box=box.ROUNDED)
        table.add_column("Name", style="cyan", no_wrap=True)
        table.add_column("Category", style="magenta")
        table.add_column("Model", style="white")
        table.add_column("Tools", justify="right", style="green")
        table.add_column("Tokens", justify="right", style="yellow")
        table.add_column("Status", style="blue")
        
        for agent in agents:
            tokens = counter.analyze_agent_tokens(agent)
            installation = validator.check_installation_status(agent['name'])
            
            status = "✅ Installed" if installation['installed'] else "❌ Not Installed"
            
            table.add_row(
                agent['name'],
                agent.get('category', 'Unknown'),
                agent['model'],
                str(len(agent['tools'])),
                str(tokens['description_tokens']),
                status
            )
        
        console.print(table)
        console.print(f"\nTotal agents: {len(agents)}")


@cli.command()
@click.argument('agent_name')
def info(agent_name):
    """Show detailed information about a specific agent."""
    parser = AgentParser()
    counter = TokenCounter()
    validator = AgentValidator()
    
    agent = parser.get_agent_by_name(agent_name)
    
    if not agent:
        console.print(f"[red]Agent '{agent_name}' not found[/red]")
        return
    
    tokens = counter.analyze_agent_tokens(agent)
    validation = validator.validate_agent_structure(agent)
    installation = validator.check_installation_status(agent['name'])
    
    # Create info panels
    console.print(Panel.fit(f"[bold cyan]{agent['name']}[/bold cyan]", box=box.DOUBLE))
    
    # Basic info
    info_text = f"""
[bold]Category:[/bold] {agent.get('category', 'Unknown')}
[bold]Model:[/bold] {agent['model']}
[bold]Color:[/bold] {agent.get('color', 'default')}
[bold]File:[/bold] {agent['filename']}
[bold]Installation:[/bold] {installation['details']}
    """
    console.print(Panel(info_text.strip(), title="Basic Information", box=box.ROUNDED))
    
    # Token analysis
    context_pct = counter.calculate_context_percentage(tokens['full_content_tokens'])
    token_text = f"""
[bold]Description:[/bold] {tokens['description_tokens']} tokens ({counter.format_token_size(tokens['description_tokens'])})
[bold]Body:[/bold] {tokens['body_tokens']} tokens
[bold]Full Content:[/bold] {tokens['full_content_tokens']} tokens
[bold]Context Usage:[/bold] {context_pct:.3f}% of 200k limit
[bold]Estimated Cost (Claude Sonnet):[/bold] ${counter.estimate_cost(tokens['full_content_tokens'], 'claude-3-sonnet')['input_cost']:.4f} per call
    """
    console.print(Panel(token_text.strip(), title="Token Analysis", box=box.ROUNDED))
    
    # Tools
    tools_text = ""
    if agent['standard_tools']:
        tools_text += "[bold]Standard Tools:[/bold]\n"
        for tool in agent['standard_tools']:
            tools_text += f"  • {tool}\n"
    
    if agent['mcp_tools']:
        if tools_text:
            tools_text += "\n"
        tools_text += "[bold]MCP Tools:[/bold]\n"
        for tool in agent['mcp_tools']:
            tools_text += f"  • {tool}\n"
    
    console.print(Panel(tools_text.strip() if tools_text else "No tools", title="Tools", box=box.ROUNDED))
    
    # Description
    console.print("\n[bold]Description:[/bold]")
    # Clean up the description for display
    desc = agent['description'].replace('\\n', '\n')
    console.print(Panel(desc, box=box.ROUNDED))
    
    # Validation
    if validation['errors'] or validation['warnings']:
        console.print("\n[bold]Validation Results:[/bold]")
        for error in validation['errors']:
            console.print(f"  [red]✗ {error}[/red]")
        for warning in validation['warnings']:
            console.print(f"  [yellow]⚠ {warning}[/yellow]")


@cli.command()
def stats():
    """Show aggregate statistics about all agents."""
    parser = AgentParser()
    counter = TokenCounter()
    validator = AgentValidator()
    
    agents = parser.get_all_agents()
    tools_summary = parser.get_tools_summary()
    
    # Calculate total tokens
    total_tokens = 0
    model_distribution = {}
    
    for agent in agents:
        tokens = counter.analyze_agent_tokens(agent)
        total_tokens += tokens['full_content_tokens']
        
        model = agent.get('model', 'unknown')
        model_distribution[model] = model_distribution.get(model, 0) + 1
    
    # Validation summary
    validation_results = validator.validate_all_agents(agents)
    
    # Display statistics
    console.print(Panel.fit("[bold cyan]Agent Statistics[/bold cyan]", box=box.DOUBLE))
    
    # Agent counts
    stats_text = f"""
[bold]Total Agents:[/bold] {len(agents)}
[bold]Installed:[/bold] {validation_results['installed']}
[bold]Not Installed:[/bold] {validation_results['not_installed']}
[bold]Valid:[/bold] {validation_results['valid']}
[bold]With Warnings:[/bold] {validation_results['warnings']}
    """
    console.print(Panel(stats_text.strip(), title="Agent Summary", box=box.ROUNDED))
    
    # Model distribution
    console.print("\n[bold]Model Distribution:[/bold]")
    for model, count in model_distribution.items():
        percentage = (count / len(agents)) * 100
        console.print(f"  • {model}: {count} agents ({percentage:.1f}%)")
    
    # Token statistics
    avg_tokens = total_tokens // len(agents) if agents else 0
    total_cost = counter.estimate_cost(total_tokens, 'claude-3-sonnet')
    context_pct = counter.calculate_context_percentage(total_tokens)
    
    token_stats = f"""
[bold]Total Tokens:[/bold] {total_tokens:,}
[bold]Average per Agent:[/bold] {avg_tokens:,}
[bold]Context Usage:[/bold] {context_pct:.2f}% of 200k limit
[bold]Est. Total Cost (Sonnet):[/bold] ${total_cost['input_cost']:.4f} per full load
    """
    console.print(Panel(token_stats.strip(), title="Token Statistics", box=box.ROUNDED))
    
    # Tool statistics
    console.print("\n[bold]Tool Statistics:[/bold]")
    console.print(f"  • Total Unique Tools: {tools_summary['total_unique_tools']}")
    console.print(f"  • MCP Tools: {len(tools_summary['mcp_tools'])}")
    console.print(f"  • Standard Tools: {len(tools_summary['standard_tools'])}")
    
    # Most used tools
    tool_usage_sorted = sorted(
        tools_summary['tool_usage'].items(),
        key=lambda x: len(x[1]),
        reverse=True
    )[:10]
    
    console.print("\n[bold]Top 10 Most Used Tools:[/bold]")
    for tool, agents_using in tool_usage_sorted:
        console.print(f"  • {tool}: used by {len(agents_using)} agents")
    
    # Shared tools
    if tools_summary['shared_tools']:
        console.print("\n[bold]Tools Shared by Multiple Agents:[/bold]")
        for tool, agents_using in list(tools_summary['shared_tools'].items())[:5]:
            console.print(f"  • {tool}: {', '.join(agents_using)}")


@cli.command()
@click.option('--format', type=click.Choice(['json', 'csv']), default='json')
@click.option('--output', '-o', type=click.Path(), default=None)
def export(format, output):
    """Export agent data to JSON or CSV format."""
    parser = AgentParser()
    counter = TokenCounter()
    validator = AgentValidator()
    
    agents = parser.get_all_agents()
    
    # Prepare export data
    export_data = []
    for agent in agents:
        tokens = counter.analyze_agent_tokens(agent)
        installation = validator.check_installation_status(agent['name'])
        
        export_data.append({
            'name': agent['name'],
            'model': agent['model'],
            'color': agent.get('color', ''),
            'tool_count': len(agent['tools']),
            'mcp_tools': len(agent['mcp_tools']),
            'standard_tools': len(agent['standard_tools']),
            'description_tokens': tokens['description_tokens'],
            'body_tokens': tokens['body_tokens'],
            'total_tokens': tokens['full_content_tokens'],
            'installed': installation['installed'],
            'description': agent['description'],
            'tools': ', '.join(agent['tools'])
        })
    
    # Determine output path
    if output:
        output_path = Path(output)
    else:
        output_path = Path(f"exports/agents.{format}")
        output_path.parent.mkdir(exist_ok=True)
    
    # Export based on format
    if format == 'json':
        with open(output_path, 'w') as f:
            json.dump(export_data, f, indent=2)
    else:  # CSV
        if export_data:
            keys = export_data[0].keys()
            with open(output_path, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=keys)
                writer.writeheader()
                writer.writerows(export_data)
    
    console.print(f"[green]✓[/green] Exported {len(export_data)} agents to {output_path}")


@cli.command()
def validate():
    """Validate all agent files and check installation status."""
    parser = AgentParser()
    validator = AgentValidator()
    
    agents = parser.get_all_agents()
    results = validator.validate_all_agents(agents)
    
    console.print(Panel.fit("[bold cyan]Agent Validation Report[/bold cyan]", box=box.DOUBLE))
    
    # Summary
    summary_table = Table(box=box.SIMPLE)
    summary_table.add_column("Metric", style="bold")
    summary_table.add_column("Value", justify="right")
    
    summary_table.add_row("Total Agents", str(results['total']))
    summary_table.add_row("Valid", f"[green]{results['valid']}[/green]")
    summary_table.add_row("Invalid", f"[red]{results['invalid']}[/red]")
    summary_table.add_row("With Warnings", f"[yellow]{results['warnings']}[/yellow]")
    summary_table.add_row("Installed", f"[green]{results['installed']}[/green]")
    summary_table.add_row("Not Installed", f"[yellow]{results['not_installed']}[/yellow]")
    
    console.print(summary_table)
    
    # Detailed results
    if any(d['errors'] or d['warnings'] for d in results['details']):
        console.print("\n[bold]Issues Found:[/bold]")
        
        for detail in results['details']:
            if detail['errors'] or detail['warnings']:
                console.print(f"\n[cyan]{detail['name']}:[/cyan]")
                
                for error in detail['errors']:
                    console.print(f"  [red]✗ {error}[/red]")
                
                for warning in detail['warnings']:
                    console.print(f"  [yellow]⚠ {warning}[/yellow]")
    else:
        console.print("\n[green]✓ All agents are valid![/green]")
    
    # Installation status
    console.print("\n[bold]Installation Status:[/bold]")
    for detail in results['details']:
        status_icon = "✅" if detail['installed'] else "❌"
        console.print(f"  {status_icon} {detail['name']}: {detail['installation_details']}")


if __name__ == '__main__':
    cli()