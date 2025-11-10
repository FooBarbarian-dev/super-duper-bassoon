{-# LANGUAGE OverloadedStrings #-}

module LLMPatterns.AgentSpec (spec) where

import Test.Hspec
import LLMPatterns.Agent
import LLMPatterns.Types
import qualified Data.Text as T

spec :: Spec
spec = do
  describe "AgentConfig" $ do
    it "should create AgentConfig" $ do
      let config = AgentConfig
            { acId = AgentId "test-agent"
            , acProvider = "ollama"
            , acModel = "llama3.2"
            , acSystemPrompt = "You are helpful"
            }
      unAgentId (acId config) `shouldBe` "test-agent"
      acProvider config `shouldBe` "ollama"
      acModel config `shouldBe` "llama3.2"
      acSystemPrompt config `shouldBe` "You are helpful"

    it "should support different providers" $ do
      let ollamaConfig = AgentConfig (AgentId "ollama-agent") "ollama" "model" "prompt"
      let openaiConfig = AgentConfig (AgentId "openai-agent") "openai" "model" "prompt"
      acProvider ollamaConfig `shouldBe` "ollama"
      acProvider openaiConfig `shouldBe` "openai"

  describe "fromConfig" $ do
    it "should create agent builder from ollama config" $ do
      let config = AgentConfig
            { acId = AgentId "test"
            , acProvider = "ollama"
            , acModel = "llama3.2"
            , acSystemPrompt = "Test prompt"
            }
      case fromConfig config of
        Right _ -> pure ()  -- Success
        Left err -> expectationFailure $ "Should succeed but got: " ++ show err

    it "should create agent builder from openai config" $ do
      let config = AgentConfig
            { acId = AgentId "test"
            , acProvider = "openai"
            , acModel = "gpt-4"
            , acSystemPrompt = "Test prompt"
            }
      case fromConfig config of
        Right _ -> pure ()  -- Success
        Left err -> expectationFailure $ "Should succeed but got: " ++ show err

    it "should fail for unknown provider" $ do
      let config = AgentConfig
            { acId = AgentId "test"
            , acProvider = "unknown-provider"
            , acModel = "model"
            , acSystemPrompt = "prompt"
            }
      case fromConfig config of
        Left (ConfigurationError msg) ->
          msg `shouldSatisfy` T.isInfixOf "Unknown provider"
        Left err -> expectationFailure $ "Wrong error type: " ++ show err
        Right _ -> expectationFailure "Should have failed"

    it "should preserve agent ID in config" $ do
      let config = AgentConfig
            { acId = AgentId "my-special-agent"
            , acProvider = "ollama"
            , acModel = "model"
            , acSystemPrompt = "prompt"
            }
      case fromConfig config of
        Right agentIO -> do
          agent <- agentIO
          agentId agent `shouldBe` AgentId "my-special-agent"
        Left err -> expectationFailure $ "Should succeed but got: " ++ show err

  describe "mkOllamaAgent" $ do
    it "should create agent with correct ID" $ do
      let agent = mkOllamaAgent (AgentId "ollama-test") "llama3.2" "Test prompt"
      agentId agent `shouldBe` AgentId "ollama-test"

    it "should preserve system prompt" $ do
      let prompt = "You are a test assistant"
      let agent = mkOllamaAgent (AgentId "test") "model" prompt
      agentSystemPrompt agent `shouldBe` prompt

  describe "mkOpenAIAgent" $ do
    it "should create agent with correct ID" $ do
      let agent = mkOpenAIAgent (AgentId "openai-test") "gpt-4" "Test prompt"
      agentId agent `shouldBe` AgentId "openai-test"

    it "should preserve system prompt" $ do
      let prompt = "You are a test assistant"
      let agent = mkOpenAIAgent (AgentId "test") "model" prompt
      agentSystemPrompt agent `shouldBe` prompt
