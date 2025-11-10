{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Example comparing different orchestration patterns

module Main where

import LLMPatterns
import Data.Text (Text)
import qualified Data.Text as T

main :: IO ()
main = do
  putStrLn "=== LLM Orchestration Pattern Comparison ===\n"

  -- Create agents
  let agent1 = mkOllamaAgent
        (AgentId "agent1")
        "llama3.2"
        "You are a helpful assistant."

      agent2 = mkOllamaAgent
        (AgentId "agent2")
        "llama3.2"
        "You are a helpful assistant."

      agents = [agent1, agent2]
      input = "What are the main benefits of functional programming?"

  -- Define patterns to compare
  let patterns =
        [ ("Sequential", Sequential)
        , ("Concurrent (Vote)", Concurrent Vote)
        , ("Concurrent (Combine)", Concurrent Combine)
        , ("Group Chat", GroupChat 3)
        ]

  putStrLn "Comparing patterns with 2 agents...\n"

  -- Execute each pattern
  results <- mapM (executePattern agents input) patterns

  -- Display results
  putStrLn "\n=== Comparison Results ===\n"
  mapM_ displayResult results

  where
    executePattern :: [Agent] -> Text -> (Text, Pattern) -> IO (Text, Either OrchestrationError PatternResult)
    executePattern agents input (name, pattern) = do
      putStrLn $ "Executing: " ++ T.unpack name ++ "..."
      let orchestrator = withPattern pattern (new agents)
      result <- execute orchestrator input
      pure (name, result)

    displayResult :: (Text, Either OrchestrationError PatternResult) -> IO ()
    displayResult (name, Left err) = do
      putStrLn $ "❌ " ++ T.unpack name
      putStrLn $ "   Error: " ++ show err
      putStrLn ""

    displayResult (name, Right PatternResult{..}) = do
      putStrLn $ "✅ " ++ T.unpack name
      putStrLn $ "   Duration: " ++ show prDuration
      putStrLn $ "   Events: " ++ show (length prTrace)
      putStrLn $ "   Output: " ++ T.unpack (T.take 100 prOutput) ++ "..."
      putStrLn ""
