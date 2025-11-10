{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}

-- | Stub module for Langchain LLM Core
-- This is a minimal implementation for compilation and testing
module Langchain.LLM.Core
  ( LLM(..)
  , LLMParams
  , Message(..)
  , Role(..)
  , MessageData(..)
  , chat
  , defaultMessageData
  -- Re-export specific models for compatibility
  , OllamaModel(..)
  , OpenAIModel(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)

-- | Role in a conversation
data Role = System | User | Assistant
  deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Message metadata
data MessageData = MessageData
  deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Default message metadata
defaultMessageData :: MessageData
defaultMessageData = MessageData

-- | Chat message
data Message = Message
  { msgRole :: Role
  , msgContent :: Text
  , msgData :: MessageData
  } deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | LLM parameters (stub)
data LLMParams m = LLMParams
  deriving stock (Eq, Show, Generic)

-- | Ollama model configuration
data OllamaModel = OllamaModel
  { ollamaModelName :: Text
  , ollamaOptions :: [Text]
  } deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | OpenAI model configuration
data OpenAIModel = OpenAIModel
  { openaiModelName :: Text
  , openaiApiKey :: Maybe Text
  , openaiOptions :: [Text]
  } deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | LLM typeclass
class LLM m where
  -- | Chat with the model
  chat :: m -> [Message] -> Maybe (LLMParams m) -> IO (Either String Text)

-- | Ollama instance (stub implementation for testing)
instance LLM OllamaModel where
  chat model messages _params = do
    -- Stub implementation: just echo the last user message
    let lastUserMsg = reverse [ msgContent msg | msg <- messages, msgRole msg == User ]
    case lastUserMsg of
      (msg:_) -> pure $ Right $ "Ollama (" <> ollamaModelName model <> ") response to: " <> msg
      [] -> pure $ Left "No user message found"

-- | OpenAI instance (stub implementation for testing)
instance LLM OpenAIModel where
  chat model messages _params = do
    -- Stub implementation: just echo the last user message
    let lastUserMsg = reverse [ msgContent msg | msg <- messages, msgRole msg == User ]
    case lastUserMsg of
      (msg:_) -> pure $ Right $ "OpenAI (" <> openaiModelName model <> ") response to: " <> msg
      [] -> pure $ Left "No user message found"
