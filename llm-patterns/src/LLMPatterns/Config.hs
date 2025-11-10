{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}

module LLMPatterns.Config
  ( OrchestratorConfig(..)
  , loadOrchestrator
  , loadConfig
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent
import LLMPatterns.Orchestrator
import Data.Yaml (decodeFileEither, prettyPrintParseException, FromJSON)
import qualified Data.Text as T
import GHC.Generics (Generic)

-- | Configuration file structure
data OrchestratorConfig = OrchestratorConfig
  { ocAgents :: [AgentConfig]
  , ocPattern :: Pattern
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON)

-- | Load orchestrator from YAML file
-- More idiomatic: proper error handling, pure/IO separation
loadOrchestrator :: FilePath -> IO (Either OrchestrationError Orchestrator)
loadOrchestrator path = do
  configResult <- loadConfig path
  case configResult of
    Left err -> pure $ Left err
    Right config -> buildOrchestrator config

-- | Load configuration file (pure YAML parsing)
loadConfig :: FilePath -> IO (Either OrchestrationError OrchestratorConfig)
loadConfig path = do
  result <- decodeFileEither path
  pure $ case result of
    Left parseErr ->
      Left $ ConfigurationError $ T.pack $ prettyPrintParseException parseErr
    Right config ->
      Right config

-- | Build orchestrator from configuration
buildOrchestrator :: OrchestratorConfig -> IO (Either OrchestrationError Orchestrator)
buildOrchestrator OrchestratorConfig{..} = do
  agentResults <- mapM buildAgentFromConfig ocAgents

  -- Collect any errors
  let (errors, agents) = partitionEithers agentResults

  case errors of
    (err:_) -> pure $ Left err  -- Return first error
    [] -> pure $ Right $ withPattern ocPattern (new agents)
  where
    -- Build agent from configuration
    buildAgentFromConfig :: AgentConfig -> IO (Either OrchestrationError Agent)
    buildAgentFromConfig AgentConfig{..} =
      case fromConfig (AgentConfig acId acProvider acModel acSystemPrompt) of
        Left err -> pure $ Left err
        Right agentIO -> Right <$> agentIO

-- | Partition Either into lefts and rights (like Data.Either but manual)
partitionEithers :: [Either a b] -> ([a], [b])
partitionEithers = foldr (either left right) ([], [])
  where
    left  a (ls, rs) = (a:ls, rs)
    right b (ls, rs) = (ls, b:rs)
