// LLM Orchestration Patterns UI - 5 Tab Comparison
// ================================================

// Global State Management
const state = {
  currentPattern: 'sequential',
  ws: null,
  patterns: {
    sequential: {
      agents: [],
      status: 'ready',
      result: null,
      logs: []
    },
    concurrent: {
      agents: [],
      aggregation: 'combine',
      status: 'ready',
      result: null,
      logs: []
    },
    groupchat: {
      agents: [],
      rounds: 5,
      status: 'ready',
      result: null,
      logs: []
    },
    handoff: {
      agents: [],
      maxHops: 10,
      status: 'ready',
      result: null,
      logs: []
    },
    magentic: {
      agents: [],
      maxIterations: 10,
      status: 'ready',
      result: null,
      logs: []
    }
  }
};

// Default agent configurations per pattern
const defaultAgents = {
  sequential: [
    {
      acId: 'analyzer',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are an analytical AI that breaks down problems into components.'
    },
    {
      acId: 'synthesizer',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are a synthesis AI that combines insights into coherent solutions.'
    }
  ],
  concurrent: [
    {
      acId: 'expert1',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are an AI expert focusing on technical accuracy.'
    },
    {
      acId: 'expert2',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are an AI expert focusing on practical applications.'
    },
    {
      acId: 'expert3',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are an AI expert focusing on creative solutions.'
    }
  ],
  groupchat: [
    {
      acId: 'facilitator',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You facilitate discussions and summarize key points.'
    },
    {
      acId: 'critic',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You provide critical analysis and identify potential issues.'
    },
    {
      acId: 'builder',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You build upon ideas and propose concrete implementations.'
    }
  ],
  handoff: [
    {
      acId: 'router',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You route tasks to specialized agents based on requirements.'
    },
    {
      acId: 'specialist_a',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are a specialist in data analysis and processing.'
    },
    {
      acId: 'specialist_b',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are a specialist in solution design and architecture.'
    }
  ],
  magentic: [
    {
      acId: 'manager',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are a manager that decomposes tasks and coordinates workers.'
    },
    {
      acId: 'worker1',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are a worker agent that executes assigned subtasks efficiently.'
    },
    {
      acId: 'worker2',
      acProvider: 'ollama',
      acModel: 'llama3.2',
      acSystemPrompt: 'You are a worker agent specialized in verification and quality checks.'
    }
  ]
};

// Mermaid.js Configuration
mermaid.initialize({
  startOnLoad: false,
  theme: 'dark',
  themeVariables: {
    primaryColor: '#0d1128',
    primaryTextColor: '#ffffff',
    primaryBorderColor: '#00ffff',
    lineColor: '#00d9ff',
    secondaryColor: '#0f1330',
    tertiaryColor: '#0a0e27',
    background: '#000000',
    mainBkg: '#0d1128',
    nodeBorder: '#00ffff',
    clusterBkg: '#0f1330',
    clusterBorder: '#00d9ff',
    titleColor: '#00ffff',
    edgeLabelBackground: '#0d1128',
    nodeTextColor: '#ffffff'
  },
  flowchart: {
    curve: 'basis',
    padding: 15
  }
});

// Initialize Application
document.addEventListener('DOMContentLoaded', () => {
  console.log('Initializing LLM Orchestration Patterns UI...');

  initializeState();
  initializeEventListeners();
  initializeWebSocket();
  renderAllAgents();
  renderAllDAGs();

  console.log('UI initialized successfully');
});

// Initialize State with Default Agents
function initializeState() {
  Object.keys(state.patterns).forEach(pattern => {
    state.patterns[pattern].agents = JSON.parse(JSON.stringify(defaultAgents[pattern]));
  });
}

