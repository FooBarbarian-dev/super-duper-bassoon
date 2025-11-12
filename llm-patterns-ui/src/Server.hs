{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}

module Server
  ( server
  , runServer
  ) where

import Servant
import Servant.Server.StaticFiles (serveDirectoryWith)
import API
import LLMPatterns
import LLMPatterns.PatternDefaults
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Control.Monad.IO.Class (liftIO)
import Data.Time.Clock (nominalDiffTimeToSeconds, getCurrentTime, diffUTCTime)
import Network.Wai.Handler.Warp (run)
import Network.Wai.Application.Static (defaultFileServerSettings)
import WaiAppStatic.Types (ssIndices, ssMaxAge, unsafeToPiece, MaxAge(..))
import Network.WebSockets (Connection, receiveData, sendTextData, sendClose)
import Data.Aeson (encode, decode, object, (.=))
import qualified Data.Aeson as JSON
import Data.Traversable (for)
import Data.Foldable (traverse_)
import Data.Either (partitionEithers)
import System.Log.FastLogger
import qualified Data.ByteString.Lazy.Char8 as BSL

-- | Server implementation using more idiomatic handler composition
server :: Server API
server = patternsHandler
    :<|> patternDefaultsHandler
    :<|> providersHandler
    :<|> validateAgentHandler
    :<|> executeHandler
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

-- | Get all available patterns
patternsHandler :: Handler [PatternInfo]
patternsHandler = pure getAllPatterns

-- | Get default configuration for a specific pattern
patternDefaultsHandler :: Text -> Handler PatternDefaults
patternDefaultsHandler name =
  case getPatternDefaults name of
    Just defaults -> pure defaults
    Nothing -> throwError err404 { errBody = "Pattern not found: " <> BSL.fromStrict (TE.encodeUtf8 name) }

-- | Get all available providers
providersHandler :: Handler [ProviderInfo]
providersHandler = pure getAllProviders

-- | Validate an agent configuration
validateAgentHandler :: AgentConfig -> Handler ValidationResponse
validateAgentHandler config =
  case fromConfig config of
    Left err -> pure $ ValidationResponse False (Just $ errorToText err)
    Right _ -> pure $ ValidationResponse True Nothing

-- | Execute a single pattern
-- More idiomatic: uses traverse and ExceptT-style error handling
executeHandler :: ExecuteRequest -> Handler ExecuteResponse
executeHandler ExecuteRequest{..} = liftIO $ do
  -- Initialize logger
  timeCache <- newTimeCache simpleTimeFormat
  (logger, cleanup) <- newTimedFastLogger timeCache (LogStdout defaultBufSize)

  -- Log incoming request
  logger $ \_ -> toLogStr ("📥 Execute request received: " ++ show erPattern ++ " with " ++ show (length erAgents) ++ " agent(s)\n" :: String)
  logger $ \_ -> toLogStr ("   Request body: " ++ BSL.unpack (JSON.encode (object ["pattern" .= erPattern, "agents" .= (length erAgents), "input_length" .= T.length erInput])) ++ "\n" :: String)

  -- Log agent details
  logger $ \_ -> toLogStr ("🤖 Agent configurations:\n" :: String)
  traverse_ (\(idx, AgentConfig{..}) ->
    logger $ \_ -> toLogStr ("   " ++ show (idx :: Int) ++ ". " ++ T.unpack (unAgentId acId) ++ " (provider: " ++ T.unpack acProvider ++ ", model: " ++ T.unpack acModel ++ ")\n" :: String)
    ) (zip [1..] erAgents)

  -- Build agents using traverse (combines mapM + sequence idiomatically)
  startTime <- getCurrentTime
  logger $ \_ -> toLogStr ("🔧 Building agents...\n" :: String)
  agentResults <- traverse buildAgentIO erAgents

  -- Partition Either values to separate errors from successes
  let (errors, agents) = partitionEithers agentResults

  result <- case errors of
    (err:_) -> do
      logger $ \_ -> toLogStr ("❌ Agent build error: " ++ T.unpack (errorToText err) ++ "\n" :: String)
      pure $ errorResponse err  -- Return first error
    [] -> do
      logger $ \_ -> toLogStr ("✅ Built " ++ show (length agents) ++ " agent(s) successfully\n" :: String)
      logger $ \_ -> toLogStr ("🚀 Executing pattern: " ++ show erPattern ++ "\n" :: String)

      -- Create orchestrator and execute
      let orchestrator = withPattern erPattern (new agents)
      execResult <- execute orchestrator erInput

      endTime <- getCurrentTime
      let duration = realToFrac $ nominalDiffTimeToSeconds (endTime `diffUTCTime` startTime) :: Double

      case execResult of
        Left err -> do
          logger $ \_ -> toLogStr ("❌ Pattern execution failed: " ++ T.unpack (errorToText err) ++ "\n" :: String)
          pure $ errorResponse err
        Right pr -> do
          logger $ \_ -> toLogStr ("✅ Pattern execution completed in " ++ show duration ++ "s\n" :: String)
          logger $ \_ -> toLogStr ("   Output length: " ++ show (T.length (prOutput pr)) ++ " chars\n" :: String)
          logger $ \_ -> toLogStr ("   Trace events: " ++ show (length (prTrace pr)) ++ "\n" :: String)
          pure $ successResponse pr

  cleanup
  pure result

-- | Compare all patterns
-- More idiomatic: uses traverse and for with proper error handling
compareHandler :: CompareRequest -> Handler CompareResponse
compareHandler CompareRequest{..} = liftIO $ do
  -- Build agents using traverse
  agentResults <- traverse buildAgentIO crAgents

  -- Partition Either values to separate errors from successes
  let (errors, agents) = partitionEithers agentResults

  case errors of
    (err:_) -> pure $ CompareResponse [("error", errorResponse err)]
    [] -> do
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

      -- Partition Either values to separate errors from successes
      let (errors, agents) = partitionEithers agentResults

      case errors of
        (err:_) -> sendTextData conn $ encode $ errorResponse err
        [] -> do
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
