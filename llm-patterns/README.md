# llm-patterns

Ergonomic orchestration patterns for Large Language Models in Haskell.

## Overview

This library provides composable patterns for coordinating multiple LLM agents, built on top of the `langchain-hs` framework. It demonstrates idiomatic Haskell design with:

- **Type-safe patterns** using GADTs
- **Monad transformers** (MTL style) for clean error handling
- **Proper error types** instead of stringly-typed errors
- **Functional composition** throughout
- **No partial functions** (no `head`, `tail`, etc.)

## Patterns

### Sequential
Agents process input one after another, threading output through the chain.

```haskell
let orchestrator = withPattern Sequential (new agents)
```

### Concurrent
All agents process input simultaneously, results are aggregated.

```haskell
let orchestrator = withPattern (Concurrent Vote) (new agents)
```

Aggregation strategies:
- `Consensus` - Use first agent's output (simplified)
- `Vote` - Most common output wins
- `Combine` - Concatenate all outputs

### Group Chat
Agents converse in rounds until consensus or max rounds reached.

```haskell
let orchestrator = withPattern (GroupChat 5) (new agents)
```

### Handoff
Agents can hand off work to other specialized agents.

```haskell
let orchestrator = withPattern (Handoff 10) (new agents)
```

Agents can signal handoff with: `HANDOFF: targetAgentId reason`

### Magentic
Task decomposition with manager/worker architecture.

```haskell
let orchestrator = withPattern (Magentic 10) (new agents)
```

First agent is the manager, rest are workers.

## Installation

```bash
cabal build llm-patterns
```

## Usage

### Basic Example

```haskell
import LLMPatterns

main :: IO ()
main = do
  let agent1 = mkOllamaAgent (AgentId "researcher") "llama3.2" "You are a researcher."
      agent2 = mkOllamaAgent (AgentId "writer") "llama3.2" "You are a writer."
      orchestrator = withPattern Sequential (new [agent1, agent2])

  result <- execute orchestrator "Write about Haskell"

  case result of
    Left err -> print err
    Right PatternResult{..} -> putStrLn prOutput
```

### YAML Configuration

```yaml
ocAgents:
  - acId: "agent1"
    acProvider: "ollama"
    acModel: "llama3.2"
    acSystemPrompt: "You are helpful."

ocPattern: "Sequential"
```

```haskell
result <- loadOrchestrator "config.yaml"
case result of
  Right orchestrator -> execute orchestrator "Hello"
  Left err -> print err
```

## Examples

See the `examples/` directory:

- `BasicUsage.hs` - Simple sequential pattern
- `YamlConfig.hs` - Load from YAML configuration
- `PatternComparison.hs` - Compare all patterns

## Architecture

### Idiomatic Haskell Features

1. **GADTs** for type-safe pattern definitions
2. **Monad transformers** (`ExceptT` + `StateT` + `IO`) for orchestration
3. **Proper error ADT** instead of `String` or `Either String`
4. **Smart constructors** for validation
5. **Rank-N types** instead of existential types for agents
6. **Pure/impure separation** - configuration parsing is separate from execution

### Why This Approach?

- **Type safety**: Patterns are type-checked at compile time
- **Composable**: Easy to extend with new patterns
- **Testable**: Pure functions where possible, IO isolated
- **Maintainable**: Clear separation of concerns
- **Idiomatic**: Uses Haskell's strengths, not fighting them

## License

MIT