// Event Listeners
function initializeEventListeners() {
  // Execute All button
  document.getElementById('execute-all').addEventListener('click', executeAllPatterns);

  // Tab buttons
  document.querySelectorAll('.tab-button').forEach(button => {
    button.addEventListener('click', (e) => {
      const pattern = e.currentTarget.dataset.pattern;
      switchTab(pattern);
    });
  });

  // Add Agent buttons
  document.querySelectorAll('.btn-add-agent').forEach(button => {
    button.addEventListener('click', (e) => {
      const pattern = e.currentTarget.dataset.pattern;
      addAgent(pattern);
    });
  });

  // Aggregation method selector (Concurrent)
  const concurrentAggregation = document.getElementById('concurrent-aggregation');
  if (concurrentAggregation) {
    concurrentAggregation.addEventListener('change', (e) => {
      state.patterns.concurrent.aggregation = e.target.value;
      renderDAG('concurrent');
    });
  }

  // Rounds selector (Group Chat)
  const groupchatRounds = document.getElementById('groupchat-rounds');
  if (groupchatRounds) {
    groupchatRounds.addEventListener('change', (e) => {
      state.patterns.groupchat.rounds = parseInt(e.target.value);
      renderDAG('groupchat');
    });
  }

  // Max Hops selector (Handoff)
  const handoffHops = document.getElementById('handoff-hops');
  if (handoffHops) {
    handoffHops.addEventListener('change', (e) => {
      state.patterns.handoff.maxHops = parseInt(e.target.value);
    });
  }

  // Max Iterations selector (Magentic)
  const magenticIterations = document.getElementById('magentic-iterations');
  if (magenticIterations) {
    magenticIterations.addEventListener('change', (e) => {
      state.patterns.magentic.maxIterations = parseInt(e.target.value);
    });
  }
}

