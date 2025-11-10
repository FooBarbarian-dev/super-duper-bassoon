{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}

module Server
  ( server
  , runServer
  ) where

import Servant
import API
import LLMPatterns
import qualified Data.Text as T
import Control.Monad.IO.Class (liftIO)
import Data.Time.Clock (nominalDiffTimeToSeconds)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Application.Static (defaultFileServerSettings, serveDirectoryWith)
import WaiAppStatic.Types (ssIndices, ssMaxAge, unsafeToPiece, MaxAge(..))
import Network.WebSockets (Connection, receiveData, sendTextData, sendClose)
import Data.Aeson (encode, decode, object, (.=))
import Data.Traversable (for)

-- | Server implementation using more idiomatic handler composition
server :: Server API
server = executeHandler
    :<|> compareHandler
    :<|> wsHandler
    :<|> serveStatic
  where
    serveStatic = serveDirectoryWith settings
      where
        settings = (defaultFileServerSettings "static")
          { ssIndices = [unsafeToPiece "index.html"]
          , ssMaxAge = MaxAgeSeconds 3600
          }

-- | Execute a single pattern
-- More idiomatic: uses traverse and ExceptT-style error handling
executeHandler :: ExecuteRequest -> Handler ExecuteResponse
executeHandler ExecuteRequest{..} = liftIO $ do
  -- Build agents using traverse (combines mapM + sequence idiomatically)
  agentResults <- traverse buildAgentIO erAgents

  case agentResults of
    Left err -> pure $ errorResponse err
    Right agents -> do
      -- Create orchestrator and execute
      let orchestrator = withPattern erPattern (new agents)
      result <- execute orchestrator erInput

      pure $ either errorResponse successResponse result

-- | Compare all patterns
-- More idiomatic: uses traverse and for with proper error handling
compareHandler :: CompareRequest -> Handler CompareResponse
compareHandler CompareRequest{..} = liftIO $ do
  -- Build agents using traverse
  agentResults <- traverse buildAgentIO crAgents

  case agentResults of
    Left err -> pure $ CompareResponse [("error", errorResponse err)]
    Right agents -> do
      -- Define all patterns to compare
      let patterns =
            [ ("Sequential", Sequential)
            , ("Concurrent (Vote)", Concurrent Vote)
            , ("Concurrent (Consensus)", Concurrent Consensus)
            , ("Concurrent (Combine)", Concurrent Combine)
            , ("Group Chat (5 rounds)", GroupChat 5)
            , ("Handoff (10 hops)", Handoff 10)
            , ("Magentic (10 iterations)", Magentic 10)
            ]

      -- Execute each pattern using for (flipped traverse)
      results <- for patterns $ executePattern agents
      pure $ CompareResponse results
  where
    executePattern :: [Agent] -> (T.Text, Pattern) -> IO (T.Text, ExecuteResponse)
    executePattern agents (name, pattern) = do
      let orchestrator = withPattern pattern (new agents)
      result <- execute orchestrator crInput
      pure (name, either errorResponse successResponse result)

-- | WebSocket handler for real-time execution
-- More idiomatic: uses traverse and proper functional composition
wsHandler :: Connection -> Handler ()
wsHandler conn = liftIO $ do
  -- Receive request
  msg <- receiveData conn

  case decode msg of
    Nothing -> sendClose conn ("Invalid request" :: T.Text)
    Just ExecuteRequest{..} -> do
      -- Build agents using traverse
      agentResults <- traverse buildAgentIO erAgents

      case agentResults of
        Left err -> sendTextData conn $ encode $ errorResponse err
        Right agents -> do
          -- Execute and stream events
          let orchestrator = withPattern erPattern (new agents)
          result <- execute orchestrator erInput

          case result of
            Left err ->
              sendTextData conn $ encode $ errorResponse err
            Right pr -> do
              -- Send trace events one by one with traverse_
              traverse_ (sendTraceEvent conn) (prTrace pr)

              -- Send final result
              sendTextData conn $ encode $ object
                [ "type" .= ("complete" :: T.Text)
                , "output" .= prOutput pr
                , "duration" .= (realToFrac $ nominalDiffTimeToSeconds $ prDuration pr :: Double)
                ]

-- | Build agent from configuration with error handling
buildAgentIO :: AgentConfig -> IO (Either OrchestrationError Agent)
buildAgentIO config = do
  case fromConfig config of
    Left err -> pure $ Left err
    Right agentIO -> Right <$> agentIO

-- | Convert PatternResult to ExecuteResponse
successResponse :: PatternResult -> ExecuteResponse
successResponse PatternResult{..} = ExecuteResponse
  { exOutput = prOutput
  , exTrace = prTrace
  , exDuration = realToFrac $ nominalDiffTimeToSeconds prDuration
  , exError = Nothing
  }

-- | Create error response
errorResponse :: OrchestrationError -> ExecuteResponse
errorResponse err = ExecuteResponse
  { exOutput = ""
  , exTrace = []
  , exDuration = 0
  , exError = Just $ errorToText err
  }

-- | Send trace event over WebSocket
sendTraceEvent :: Connection -> TraceEvent -> IO ()
sendTraceEvent conn event =
  sendTextData conn $ encode $ object
    [ "type" .= ("trace" :: Text)
    , "event" .= event
    ]

-- | Run server on specified port
runServer :: Int -> IO ()
runServer port = do
  putStrLn $ "🚀 LLM Orchestration Patterns UI"
  putStrLn $ "   Server running on http://localhost:" ++ show port
  putStrLn $ "   Press Ctrl+C to stop"
  run port (serve (Proxy @API) server)
