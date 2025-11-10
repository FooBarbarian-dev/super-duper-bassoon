{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module LLMPatterns.OrchestratorSpec (spec) where

import Test.Hspec
import LLMPatterns.Orchestrator
import LLMPatterns.Agent
import LLMPatterns.Types
import Control.Monad (forM_)

spec :: Spec
spec = do
  describe "Orchestrator" $ do
    it "should create orchestrator with default Sequential pattern" $ do
      let agent1 = mkOllamaAgent (AgentId "agent1") "llama3.2" "Test"
      let agent2 = mkOllamaAgent (AgentId "agent2") "llama3.2" "Test"
      let orch = new [agent1, agent2]
      orchPattern orch `shouldBe` Sequential

    it "should update pattern with withPattern" $ do
      let agent = mkOllamaAgent (AgentId "agent") "model" "prompt"
      let orch1 = new [agent]
      let orch2 = withPattern (GroupChat 5) orch1
      orchPattern orch2 `shouldSatisfy` \case
        GroupChat n -> n == 5
        _ -> False

    it "should preserve agents when changing pattern" $ do
      let agent1 = mkOllamaAgent (AgentId "agent1") "model" "prompt"
      let agent2 = mkOllamaAgent (AgentId "agent2") "model" "prompt"
      let orch1 = new [agent1, agent2]
      let orch2 = withPattern (Concurrent Vote) orch1
      length (orchAgents orch2) `shouldBe` 2

    it "should support all pattern types" $ do
      let agent = mkOllamaAgent (AgentId "test") "model" "prompt"
      let patterns =
            [ Sequential
            , Concurrent Vote
            , GroupChat 5
            , Handoff 10
            , Magentic 10
            ]
      forM_ patterns $ \pattern -> do
        let orch = withPattern pattern (new [agent])
        orchPattern orch `shouldBe` pattern

  describe "Pattern composition" $ do
    it "should allow chaining withPattern calls" $ do
      let agent = mkOllamaAgent (AgentId "test") "model" "prompt"
      let orch = new [agent]
              & withPattern (GroupChat 3)
              & withPattern Sequential
      orchPattern orch `shouldBe` Sequential

    it "should work with no agents (empty list)" $ do
      let orch = new []
      length (orchAgents orch) `shouldBe` 0

    it "should work with single agent" $ do
      let agent = mkOllamaAgent (AgentId "solo") "model" "prompt"
      let orch = new [agent]
      length (orchAgents orch) `shouldBe` 1

-- Helper for reverse function application
(&) :: a -> (a -> b) -> b
x & f = f x
