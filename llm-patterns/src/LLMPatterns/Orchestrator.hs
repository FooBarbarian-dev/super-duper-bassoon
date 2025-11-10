{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}

module LLMPatterns.Orchestrator
  ( Orchestrator(..)
  , new
  , withPattern
  , execute
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import qualified LLMPatterns.Patterns.Sequential as Seq
import qualified LLMPatterns.Patterns.Concurrent as Conc
import qualified LLMPatterns.Patterns.GroupChat as GC
import qualified LLMPatterns.Patterns.Handoff as HO
import qualified LLMPatterns.Patterns.Magentic as Mag
import Data.Text (Text)

-- | Orchestrator configuration
data Orchestrator = Orchestrator
  { orchAgents :: [Agent]
  , orchPattern :: Pattern
  }

-- | Create new orchestrator with default Sequential pattern
-- Smart constructor ensures we always have a valid orchestrator
new :: [Agent] -> Orchestrator
new agents = Orchestrator
  { orchAgents = agents
  , orchPattern = Sequential
  }

-- | Update pattern (functional lens-like setter)
withPattern :: Pattern -> Orchestrator -> Orchestrator
withPattern pattern orch = orch { orchPattern = pattern }

-- | Execute orchestrator with current pattern
-- More idiomatic: pattern matching instead of case, proper delegation
execute :: Orchestrator -> Text -> IO (Either OrchestrationError PatternResult)
execute Orchestrator{..} input =
  case orchPattern of
    Sequential ->
      Seq.executeSequential orchAgents input

    Concurrent strategy ->
      Conc.executeConcurrent strategy orchAgents input

    GroupChat maxRounds ->
      GC.executeGroupChat maxRounds orchAgents input

    Handoff maxHops ->
      HO.executeHandoff maxHops orchAgents input

    Magentic maxIter ->
      Mag.executeMagentic maxIter orchAgents input