// WebSocket Initialization
function initializeWebSocket() {
  const wsStatus = document.getElementById('ws-status');
  const wsText = wsStatus.querySelector('.ws-text');

  try {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws`;

    wsStatus.classList.remove('connected');
    wsStatus.classList.add('connecting');
    wsText.textContent = 'Connecting...';

    state.ws = new WebSocket(wsUrl);

    state.ws.onopen = () => {
      console.log('WebSocket connected');
      wsStatus.classList.remove('connecting');
      wsStatus.classList.add('connected');
      wsText.textContent = 'Connected';
    };

    state.ws.onmessage = (event) => {
      handleWebSocketMessage(JSON.parse(event.data));
    };

    state.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
      wsStatus.classList.remove('connecting', 'connected');
      wsText.textContent = 'Error';
    };

    state.ws.onclose = () => {
      console.log('WebSocket disconnected');
      wsStatus.classList.remove('connecting', 'connected');
      wsText.textContent = 'Disconnected';

      // Attempt to reconnect after 5 seconds
      setTimeout(initializeWebSocket, 5000);
    };
  } catch (error) {
    console.error('Failed to initialize WebSocket:', error);
    wsStatus.classList.remove('connecting', 'connected');
    wsText.textContent = 'Unavailable';
  }
}

// Handle WebSocket Messages
function handleWebSocketMessage(data) {
  if (!data.pattern || !state.patterns[data.pattern]) {
    console.warn('Unknown pattern in WebSocket message:', data);
    return;
  }

  const pattern = data.pattern;

  if (data.event) {
    // Log event to pattern's log
    addLog(pattern, formatEvent(data.event));

    // Update status based on event type
    if (data.event.ExecutionStarted) {
      updatePatternStatus(pattern, 'running');
    } else if (data.event.ExecutionCompleted) {
      updatePatternStatus(pattern, 'complete');
      setResult(pattern, data.event.ExecutionCompleted);
    } else if (data.event.ExecutionFailed) {
      updatePatternStatus(pattern, 'error');
      setResult(pattern, { error: data.event.ExecutionFailed });
    }
  }
}

// Tab Switching
function switchTab(pattern) {
  if (state.currentPattern === pattern) return;

  state.currentPattern = pattern;

  // Update tab buttons
  document.querySelectorAll('.tab-button').forEach(button => {
    if (button.dataset.pattern === pattern) {
      button.classList.add('active');
    } else {
      button.classList.remove('active');
    }
  });

  // Update panels
  document.querySelectorAll('.pattern-panel').forEach(panel => {
    if (panel.id === `panel-${pattern}`) {
      panel.classList.add('active');
    } else {
      panel.classList.remove('active');
    }
  });
}

// Agent Management
function addAgent(pattern) {
  const agentIndex = state.patterns[pattern].agents.length;
  const newAgent = {
    acId: `agent${agentIndex + 1}`,
    acProvider: 'ollama',
    acModel: 'llama3.2',
    acSystemPrompt: 'You are a helpful AI assistant.'
  };

  state.patterns[pattern].agents.push(newAgent);
  renderAgents(pattern);
  renderDAG(pattern);
}

function removeAgent(pattern, index) {
  if (state.patterns[pattern].agents.length <= 1) {
    showError('At least one agent is required');
    return;
  }

  state.patterns[pattern].agents.splice(index, 1);
  renderAgents(pattern);
  renderDAG(pattern);
}

function updateAgent(pattern, index, field, value) {
  if (state.patterns[pattern].agents[index]) {
    state.patterns[pattern].agents[index][field] = value;
    // Re-render DAG if agent ID changed
    if (field === 'acId') {
      renderDAG(pattern);
    }
  }
}

// Render All Agents
function renderAllAgents() {
  Object.keys(state.patterns).forEach(pattern => {
    renderAgents(pattern);
  });
}

// Render Agents for a Pattern
function renderAgents(pattern) {
  const container = document.getElementById(`agents-${pattern}`);
  if (!container) return;

  container.innerHTML = '';

  state.patterns[pattern].agents.forEach((agent, index) => {
    const card = createAgentCard(pattern, agent, index);
    container.appendChild(card);
  });
}

// Create Agent Card
function createAgentCard(pattern, agent, index) {
  const card = document.createElement('div');
  card.className = 'agent-card';

  card.innerHTML = `
    <div class="agent-card-header">
      <span class="agent-card-title">Agent ${index + 1}</span>
      ${state.patterns[pattern].agents.length > 1 ?
        `<button class="btn-remove-agent" data-pattern="${pattern}" data-index="${index}">×</button>` :
        ''}
    </div>
    <div class="agent-field">
      <label>Agent ID</label>
      <input type="text" value="${agent.acId}" data-field="acId" data-pattern="${pattern}" data-index="${index}">
    </div>
    <div class="agent-field">
      <label>Provider</label>
      <select data-field="acProvider" data-pattern="${pattern}" data-index="${index}">
        <option value="ollama" ${agent.acProvider === 'ollama' ? 'selected' : ''}>Ollama</option>
        <option value="openai" ${agent.acProvider === 'openai' ? 'selected' : ''}>OpenAI</option>
      </select>
    </div>
    <div class="agent-field">
      <label>Model</label>
      <input type="text" value="${agent.acModel}" data-field="acModel" data-pattern="${pattern}" data-index="${index}">
    </div>
    <div class="agent-field">
      <label>System Prompt</label>
      <textarea rows="3" data-field="acSystemPrompt" data-pattern="${pattern}" data-index="${index}">${agent.acSystemPrompt}</textarea>
    </div>
  `;

  // Event listeners for agent card
  card.querySelectorAll('input, select, textarea').forEach(input => {
    input.addEventListener('change', (e) => {
      const field = e.target.dataset.field;
      const pattern = e.target.dataset.pattern;
      const index = parseInt(e.target.dataset.index);
      updateAgent(pattern, index, field, e.target.value);
    });
  });

  const removeBtn = card.querySelector('.btn-remove-agent');
  if (removeBtn) {
    removeBtn.addEventListener('click', (e) => {
      const pattern = e.target.dataset.pattern;
      const index = parseInt(e.target.dataset.index);
      removeAgent(pattern, index);
    });
  }

  return card;
}

// Render All DAGs
function renderAllDAGs() {
  Object.keys(state.patterns).forEach(pattern => {
    renderDAG(pattern);
  });
}

// Render DAG for a Pattern
function renderDAG(pattern) {
  const container = document.getElementById(`dag-${pattern}`);
  if (!container) return;

  const agents = state.patterns[pattern].agents;
  const agentIds = agents.map(a => a.acId);

  let mermaidCode = '';

  switch (pattern) {
    case 'sequential':
      mermaidCode = generateSequentialDAG(agentIds);
      break;
    case 'concurrent':
      mermaidCode = generateConcurrentDAG(agentIds, state.patterns.concurrent.aggregation);
      break;
    case 'groupchat':
      mermaidCode = generateGroupChatDAG(agentIds, state.patterns.groupchat.rounds);
      break;
    case 'handoff':
      mermaidCode = generateHandoffDAG(agentIds);
      break;
    case 'magentic':
      mermaidCode = generateMagenticDAG(agentIds);
      break;
  }

  container.innerHTML = mermaidCode;
  container.removeAttribute('data-processed');
  mermaid.run({ nodes: [container] });
}

// DAG Generation Functions
function generateSequentialDAG(agents) {
  let code = 'graph TD\n';

  if (agents.length === 0) return code;

  code += `  Start([Input]) --> A0["${agents[0]}"]\n`;

  for (let i = 0; i < agents.length - 1; i++) {
    code += `  A${i} --> A${i + 1}["${agents[i + 1]}"]\n`;
  }

  code += `  A${agents.length - 1} --> End([Output])\n`;
  return code;
}

function generateConcurrentDAG(agents, aggregation) {
  let code = 'graph TD\n';

  if (agents.length === 0) return code;

  const aggMethod = aggregation.charAt(0).toUpperCase() + aggregation.slice(1);

  code += '  Start([Input]) --> Broadcast{Broadcast}\n';

  agents.forEach((agent, i) => {
    code += `  Broadcast --> A${i}["${agent}"]\n`;
  });

  agents.forEach((agent, i) => {
    code += `  A${i} --> Aggregate["${aggMethod}"]\n`;
  });

  code += '  Aggregate --> End([Output])\n';
  return code;
}

function generateGroupChatDAG(agents, rounds) {
  let code = 'graph TD\n';

  if (agents.length === 0) return code;

  const maxRoundsToShow = Math.min(rounds, 3);

  code += '  Start([Input]) --> Round1["Round 1"]\n';

  for (let r = 1; r <= maxRoundsToShow; r++) {
    agents.forEach((agent, i) => {
      code += `  Round${r} --> R${r}A${i}["${agent}"]\n`;
    });

    if (r < maxRoundsToShow) {
      agents.forEach((agent, i) => {
        code += `  R${r}A${i} --> Round${r + 1}["Round ${r + 1}"]\n`;
      });
    }
  }

  if (rounds > 3) {
    code += `  R3A0 -.-> More["... ${rounds - 3} more rounds"]\n`;
    code += '  More -.-> Consensus["Consensus"]\n';
  } else {
    agents.forEach((agent, i) => {
      code += `  R${maxRoundsToShow}A${i} --> Consensus["Consensus"]\n`;
    });
  }

  code += '  Consensus --> End([Output])\n';
  return code;
}

function generateHandoffDAG(agents) {
  let code = 'graph TD\n';

  if (agents.length === 0) return code;

  code += `  Start([Input]) --> A0["${agents[0]}"]\n`;

  for (let i = 0; i < agents.length - 1; i++) {
    code += `  A${i} -.->|handoff| A${i + 1}["${agents[i + 1]}"]\n`;
  }

  code += `  A${agents.length - 1} --> End([Output])\n`;
  return code;
}

function generateMagenticDAG(agents) {
  let code = 'graph TD\n';

  if (agents.length === 0) return code;

  code += `  Start([Input]) --> Manager["${agents[0]}"]\n`;

  for (let i = 1; i < agents.length; i++) {
    code += `  Manager -->|task| W${i}["${agents[i]}"]\n`;
  }

  for (let i = 1; i < agents.length; i++) {
    code += `  W${i} -->|result| Manager\n`;
  }

  code += '  Manager --> End([Output])\n';
  return code;
}

// Execute All Patterns
async function executeAllPatterns() {
  const rootPrompt = document.getElementById('root-prompt').value.trim();

  if (!rootPrompt) {
    showError('Please enter a root prompt');
    return;
  }

  // Disable execute button
  const executeBtn = document.getElementById('execute-all');
  executeBtn.disabled = true;

  // Clear previous results
  Object.keys(state.patterns).forEach(pattern => {
    state.patterns[pattern].logs = [];
    state.patterns[pattern].result = null;
    updatePatternStatus(pattern, 'ready');
    clearLog(pattern);
    clearResult(pattern);
  });

  try {
    // Execute all patterns in parallel
    const promises = Object.keys(state.patterns).map(async (pattern) => {
      updatePatternStatus(pattern, 'running');

      try {
        const result = await executePattern(pattern, rootPrompt);
        updatePatternStatus(pattern, 'complete');
        setResult(pattern, result);
      } catch (error) {
        console.error(`Pattern ${pattern} failed:`, error);
        updatePatternStatus(pattern, 'error');
        setResult(pattern, { error: error.message });
      }
    });

    await Promise.all(promises);
  } catch (error) {
    console.error('Execution failed:', error);
    showError('Execution failed: ' + error.message);
  } finally {
    executeBtn.disabled = false;
  }
}

// Execute Individual Pattern
async function executePattern(patternName, input) {
  const pattern = state.patterns[patternName];

  // Build request based on pattern type
  let requestBody = {
    crAgents: pattern.agents,
    crInput: input
  };

  // Add pattern-specific configuration
  switch (patternName) {
    case 'concurrent':
      requestBody.crAggregation = pattern.aggregation;
      break;
    case 'groupchat':
      requestBody.crRounds = pattern.rounds;
      break;
    case 'handoff':
      requestBody.crMaxHops = pattern.maxHops;
      break;
    case 'magentic':
      requestBody.crMaxIterations = pattern.maxIterations;
      break;
  }

  addLog(patternName, `Starting ${patternName} pattern execution...`);

  const response = await fetch(`/api/${patternName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(requestBody)
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }

  const result = await response.json();

  // Process trace events
  if (result.exTrace) {
    result.exTrace.forEach(event => {
      addLog(patternName, formatEvent(event));
    });
  }

  return result;
}

// Update Pattern Status
function updatePatternStatus(pattern, status) {
  state.patterns[pattern].status = status;

  const tabButton = document.querySelector(`.tab-button[data-pattern="${pattern}"]`);
  if (tabButton) {
    const statusSpan = tabButton.querySelector('.tab-status');
    statusSpan.setAttribute('data-status', status);
    statusSpan.textContent = status.toUpperCase();
  }
}

// Log Management
function addLog(pattern, message) {
  state.patterns[pattern].logs.push(message);

  const logContainer = document.getElementById(`log-${pattern}`);
  if (!logContainer) return;

  // Remove placeholder if exists
  const placeholder = logContainer.querySelector('.log-placeholder');
  if (placeholder) {
    placeholder.remove();
  }

  const logEntry = document.createElement('div');
  logEntry.className = 'log-entry';

  // Determine log entry class based on content
  if (typeof message === 'object') {
    logEntry.className += ' ' + getEventClass(message);
    logEntry.textContent = formatEventText(message);
  } else {
    logEntry.className += ' event-info';
    logEntry.textContent = message;
  }

  logContainer.appendChild(logEntry);
  logContainer.scrollTop = logContainer.scrollHeight;
}

function clearLog(pattern) {
  const logContainer = document.getElementById(`log-${pattern}`);
  if (!logContainer) return;

  logContainer.innerHTML = '<div class="log-placeholder">Execution log will appear here...</div>';
}

// Event Formatting
function formatEvent(event) {
  if (typeof event === 'string') {
    return event;
  }
  return event;
}

function getEventClass(event) {
  if (event.AgentStarted) return 'event-start';
  if (event.AgentCompleted) return 'event-complete';
  if (event.AgentFailed) return 'event-error';
  if (event.HandoffOccurred) return 'event-handoff';
  if (event.TaskCreated) return 'event-task';
  if (event.TaskCompleted) return 'event-task';
  if (event.RoundStarted) return 'event-round';
  if (event.RoundCompleted) return 'event-round';
  return 'event-info';
}

function formatEventText(event) {
  if (typeof event === 'string') return event;

  if (event.AgentStarted) return `▶ Agent ${event.AgentStarted} started`;
  if (event.AgentCompleted) return `✓ Agent ${event.AgentCompleted[0]} completed`;
  if (event.AgentFailed) return `✗ Agent ${event.AgentFailed[0]} failed: ${event.AgentFailed[1]}`;
  if (event.HandoffOccurred) return `⤷ Handoff: ${event.HandoffOccurred[0]} → ${event.HandoffOccurred[1]}`;
  if (event.TaskCreated) return `+ Task created: ${event.TaskCreated}`;
  if (event.TaskCompleted) return `✓ Task completed: ${event.TaskCompleted}`;
  if (event.RoundStarted) return `🔄 Round ${event.RoundStarted} started`;
  if (event.RoundCompleted) return `✓ Round ${event.RoundCompleted} completed`;

  return JSON.stringify(event);
}

// Result Management
function setResult(pattern, result) {
  state.patterns[pattern].result = result;

  const resultContainer = document.getElementById(`result-${pattern}`);
  if (!resultContainer) return;

  resultContainer.innerHTML = '';

  if (result.error || result.exError) {
    resultContainer.classList.add('result-error');
    const errorMsg = result.error || result.exError;
    resultContainer.innerHTML = `<div class="result-content">${escapeHtml(errorMsg)}</div>`;
  } else {
    resultContainer.classList.remove('result-error');
    const output = result.exOutput || result;
    resultContainer.innerHTML = `<div class="result-content">${escapeHtml(output)}</div>`;
  }
}

function clearResult(pattern) {
  const resultContainer = document.getElementById(`result-${pattern}`);
  if (!resultContainer) return;

  resultContainer.classList.remove('result-error');
  resultContainer.innerHTML = '<div class="result-placeholder">No results yet. Click "EXECUTE ALL" to run this pattern.</div>';
}

// Error Toast
function showError(message) {
  const toast = document.getElementById('error-toast');
  toast.textContent = message;
  toast.style.display = 'block';

  setTimeout(() => {
    toast.style.display = 'none';
  }, 5000);
}

// Utility Functions
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
