// LLM Orchestration Patterns UI - Comparison Focus

// Pattern descriptions for DAG visualization
const patternInfo = {
  'Sequential': {
    desc: 'Chain agents one after another',
    color: '#00f0ff',
    flow: (agents) => agents.map((a, i) => ({ from: i > 0 ? i-1 : null, to: i, label: a }))
  },
  'Concurrent (Vote)': {
    desc: 'All agents vote on the result',
    color: '#ff00ff',
    flow: (agents) => agents.map((a, i) => ({ from: 'input', to: i, label: a, parallel: true }))
  },
  'Concurrent (Consensus)': {
    desc: 'Agents reach consensus',
    color: '#b537f2',
    flow: (agents) => agents.map((a, i) => ({ from: 'input', to: i, label: a, parallel: true }))
  },
  'Concurrent (Combine)': {
    desc: 'Combine all agent outputs',
    color: '#39ff14',
    flow: (agents) => agents.map((a, i) => ({ from: 'input', to: i, label: a, parallel: true }))
  },
  'Group Chat (5 rounds)': {
    desc: 'Agents chat in rounds',
    color: '#ffcc00',
    flow: (agents) => agents.flatMap((a, i) => [
      { from: i > 0 ? i-1 : 'input', to: i, label: a, round: true }
    ])
  },
  'Handoff (10 hops)': {
    desc: 'Dynamic agent routing',
    color: '#ff6b6b',
    flow: (agents) => [
      { from: 'input', to: 0, label: agents[0] || 'Start' },
      ...agents.slice(1).map((a, i) => ({ from: i, to: i+1, label: a, conditional: true }))
    ]
  },
  'Magentic (10 iterations)': {
    desc: 'Manager decomposes tasks',
    color: '#4ecdc4',
    flow: (agents) => [
      { from: 'input', to: 0, label: agents[0] || 'Manager', manager: true },
      ...agents.slice(1).map((a, i) => ({ from: 0, to: i+1, label: a, worker: true }))
    ]
  }
};

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
  initializeEventListeners();
  // Start with 2 agents
  addAgent();
  addAgent();
});

function initializeEventListeners() {
  document.getElementById('add-agent').addEventListener('click', addAgent);
  document.getElementById('compare-all').addEventListener('click', compareAllPatterns);
}

// Agent Management
function addAgent() {
  const agentList = document.getElementById('agent-list');
  const agentIndex = agentList.children.length;

  const card = document.createElement('div');
  card.className = 'agent-card';
  card.innerHTML = `
    <div class="agent-header">
      <span class="agent-number">Agent ${agentIndex + 1}</span>
      ${agentIndex > 0 ? '<button class="remove-agent" onclick="this.closest(\'.agent-card\').remove()">×</button>' : ''}
    </div>
    <div class="agent-fields">
      <div class="field">
        <label>Agent ID</label>
        <input type="text" class="agent-id" placeholder="agent${agentIndex + 1}" value="agent${agentIndex + 1}">
      </div>
      <div class="field">
        <label>Provider</label>
        <select class="agent-provider">
          <option value="ollama">Ollama</option>
          <option value="openai">OpenAI</option>
        </select>
      </div>
      <div class="field">
        <label>Model</label>
        <input type="text" class="agent-model" placeholder="Model name" value="llama3.2">
      </div>
      <div class="field">
        <label>System Prompt</label>
        <textarea class="agent-prompt" placeholder="System prompt for this agent..." rows="3">You are a helpful AI assistant ${agentIndex > 0 ? `specializing in ${['analysis', 'synthesis', 'review', 'validation'][agentIndex % 4]}` : ''}.</textarea>
      </div>
    </div>
  `;

  agentList.appendChild(card);
}

function collectAgents() {
  const agentCards = document.querySelectorAll('.agent-card');
  return Array.from(agentCards).map(card => ({
    acId: card.querySelector('.agent-id').value,
    acProvider: card.querySelector('.agent-provider').value,
    acModel: card.querySelector('.agent-model').value,
    acSystemPrompt: card.querySelector('.agent-prompt').value
  }));
}

