{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}

-- | Retry logic for LLM API calls
module Langchain.LLM.Retry
  ( RetryConfig(..)
  , defaultRetryConfig
  , withRetry
  , withExponentialBackoff
  ) where

import Control.Exception (try, SomeException, Exception(..), catch)
import Control.Concurrent (threadDelay)
import Data.Text (Text)
import qualified Data.Text as T

-- | Retry configuration
data RetryConfig = RetryConfig
  { rcMaxRetries :: Int
  , rcInitialDelay :: Int  -- microseconds
  , rcMaxDelay :: Int      -- microseconds
  , rcBackoffMultiplier :: Double
  } deriving (Show, Eq)

-- | Default retry configuration
-- - Up to 4 retries (5 total attempts)
-- - Initial delay: 2 seconds
-- - Max delay: 16 seconds
-- - Exponential backoff with 2x multiplier
defaultRetryConfig :: RetryConfig
defaultRetryConfig = RetryConfig
  { rcMaxRetries = 4
  , rcInitialDelay = 2000000  -- 2 seconds
  , rcMaxDelay = 16000000     -- 16 seconds
  , rcBackoffMultiplier = 2.0
  }

-- | Execute an action with retry logic
withRetry :: RetryConfig -> IO (Either String a) -> IO (Either String a)
withRetry config action = go 0
  where
    go attempt
      | attempt >= rcMaxRetries config = action  -- Last attempt, no retry
      | otherwise = do
          result <- try action :: IO (Either SomeException (Either String a))
          case result of
            Left exception -> do
              -- Network/exception error - retry
              let delay = calculateDelay config attempt
              threadDelay delay
              go (attempt + 1)
            Right (Left err) -> do
              -- Application error - check if retryable
              if isRetryable err
                then do
                  let delay = calculateDelay config attempt
                  threadDelay delay
                  go (attempt + 1)
                else pure (Left err)
            Right (Right success) ->
              pure (Right success)

-- | Execute an action with exponential backoff retry
withExponentialBackoff :: Int -> Int -> IO (Either String a) -> IO (Either String a)
withExponentialBackoff maxRetries initialDelaySeconds action =
  withRetry config action
  where
    config = RetryConfig
      { rcMaxRetries = maxRetries
      , rcInitialDelay = initialDelaySeconds * 1000000
      , rcMaxDelay = initialDelaySeconds * 1000000 * (2 ^ maxRetries)
      , rcBackoffMultiplier = 2.0
      }

-- | Calculate delay for a given attempt
calculateDelay :: RetryConfig -> Int -> Int
calculateDelay RetryConfig{..} attempt =
  min rcMaxDelay $ round $ fromIntegral rcInitialDelay * (rcBackoffMultiplier ^ attempt)

-- | Check if an error is retryable
isRetryable :: String -> Bool
isRetryable err =
  any (`T.isInfixOf` T.pack err)
    [ "timeout"
    , "connection"
    , "network"
    , "429"  -- Rate limit
    , "500"  -- Server error
    , "502"  -- Bad gateway
    , "503"  -- Service unavailable
    , "504"  -- Gateway timeout
    ]
