{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Basic usage example demonstrating the Sequential pattern

module Main where

import LLMPatterns
import Data.Text (Text)
import qualified Data.Text.IO as TIO

main :: IO ()
main = do
  putStrLn "=== Basic LLM Orchestration Pattern Example ===\n"

  -- Create agents with different roles
  let researcher = mkOllamaAgent
        (AgentId "researcher")
        "llama3.2"
        "You are a research assistant. Research the topic and provide key facts."

      writer = mkOllamaAgent
        (AgentId "writer")
        "llama3.2"
        "You are a writer. Take the research and write a concise article."

      editor = mkOllamaAgent
        (AgentId "editor")
        "llama3.2"
        "You are an editor. Polish the article and fix any issues."

  -- Build orchestrator with Sequential pattern
  let orchestrator = new [researcher, writer, editor]

  -- Execute
  putStrLn "Executing Sequential pattern with 3 agents...\n"
  result <- execute orchestrator "Write a short article about functional programming"

  case result of
    Left err -> do
      putStrLn $ "Error: " ++ show err

    Right PatternResult{..} -> do
      putStrLn $ "=== Final Output (after " ++ show prDuration ++ ") ===\n"
      TIO.putStrLn prOutput

      putStrLn "\n=== Execution Trace ==="
      mapM_ print prTrace

      putStrLn "\n✅ Execution completed successfully!"
