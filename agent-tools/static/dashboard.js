// Global variables
let agentsData = [];
let statsData = {};

// Initialize dashboard
document.addEventListener('DOMContentLoaded', function() {
    loadInitialData();
});

// Load initial data
async function loadInitialData() {
    try {
        // Load agents data
        const agentsResponse = await fetch('/api/agents');
        agentsData = await agentsResponse.json();
        
        // Load stats
        const statsResponse = await fetch('/api/stats');
        statsData = await statsResponse.json();
        
        // Update summary cards
        updateSummaryCards();
        
        // Load visualizations
        loadVisualizations();
        
    } catch (error) {
        console.error('Error loading data:', error);
    }
}

// Update summary cards
function updateSummaryCards() {
    const totalTokens = statsData.total_tokens || 0;
    const contextLimit = 200000; // 200k token limit
    const contextPercentage = ((totalTokens / contextLimit) * 100).toFixed(1);
    
    document.getElementById('total-agents').textContent = statsData.agent_count || 0;
    document.getElementById('installed-agents').textContent = statsData.validation_summary?.installed || 0;
    document.getElementById('context-usage').textContent = `${contextPercentage}%`;
    document.getElementById('total-tokens').textContent = totalTokens.toLocaleString();
}

// Show tab
function showTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Remove active from all buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    // Show selected tab
    document.getElementById(`${tabName}-tab`).classList.add('active');
    
    // Mark button as active
    event.target.classList.add('active');
    
    // Load tab-specific content
    if (tabName === 'stats') {
        loadVisualizations();
    } else if (tabName === 'tools') {
        loadToolsMatrix();
    }
}

// Filter agents
function filterAgents() {
    const searchTerm = document.getElementById('search-input').value.toLowerCase();
    const agentCards = document.querySelectorAll('.agent-card');
    
    agentCards.forEach(card => {
        const name = card.dataset.name.toLowerCase();
        const category = card.dataset.category ? card.dataset.category.toLowerCase() : '';
        const description = card.querySelector('.agent-description').textContent.toLowerCase();
        
        if (name.includes(searchTerm) || description.includes(searchTerm) || category.includes(searchTerm)) {
            card.style.display = 'block';
        } else {
            card.style.display = 'none';
        }
    });
}

// Show agent detail
async function showAgentDetail(agentName) {
    try {
        const response = await fetch(`/api/agent/${agentName}`);
        const data = await response.json();
        
        const modalBody = document.getElementById('modal-body');
        modalBody.innerHTML = `
            <h2>${data.agent.name}</h2>
            <span class="category-badge category-${data.agent.category.toLowerCase().replace(' ', '-')}">${data.agent.category}</span>
            
            <div class="detail-section">
                <h3>Basic Information</h3>
                <table class="detail-table">
                    <tr><th>Category</th><td>${data.agent.category}</td></tr>
                    <tr><th>Model</th><td>${data.agent.model}</td></tr>
                    <tr><th>Color</th><td>${data.agent.color || 'default'}</td></tr>
                    <tr><th>File</th><td>${data.agent.filename}</td></tr>
                    <tr><th>Location</th><td>${data.agent.location || 'Project: ../agents/'}</td></tr>
                    <tr><th>Installation</th><td>${data.installation.details}</td></tr>
                </table>
            </div>
            
            <div class="detail-section">
                <h3>Token Analysis</h3>
                <table class="detail-table">
                    <tr><th>Description</th><td>${data.tokens.description_tokens} tokens</td></tr>
                    <tr><th>Body</th><td>${data.tokens.body_tokens} tokens</td></tr>
                    <tr><th>Total</th><td>${data.tokens.full_content_tokens} tokens</td></tr>
                </table>
            </div>
            
            <div class="detail-section">
                <h3>Cost Estimates (per call)</h3>
                <table class="detail-table">
                    <tr><th>Claude Opus</th><td>$${data.costs['claude-3-opus'].input_cost.toFixed(4)}</td></tr>
                    <tr><th>Claude Sonnet</th><td>$${data.costs['claude-3-sonnet'].input_cost.toFixed(4)}</td></tr>
                    <tr><th>Claude Haiku</th><td>$${data.costs['claude-3-haiku'].input_cost.toFixed(4)}</td></tr>
                </table>
            </div>
            
            <div class="detail-section">
                <h3>Tools (${data.agent.tools.length})</h3>
                <div style="max-height: 200px; overflow-y: auto;">
                    ${data.agent.tools.map(tool => `<div>• ${tool}</div>`).join('')}
                </div>
            </div>
            
            <div class="detail-section">
                <h3>Description</h3>
                <div style="background: #f3f4f6; padding: 15px; border-radius: 8px;">
                    ${data.agent.description.replace(/\\n/g, '<br>')}
                </div>
            </div>
            
            ${data.validation.errors.length > 0 || data.validation.warnings.length > 0 ? `
                <div class="detail-section">
                    <h3>Validation</h3>
                    ${data.validation.errors.map(e => `<div style="color: red;">✗ ${e}</div>`).join('')}
                    ${data.validation.warnings.map(w => `<div style="color: orange;">⚠ ${w}</div>`).join('')}
                </div>
            ` : ''}
            
            <div class="detail-section">
                <h3>Full Agent Content</h3>
                <pre style="background: #1f2937; color: #e5e7eb; padding: 20px; border-radius: 8px; overflow-x: auto; font-family: 'Courier New', monospace; font-size: 13px; line-height: 1.5; max-height: 400px; overflow-y: auto;">
${data.agent.full_content}
                </pre>
            </div>
        `;
        
        document.getElementById('agent-modal').style.display = 'block';
    } catch (error) {
        console.error('Error loading agent detail:', error);
    }
}

