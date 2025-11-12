{-# LANGUAGE RecordWildCards #-}

module LLMPatterns.Patterns.Magentic
  ( executeMagentic
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import Data.Text (Text)
import qualified Data.Text as T
import Control.Monad.Except (runExceptT, throwError)
import Control.Monad.State (runStateT, modify, get)
import Control.Monad.IO.Class (liftIO)
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import qualified Data.Set as Set
import Data.List (find)
import Control.Concurrent.Async (mapConcurrently)

-- | Task ledger for tracking work
data TaskLedger = TaskLedger
  { tlTasks :: [Text]
  , tlCompleted :: Set.Set Text
  , tlResults :: [(Text, Text)]  -- (task, result) pairs
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
          in pure $ TaskLedger tasks Set.empty []
        Left _ ->
          -- Fallback: treat input as single task
          pure $ TaskLedger [inputGoal] Set.empty []

    -- Execute task ledger recursively with parallel execution
    executeLedger :: [Agent] -> TaskLedger -> Int -> OrchestrationM Text
    executeLedger workers ledger iter
      | allTasksComplete ledger =
          -- Aggregate all results
          let resultsText = T.unlines
                [ T.concat ["## ", task, "\n\n", result, "\n"]
                | (task, result) <- tlResults ledger
                ]
              summary = T.pack $ "# Task Completion Summary\n\n"
                     ++ "Completed " ++ show (length (tlTasks ledger)) ++ " tasks:\n\n"
          in pure $ summary <> resultsText
      | iter >= maxIter = throwError $ MaxIterationsExceeded maxIter
      | otherwise = do
          -- Collect all pending tasks for this batch
          let pendingTasks = filter (`Set.notMember` tlCompleted ledger) (tlTasks ledger)

          case pendingTasks of
            [] -> pure "No remaining tasks"
            tasks -> do
              -- Record task creation for all tasks in this batch
              mapM_ (\task -> modify $ \s -> s { esTrace = TaskCreated task : esTrace s }) tasks

              -- Assign workers to tasks (cycle through workers for load balancing)
              let taskWorkerPairs = zip tasks (cycle workers)

              -- Execute all tasks in parallel
              currentState <- get
              results <- liftIO $ mapConcurrently
                (\(task, worker) -> executeTaskWithWorker worker task)
                taskWorkerPairs

              -- Record task completion for all tasks
              mapM_ (\task -> modify $ \s -> s { esTrace = TaskCompleted task : esTrace s }) tasks

              -- Update ledger with all results
              let newLedger = ledger
                    { tlCompleted = Set.union (tlCompleted ledger) (Set.fromList tasks)
                    , tlResults = tlResults ledger ++ results
                    }

              -- Continue with next iteration if there are more tasks
              executeLedger workers newLedger (iter + 1)

    -- Execute a single task with a worker (used by parallel execution)
    executeTaskWithWorker :: Agent -> Text -> IO (Text, Text)
    executeTaskWithWorker worker task = do
      (result, _) <- runStateT (runExceptT $ promptAgent worker task) initialState
      case result of
        Right output -> pure (task, output)
        Left _ -> pure (task, "Task failed")

    -- Check if all tasks are complete
    allTasksComplete :: TaskLedger -> Bool
    allTasksComplete TaskLedger{..} =
      all (`Set.member` tlCompleted) tlTasks

    -- Find next incomplete task
    findNextTask :: TaskLedger -> Maybe Text
    findNextTask TaskLedger{..} =
      find (`Set.notMember` tlCompleted) tlTasks
