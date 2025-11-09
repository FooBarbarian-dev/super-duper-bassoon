{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}

module API where

import Servant
import Servant.API.WebSocket (WebSocket)
import LLMPatterns
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics (Generic)

-- | Main API type
-- More idiomatic: clean type-level API definition
type API =
       "api" :> "execute" :> ReqBody '[JSON] ExecuteRequest :> Post '[JSON] ExecuteResponse
  :<|> "api" :> "compare" :> ReqBody '[JSON] CompareRequest :> Post '[JSON] CompareResponse
  :<|> "api" :> "ws" :> "execute" :> WebSocket
  :<|> Raw  -- Serve static files

-- | Request to execute a single pattern
data ExecuteRequest = ExecuteRequest
  { erAgents :: [AgentConfig]
  , erPattern :: Pattern
  , erInput :: Text
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Response from pattern execution
data ExecuteResponse = ExecuteResponse
  { exOutput :: Text
  , exTrace :: [TraceEvent]
  , exDuration :: Double
  , exError :: Maybe Text
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Request to compare all patterns
data CompareRequest = CompareRequest
  { crAgents :: [AgentConfig]
  , crInput :: Text
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Comparison response with results for each pattern
data CompareResponse = CompareResponse
  { cmpResults :: [(Text, ExecuteResponse)]
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Convert OrchestrationError to user-friendly message
errorToText :: OrchestrationError -> Text
errorToText (AgentExecutionError aid msg) = "Agent " <> unAgentId aid <> " failed: " <> msg
errorToText (ConfigurationError msg) = "Configuration error: " <> msg
errorToText (PatternError msg) = "Pattern error: " <> msg
errorToText (HandoffError from to msg) =
  "Handoff failed from " <> unAgentId from <> " to " <> unAgentId to <> ": " <> msg
errorToText (MaxIterationsExceeded n) = "Max iterations exceeded: " <> T.pack (show n)
errorToText NoAgentsAvailable = "No agents available"
