{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}

{-# LANGUAE DeriveAnyClass #-}

module LLMPatterns.Types where

import Control.Monad.Except (ExceptT)
import Control.Monad.Reader (ReaderT)
import Control.Monad.State (StateT, get, modify, put)

-- import Data.Aeson (FromJSON, ToJSON, object, (.=))
import Data.Aeson (FromJSON (..), ToJSON (..), Value (..), object, (.:), (.=))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time (NominalDiffTime)
import GHC.Generics (Generic)

-- | Agent identifier with newtype safety
newtype AgentId = AgentId {unAgentId :: Text}
    deriving stock (Eq, Ord, Show, Generic)
    deriving newtype (FromJSON, ToJSON)

-- \| Proper error type instead of String
data OrchestrationError
    = AgentExecutionError AgentId Text
    | ConfigurationError Text
    | PatternError Text
    | HandoffError AgentId AgentId Text -- from, to, reason
    | MaxIterationsExceeded Int
    | NoAgentsAvailable
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

-- | Execution result with proper error handling
data PatternResult = PatternResult
    { prOutput :: Text
    , prTrace :: [TraceEvent]
    , prDuration :: NominalDiffTime
    , prTokens :: Maybe Int
    }
    deriving stock (Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

-- | Execution trace event
data TraceEvent
    = AgentStarted AgentId
    | AgentCompleted AgentId Text
    | AgentFailed AgentId Text
    | HandoffOccurred AgentId AgentId Text
    | TaskCreated Text
    | TaskCompleted Text
    | RoundStarted Int
    | RoundCompleted Int
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

-- | Aggregation strategy with clear semantics
data AggregationStrategy
    = Consensus -- Use first agent's output (simplified)
    | Vote -- Most common output
    | Combine -- Concatenate all outputs
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

-- | GADT for type-safe pattern configuration
data Pattern where
    Sequential :: Pattern
    Concurrent :: AggregationStrategy -> Pattern
    GroupChat :: Int -> Pattern -- max rounds
    Handoff :: Int -> Pattern -- max hops
    Magentic :: Int -> Pattern -- max iterations

deriving instance Show Pattern

deriving instance Eq Pattern

-- Manual JSON instances for GADT
instance FromJSON Pattern where
    parseJSON = \case
        String "Sequential" -> pure Sequential
        v -> fail $ "Unknown pattern: " ++ show v

instance ToJSON Pattern where
    toJSON Sequential = "Sequential"
    toJSON (Concurrent s) = object ["type" .= ("Concurrent" :: Text), "strategy" .= s]
    toJSON (GroupChat n) = object ["type" .= ("GroupChat" :: Text), "maxRounds" .= n]
    toJSON (Handoff n) = object ["type" .= ("Handoff" :: Text), "maxHops" .= n]
    toJSON (Magentic n) = object ["type" .= ("Magentic" :: Text), "maxIterations" .= n]

{- | Orchestration monad using MTL style
This eliminates the need for manual error threading
-}
type OrchestrationM = ExceptT OrchestrationError (StateT ExecutionState IO)

-- | Execution state for stateful patterns
data ExecutionState = ExecutionState
    { esTrace :: [TraceEvent]
    , esVisits :: Map.Map AgentId Int
    , esConversationHistory :: [Text]
    }
    deriving stock (Show, Generic)

-- | Initial execution state
initialState :: ExecutionState
initialState =
    ExecutionState
        { esTrace = []
        , esVisits = mempty
        , esConversationHistory = []
        }

-- | Add trace event helper
addTrace :: TraceEvent -> OrchestrationM ()
addTrace event = modify $ \s -> s{esTrace = event : esTrace s}

-- | Record agent visit
recordVisit :: AgentId -> OrchestrationM Int
recordVisit aid = do
    s <- get
    let visits = Map.findWithDefault 0 aid (esVisits s)
        newVisits = visits + 1
    put $ s{esVisits = Map.insert aid newVisits (esVisits s)}
    pure newVisits
