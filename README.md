# Haskell LLM Orchestration Patterns

A complete Haskell implementation demonstrating idiomatic patterns for orchestrating multiple LLM agents.

## 🎯 Project Goals

This project showcases:

1. **Idiomatic Haskell** - Leveraging the language's strengths
2. **Type Safety** - Compile-time guarantees for pattern correctness
3. **Functional Design** - Pure functions, immutable data, composability
4. **Modern Web Stack** - Type-safe APIs with Servant

## 📦 Components

### [`llm-patterns/`](llm-patterns/) - Core Library

Composable orchestration patterns for LLMs:

- **Sequential** - Chain agents together
- **Concurrent** - Run agents in parallel with aggregation
- **Group Chat** - Multi-agent conversation
- **Handoff** - Dynamic agent routing
- **Magentic** - Task decomposition with manager/workers

**Key Features:**
- GADTs for type-safe patterns
- MTL-style monad transformers
- Proper error ADT (no String errors!)
- Rank-N types (no existential types needed!)
- Pure/IO separation

### [`llm-patterns-ui/`](llm-patterns-ui/) - Web Application

Interactive UI for pattern demonstration:

- Configure multiple agents
- Execute any pattern
- Compare all patterns side-by-side
- Real-time execution visualization
- WebSocket streaming

**Stack:**
- Servant (type-safe API)
- WebSockets
- Modern vanilla JavaScript
- Responsive CSS

## 🚀 Quick Start

### Prerequisites

- GHC 9.2+
- Cabal 3.0+
- Ollama running locally (or OpenAI API key)

### One-Command Setup (Recommended)

The easiest way to build, test, and launch the UI:

```bash
./build-and-run.sh
```

This script will:
1. Pull latest changes from git
2. Clean and build all projects
3. Run all tests
4. Launch the UI on http://localhost:8080 (if tests pass)

### Manual Build

```bash
# Build everything
cabal build all

# Build library only
cabal build llm-patterns

# Build UI
cabal build llm-patterns-ui

# Run tests
cabal test
```

### Run Examples

```bash
# Basic usage
cabal run basic-usage

# YAML configuration
cabal run yaml-config

# Pattern comparison
cabal run pattern-comparison
```

### Run Web UI

```bash
cabal run llm-patterns-ui
```

Then open: http://localhost:8080

## 📚 Documentation

See individual README files:

- [llm-patterns README](llm-patterns/README.md) - Library documentation
- [llm-patterns-ui README](llm-patterns-ui/README.md) - UI documentation

## 🎨 Idiomatic Haskell Features

This project demonstrates several advanced Haskell idioms:

### 1. GADTs for Type-Safe Patterns

```haskell
data Pattern where
  Sequential :: Pattern
  Concurrent :: AggregationStrategy -> Pattern
  GroupChat :: Int -> Pattern
  -- ...
```

### 2. MTL-Style Monad Transformers

```haskell
type OrchestrationM = ExceptT OrchestrationError (StateT ExecutionState IO)
```

No manual error threading or state passing!

### 3. Proper Error Types

```haskell
data OrchestrationError
  = AgentExecutionError AgentId Text
  | ConfigurationError Text
  | PatternError Text
  -- ...
```

### 4. Rank-N Types Instead of Existentials

```haskell
-- Instead of existential Agent wrapper:
mkAgent :: forall m. LLM m => AgentId -> m -> Text -> Agent
```

### 5. Smart Constructors

```haskell
new :: [Agent] -> Orchestrator
withPattern :: Pattern -> Orchestrator -> Orchestrator
```

### 6. Type-Safe Web API

```haskell
type API =
       "api" :> "execute" :> ReqBody '[JSON] ExecuteRequest :> Post '[JSON] ExecuteResponse
  :<|> "api" :> "compare" :> ReqBody '[JSON] CompareRequest :> Post '[JSON] CompareResponse
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│           llm-patterns-ui               │
│  ┌────────────┐        ┌─────────────┐  │
│  │  Frontend  │◄──────►│  Servant    │  │
│  │  (JS/CSS)  │  HTTP  │  Server     │  │
│  └────────────┘        └──────┬──────┘  │
└────────────────────────────────┼─────────┘
                                 │
                                 ▼
                    ┌────────────────────┐
                    │   llm-patterns     │
                    │                    │
                    │  ┌──────────────┐  │
                    │  │ Orchestrator │  │
                    │  └──────┬───────┘  │
                    │         │          │
                    │    ┌────▼────┐     │
                    │    │ Patterns│     │
                    │    └────┬────┘     │
                    │         │          │
                    │    ┌────▼────┐     │
                    │    │ Agents  │     │
                    │    └────┬────┘     │
                    └─────────┼──────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │   langchain-hs   │
                    │                  │
                    │  LLM Abstraction │
                    └──────────────────┘
```

## 🔍 Pattern Details

### Sequential Pattern

```haskell
researcher -> writer -> editor
```

Each agent receives the previous agent's output.

### Concurrent Pattern

```haskell
    ┌─► agent1 ──┐
input──► agent2 ──┼─► aggregate
    └─► agent3 ──┘
```

All agents run in parallel, results aggregated.

### Group Chat Pattern

```haskell
agent1 ──► agent2 ──► agent3 ──► agent1 ...
  └────────────────────┘
       (until consensus)
```

Agents converse in rounds.

### Handoff Pattern

```haskell
agent1 ──HANDOFF──► agent2 ──HANDOFF──► agent3
```

Dynamic routing based on agent decisions.

### Magentic Pattern

```haskell
        Manager
          │
    ┌─────┼─────┐
    ▼     ▼     ▼
worker1 worker2 worker3
```

Task decomposition with delegation.

## 🤔 Why Haskell?

- **Type Safety** - Catch errors at compile time
- **Composability** - Easy to build complex patterns from simple ones
- **Immutability** - No accidental state mutations
- **Laziness** - Efficient handling of large data
- **Purity** - Easy to reason about and test

## 📝 License

MIT

## 🙏 Acknowledgments

Built on top of:
- `langchain-hs` - LLM abstraction layer
- `servant` - Type-safe web framework
- `async` - Concurrent programming
