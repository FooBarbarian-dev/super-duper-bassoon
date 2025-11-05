# llm-patterns-ui

Web application for demonstrating and comparing LLM orchestration patterns.

## Overview

This is a web UI for the `llm-patterns` library, built with:

- **Servant** - Type-safe web API
- **WebSockets** - Real-time execution streaming
- **Modern CSS** - Clean, responsive interface
- **Vanilla JavaScript** - No framework dependencies

## Features

- 🎨 Configure multiple agents with different models and prompts
- 🔄 Execute any orchestration pattern
- 📊 Compare all patterns side-by-side
- 📈 Visualize execution traces
- ⚡ Real-time updates via WebSockets

## Installation

```bash
cabal build llm-patterns-ui
```

## Running

```bash
cabal run llm-patterns-ui
```

Or with custom port:

```bash
PORT=8080 cabal run llm-patterns-ui
```

Then open: http://localhost:3000

## Usage

1. **Configure Agents**
   - Click "Add Agent" to create agents
   - Set ID, provider (Ollama/OpenAI), model, and system prompt

2. **Select Pattern**
   - Choose from Sequential, Concurrent, Group Chat, Handoff, or Magentic
   - See pattern description update automatically

3. **Execute**
   - Enter your prompt
   - Click "Execute Pattern" for single execution
   - Click "Compare All Patterns" to run all patterns

4. **View Results**
   - See execution time and event count
   - View final output
   - Inspect execution trace

## API

### POST `/api/execute`

Execute a single pattern.

**Request:**
```json
{
  "erAgents": [
    {
      "acId": "agent1",
      "acProvider": "ollama",
      "acModel": "llama3.2",
      "acSystemPrompt": "You are helpful."
    }
  ],
  "erPattern": "Sequential",
  "erInput": "Hello"
}
```

**Response:**
```json
{
  "exOutput": "Response text",
  "exTrace": [...],
  "exDuration": 1.23,
  "exError": null
}
```

### POST `/api/compare`

Compare all patterns.

**Request:**
```json
{
  "crAgents": [...],
  "crInput": "Hello"
}
```

**Response:**
```json
{
  "cmpResults": [
    ["Sequential", {...}],
    ["Concurrent", {...}]
  ]
}
```

### WebSocket `/api/ws/execute`

Real-time execution with event streaming.

## Architecture

### Backend (Haskell + Servant)

- `API.hs` - Type-level API definition
- `Server.hs` - Request handlers
- `Main.hs` - Entry point

### Frontend

- `index.html` - Structure
- `styles.css` - Modern, responsive styling
- `app.js` - Agent management, API calls, visualization

## Development

The UI automatically serves static files from the `static/` directory.

To modify:

1. Edit files in `static/`
2. Rebuild and run: `cabal run llm-patterns-ui`
3. Refresh browser

## License

MIT
