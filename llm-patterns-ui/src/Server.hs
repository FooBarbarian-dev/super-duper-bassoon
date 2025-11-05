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
import Network.Wai.Application.Static (staticApp, defaultFileServerSettings)
import WaiAppStatic.Types (ssIndices, ssMaxAge, unsafeToPiece, MaxAge(..))
import Network.WebSockets (Connection, receiveData, sendTextData, sendClose)
import Data.Aeson (encode, decode, object, (.=))

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
-- More idiomatic: proper error handling, clean code flow
executeHandler :: ExecuteRequest -> Handler ExecuteResponse
executeHandler ExecuteRequest{..} = liftIO $ do
  -- Build agents from configuration
  agentResults <- mapM buildAgentIO erAgents

  case sequence agentResults of
    Left err -> pure $ errorResponse err
    Right agents -> do
      -- Create orchestrator and execute
      let orchestrator = withPattern erPattern (new agents)
      result <- execute orchestrator erInput

      case result of
        Left err -> pure $ errorResponse err
        Right pr -> pure $ successResponse pr

-- | Compare all patterns
-- More idiomatic: uses traverse for effect composition
compareHandler :: CompareRequest -> Handler CompareResponse
compareHandler CompareRequest{..} = liftIO $ do
  -- Build agents
  agentResults <- mapM buildAgentIO crAgents

  case sequence agentResults of
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

      -- Execute each pattern
      results <- mapM (executePattern agents) patterns
      pure $ CompareResponse results
  where
    executePattern agents (name, pattern) = do
      let orchestrator = withPattern pattern (new agents)
      result <- execute orchestrator crInput

      let response = case result of
            Left err -> errorResponse err
            Right pr -> successResponse pr

      pure (name, response)

-- | WebSocket handler for real-time execution
-- More idiomatic: explicit connection handling
wsHandler :: Connection -> Handler ()
wsHandler conn = liftIO $ do
  -- Receive request
  msg <- receiveData conn

  case decode msg of
    Nothing -> sendClose conn ("Invalid request" :: Text)
    Just req@ExecuteRequest{..} -> do
      -- Build agents
      agentResults <- mapM buildAgentIO erAgents

      case sequence agentResults of
        Left err -> sendTextData conn $ encode $ errorResponse err
        Right agents -> do
          -- Execute and stream events
          let orchestrator = withPattern erPattern (new agents)
          result <- execute orchestrator erInput

          case result of
            Left err ->
              sendTextData conn $ encode $ errorResponse err
            Right pr -> do
              -- Send trace events one by one
              mapM_ (sendTraceEvent conn) (prTrace pr)

              -- Send final result
              sendTextData conn $ encode $ object
                [ "type" .= ("complete" :: Text)
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
