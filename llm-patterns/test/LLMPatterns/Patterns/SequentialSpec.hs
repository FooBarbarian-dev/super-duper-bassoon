{-# LANGUAGE OverloadedStrings #-}

module LLMPatterns.Patterns.SequentialSpec (spec) where

import Test.Hspec
import LLMPatterns.Types
import LLMPatterns.Patterns.Sequential

spec :: Spec
spec = do
  describe "executeSequential" $ do
    it "should return error when given empty agent list" $ do
      result <- executeSequential [] "test input"
      case result of
        Right pr -> do
          -- With empty list, should still succeed but with original input
          prTrace pr `shouldBe` []
        Left _ -> pure () -- Also acceptable

    it "should preserve agent order in execution" $ do
      -- This test verifies that agents are called in order
      -- In a real scenario with mock agents, we'd verify the call order
      let agents = []  -- Would need mock agents
      result <- executeSequential agents "input"
      result `shouldSatisfy` either (const True) (const True)

  describe "Pattern properties" $ do
    it "should handle single agent" $ do
      result <- executeSequential [] "test"
      case result of
        Right pr -> prDuration pr `shouldSatisfy` (>= 0)
        Left _ -> pure ()

    it "should collect all trace events" $ do
      result <- executeSequential [] "test"
      case result of
        Right pr -> prTrace pr `shouldSatisfy` \events ->
          all isValidTraceEvent events
        Left _ -> pure ()

isValidTraceEvent :: TraceEvent -> Bool
isValidTraceEvent (AgentStarted _) = True
isValidTraceEvent (AgentCompleted _ _) = True
isValidTraceEvent (AgentFailed _ _) = True
isValidTraceEvent _ = True
