{-# LANGUAGE OverloadedStrings #-}

module LLMPatterns.ConfigSpec (spec) where

import Test.Hspec
import LLMPatterns.Config
import LLMPatterns.Types
import LLMPatterns.Agent
import LLMPatterns.Orchestrator (Orchestrator(..))
import System.IO.Temp (withSystemTempDirectory)
import System.FilePath ((</>))
import Control.Monad (forM_)
import qualified Data.Text as T

spec :: Spec
spec = do
  describe "OrchestratorConfig" $ do
    it "should parse config with agents and pattern" $ do
      let config = OrchestratorConfig
            { ocAgents =
                [ AgentConfig (AgentId "agent1") "ollama" "llama3.2" "Prompt 1"
                , AgentConfig (AgentId "agent2") "openai" "gpt-4" "Prompt 2"
                ]
            , ocPattern = Sequential
            }
      length (ocAgents config) `shouldBe` 2
      ocPattern config `shouldBe` Sequential

    it "should support different patterns" $ do
      let patterns = [Sequential, GroupChat 5, Handoff 10, Magentic 10]
      forM_ patterns $ \p -> do
        let config = OrchestratorConfig [] p
        ocPattern config `shouldBe` p

  describe "loadConfig" $ do
    it "should load valid YAML config" $ do
      withSystemTempDirectory "test-config" $ \tmpDir -> do
        let configPath = tmpDir </> "test.yaml"
        let yamlContent = unlines
              [ "ocAgents:"
              , "  - acId:"
              , "      unAgentId: agent1"
              , "    acProvider: ollama"
              , "    acModel: llama3.2"
              , "    acSystemPrompt: Test prompt"
              , "ocPattern: Sequential"
              ]
        writeFile configPath yamlContent
        result <- loadConfig configPath
        case result of
          Right config -> do
            length (ocAgents config) `shouldBe` 1
            ocPattern config `shouldBe` Sequential
          Left err -> expectationFailure $ "Should parse valid YAML: " ++ show err

    it "should fail on non-existent file" $ do
      result <- loadConfig "/nonexistent/path/config.yaml"
      case result of
        Left (ConfigurationError _) -> pure ()  -- Expected
        Left err -> expectationFailure $ "Wrong error type: " ++ show err
        Right _ -> expectationFailure "Should have failed"

    it "should fail on invalid YAML" $ do
      withSystemTempDirectory "test-config" $ \tmpDir -> do
        let configPath = tmpDir </> "invalid.yaml"
        writeFile configPath "invalid: yaml: content: [[[["
        result <- loadConfig configPath
        case result of
          Left (ConfigurationError _) -> pure ()  -- Expected
          Left err -> expectationFailure $ "Wrong error type: " ++ show err
          Right _ -> expectationFailure "Should have failed"

  describe "loadOrchestrator" $ do
    it "should build orchestrator from valid config" $ do
      withSystemTempDirectory "test-config" $ \tmpDir -> do
        let configPath = tmpDir </> "orch.yaml"
        let yamlContent = unlines
              [ "ocAgents:"
              , "  - acId:"
              , "      unAgentId: agent1"
              , "    acProvider: ollama"
              , "    acModel: llama3.2"
              , "    acSystemPrompt: Prompt 1"
              , "  - acId:"
              , "      unAgentId: agent2"
              , "    acProvider: ollama"
              , "    acModel: llama3.2"
              , "    acSystemPrompt: Prompt 2"
              , "ocPattern: Sequential"
              ]
        writeFile configPath yamlContent
        result <- loadOrchestrator configPath
        case result of
          Right orch -> do
            length (orchAgents orch) `shouldBe` 2
            orchPattern orch `shouldBe` Sequential
          Left err -> expectationFailure $ "Should build orchestrator: " ++ show err

    it "should fail with unknown provider" $ do
      withSystemTempDirectory "test-config" $ \tmpDir -> do
        let configPath = tmpDir </> "bad.yaml"
        let yamlContent = unlines
              [ "ocAgents:"
              , "  - acId:"
              , "      unAgentId: agent1"
              , "    acProvider: unknown-provider"
              , "    acModel: model"
              , "    acSystemPrompt: Prompt"
              , "ocPattern: Sequential"
              ]
        writeFile configPath yamlContent
        result <- loadOrchestrator configPath
        case result of
          Left (ConfigurationError msg) ->
            msg `shouldSatisfy` T.isInfixOf "Unknown provider"
          Left err -> expectationFailure $ "Wrong error type: " ++ show err
          Right _ -> expectationFailure "Should have failed"
