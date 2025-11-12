{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Structured logging for LLM patterns
module LLMPatterns.Logging
  ( LogLevel(..)
  , LogContext(..)
  , Logger
  , withLogger
  , logDebug
  , logInfo
  , logWarn
  , logError
  , logExecution
  , logAPICall
  , logAPIResponse
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Control.Monad.IO.Class (MonadIO, liftIO)
import System.Log.FastLogger
import qualified Data.ByteString.Char8 as BS

-- | Log levels
data LogLevel
  = DEBUG
  | INFO
  | WARN
  | ERROR
  deriving (Show, Eq, Ord)

-- | Log context for structured logging
data LogContext = LogContext
  { lcRequestId :: Maybe Text
  , lcPattern :: Maybe Text
  , lcAgent :: Maybe Text
  , lcProvider :: Maybe Text
  , lcModel :: Maybe Text
  }

-- | Default empty context
emptyContext :: LogContext
emptyContext = LogContext
  { lcRequestId = Nothing
  , lcPattern = Nothing
  , lcAgent = Nothing
  , lcProvider = Nothing
  , lcModel = Nothing
  }

-- | Logger handle
data Logger = Logger
  { lgLogger :: TimedFastLogger
  , lgCleanup :: IO ()
  , lgMinLevel :: LogLevel
  }

-- | Create a logger with cleanup action
withLogger :: LogLevel -> (Logger -> IO a) -> IO a
withLogger minLevel action = do
  timeCache <- newTimeCache simpleTimeFormat
  (logger, cleanup) <- newTimedFastLogger timeCache (LogStdout defaultBufSize)
  let lg = Logger logger cleanup minLevel
  result <- action lg
  cleanup
  pure result

-- | Format log level with color emoji
formatLevel :: LogLevel -> Text
formatLevel DEBUG = "🔍 DEBUG"
formatLevel INFO  = "ℹ️  INFO "
formatLevel WARN  = "⚠️  WARN "
formatLevel ERROR = "❌ ERROR"

-- | Format context as key-value pairs
formatContext :: LogContext -> Text
formatContext LogContext{..} =
  T.intercalate " " $ filter (not . T.null)
    [ maybe "" (\r -> "[req:" <> r <> "]") lcRequestId
    , maybe "" (\p -> "[pattern:" <> p <> "]") lcPattern
    , maybe "" (\a -> "[agent:" <> a <> "]") lcAgent
    , maybe "" (\p -> "[provider:" <> p <> "]") lcProvider
    , maybe "" (\m -> "[model:" <> m <> "]") lcModel
    ]

-- | Internal logging function
logMessage :: MonadIO m => Logger -> LogLevel -> LogContext -> Text -> m ()
logMessage Logger{..} level ctx msg = liftIO $ do
  when (level >= lgMinLevel) $ do
    let formatted = T.unwords $ filter (not . T.null)
          [ formatLevel level
          , formatContext ctx
          , msg
          ]
    lgLogger $ \ft -> toLogStr $ T.unpack (T.pack (BS.unpack ft) <> " " <> formatted) <> "\n"
  where
    when True action = action
    when False _ = pure ()

-- | Log debug message
logDebug :: MonadIO m => Logger -> LogContext -> Text -> m ()
logDebug logger ctx = logMessage logger DEBUG ctx

-- | Log info message
logInfo :: MonadIO m => Logger -> LogContext -> Text -> m ()
logInfo logger ctx = logMessage logger INFO ctx

-- | Log warning message
logWarn :: MonadIO m => Logger -> LogContext -> Text -> m ()
logWarn logger ctx = logMessage logger WARN ctx

-- | Log error message
logError :: MonadIO m => Logger -> LogContext -> Text -> m ()
logError logger ctx = logMessage logger ERROR ctx

-- | Log pattern execution start/end
logExecution :: MonadIO m => Logger -> Text -> Text -> Maybe Double -> m ()
logExecution logger pattern' input duration = do
  let ctx = emptyContext { lcPattern = Just pattern' }
  case duration of
    Nothing -> logInfo logger ctx $ "Executing pattern with input length: " <> T.pack (show $ T.length input)
    Just d -> logInfo logger ctx $ "Execution completed in " <> T.pack (show d) <> "s"

-- | Log API call
logAPICall :: MonadIO m => Logger -> Text -> Text -> Text -> m ()
logAPICall logger provider model msg = do
  let ctx = emptyContext { lcProvider = Just provider, lcModel = Just model }
      icon = case provider of
        "openai" -> "🔵"
        "claude" -> "🟣"
        "ollama" -> "🟢"
        _ -> "📡"
  logInfo logger ctx $ icon <> " API Call: " <> msg

-- | Log API response
logAPIResponse :: MonadIO m => Logger -> Text -> Text -> Bool -> Int -> m ()
logAPIResponse logger provider model success charCount = do
  let ctx = emptyContext { lcProvider = Just provider, lcModel = Just model }
      icon = if success then "✅" else "❌"
      status = if success then "Success" else "Failed"
  logInfo logger ctx $ icon <> " API Response: " <> status <> " (" <> T.pack (show charCount) <> " chars)"
