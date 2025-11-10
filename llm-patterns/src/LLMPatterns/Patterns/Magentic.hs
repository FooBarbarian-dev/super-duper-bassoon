{-# LANGUAGE RecordWildCards #-}

module LLMPatterns.Patterns.Magentic
  ( executeMagentic
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import Data.Text (Text)
import qualified Data.Text as T
import Control.Monad.Except (runExceptT, throwError)
import Control.Monad.State (runStateT, modify)
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import qualified Data.Set as Set
import Data.List (find, cycle)

-- | Task ledger for tracking work
data TaskLedger = TaskLedger
  { tlTasks :: [Text]
  , tlCompleted :: Set.Set Text
  } deriving (Show, Eq)

-- | Execute magentic pattern with task decomposition
-- More idiomatic: uses Set for O(log n) membership checks, cycle for worker rotation
executeMagentic
  :: Int
  -> [Agent]
  -> Text
  -> IO (Either OrchestrationError PatternResult)
executeMagentic maxIter agents input
  | null agents = pure $ Left NoAgentsAvailable
  | maxIter <= 0 = pure $ Left $ PatternError "Max iterations must be positive"
  | otherwise = do
      start <- getCurrentTime

      let managerAgent = head agents
          workerAgents = if length agents > 1 then tail agents else [head agents]

      -- Manager builds task list
      ledger <- buildTaskLedger managerAgent input

      -- Execute task ledger with workers
      result <- runStateT (runExceptT $ executeLedger (cycle workerAgents) ledger 0) initialState

      end <- getCurrentTime

      case result of
        (Left err, _) -> pure $ Left err
        (Right finalMsg, state) -> pure $ Right $ PatternResult
          { prOutput = finalMsg
          , prTrace = reverse $ esTrace state
          , prDuration = diffUTCTime end start
          , prTokens = Nothing
          }
  where
    -- Build initial task ledger using manager agent
    buildTaskLedger :: Agent -> Text -> IO TaskLedger
    buildTaskLedger manager inputGoal = do
      let prompt = T.unlines
            [ "Break down this goal into specific tasks:"
            , inputGoal
            , ""
            , "Format: one task per line."
            ]

      (result, _) <- runStateT (runExceptT $ promptAgent manager prompt) initialState

      case result of
        Right taskList ->
          let tasks = filter (not . T.null) $ T.lines taskList
          in pure $ TaskLedger tasks Set.empty
        Left _ ->
          -- Fallback: treat input as single task
          pure $ TaskLedger [inputGoal] Set.empty

    -- Execute task ledger recursively
    executeLedger :: [Agent] -> TaskLedger -> Int -> OrchestrationM Text
    executeLedger _ ledger iter
      | iter >= maxIter = throwError $ MaxIterationsExceeded maxIter
      | allTasksComplete ledger = pure "All tasks completed successfully"
      | otherwise = do
          case findNextTask ledger of
            Nothing -> pure "No remaining tasks"
            Just task -> do
              -- Record task creation
              modify $ \s -> s { esTrace = TaskCreated task : esTrace s }

              -- Get next worker
              let worker = head $ drop iter $ cycle workersList

              -- Execute task
              _ <- promptAgent worker task

              -- Mark complete
              modify $ \s -> s { esTrace = TaskCompleted task : esTrace s }

              let newLedger = ledger { tlCompleted = Set.insert task (tlCompleted ledger) }

              -- Continue with next iteration
              executeLedger (tail workersList) newLedger (iter + 1)
      where
        workersList = drop 1 agents

    -- Check if all tasks are complete
    allTasksComplete :: TaskLedger -> Bool
    allTasksComplete TaskLedger{..} =
      all (`Set.member` tlCompleted) tlTasks

    -- Find next incomplete task
    findNextTask :: TaskLedger -> Maybe Text
    findNextTask TaskLedger{..} =
      find (`Set.notMember` tlCompleted) tlTasks
