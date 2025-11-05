{-# LANGUAGE RecordWildCards #-}

module LLMPatterns.Patterns.Sequential
  ( executeSequential
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import Data.Text (Text)
import Control.Monad (foldM)
import Control.Monad.Except (runExceptT)
import Control.Monad.State (runStateT, get)
import Data.Time.Clock (getCurrentTime, diffUTCTime)

-- | Execute agents sequentially, threading output through each
-- More idiomatic: uses foldM for composition, proper error handling
executeSequential :: [Agent] -> Text -> IO (Either OrchestrationError PatternResult)
executeSequential agents input = do
  start <- getCurrentTime

  result <- runOrchestration $ do
    -- Use foldM to thread the output through each agent
    -- This is more functional than manual recursion
    finalOutput <- foldM processAgent input agents
    pure finalOutput

  end <- getCurrentTime

  case result of
    Left err -> pure $ Left err
    Right (output, state) -> pure $ Right $ PatternResult
      { prOutput = output
      , prTrace = reverse $ esTrace state  -- Reverse to get chronological order
      , prDuration = diffUTCTime end start
      , prTokens = Nothing
      }
  where
    -- Run the orchestration monad - more efficient, runs action only once
    runOrchestration :: OrchestrationM a -> IO (Either OrchestrationError (a, ExecutionState))
    runOrchestration action = do
      (result, finalState) <- runStateT (runExceptT action) initialState
      case result of
        Left err -> pure $ Left err
        Right val -> pure $ Right (val, finalState)

    -- Process a single agent
    processAgent :: Text -> Agent -> OrchestrationM Text
    processAgent currentInput agent = promptAgent agent currentInput
