{-# LANGUAGE RecordWildCards #-}

module LLMPatterns.Patterns.GroupChat
  ( executeGroupChat
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import Data.Text (Text)
import qualified Data.Text as T
import Control.Monad.Except (runExceptT)
import Control.Monad.State (runStateT, modify, get)
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import Data.List (cycle)

-- | Execute group chat pattern with round-robin agent selection
-- More idiomatic: uses cycle for infinite agent rotation, proper recursion
executeGroupChat
  :: Int
  -> [Agent]
  -> Text
  -> IO (Either OrchestrationError PatternResult)
executeGroupChat maxRounds agents input
  | null agents = pure $ Left NoAgentsAvailable
  | maxRounds <= 0 = pure $ Left $ PatternError "Max rounds must be positive"
  | otherwise = do
      start <- getCurrentTime

      result <- runStateT (runExceptT $ runChat 0 (cycle agents) [input]) initialState

      end <- getCurrentTime

      case result of
        (Left err, _) -> pure $ Left err
        (Right history, state) -> pure $ Right $ PatternResult
          { prOutput = lastOrInput history
          , prTrace = reverse $ esTrace state
          , prDuration = diffUTCTime end start
          , prTokens = Nothing
          }
  where
    -- Recursive chat implementation using tail recursion
    runChat :: Int -> [Agent] -> [Text] -> OrchestrationM [Text]
    runChat round _ history | round >= maxRounds = pure history
    runChat round (agent:restAgents) history = do
      -- Record round start
      modify $ \s -> s { esTrace = RoundStarted round : esTrace s }

      -- Check for consensus
      if hasConsensus (lastOrInput history)
        then pure history
        else do
          -- Build context from conversation history
          let context = T.unlines history

          -- Prompt current agent
          output <- promptAgent agent context

          -- Update conversation history
          let newHistory = history ++ [output]

          -- Record round completion
          modify $ \s -> s { esTrace = RoundCompleted round : esTrace s }

          -- Continue with next round
          runChat (round + 1) restAgents newHistory
    runChat _ [] _ = pure []  -- Should never happen due to cycle

    -- Safe head with default
    lastOrInput :: [Text] -> Text
    lastOrInput [] = input
    lastOrInput xs = last xs

    -- Check if consensus has been reached
    hasConsensus :: Text -> Bool
    hasConsensus msg = "CONSENSUS_REACHED" `T.isInfixOf` T.toUpper msg
