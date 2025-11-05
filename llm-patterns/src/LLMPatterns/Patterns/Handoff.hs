{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}

module LLMPatterns.Patterns.Handoff
  ( executeHandoff
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import Data.Text (Text)
import qualified Data.Text as T
import Control.Monad (when)
import Control.Monad.Except (runExceptT, throwError)
import Control.Monad.State (runStateT, get, modify)
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import qualified Data.Map.Strict as Map
import Data.Maybe (listToMaybe)

-- | Handoff decision from agent output
data HandoffDecision
  = Handle Text              -- Agent handles the request
  | Handoff AgentId Text     -- Handoff to another agent with reason

-- | Execute handoff pattern with agent routing
-- More idiomatic: uses Map for O(log n) lookups, safer recursion with visit tracking
executeHandoff
  :: Int
  -> [Agent]
  -> Text
  -> IO (Either OrchestrationError PatternResult)
executeHandoff maxHops agents input
  | null agents = pure $ Left NoAgentsAvailable
  | maxHops <= 0 = pure $ Left $ PatternError "Max hops must be positive"
  | otherwise = do
      start <- getCurrentTime

      -- Build agent lookup map for efficient access
      let agentMap = Map.fromList [(agentId a, a) | a <- agents]
          startAgentId = agentId $ head agents

      result <- runStateT (runExceptT $ runHandoffs maxHops agentMap startAgentId input) initialState

      end <- getCurrentTime

      case result of
        (Left err, _) -> pure $ Left err
        (Right finalOutput, state) -> pure $ Right $ PatternResult
          { prOutput = finalOutput
          , prTrace = reverse $ esTrace state
          , prDuration = diffUTCTime end start
          , prTokens = Nothing
          }
  where
    -- Recursive handoff execution with loop detection
    runHandoffs :: Int -> Map.Map AgentId Agent -> AgentId -> Text -> OrchestrationM Text
    runHandoffs hopsLeft agentMap currentId input
      | hopsLeft <= 0 = pure input  -- Max hops exceeded
      | otherwise = do
          -- Check visit count to prevent infinite loops
          visits <- recordVisit currentId
          when (visits > 2) $
            throwError $ PatternError $ "Agent " <> unAgentId currentId <> " visited too many times"

          -- Lookup current agent
          case Map.lookup currentId agentMap of
            Nothing -> throwError $ PatternError $ "Agent not found: " <> unAgentId currentId
            Just agent -> do
              -- Prompt agent
              output <- promptAgent agent input

              -- Parse decision from output
              case parseHandoffDecision output of
                Handle finalOutput ->
                  pure finalOutput
                Handoff nextId reason -> do
                  -- Record handoff
                  modify $ \s -> s { esTrace = HandoffOccurred currentId nextId reason : esTrace s }

                  -- Continue with next agent
                  runHandoffs (hopsLeft - 1) agentMap nextId output

    -- Parse agent output for handoff signals
    parseHandoffDecision :: Text -> HandoffDecision
    parseHandoffDecision output =
      case T.breakOn "HANDOFF:" output of
        (content, "") -> Handle content  -- No handoff signal found
        (_, rest) ->
          -- Extract next agent ID from "HANDOFF: agentId reason..."
          case T.words (T.strip $ T.drop 8 rest) of
            (nextAgentText:reasonWords) ->
              Handoff (AgentId nextAgentText) (T.unwords reasonWords)
            [] -> Handle output
