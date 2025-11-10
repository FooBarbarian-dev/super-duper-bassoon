{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}

module LLMPatterns.Agent
  ( Agent
  , AgentConfig(..)
  , mkAgent
  , promptAgent
  , mkOllamaAgent
  , mkOpenAIAgent
  , fromConfig
  ) where

import LLMPatterns.Types
import Langchain.LLM.Core
import Data.Text (Text)
import qualified Data.Text as T
import Control.Monad.Except (throwError)
import Control.Monad.IO.Class (liftIO)
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)

-- | Agent configuration that can be serialized
data AgentConfig = AgentConfig
  { acId :: AgentId
  , acProvider :: Text
  , acModel :: Text
  , acSystemPrompt :: Text
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Instead of existential types, use a function that captures the LLM behavior
-- This is more idiomatic - we abstract over the behavior, not the type
data Agent = Agent
  { agentId :: AgentId
  , agentPrompt :: Text -> IO (Either String Text)
  , agentSystemPrompt :: Text
  }

-- | Create agent from any LLM instance using rank-N types
-- This is more idiomatic than existential types
mkAgent :: forall m. LLM m => AgentId -> m -> Text -> Maybe (LLMParams m) -> Agent
mkAgent aid model sysPrompt params = Agent
  { agentId = aid
  , agentPrompt = \input -> do
      let messages =
            [ Message System sysPrompt defaultMessageData
            , Message User input defaultMessageData
            ]
      chat model messages params
  , agentSystemPrompt = sysPrompt
  }

-- | Prompt agent with proper error handling in OrchestrationM
promptAgent :: Agent -> Text -> OrchestrationM Text
promptAgent Agent{..} input = do
  addTrace (AgentStarted agentId)
  result <- liftIO $ agentPrompt input
  case result of
    Left err -> do
      let errText = T.pack err
      addTrace (AgentFailed agentId errText)
      throwError (AgentExecutionError agentId errText)
    Right output -> do
      addTrace (AgentCompleted agentId output)
      pure output

-- | Smart constructors for common providers
mkOllamaAgent :: AgentId -> Text -> Text -> Agent
mkOllamaAgent aid modelName prompt =
  mkAgent aid (OllamaModel modelName []) prompt Nothing

mkOpenAIAgent :: AgentId -> Text -> Text -> Agent
mkOpenAIAgent aid modelName prompt =
  mkAgent aid (OpenAIModel modelName Nothing []) prompt Nothing

-- | Build agent from configuration
-- This is a pure function that describes how to build an agent
fromConfig :: AgentConfig -> Either OrchestrationError (IO Agent)
fromConfig AgentConfig{..} = case acProvider of
  "ollama" -> Right $ pure $ mkOllamaAgent acId acModel acSystemPrompt
  "openai" -> Right $ pure $ mkOpenAIAgent acId acModel acSystemPrompt
  unknown -> Left $ ConfigurationError $ "Unknown provider: " <> unknown
