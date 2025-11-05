{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}

module LLMPatterns.Patterns.Concurrent
  ( executeConcurrent
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import Data.Text (Text)
import qualified Data.Text as T
import Control.Concurrent.Async (mapConcurrently)
import Control.Monad.Except (runExceptT)
import Control.Monad.State (runStateT)
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import Data.List (group, sort, maximumBy)
import Data.Ord (comparing)
import Data.Maybe (mapMaybe)

-- | Execute agents concurrently and aggregate results
-- More idiomatic: uses mapConcurrently, better aggregation strategies
executeConcurrent
  :: AggregationStrategy
  -> [Agent]
  -> Text
  -> IO (Either OrchestrationError PatternResult)
executeConcurrent strategy agents input = do
  start <- getCurrentTime

  -- Run all agents concurrently - each with its own state
  results <- mapConcurrently (executeAgent input) agents

  -- Collect successful outputs and all events
  let (outputs, allEvents) = partitionResults results

  -- Aggregate based on strategy
  case aggregateOutputs strategy outputs of
    Nothing -> pure $ Left $ PatternError "No outputs to aggregate"
    Just finalOutput -> do
      end <- getCurrentTime
      pure $ Right $ PatternResult
        { prOutput = finalOutput
        , prTrace = allEvents
        , prDuration = diffUTCTime end start
        , prTokens = Nothing
        }
  where
    -- Execute single agent and collect its trace
    executeAgent :: Text -> Agent -> IO (Either OrchestrationError (Text, [TraceEvent]))
    executeAgent inp agent = do
      (result, state) <- runStateT (runExceptT $ promptAgent agent inp) initialState
      case result of
        Left err -> pure $ Left err
        Right output -> pure $ Right (output, reverse $ esTrace state)

    -- Partition results into outputs and events
    partitionResults
      :: [Either OrchestrationError (Text, [TraceEvent])]
      -> ([Text], [TraceEvent])
    partitionResults results =
      let successes = mapMaybe (either (const Nothing) Just) results
          outputs = map fst successes
          events = concatMap snd successes
      in (outputs, events)

    -- Aggregate outputs based on strategy (pure function)
    aggregateOutputs :: AggregationStrategy -> [Text] -> Maybe Text
    aggregateOutputs _ [] = Nothing
    aggregateOutputs Consensus (x:_) = Just x  -- Take first (simplified consensus)
    aggregateOutputs Vote outputs =
      -- Group identical outputs, find most common
      let grouped = group . sort $ outputs
      in case grouped of
           [] -> Nothing
           gs -> Just . head $ maximumBy (comparing length) gs
    aggregateOutputs Combine outputs =
      Just $ T.intercalate "\n\n---\n\n" outputs
