{-|
Module      : LLMPatterns
Description : Ergonomic orchestration patterns for LLMs in Haskell
License     : MIT
Maintainer  : you@example.com

This library provides composable orchestration patterns for Large Language Models,
built on top of the langchain-hs framework.

= Example Usage

@
import LLMPatterns

main :: IO ()
main = do
  -- Create agents
  let agent1 = mkOllamaAgent (AgentId "researcher") "llama3.2" "You are a researcher."
      agent2 = mkOllamaAgent (AgentId "writer") "llama3.2" "You are a writer."

  -- Build orchestrator
  let orchestrator = withPattern (GroupChat 5) (new [agent1, agent2])

  -- Execute
  result <- execute orchestrator "Write a short article about Haskell"

  case result of
    Left err -> print err
    Right PatternResult{..} -> putStrLn prOutput
@
-}

module LLMPatterns
  ( -- * Core Types
    Agent
  , AgentId(..)
  , Pattern(..)
  , PatternResult(..)
  , AggregationStrategy(..)
  , TraceEvent(..)
  , OrchestrationError(..)

    -- * Agent Construction
  , mkAgent
  , mkOllamaAgent
  , mkOpenAIAgent
  , mkClaudeAgent
  , AgentConfig(..)
  , fromConfig

    -- * Orchestrator
  , Orchestrator
  , new
  , withPattern
  , execute

    -- * Configuration
  , OrchestratorConfig(..)
  , loadOrchestrator
  , loadConfig
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import LLMPatterns.Orchestrator
import LLMPatterns.Config
