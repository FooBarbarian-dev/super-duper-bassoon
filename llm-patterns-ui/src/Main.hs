module Main where

import Server (runServer)
import System.Environment (lookupEnv)
import Text.Read (readMaybe)
import Data.Maybe (fromMaybe)

-- | Main entry point with environment variable configuration
main :: IO ()
main = do
  portStr <- lookupEnv "PORT"
  let port = fromMaybe 3003 $ portStr >>= readMaybe
  runServer port
