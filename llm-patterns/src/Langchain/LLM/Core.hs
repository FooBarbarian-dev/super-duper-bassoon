{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Langchain LLM Core with real API implementations
module Langchain.LLM.Core
  ( LLM(..)
  , LLMParams
  , Message(..)
  , Role(..)
  , MessageData(..)
  , defaultMessageData
  -- Re-export specific models for compatibility
  , OllamaModel(..)
  , OpenAIModel(..)
  , ClaudeModel(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON, object, (.=), (.:))
import qualified Data.Aeson as JSON
import Data.Aeson.Types (Parser, parseMaybe)
import Network.HTTP.Simple
import Network.HTTP.Client (responseTimeoutMicro)
import qualified Data.ByteString.Lazy as BSL
import qualified Data.ByteString as BS
import System.Environment (lookupEnv)
import Control.Exception (try, SomeException)

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

-- | Claude model configuration
data ClaudeModel = ClaudeModel
  { claudeModelName :: Text
  , claudeApiKey :: Maybe Text
  , claudeOptions :: [Text]
  } deriving stock (Eq, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | LLM typeclass
class LLM m where
  -- | Chat with the model (with 60 second timeout)
  chat :: m -> [Message] -> Maybe (LLMParams m) -> IO (Either String Text)

-- | Ollama instance (stub implementation for testing)
instance LLM OllamaModel where
  chat model messages _params = do
    -- Stub implementation: just echo the last user message
    let lastUserMsg = reverse [ msgContent msg | msg <- messages, msgRole msg == User ]
    case lastUserMsg of
      (msg:_) -> pure $ Right $ "Ollama (" <> ollamaModelName model <> ") response to: " <> msg
      [] -> pure $ Left "No user message found"

-- | OpenAI instance with real API calls
instance LLM OpenAIModel where
  chat model messages _params = do
    putStrLn $ "🔵 OpenAI API: Calling model " ++ T.unpack (openaiModelName model)
    putStrLn $ "   Messages: " ++ show (length messages) ++ " message(s)"

    -- Get API key from model config or environment
    apiKey <- case openaiApiKey model of
      Just key -> pure key
      Nothing -> do
        envKey <- lookupEnv "OPENAI_API_KEY"
        case envKey of
          Just k -> pure $ T.pack k
          Nothing -> pure ""

    if T.null apiKey
      then do
        putStrLn "❌ OpenAI API: No API key found"
        pure $ Left "OpenAI API key not found in config or OPENAI_API_KEY environment variable"
      else do
        putStrLn "🔑 OpenAI API: API key found, making request..."
        result <- try $ makeOpenAIRequest apiKey (openaiModelName model) messages
        case result of
          Left (e :: SomeException) -> do
            putStrLn $ "❌ OpenAI API error: " ++ show e
            pure $ Left $ "OpenAI API error: " ++ show e
          Right resp -> do
            case resp of
              Left err -> putStrLn $ "❌ OpenAI API returned error: " ++ err
              Right txt -> putStrLn $ "✅ OpenAI API success: " ++ show (T.length txt) ++ " chars"
            pure resp

-- | Claude instance with real API calls
instance LLM ClaudeModel where
  chat model messages _params = do
    putStrLn $ "🟣 Claude API: Calling model " ++ T.unpack (claudeModelName model)
    putStrLn $ "   Messages: " ++ show (length messages) ++ " message(s)"

    -- Get API key from model config or environment
    apiKey <- case claudeApiKey model of
      Just key -> pure key
      Nothing -> do
        envKey <- lookupEnv "ANTHROPIC_API_KEY"
        case envKey of
          Just k -> pure $ T.pack k
          Nothing -> pure ""

    if T.null apiKey
      then do
        putStrLn "❌ Claude API: No API key found"
        pure $ Left "Claude API key not found in config or ANTHROPIC_API_KEY environment variable"
      else do
        putStrLn "🔑 Claude API: API key found, making request..."
        result <- try $ makeClaudeRequest apiKey (claudeModelName model) messages
        case result of
          Left (e :: SomeException) -> do
            putStrLn $ "❌ Claude API error: " ++ show e
            pure $ Left $ "Claude API error: " ++ show e
          Right resp -> do
            case resp of
              Left err -> putStrLn $ "❌ Claude API returned error: " ++ err
              Right txt -> putStrLn $ "✅ Claude API success: " ++ show (T.length txt) ++ " chars"
            pure resp

-- | Make OpenAI API request with 60 second timeout
makeOpenAIRequest :: Text -> Text -> [Message] -> IO (Either String Text)
makeOpenAIRequest apiKey modelName messages = do
  let url = "https://api.openai.com/v1/chat/completions"

  -- Convert messages to OpenAI format
  let openAIMessages = map messageToOpenAI messages

  -- Build request body
  let requestBody = object
        [ "model" .= modelName
        , "messages" .= openAIMessages
        , "max_tokens" .= (4000 :: Int)
        , "temperature" .= (0.7 :: Double)
        ]

  putStrLn $ "📤 OpenAI Request: " ++ T.unpack modelName

  -- Create request with 60 second timeout
  request <- parseRequest $ T.unpack url
  let request' = setRequestMethod "POST"
               $ setRequestHeader "Content-Type" ["application/json"]
               $ setRequestHeader "Authorization" [TE.encodeUtf8 $ "Bearer " <> apiKey]
               $ setRequestBodyJSON requestBody
               $ setRequestResponseTimeout (responseTimeoutMicro 60000000) -- 60 seconds
               $ request

  -- Make request
  response <- httpLBS request'

  -- Parse response
  let responseBody = getResponseBody response
  let responsePreview = T.unpack $ T.take 500 $ TE.decodeUtf8 $ BSL.toStrict responseBody
  putStrLn $ "📥 OpenAI Response: " ++ responsePreview

  case JSON.eitherDecode responseBody of
    Left err -> do
      putStrLn $ "❌ JSON decode error: " ++ err
      pure $ Left $ "Failed to parse OpenAI response: " ++ err
    Right value -> do
      putStrLn $ "✅ JSON decoded successfully"
      case parseMaybe extractOpenAIContent value of
        Just content -> pure $ Right content
        Nothing -> do
          putStrLn $ "❌ Failed to extract content from parsed JSON"
          putStrLn $ "Response structure: " ++ take 300 (show value)
          pure $ Left $ "Failed to extract content from OpenAI response"

-- | Make Claude API request with 60 second timeout
makeClaudeRequest :: Text -> Text -> [Message] -> IO (Either String Text)
makeClaudeRequest apiKey modelName messages = do
  let url = "https://api.anthropic.com/v1/messages"

  -- Separate system message from other messages
  let (systemMsg, otherMessages) = case messages of
        (Message System content _ : rest) -> (Just content, rest)
        _ -> (Nothing, messages)

  -- Convert messages to Claude format (only user/assistant)
  let claudeMessages = map messageToClaude otherMessages

  -- Build request body
  let requestBody = object $
        [ "model" .= modelName
        , "messages" .= claudeMessages
        , "max_tokens" .= (4000 :: Int)
        ] ++ case systemMsg of
          Just sys -> ["system" .= sys]
          Nothing -> []

  putStrLn $ "📤 Claude Request: " ++ T.unpack modelName

  -- Create request with 60 second timeout
  request <- parseRequest $ T.unpack url
  let request' = setRequestMethod "POST"
               $ setRequestHeader "Content-Type" ["application/json"]
               $ setRequestHeader "x-api-key" [TE.encodeUtf8 apiKey]
               $ setRequestHeader "anthropic-version" ["2023-06-01"]
               $ setRequestBodyJSON requestBody
               $ setRequestResponseTimeout (responseTimeoutMicro 60000000) -- 60 seconds
               $ request

  -- Make request
  response <- httpLBS request'

  -- Parse response
  let responseBody = getResponseBody response
  let responsePreview = T.unpack $ T.take 500 $ TE.decodeUtf8 $ BSL.toStrict responseBody
  putStrLn $ "📥 Claude Response: " ++ responsePreview

  case JSON.eitherDecode responseBody of
    Left err -> do
      putStrLn $ "❌ JSON decode error: " ++ err
      pure $ Left $ "Failed to parse Claude response: " ++ err
    Right value -> do
      putStrLn $ "✅ JSON decoded successfully"
      case parseMaybe extractClaudeContent value of
        Just content -> pure $ Right content
        Nothing -> do
          putStrLn $ "❌ Failed to extract content from parsed JSON"
          putStrLn $ "Response structure: " ++ take 300 (show value)
          pure $ Left $ "Failed to extract content from Claude response"

-- | Convert Message to OpenAI format
messageToOpenAI :: Message -> JSON.Value
messageToOpenAI (Message role content _) = object
  [ "role" .= roleToText role
  , "content" .= content
  ]
  where
    roleToText System = "system" :: Text
    roleToText User = "user"
    roleToText Assistant = "assistant"

-- | Convert Message to Claude format (excludes system messages)
messageToClaude :: Message -> JSON.Value
messageToClaude (Message role content _) = object
  [ "role" .= roleToText role
  , "content" .= content
  ]
  where
    roleToText User = "user" :: Text
    roleToText Assistant = "assistant"
    roleToText System = "user" -- Claude doesn't support system in messages array

-- | Extract content from OpenAI response
extractOpenAIContent :: JSON.Value -> Parser Text
extractOpenAIContent = JSON.withObject "OpenAI Response" $ \o -> do
  choices <- o .: "choices"
  case choices of
    [] -> fail "No choices in response"
    (firstChoice:_) -> JSON.withObject "Choice" (\c -> do
      message <- c .: "message"
      JSON.withObject "Message" (\m -> m .: "content") message
      ) firstChoice

-- | Extract content from Claude response
extractClaudeContent :: JSON.Value -> Parser Text
extractClaudeContent = JSON.withObject "Claude Response" $ \o -> do
  contentArray <- o .: "content"
  case contentArray of
    [] -> fail "No content in response"
    (firstContent:_) -> JSON.withObject "Content" (\c -> c .: "text") firstContent
