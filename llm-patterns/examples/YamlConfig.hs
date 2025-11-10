{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Example demonstrating YAML configuration loading

module Main where

import LLMPatterns
import qualified Data.Text.IO as TIO
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs

  let configPath = case args of
        (path:_) -> path
        [] -> "examples/configs/example.yaml"

  putStrLn $ "Loading configuration from: " ++ configPath
  putStrLn ""

  -- Load orchestrator from YAML
  result <- loadOrchestrator configPath

  case result of
    Left err -> do
      putStrLn $ "Configuration error: " ++ show err

    Right orchestrator -> do
      putStrLn "✅ Configuration loaded successfully!"
      putStrLn "Executing orchestrator...\n"

      -- Execute with the loaded configuration
      execResult <- execute orchestrator "Analyze the market trends for renewable energy"

      case execResult of
        Left err ->
          putStrLn $ "Execution error: " ++ show err

        Right PatternResult{..} -> do
          putStrLn $ "=== Output (Duration: " ++ show prDuration ++ ") ===\n"
          TIO.putStrLn prOutput

          putStrLn "\n=== Execution Summary ==="
          putStrLn $ "Events: " ++ show (length prTrace)
          putStrLn "✅ Done!"