// Close modal
function closeModal() {
    document.getElementById('agent-modal').style.display = 'none';
}

// Load visualizations
async function loadVisualizations() {
    try {
        // Token distribution chart
        const tokenResponse = await fetch('/api/visualization/tokens');
        const tokenData = await tokenResponse.json();
        Plotly.newPlot('token-chart', tokenData.data, tokenData.layout, {responsive: true});
        
        // Tools usage chart
        const toolsResponse = await fetch('/api/visualization/tools');
        const toolsData = await toolsResponse.json();
        Plotly.newPlot('tools-chart', toolsData.data, toolsData.layout, {responsive: true});
        
        // Stats summary
        updateStatsSummary();
        
    } catch (error) {
        console.error('Error loading visualizations:', error);
    }
}

// Update stats summary
function updateStatsSummary() {
    const summaryDiv = document.getElementById('stats-summary');
    
    summaryDiv.innerHTML = `
        <div class="stats-grid">
            <div class="stat-item">
                <strong>Model Distribution:</strong>
                ${Object.entries(statsData.model_distribution || {}).map(([model, count]) => 
                    `<div>${model}: ${count} agents</div>`
                ).join('')}
            </div>
            
            <div class="stat-item">
                <strong>Average Tokens:</strong> ${statsData.average_tokens?.toLocaleString() || 0}
            </div>
            
            <div class="stat-item">
                <strong>Validation Status:</strong>
                <div>Valid: ${statsData.validation_summary?.valid || 0}</div>
                <div>With Warnings: ${statsData.validation_summary?.warnings || 0}</div>
            </div>
            
            <div class="stat-item">
                <strong>Top Tools:</strong>
                ${(statsData.tools_summary?.top_tools || []).slice(0, 5).map(tool => 
                    `<div>${tool.tool}: ${tool.count} agents</div>`
                ).join('')}
            </div>
        </div>
    `;
}

// Load tools matrix
function loadToolsMatrix() {
    const matrixDiv = document.getElementById('tools-matrix');
    
    // Create a simple matrix showing which agents use which tools
    const tools = new Set();
    const matrix = {};
    
    agentsData.forEach(agent => {
        agent.tools.forEach(tool => tools.add(tool));
        matrix[agent.name] = new Set(agent.tools);
    });
    
    // Sort tools by usage count
    const toolUsage = {};
    Array.from(tools).forEach(tool => {
        toolUsage[tool] = agentsData.filter(agent => agent.tools.includes(tool)).length;
    });
    
    const sortedTools = Object.entries(toolUsage)
        .sort((a, b) => b[1] - a[1])
        .map(([tool, _]) => tool)
        .slice(0, 20); // Show top 20 tools
    
    // Create table with tools as rows and agents as columns
    let html = '<div style="overflow-x: auto;"><table class="detail-table">';
    
    // Header row with agent names
    html += '<tr><th style="text-align: left; width: 300px;">Tool / Agent</th>';
    Object.keys(matrix).forEach(agent => {
        // Shorten agent names for column headers
        const shortName = agent.replace('atlas-jira-analyst', 'Atlas')
            .replace('athena-pr-reviewer', 'Athena')
            .replace('heimdall-pr-guardian', 'Heimdall')
            .replace('hermes-pr-courier', 'Hermes')
            .replace('minerva-notion-oracle', 'Minerva');
        html += `<th style="writing-mode: vertical-lr; text-orientation: mixed; height: 100px; padding: 5px;">${shortName}</th>`;
    });
    html += '<th style="writing-mode: vertical-lr; text-orientation: mixed; height: 100px;">Usage</th>';
    html += '</tr>';
    
    // Add rows for each tool
    sortedTools.forEach(tool => {
        html += `<tr><td style="font-size: 12px;"><strong>${tool}</strong></td>`;
        Object.entries(matrix).forEach(([agent, agentTools]) => {
            const hasT = agentTools.has(tool);
            html += `<td style="text-align: center; background: ${hasT ? '#d1fae5' : '#f9fafb'}; padding: 4px;">
                ${hasT ? '✓' : ''}
            </td>`;
        });
        // Add usage count
        html += `<td style="text-align: center; font-weight: bold; color: #6b7280;">${toolUsage[tool]}</td>`;
        html += '</tr>';
    });
    
    html += '</table></div>';
    matrixDiv.innerHTML = html;
}

// Export data
function exportData(format) {
    window.location.href = `/export/${format}`;
}

// Refresh data
function refreshData() {
    location.reload();
}

// Close modal when clicking outside
window.onclick = function(event) {
    const modal = document.getElementById('agent-modal');
    if (event.target == modal) {
        modal.style.display = 'none';
    }
}