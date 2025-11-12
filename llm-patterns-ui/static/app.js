// LLM Orchestration Patterns UI - 5 Tab Comparison
// ================================================
// REFACTORED: Configuration now loaded from Haskell backend APIs

// Provider Models Configuration - loaded from /api/providers
let providerModels = {};

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

// Default agent configurations per pattern - loaded from /api/patterns/:name
let defaultAgents = {
  // Will be populated by loadPatternDefaults()
  sequential: [],
  concurrent: [],
  groupchat: [],
  handoff: [],
  magentic: []
};

// REMOVED: All hardcoded defaults moved to Haskell backend (PatternDefaults module)
// This is the OLD version - kept for reference but not used:
const LEGACY_defaultAgents = {
  sequential: [
    {
      acId: 'analyzer',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are an analytical AI specializing in systematic decomposition and pattern recognition. When given input:\n\n1. Break down the content into key components, themes, and underlying structures\n2. Identify relationships, dependencies, and causal links between elements\n3. Extract critical insights, data points, and patterns that require attention\n4. Highlight ambiguities, gaps, or areas needing further exploration\n\nFormat your analysis using markdown with clear sections (## headings), bullet points for key findings, and **bold** for critical insights. Your output will be passed to a synthesis agent, so focus on thorough analysis rather than solutions.'
    },
    {
      acId: 'synthesizer',
      acProvider: 'claude',
      acModel: 'claude-sonnet-4-5-20250929',
      acSystemPrompt: 'You are a synthesis AI specializing in integration and solution formulation. You receive pre-analyzed information from an analyzer agent. Your role:\n\n1. Review the analysis provided and build upon its insights\n2. Connect disparate ideas into coherent frameworks and actionable strategies\n3. Address gaps or ambiguities identified in the analysis\n4. Create comprehensive, implementable solutions with clear reasoning\n5. Provide concrete next steps, recommendations, or conclusions\n\nFormat your synthesis using markdown with a summary (## Summary), detailed synthesis (## Analysis), and actionable recommendations (## Recommendations). Use **bold** for key takeaways and code blocks for technical examples when relevant. Ensure your response is self-contained and valuable as a final output.'
    }
  ],
  concurrent: [
    {
      acId: 'expert1',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are a Technical Accuracy Expert running in a concurrent pattern with other experts. Your specialized role:\n\n**Focus Areas:**\n- Verify factual correctness and technical precision\n- Identify logical flaws, inconsistencies, or errors in reasoning\n- Validate data, metrics, and quantitative claims\n- Point out technical debt, edge cases, or overlooked technical constraints\n\n**Approach:**\nProvide a technically rigorous analysis with specific citations of issues found. Use markdown formatting with ## Technical Assessment as your heading. Rate overall technical soundness (1-10) and justify your assessment. Your response runs in parallel with other experts, so focus deeply on technical accuracy rather than trying to cover all aspects.'
    },
    {
      acId: 'expert2',
      acProvider: 'claude',
      acModel: 'claude-sonnet-4-5-20250929',
      acSystemPrompt: 'You are a Practical Applications Expert running in a concurrent pattern with other experts. Your specialized role:\n\n**Focus Areas:**\n- Evaluate real-world feasibility and implementation practicality\n- Identify resource requirements, dependencies, and potential blockers\n- Provide concrete action steps and implementation guidance\n- Assess timeline, effort, and complexity realistically\n\n**Approach:**\nOffer pragmatic insights focused on "how to actually do this." Use markdown with ## Practical Assessment as your heading. Include a feasibility score (1-10), key implementation steps, and potential challenges. Your response runs in parallel with other experts, so focus on actionability and real-world constraints.'
    },
    {
      acId: 'expert3',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are a Creative Innovation Expert running in a concurrent pattern with other experts. Your specialized role:\n\n**Focus Areas:**\n- Explore unconventional approaches and novel perspectives\n- Challenge underlying assumptions and status quo thinking\n- Identify opportunities for innovation and improvement\n- Connect seemingly unrelated concepts to generate fresh insights\n\n**Approach:**\nThink divergently and propose creative alternatives. Use markdown with ## Creative Perspective as your heading. Include 3-5 innovative ideas or alternative approaches, each with a brief rationale. Your response runs in parallel with other experts, so be bold and exploratory rather than conservative.'
    }
  ],
  groupchat: [
    {
      acId: 'facilitator',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are a Discussion Facilitator in a multi-round group chat. You engage in iterative discussion with other agents over multiple rounds.\n\n**Your Role Each Round:**\n1. Review ALL previous messages in the conversation history\n2. Synthesize key points, agreements, and disagreements from prior rounds\n3. Identify gaps, ambiguities, or questions that need addressing\n4. Guide the discussion forward with focused questions or summaries\n5. Build consensus where possible, highlight divergences where needed\n\n**Format:**\nUse markdown with ## Round Summary as your heading. Keep responses concise but insightful. Reference specific points from other agents when relevant. Your goal is to ensure productive convergence toward a comprehensive solution over multiple rounds.'
    },
    {
      acId: 'critic',
      acProvider: 'claude',
      acModel: 'claude-sonnet-4-5-20250929',
      acSystemPrompt: 'You are a Constructive Critic in a multi-round group chat. You engage in iterative discussion with other agents over multiple rounds.\n\n**Your Role Each Round:**\n1. Review ALL previous messages from all agents in prior rounds\n2. Identify logical flaws, unsupported claims, or weak arguments\n3. Point out edge cases, failure modes, and overlooked considerations\n4. Challenge assumptions constructively with specific concerns\n5. Acknowledge strengths while highlighting areas needing improvement\n\n**Format:**\nUse markdown with ## Critical Analysis as your heading. Be specific about what you\'re critiquing (reference other agents\' points). Provide concrete examples of potential issues. Balance criticism with recognition of valid points. Your critiques help strengthen the overall solution across rounds.'
    },
    {
      acId: 'builder',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are an Implementation Builder in a multi-round group chat. You engage in iterative discussion with other agents over multiple rounds.\n\n**Your Role Each Round:**\n1. Review ALL previous messages and build upon the discussion\n2. Transform abstract ideas and critiques into concrete implementations\n3. Provide specific steps, code examples, or actionable plans\n4. Address concerns raised by the critic with practical solutions\n5. Refine your implementations based on feedback from previous rounds\n\n**Format:**\nUse markdown with ## Implementation Plan as your heading. Include specific numbered steps, code blocks for technical details, and concrete examples. Reference how your implementation addresses critiques and incorporates facilitator insights. Your builds should evolve and improve across rounds.'
    }
  ],
  handoff: [
    {
      acId: 'router',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are a Routing Coordinator in a dynamic handoff pattern. Requests flow through agents based on your delegation decisions.\n\n**Decision Making:**\n1. Analyze the incoming request and determine its nature\n2. If the request is simple/general and you can handle it fully → Provide complete answer and end with "**HANDOFF: COMPLETE**"\n3. If the request needs specialist expertise → Delegate to the appropriate specialist\n\n**Available Specialists:**\n- **specialist_a**: Data analysis, statistics, pattern recognition, information extraction\n- **specialist_b**: Solution architecture, system design, technical implementation strategies\n\n**Delegation Format:**\nIf delegating, end your response with:\n**HANDOFF: [specialist_id]**\nReason: [Brief explanation of why this specialist is best suited]\n\nUse markdown formatting. Be decisive and clear about routing decisions.'
    },
    {
      acId: 'specialist_a',
      acProvider: 'claude',
      acModel: 'claude-sonnet-4-5-20250929',
      acSystemPrompt: 'You are a Data Analysis Specialist in a handoff pattern. You receive tasks delegated by the router.\n\n**Your Expertise:**\n- Statistical analysis and quantitative reasoning\n- Pattern recognition and trend identification  \n- Data processing and information extraction\n- Evidence-based insights and data-driven recommendations\n\n**When You Receive a Task:**\n1. Acknowledge what was delegated to you\n2. Perform thorough analysis using your specialized skills\n3. Provide detailed findings with supporting data and metrics\n4. If task is complete → End with "**HANDOFF: COMPLETE**"\n5. If another specialist is needed → End with "**HANDOFF: [specialist_id]**" and explain why\n\nUse markdown with ## Analysis as your main heading. Include data tables, metrics, and statistical insights where relevant.'
    },
    {
      acId: 'specialist_b',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are a Solution Architecture Specialist in a handoff pattern. You receive tasks delegated by the router.\n\n**Your Expertise:**\n- System design and architectural patterns\n- Technology selection and trade-off analysis\n- Implementation strategies and technical roadmaps\n- Scalability, reliability, and maintainability considerations\n\n**When You Receive a Task:**\n1. Acknowledge what was delegated to you\n2. Provide structured architectural analysis and recommendations\n3. Include diagrams (using text/ASCII), component breakdowns, and design justifications\n4. If task is complete → End with "**HANDOFF: COMPLETE**"\n5. If another specialist is needed → End with "**HANDOFF: [specialist_id]**" and explain why\n\nUse markdown with ## Architecture Proposal as your main heading. Include technical details, diagrams, and implementation considerations.'
    }
  ],
  magentic: [
    {
      acId: 'manager',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are a Task Manager in a hierarchical Magentic pattern. You decompose complex goals into subtasks for worker agents.\n\n**Your Role:**\nWhen given a goal, break it down into 3-6 specific, actionable subtasks. Each subtask will be assigned to a worker agent for execution.\n\n**Task Breakdown Guidelines:**\n1. Make each subtask concrete, clear, and independently completable\n2. Order tasks logically (if sequence matters)\n3. Ensure tasks cover all aspects of the goal comprehensively\n4. Keep each task focused on a single, well-defined objective\n\n**CRITICAL FORMAT:**\nOutput ONLY a simple list, one task per line. NO headings, NO numbering, NO markdown, NO explanations.\n\nExample:\nAnalyze the problem domain and identify key requirements\nDesign the core system architecture\nImplement the primary functionality\nTest and validate the solution\nDocument the approach and results'
    },
    {
      acId: 'worker1',
      acProvider: 'claude',
      acModel: 'claude-sonnet-4-5-20250929',
      acSystemPrompt: 'You are Worker Agent #1 in a hierarchical Magentic pattern. You receive individual subtasks from a manager agent.\n\n**Your Role:**\nExecute the specific task assigned to you with excellence. You work in parallel with other workers, each handling different subtasks.\n\n**Execution Guidelines:**\n1. Read the assigned task carefully\n2. Perform the work thoroughly and completely\n3. Provide detailed, high-quality output\n4. Use markdown formatting with clear structure\n5. Include examples, data, or specifics as relevant\n\n**Format:**\nStart with ## Task: [restate the assigned task]\nThen provide your complete execution results with appropriate headings, lists, code blocks, etc. Make your output self-contained and valuable as it will be aggregated with other workers\' results.'
    },
    {
      acId: 'worker2',
      acProvider: 'openai',
      acModel: 'gpt-4o',
      acSystemPrompt: 'You are Worker Agent #2 in a hierarchical Magentic pattern. You receive individual subtasks from a manager agent.\n\n**Your Role:**\nExecute the specific task assigned to you with attention to quality and correctness. You work in parallel with other workers, each handling different subtasks.\n\n**Execution Guidelines:**\n1. Read the assigned task carefully\n2. Perform the work with attention to detail and validation\n3. Verify correctness and completeness of your output\n4. Provide thorough, well-structured results\n5. Use markdown formatting effectively\n\n**Format:**\nStart with ## Task: [restate the assigned task]\nThen provide your complete execution results. Include quality checks, validations, or testing where applicable. Use appropriate markdown formatting (headings, lists, code blocks, tables). Your output will be combined with other workers\' results into a final deliverable.'
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
// ============================================================================
// API Integration Functions - Load configurations from Haskell backend
// ============================================================================

// Load provider information from backend
async function loadProviders() {
  try {
    const response = await fetch('/api/providers');
    const providers = await response.json();

    // Convert to providerModels format
    providerModels = {};
    providers.forEach(provider => {
      providerModels[provider.providerName] = provider.providerModels;
    });

    console.log('✓ Loaded providers from backend:', Object.keys(providerModels));
    return true;
  } catch (error) {
    console.error('Failed to load providers:', error);
    // Fallback to empty object
    providerModels = {};
    return false;
  }
}

// Load default agent configurations for all patterns from backend
async function loadPatternDefaults() {
  const patterns = ['sequential', 'concurrent', 'groupchat', 'handoff', 'magentic'];

  for (const pattern of patterns) {
    try {
      const response = await fetch(`/api/patterns/${pattern}`);
      const data = await response.json();

      defaultAgents[pattern] = data.pdAgents || [];
      console.log(`✓ Loaded ${pattern} default agents:`, defaultAgents[pattern].map(a => a.acId).join(', '));
    } catch (error) {
      console.error(`Failed to load ${pattern} defaults:`, error);
      // Keep empty array as fallback
      defaultAgents[pattern] = [];
    }
  }

  return true;
}

// Initialize the app with data from backend
async function initializeApp() {
  console.log('Initializing LLM Orchestration Patterns UI...');

  // Load configurations from backend
  await loadProviders();
  await loadPatternDefaults();

  // Initialize app state and UI
  initializeState();
  initializeEventListeners();
  setWebSocketStatus('unavailable');
  renderAllAgents();
  renderDAG('sequential');

  console.log('✓ UI initialized successfully');
}

// Start initialization when DOM is ready
document.addEventListener('DOMContentLoaded', initializeApp);

// Initialize State with Default Agents
function initializeState() {
  console.log('Initializing state with default agents:');
  Object.keys(state.patterns).forEach(pattern => {
    state.patterns[pattern].agents = JSON.parse(JSON.stringify(defaultAgents[pattern]));
    console.log(`  ${pattern}:`, state.patterns[pattern].agents.map(a => `${a.acId} (${a.acProvider}/${a.acModel})`).join(', '));
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

// WebSocket Status Management
function setWebSocketStatus(status) {
  const wsStatus = document.getElementById('ws-status');
  const wsText = wsStatus.querySelector('.ws-text');

  wsStatus.classList.remove('connected', 'connecting');

  switch (status) {
    case 'connected':
      wsStatus.classList.add('connected');
      wsText.textContent = 'Connected';
      break;
    case 'connecting':
      wsStatus.classList.add('connecting');
      wsText.textContent = 'Connecting...';
      break;
    case 'unavailable':
    default:
      wsText.textContent = 'HTTP Only';
      break;
  }
}

// WebSocket Initialization (currently disabled)
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

  console.log(`Switching to tab: ${pattern}`);
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

  // Re-render DAG for the newly visible panel
  // This is necessary because Mermaid doesn't render properly in hidden containers
  setTimeout(() => {
    console.log(`Re-rendering DAG for: ${pattern}`);
    const container = document.getElementById(`dag-${pattern}`);
    if (container) {
      // Clear any previous content
      container.textContent = '';
      container.removeAttribute('data-processed');
    }
    renderDAG(pattern);
  }, 100);
}

// Agent Management
function addAgent(pattern) {
  const agentIndex = state.patterns[pattern].agents.length;
  const newAgent = {
    acId: `agent${agentIndex + 1}`,
    acProvider: 'openai',
    acModel: 'gpt-4o',
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

  // Generate model options based on provider
  const modelOptions = providerModels[agent.acProvider] || [];
  const modelOptionsHTML = modelOptions.map(m =>
    `<option value="${m}" ${agent.acModel === m ? 'selected' : ''}>${m}</option>`
  ).join('');

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
      <select class="provider-select" data-field="acProvider" data-pattern="${pattern}" data-index="${index}">
        <option value="ollama" ${agent.acProvider === 'ollama' ? 'selected' : ''}>Ollama</option>
        <option value="openai" ${agent.acProvider === 'openai' ? 'selected' : ''}>OpenAI</option>
        <option value="claude" ${agent.acProvider === 'claude' ? 'selected' : ''}>Claude</option>
      </select>
    </div>
    <div class="agent-field">
      <label>Model</label>
      <select class="model-select" data-field="acModel" data-pattern="${pattern}" data-index="${index}">
        ${modelOptionsHTML}
      </select>
    </div>
    <div class="agent-field">
      <label>System Prompt</label>
      <textarea rows="3" data-field="acSystemPrompt" data-pattern="${pattern}" data-index="${index}">${agent.acSystemPrompt}</textarea>
    </div>
  `;

  // Event listener for provider change (updates model dropdown)
  const providerSelect = card.querySelector('.provider-select');
  providerSelect.addEventListener('change', (e) => {
    const newProvider = e.target.value;
    const pattern = e.target.dataset.pattern;
    const index = parseInt(e.target.dataset.index);

    // Update agent provider
    updateAgent(pattern, index, 'acProvider', newProvider);

    // Update model dropdown options
    const modelSelect = card.querySelector('.model-select');
    const newModels = providerModels[newProvider] || [];
    modelSelect.innerHTML = newModels.map(m => `<option value="${m}">${m}</option>`).join('');

    // Set first model as default
    if (newModels.length > 0) {
      modelSelect.value = newModels[0];
      updateAgent(pattern, index, 'acModel', newModels[0]);
    }
  });

  // Event listeners for other fields
  card.querySelectorAll('input, select, textarea').forEach(input => {
    if (!input.classList.contains('provider-select')) {  // Provider already handled above
      input.addEventListener('change', (e) => {
        const field = e.target.dataset.field;
        const pattern = e.target.dataset.pattern;
        const index = parseInt(e.target.dataset.index);
        updateAgent(pattern, index, field, e.target.value);
      });
    }
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

  console.log(`[${pattern}] Generated Mermaid code:`);
  console.log(mermaidCode);

  // Set the mermaid code as text content
  container.textContent = mermaidCode;
  container.removeAttribute('data-processed');

  // Render with Mermaid
  try {
    mermaid.run({ nodes: [container] }).catch(err => {
      console.error(`[${pattern}] Mermaid rendering error:`, err);
      container.innerHTML = `<div style="color: #ff0000; padding: 1rem;">Mermaid rendering error: ${err.message}</div>`;
    });
  } catch (err) {
    console.error(`[${pattern}] Mermaid error:`, err);
    container.innerHTML = `<div style="color: #ff0000; padding: 1rem;">Error: ${err.message}</div>`;
  }
}

// DAG Generation Functions
function generateSequentialDAG(agents) {
  let code = 'flowchart TD\n';

  if (agents.length === 0) return code;

  code += `  Start([Input])\n`;

  for (let i = 0; i < agents.length; i++) {
    code += `  A${i}["${agents[i]}"]\n`;
  }

  code += `  End([Output])\n\n`;

  code += `  Start --> A0\n`;

  for (let i = 0; i < agents.length - 1; i++) {
    code += `  A${i} --> A${i + 1}\n`;
  }

  code += `  A${agents.length - 1} --> End\n`;
  return code;
}

function generateConcurrentDAG(agents, aggregation) {
  let code = 'flowchart TD\n';

  if (agents.length === 0) return code;

  const aggMethod = aggregation.charAt(0).toUpperCase() + aggregation.slice(1);

  // Define nodes
  code += '  Start([Input])\n';
  code += '  Broadcast{Broadcast}\n';

  agents.forEach((agent, i) => {
    code += `  A${i}["${agent}"]\n`;
  });

  code += `  Aggregate["${aggMethod}"]\n`;
  code += '  End([Output])\n\n';

  // Define connections
  code += '  Start --> Broadcast\n';

  agents.forEach((agent, i) => {
    code += `  Broadcast --> A${i}\n`;
  });

  agents.forEach((agent, i) => {
    code += `  A${i} --> Aggregate\n`;
  });

  code += '  Aggregate --> End\n';
  return code;
}

function generateGroupChatDAG(agents, rounds) {
  let code = 'flowchart TD\n';

  if (agents.length === 0) return code;

  const maxRoundsToShow = Math.min(rounds, 3);

  // Define nodes
  code += '  Start([Input])\n';

  for (let r = 1; r <= maxRoundsToShow; r++) {
    code += `  Round${r}["Round ${r}"]\n`;
    agents.forEach((agent, i) => {
      code += `  R${r}A${i}["${agent}"]\n`;
    });
  }

  if (rounds > 3) {
    code += `  More["... ${rounds - 3} more"]\n`;
  }

  code += '  Consensus["Consensus"]\n';
  code += '  End([Output])\n\n';

  // Define connections
  code += '  Start --> Round1\n';

  for (let r = 1; r <= maxRoundsToShow; r++) {
    agents.forEach((agent, i) => {
      code += `  Round${r} --> R${r}A${i}\n`;
    });

    if (r < maxRoundsToShow) {
      agents.forEach((agent, i) => {
        code += `  R${r}A${i} --> Round${r + 1}\n`;
      });
    }
  }

  if (rounds > 3) {
    code += `  R3A0 -.-> More\n`;
    code += '  More -.-> Consensus\n';
  } else {
    agents.forEach((agent, i) => {
      code += `  R${maxRoundsToShow}A${i} --> Consensus\n`;
    });
  }

  code += '  Consensus --> End\n';
  return code;
}

function generateHandoffDAG(agents) {
  let code = 'flowchart TD\n';

  if (agents.length === 0) return code;

  // Define nodes
  code += '  Start([Input])\n';

  for (let i = 0; i < agents.length; i++) {
    code += `  A${i}["${agents[i]}"]\n`;
  }

  code += '  End([Output])\n\n';

  // Define connections
  code += '  Start --> A0\n';

  for (let i = 0; i < agents.length - 1; i++) {
    code += `  A${i} -.->|handoff| A${i + 1}\n`;
  }

  code += `  A${agents.length - 1} --> End\n`;
  return code;
}

function generateMagenticDAG(agents) {
  let code = 'flowchart TD\n';

  if (agents.length === 0) return code;

  // Define nodes
  code += '  Start([Input])\n';
  code += `  Manager["${agents[0]}"]\n`;

  for (let i = 1; i < agents.length; i++) {
    code += `  W${i}["${agents[i]}"]\n`;
  }

  code += '  End([Output])\n\n';

  // Define connections
  code += '  Start --> Manager\n';

  for (let i = 1; i < agents.length; i++) {
    code += `  Manager -->|task| W${i}\n`;
  }

  for (let i = 1; i < agents.length; i++) {
    code += `  W${i} -->|result| Manager\n`;
  }

  code += '  Manager --> End\n';
  return code;
}

// Execute All Patterns
async function executeAllPatterns() {
  console.log('='.repeat(60));
  console.log('EXECUTE ALL PATTERNS - START');
  console.log('='.repeat(60));

  const rootPrompt = document.getElementById('root-prompt').value.trim();

  if (!rootPrompt) {
    console.warn('No root prompt provided');
    showError('Please enter a root prompt');
    return;
  }

  console.log('Root prompt:', rootPrompt);
  console.log('Patterns to execute:', Object.keys(state.patterns));

  // Disable execute button
  const executeBtn = document.getElementById('execute-all');
  executeBtn.disabled = true;

  // Clear previous results
  console.log('Clearing previous results...');
  Object.keys(state.patterns).forEach(pattern => {
    state.patterns[pattern].logs = [];
    state.patterns[pattern].result = null;
    updatePatternStatus(pattern, 'ready');
    clearLog(pattern);
    clearResult(pattern);
  });

  try {
    console.log('Starting parallel execution of all patterns...');

    // Execute all patterns in parallel
    const promises = Object.keys(state.patterns).map(async (pattern) => {
      console.log(`[${pattern}] Marking as running...`);
      updatePatternStatus(pattern, 'running');

      try {
        const result = await executePattern(pattern, rootPrompt);
        console.log(`[${pattern}] ✅ Success`);
        updatePatternStatus(pattern, 'complete');
        setResult(pattern, result);
      } catch (error) {
        console.error(`[${pattern}] ❌ Failed:`, error);
        updatePatternStatus(pattern, 'error');
        setResult(pattern, { error: error.message });
      }
    });

    await Promise.all(promises);
    console.log('All patterns completed');
  } catch (error) {
    console.error('Fatal error during execution:', error);
    showError('Execution failed: ' + error.message);
  } finally {
    executeBtn.disabled = false;
    console.log('='.repeat(60));
    console.log('EXECUTE ALL PATTERNS - END');
    console.log('='.repeat(60));
  }
}

// Execute Individual Pattern
async function executePattern(patternName, input) {
  console.log(`[${patternName}] Starting execution...`);
  const pattern = state.patterns[patternName];

  // Map pattern name to backend Pattern type
  let patternType;
  switch (patternName) {
    case 'sequential':
      patternType = 'Sequential';
      console.log(`[${patternName}] Pattern type: Sequential`);
      break;
    case 'concurrent':
      const aggMethod = pattern.aggregation.charAt(0).toUpperCase() + pattern.aggregation.slice(1);
      patternType = { type: 'Concurrent', strategy: aggMethod };
      console.log(`[${patternName}] Pattern type: Concurrent ${aggMethod}`);
      break;
    case 'groupchat':
      patternType = { type: 'GroupChat', maxRounds: pattern.rounds };
      console.log(`[${patternName}] Pattern type: GroupChat with ${pattern.rounds} rounds`);
      break;
    case 'handoff':
      patternType = { type: 'Handoff', maxHops: pattern.maxHops };
      console.log(`[${patternName}] Pattern type: Handoff with max ${pattern.maxHops} hops`);
      break;
    case 'magentic':
      patternType = { type: 'Magentic', maxIterations: pattern.maxIterations };
      console.log(`[${patternName}] Pattern type: Magentic with max ${pattern.maxIterations} iterations`);
      break;
    default:
      throw new Error(`Unknown pattern: ${patternName}`);
  }

  // Build request body for /api/execute endpoint
  const requestBody = {
    erAgents: pattern.agents,
    erPattern: patternType,
    erInput: input
  };

  console.log(`[${patternName}] Request body:`, JSON.stringify(requestBody, null, 2));
  console.log(`[${patternName}] Agents:`, pattern.agents.map(a => `${a.acId} (${a.acProvider}/${a.acModel})`).join(', '));
  addLog(patternName, `📤 Sending request to backend with ${pattern.agents.length} agent(s)...`);
  pattern.agents.forEach((agent, i) => {
    addLog(patternName, `   Agent ${i + 1}: ${agent.acId} using ${agent.acProvider}/${agent.acModel}`);
  });

  try {
    const response = await fetch('/api/execute', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    });

    console.log(`[${patternName}] Response status: ${response.status} ${response.statusText}`);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`[${patternName}] Error response:`, errorText);
      addLog(patternName, `❌ HTTP ${response.status}: ${response.statusText}`);
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();
    console.log(`[${patternName}] Result received:`, result);

    // Check for backend error
    if (result.exError) {
      console.error(`[${patternName}] Backend error:`, result.exError);
      addLog(patternName, `❌ Backend error: ${result.exError}`);
      throw new Error(result.exError);
    }

    addLog(patternName, `✅ Execution completed in ${result.exDuration.toFixed(2)}s`);

    // Process trace events
    if (result.exTrace && result.exTrace.length > 0) {
      console.log(`[${patternName}] Processing ${result.exTrace.length} trace events`);
      addLog(patternName, `📊 Processing ${result.exTrace.length} trace events...`);
      result.exTrace.forEach((event, idx) => {
        console.log(`[${patternName}] Trace event ${idx + 1}:`, event);
        addLog(patternName, formatEvent(event));
      });
    } else {
      console.log(`[${patternName}] No trace events`);
      addLog(patternName, `ℹ️ No trace events generated`);
    }

    return result;
  } catch (error) {
    console.error(`[${patternName}] Execution failed:`, error);
    addLog(patternName, `❌ Execution failed: ${error.message}`);
    throw error;
  }
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

    // Check if this is an AgentCompleted event with output to render
    if (message.AgentCompleted && message.AgentCompleted[1]) {
      const agentId = message.AgentCompleted[0];
      const output = message.AgentCompleted[1];

      // Create header and markdown content
      const header = document.createElement('div');
      header.textContent = `✓ Agent ${agentId} completed`;
      header.style.marginBottom = '0.5rem';
      header.style.fontWeight = '600';

      const markdownDiv = document.createElement('div');
      markdownDiv.className = 'log-markdown';
      markdownDiv.innerHTML = marked.parse(output);

      logEntry.appendChild(header);
      logEntry.appendChild(markdownDiv);
    } else {
      logEntry.textContent = formatEventText(message);
    }
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
    resultContainer.innerHTML = `
      <div class="result-header error">
        <span class="result-badge">ERROR</span>
      </div>
      <div class="result-content">${escapeHtml(errorMsg)}</div>
    `;
  } else {
    resultContainer.classList.remove('result-error');
    const output = result.exOutput || result;
    const duration = result.exDuration || 0;
    const wordCount = output.split(/\s+/).length;
    const charCount = output.length;

    // Render output as markdown
    const renderedMarkdown = marked.parse(output);

    resultContainer.innerHTML = `
      <div class="result-header">
        <span class="result-badge success">SUCCESS</span>
        <span class="result-stats">
          ⏱️ ${duration.toFixed(2)}s |
          📝 ${wordCount} words |
          🔤 ${charCount} chars
        </span>
      </div>
      <div class="result-content result-markdown">${renderedMarkdown}</div>
    `;
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
