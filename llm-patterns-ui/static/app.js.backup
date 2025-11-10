// LLM Orchestration Patterns UI - JavaScript

// Pattern descriptions
const patternDescriptions = {
  'Sequential': 'Agents process the input one after another, with each agent receiving the previous agent\'s output. Best for multi-step transformations.',
  'Concurrent': 'All agents process the input simultaneously, then results are aggregated by voting. Best for getting consensus or multiple perspectives.',
  'GroupChat': 'Agents take turns in a conversation until consensus is reached or max rounds completed. Best for collaborative problem-solving.',
  'Handoff': 'Agents can hand off work to other specialized agents. Best for complex workflows requiring different expertise.',
  'Magentic': 'A manager agent decomposes tasks and distributes them to worker agents. Best for hierarchical task decomposition.'
};

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
  initializeEventListeners();
  addInitialAgent();
  updatePatternDescription();
});

// Event listeners
function initializeEventListeners() {
  document.getElementById('add-agent').addEventListener('click', addAgent);
  document.getElementById('execute').addEventListener('click', executePattern);
  document.getElementById('compare-all').addEventListener('click', comparePatterns);
  document.getElementById('pattern-type').addEventListener('change', updatePatternDescription);
}

// Agent management
function addInitialAgent() {
  addAgent();
}