// Compare All Patterns
async function compareAllPatterns() {
  const agents = collectAgents();
  const input = document.getElementById('user-input').value;

  if (!input.trim()) {
    showError('Please enter an input prompt');
    return;
  }

  if (agents.length === 0) {
    showError('Please add at least one agent');
    return;
  }

  // Hide any previous results
  document.getElementById('results-section').style.display = 'none';
  document.getElementById('dag-section').style.display = 'none';
  document.getElementById('error-message').style.display = 'none';

  // Show loading
  document.getElementById('loading').style.display = 'flex';
  document.getElementById('compare-all').disabled = true;

  try {
    const response = await fetch('/api/compare', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        crAgents: agents,
        crInput: input
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();

    // Display DAG visualization
    displayDAG(agents);

    // Display results in tabs
    displayTabbedResults(result.cmpResults);

  } catch (error) {
    showError('Failed to compare patterns: ' + error.message);
    console.error('Comparison error:', error);
  } finally {
    document.getElementById('loading').style.display = 'none';
    document.getElementById('compare-all').disabled = false;
  }
}

// Display DAG Visualization
function displayDAG(agents) {
  const dagSection = document.getElementById('dag-section');
  const dagContainer = document.getElementById('dag-container');

  dagSection.style.display = 'block';
  dagContainer.innerHTML = '';

  const agentNames = agents.map(a => a.acId);

  Object.entries(patternInfo).forEach(([patternName, info]) => {
    const patternDiv = document.createElement('div');
    patternDiv.className = 'dag-pattern';

    const flow = info.flow(agentNames);
    const dagHtml = createDAGVisualization(patternName, info, flow);

    patternDiv.innerHTML = `
      <h3 style="color: ${info.color}">${patternName}</h3>
      <p class="pattern-desc">${info.desc}</p>
      ${dagHtml}
    `;

    dagContainer.appendChild(patternDiv);
  });
}

function createDAGVisualization(patternName, info, flow) {
  let html = '<div class="dag-flow">';

  if (flow.some(f => f.parallel)) {
    // Parallel pattern
    html += '<div class="dag-node dag-input">Input</div>';
    html += '<div class="dag-parallel">';
    flow.forEach((f, i) => {
      html += `<div class="dag-branch">
        <div class="dag-arrow">↓</div>
        <div class="dag-node" style="border-color: ${info.color}">${f.label}</div>
      </div>`;
    });
    html += '</div>';
    html += '<div class="dag-convergence">↓</div>';
    html += '<div class="dag-node dag-output">Aggregate</div>';
  } else if (flow.some(f => f.round)) {
    // Round-robin pattern
    html += '<div class="dag-node dag-input">Input</div>';
    flow.forEach((f, i) => {
      html += `<div class="dag-arrow">${f.round ? '⟲' : '↓'}</div>`;
      html += `<div class="dag-node" style="border-color: ${info.color}">${f.label}</div>`;
    });
    html += '<div class="dag-arrow">↓</div>';
    html += '<div class="dag-node dag-output">Consensus</div>';
  } else if (flow.some(f => f.manager)) {
    // Hierarchical pattern
    html += '<div class="dag-node dag-input">Input</div>';
    html += '<div class="dag-arrow">↓</div>';
    html += `<div class="dag-node dag-manager" style="border-color: ${info.color}">${flow[0].label}</div>`;
    html += '<div class="dag-parallel">';
    flow.slice(1).forEach(f => {
      html += `<div class="dag-branch">
        <div class="dag-arrow">↓</div>
        <div class="dag-node dag-worker" style="border-color: ${info.color}">${f.label}</div>
      </div>`;
    });
    html += '</div>';
    html += '<div class="dag-convergence">↑</div>';
    html += `<div class="dag-node dag-manager" style="border-color: ${info.color}">${flow[0].label}</div>`;
  } else {
    // Sequential or conditional pattern
    html += '<div class="dag-node dag-input">Input</div>';
    flow.forEach((f, i) => {
      html += `<div class="dag-arrow">${f.conditional ? '⤷' : '↓'}</div>`;
      html += `<div class="dag-node" style="border-color: ${info.color}">${f.label}</div>`;
    });
    html += '<div class="dag-arrow">↓</div>';
    html += '<div class="dag-node dag-output">Output</div>';
  }

  html += '</div>';
  return html;
}

// Display Results in Tabs
function displayTabbedResults(results) {
  const resultsSection = document.getElementById('results-section');
  const tabHeaders = document.getElementById('tab-headers');
  const tabContents = document.getElementById('tab-contents');

  resultsSection.style.display = 'block';
  tabHeaders.innerHTML = '';
  tabContents.innerHTML = '';

  results.forEach(([patternName, result], index) => {
    const isActive = index === 0;

    // Create tab header
    const tabHeader = document.createElement('button');
    tabHeader.className = `tab-header ${isActive ? 'active' : ''}`;
    tabHeader.textContent = patternName;
    tabHeader.style.borderBottomColor = patternInfo[patternName]?.color || '#00f0ff';
    tabHeader.onclick = () => activateTab(index);
    tabHeaders.appendChild(tabHeader);

    // Create tab content
    const tabContent = document.createElement('div');
    tabContent.className = `tab-content ${isActive ? 'active' : ''}`;
    tabContent.id = `tab-${index}`;

    if (result.exError) {
      tabContent.innerHTML = `
        <div class="error-result">
          <h3>Error</h3>
          <pre>${escapeHtml(result.exError)}</pre>
        </div>
      `;
    } else {
      tabContent.innerHTML = `
        <div class="result-meta">
          <div class="meta-item">
            <span class="meta-label">Duration:</span>
            <span class="meta-value">${result.exDuration.toFixed(3)}s</span>
          </div>
          <div class="meta-item">
            <span class="meta-label">Events:</span>
            <span class="meta-value">${result.exTrace.length}</span>
          </div>
        </div>
        <div class="result-output">
          <h3>Final Output</h3>
          <pre>${escapeHtml(result.exOutput)}</pre>
        </div>
        <div class="result-trace">
          <h3>Execution Trace</h3>
          <div class="trace-events">
            ${result.exTrace.map(event => formatTraceEvent(event)).join('')}
          </div>
        </div>
      `;
    }

    tabContents.appendChild(tabContent);
  });
}

function activateTab(index) {
  const headers = document.querySelectorAll('.tab-header');
  const contents = document.querySelectorAll('.tab-content');

  headers.forEach((h, i) => h.classList.toggle('active', i === index));
  contents.forEach((c, i) => c.classList.toggle('active', i === index));
}

function formatTraceEvent(event) {
  let text = '';
  let className = 'trace-event';

  if (typeof event === 'string') {
    text = event;
  } else if (event.AgentStarted) {
    text = `▶ Agent ${event.AgentStarted} started`;
    className += ' event-start';
  } else if (event.AgentCompleted) {
    text = `✓ Agent ${event.AgentCompleted[0]} completed`;
    className += ' event-complete';
  } else if (event.AgentFailed) {
    text = `✗ Agent ${event.AgentFailed[0]} failed: ${event.AgentFailed[1]}`;
    className += ' event-error';
  } else if (event.HandoffOccurred) {
    text = `⤷ Handoff: ${event.HandoffOccurred[0]} → ${event.HandoffOccurred[1]}`;
    className += ' event-handoff';
  } else if (event.TaskCreated) {
    text = `+ Task created: ${event.TaskCreated}`;
    className += ' event-task';
  } else if (event.TaskCompleted) {
    text = `✓ Task completed: ${event.TaskCompleted}`;
    className += ' event-task-done';
  } else if (event.RoundStarted) {
    text = `🔄 Round ${event.RoundStarted} started`;
    className += ' event-round';
  } else if (event.RoundCompleted) {
    text = `✓ Round ${event.RoundCompleted} completed`;
    className += ' event-round-done';
  } else {
    text = JSON.stringify(event);
  }

  return `<div class="${className}">${escapeHtml(text)}</div>`;
}

// Utility Functions
function showError(message) {
  const errorEl = document.getElementById('error-message');
  errorEl.textContent = message;
  errorEl.style.display = 'block';
  setTimeout(() => {
    errorEl.style.display = 'none';
  }, 5000);
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
