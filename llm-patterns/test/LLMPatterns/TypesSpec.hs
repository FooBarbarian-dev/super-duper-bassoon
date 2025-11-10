{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module LLMPatterns.TypesSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import LLMPatterns.Types
import qualified Data.Map.Strict as Map
import Data.Aeson (encode, decode)
import Data.Text (Text)
import qualified Data.Text as T

-- QuickCheck generators
instance Arbitrary AgentId where
  arbitrary = AgentId . T.pack <$> listOf1 (elements ['a'..'z'])

instance Arbitrary AggregationStrategy where
  arbitrary = elements [Consensus, Vote, Combine]

instance Arbitrary TraceEvent where
  arbitrary = oneof
    [ AgentStarted <$> arbitrary
    , AgentCompleted <$> arbitrary <*> arbitraryText
    , AgentFailed <$> arbitrary <*> arbitraryText
    , HandoffOccurred <$> arbitrary <*> arbitrary <*> arbitraryText
    , TaskCreated <$> arbitraryText
    , TaskCompleted <$> arbitraryText
    , RoundStarted <$> arbitrary
    , RoundCompleted <$> arbitrary
    ]
    where
      arbitraryText = T.pack <$> listOf1 arbitrary

spec :: Spec
spec = do
  describe "AgentId" $ do
    it "should create AgentId from text" $ do
      let aid = AgentId "test-agent"
      unAgentId aid `shouldBe` "test-agent"

    it "should be equal when text is equal" $ do
      AgentId "agent1" `shouldBe` AgentId "agent1"

    it "should not be equal when text differs" $ do
      AgentId "agent1" `shouldNotBe` AgentId "agent2"

    it "should have proper Ord instance" $ do
      AgentId "agent1" < AgentId "agent2" `shouldBe` True

    it "should serialize/deserialize via JSON" $ property $ \aid ->
      decode (encode aid) `shouldBe` Just (aid :: AgentId)

  describe "OrchestrationError" $ do
    it "should create AgentExecutionError" $ do
      let err = AgentExecutionError (AgentId "test") "error message"
      case err of
        AgentExecutionError aid msg -> do
          unAgentId aid `shouldBe` "test"
          msg `shouldBe` "error message"
        _ -> expectationFailure "Wrong error type"

    it "should create ConfigurationError" $ do
      let err = ConfigurationError "config error"
      case err of
        ConfigurationError msg -> msg `shouldBe` "config error"
        _ -> expectationFailure "Wrong error type"

    it "should create PatternError" $ do
      let err = PatternError "pattern error"
      case err of
        PatternError msg -> msg `shouldBe` "pattern error"
        _ -> expectationFailure "Wrong error type"

    it "should create NoAgentsAvailable" $ do
      NoAgentsAvailable `shouldBe` NoAgentsAvailable

  describe "AggregationStrategy" $ do
    it "should have all three strategies" $ do
      [Consensus, Vote, Combine] `shouldSatisfy` not . null

    it "should serialize/deserialize via JSON" $ property $ \strat ->
      decode (encode strat) `shouldBe` Just (strat :: AggregationStrategy)

  describe "TraceEvent" $ do
    it "should create AgentStarted event" $ do
      let event = AgentStarted (AgentId "test")
      case event of
        AgentStarted aid -> unAgentId aid `shouldBe` "test"
        _ -> expectationFailure "Wrong event type"

    it "should create AgentCompleted event" $ do
      let event = AgentCompleted (AgentId "test") "output"
      case event of
        AgentCompleted aid output -> do
          unAgentId aid `shouldBe` "test"
          output `shouldBe` "output"
        _ -> expectationFailure "Wrong event type"

    it "should create HandoffOccurred event" $ do
      let event = HandoffOccurred (AgentId "from") (AgentId "to") "reason"
      case event of
        HandoffOccurred from to reason -> do
          unAgentId from `shouldBe` "from"
          unAgentId to `shouldBe` "to"
          reason `shouldBe` "reason"
        _ -> expectationFailure "Wrong event type"

    it "should serialize/deserialize via JSON" $ property $ \event ->
      decode (encode event) `shouldBe` Just (event :: TraceEvent)

  describe "Pattern" $ do
    it "should create Sequential pattern" $ do
      Sequential `shouldBe` Sequential

    it "should create Concurrent pattern" $ do
      Concurrent Vote `shouldSatisfy` \case
        Concurrent _ -> True
        _ -> False

    it "should create GroupChat pattern" $ do
      GroupChat 5 `shouldSatisfy` \case
        GroupChat n -> n == 5
        _ -> False

    it "should create Handoff pattern" $ do
      Handoff 10 `shouldSatisfy` \case
        Handoff n -> n == 10
        _ -> False

    it "should create Magentic pattern" $ do
      Magentic 10 `shouldSatisfy` \case
        Magentic n -> n == 10
        _ -> False

  describe "ExecutionState" $ do
    it "should have empty initial state" $ do
      esTrace initialState `shouldBe` []
      esVisits initialState `shouldBe` Map.empty
      esConversationHistory initialState `shouldBe` []

    it "should add trace events" $ do
      let state = initialState { esTrace = [AgentStarted (AgentId "test")] }
      length (esTrace state) `shouldBe` 1

    it "should track agent visits" $ do
      let visits = Map.singleton (AgentId "test") 3
      let state = initialState { esVisits = visits }
      Map.lookup (AgentId "test") (esVisits state) `shouldBe` Just 3

    it "should maintain conversation history" $ do
      let history = ["msg1", "msg2"]
      let state = initialState { esConversationHistory = history }
      esConversationHistory state `shouldBe` history