function addAgent() {
  const agentList = document.getElementById('agent-list');
  const agentIndex = agentList.children.length;

  const card = document.createElement('div');
  card.className = 'agent-card';
  card.innerHTML = `
    <button class="remove-agent" onclick="this.parentElement.remove()">×</button>
    <input type="text" class="agent-id" placeholder="Agent ID" value="agent${agentIndex + 1}">
    <select class="agent-provider">
      <option value="ollama">Ollama</option>
      <option value="openai">OpenAI</option>
    </select>
    <input type="text" class="agent-model" placeholder="Model name" value="llama3.2">
    <textarea class="agent-prompt" placeholder="System prompt" rows="3">You are a helpful AI assistant.</textarea>
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

// Pattern description
function updatePatternDescription() {
  const pattern = document.getElementById('pattern-type').value;
  const descEl = document.getElementById('pattern-description');
  descEl.textContent = patternDescriptions[pattern] || 'Select a pattern';
}

// Execute single pattern
async function executePattern() {
  const agents = collectAgents();
  const pattern = buildPatternObject();
  const input = document.getElementById('user-input').value;

  if (!input.trim()) {
    showError('Please enter an input prompt');
    return;
  }

  if (agents.length === 0) {
    showError('Please add at least one agent');
    return;
  }

  showLoading();

  try {
    const response = await fetch('/api/execute', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        erAgents: agents,
        erPattern: pattern,
        erInput: input
      })
    });

    const result = await response.json();

    if (result.exError) {
      showError(result.exError);
    } else {
      displayResults(result);
      visualizeExecution(result.exTrace, document.getElementById('pattern-type').value);
    }
  } catch (error) {
    showError('Failed to execute pattern: ' + error.message);
  }
}

// Compare all patterns
async function comparePatterns() {
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

  showLoading();

  try {
    const response = await fetch('/api/compare', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        crAgents: agents,
        crInput: input
      })
    });

    const result = await response.json();
    displayComparison(result.cmpResults);
  } catch (error) {
    showError('Failed to compare patterns: ' + error.message);
  }
}

// Build pattern object based on selection
function buildPatternObject() {
  const patternType = document.getElementById('pattern-type').value;

  switch (patternType) {
    case 'Sequential':
      return 'Sequential';
    case 'Concurrent':
      return { type: 'Concurrent', strategy: 'Vote' };
    case 'GroupChat':
      return { type: 'GroupChat', maxRounds: 5 };
    case 'Handoff':
      return { type: 'Handoff', maxHops: 10 };
    case 'Magentic':
      return { type: 'Magentic', maxIterations: 10 };
    default:
      return 'Sequential';
  }
}

// Display functions
function displayResults(result) {
  const container = document.getElementById('results-container');
  const resultsDiv = document.getElementById('results');

  container.style.display = 'block';
  resultsDiv.innerHTML = `
    <div class="result-metadata">
      <div class="metric">
        <span>Duration:</span>
        <span class="metric-value">${result.exDuration.toFixed(2)}s</span>
      </div>
      <div class="metric">
        <span>Events:</span>
        <span class="metric-value">${result.exTrace.length}</span>
      </div>
    </div>
    <div class="result-output">
      <h4>Final Output</h4>
      <pre>${escapeHtml(result.exOutput)}</pre>
    </div>
  `;
}

function visualizeExecution(trace, patternName) {
  const container = document.getElementById('visualization-container');
  const vizDiv = document.getElementById('visualization');

  container.style.display = 'block';

  const traceHTML = trace.map(event => {
    const eventType = getEventType(event);
    const eventClass = getEventClass(eventType);
    return `<div class="trace-event ${eventClass}">${formatTraceEvent(event)}</div>`;
  }).join('');

  vizDiv.innerHTML = `
    <div><strong>${patternName} Pattern Execution</strong></div>
    <div style="margin-top: 1rem;">${traceHTML}</div>
  `;
}

function displayComparison(results) {
  const container = document.getElementById('results-container');
  const resultsDiv = document.getElementById('results');

  container.style.display = 'block';

  const gridHTML = results.map(([name, result]) => {
    if (result.exError) {
      return `
        <div class="comparison-column">
          <h3>${name}</h3>
          <div class="error-message">${result.exError}</div>
        </div>
      `;
    }

    const preview = result.exOutput.substring(0, 200);
    return `
      <div class="comparison-column">
        <h3>${name}</h3>
        <div class="result-preview">${escapeHtml(preview)}${result.exOutput.length > 200 ? '...' : ''}</div>
        <div class="metrics">
          ⏱️ ${result.exDuration.toFixed(2)}s |
          📊 ${result.exTrace.length} events
        </div>
      </div>
    `;
  }).join('');

  resultsDiv.innerHTML = `
    <h3 style="margin-bottom: 1rem;">Pattern Comparison</h3>
    <div class="comparison-grid">${gridHTML}</div>
  `;

  // Hide visualization when showing comparison
  document.getElementById('visualization-container').style.display = 'none';
}

// Helper functions
function getEventType(event) {
  if (event.tag) return event.tag;
  if (typeof event === 'object') {
    if ('AgentStarted' in event) return 'AgentStarted';
    if ('AgentCompleted' in event) return 'AgentCompleted';
    if ('AgentFailed' in event) return 'AgentFailed';
    if ('HandoffOccurred' in event) return 'HandoffOccurred';
    if ('TaskCreated' in event) return 'TaskCreated';
    if ('TaskCompleted' in event) return 'TaskCompleted';
  }
  return 'Unknown';
}

function getEventClass(eventType) {
  if (eventType.includes('Started') || eventType.includes('Created')) return 'started';
  if (eventType.includes('Completed')) return 'completed';
  if (eventType.includes('Failed')) return 'failed';
  return '';
}

function formatTraceEvent(event) {
  const type = getEventType(event);

  switch (type) {
    case 'AgentStarted':
      return `🟦 Agent started: ${event.AgentStarted?.unAgentId || event[0] || 'unknown'}`;
    case 'AgentCompleted':
      return `✅ Agent completed: ${event.AgentCompleted?.[0]?.unAgentId || 'unknown'}`;
    case 'AgentFailed':
      return `❌ Agent failed: ${event.AgentFailed?.[0]?.unAgentId || 'unknown'}`;
    case 'HandoffOccurred':
      return `🔄 Handoff: ${event.HandoffOccurred?.[0]?.unAgentId || '?'} → ${event.HandoffOccurred?.[1]?.unAgentId || '?'}`;
    case 'TaskCreated':
      return `📝 Task created: ${event.TaskCreated || 'unknown'}`;
    case 'TaskCompleted':
      return `✓ Task completed: ${event.TaskCompleted || 'unknown'}`;
    default:
      return JSON.stringify(event);
  }
}

function showLoading() {
  const resultsDiv = document.getElementById('results');
  const container = document.getElementById('results-container');
  container.style.display = 'block';
  resultsDiv.innerHTML = '<div class="loading"></div> <span>Executing pattern...</span>';
}

function showError(message) {
  const resultsDiv = document.getElementById('results');
  const container = document.getElementById('results-container');
  container.style.display = 'block';
  resultsDiv.innerHTML = `<div class="error-message">❌ ${escapeHtml(message)}</div>`;
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
