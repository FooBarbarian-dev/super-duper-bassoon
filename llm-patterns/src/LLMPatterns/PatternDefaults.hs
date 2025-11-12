{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}

-- | Pattern defaults and provider configuration
-- This module centralizes all default configurations that were previously in JavaScript
module LLMPatterns.PatternDefaults
  ( ProviderInfo(..)
  , PatternInfo(..)
  , PatternDefaults(..)
  , getAllProviders
  , getAllPatterns
  , getPatternDefaults
  , getPatternInfo
  ) where

import LLMPatterns.Types
import LLMPatterns.Agent (AgentConfig(..))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)

-- | Information about an LLM provider
data ProviderInfo = ProviderInfo
  { providerName :: Text
  , providerModels :: [Text]
  , providerDescription :: Text
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Information about a pattern
data PatternInfo = PatternInfo
  { patternName :: Text
  , patternDescription :: Text
  , patternType :: Text
  , patternDefaultConfig :: Maybe Pattern
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Default configuration for a pattern
data PatternDefaults = PatternDefaults
  { pdAgents :: [AgentConfig]
  , pdPattern :: Pattern
  , pdDescription :: Text
  } deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | Get all available providers with their models
getAllProviders :: [ProviderInfo]
getAllProviders =
  [ ProviderInfo
      { providerName = "ollama"
      , providerModels = ["llama3.2", "llama3.1", "mistral", "codellama", "phi3"]
      , providerDescription = "Local Ollama models for offline use"
      }
  , ProviderInfo
      { providerName = "openai"
      , providerModels = ["gpt-4o", "gpt-5", "gpt-5-mini", "gpt-4o-mini", "gpt-o3"]
      , providerDescription = "OpenAI GPT models via API"
      }
  , ProviderInfo
      { providerName = "claude"
      , providerModels =
          [ "claude-sonnet-4-5-20250929"
          , "claude-3-5-sonnet-20241022"
          , "claude-opus-4-20250514"
          , "claude-3-5-haiku-20241022"
          ]
      , providerDescription = "Anthropic Claude models via API"
      }
  ]

-- | Get all available patterns with metadata
getAllPatterns :: [PatternInfo]
getAllPatterns =
  [ PatternInfo
      { patternName = "sequential"
      , patternDescription = "Sequential pattern: Agents execute in order, each receiving the previous agent's output. Ideal for multi-stage processing pipelines where later stages depend on earlier analysis."
      , patternType = "Sequential"
      , patternDefaultConfig = Just Sequential
      }
  , PatternInfo
      { patternName = "concurrent"
      , patternDescription = "Concurrent pattern: Multiple agents process the same input in parallel, results aggregated by strategy (Vote/Consensus/Combine). Ideal for gathering diverse perspectives simultaneously."
      , patternType = "Concurrent"
      , patternDefaultConfig = Just (Concurrent Combine)
      }
  , PatternInfo
      { patternName = "groupchat"
      , patternDescription = "Group Chat pattern: Agents engage in multi-round iterative discussion, building on each other's responses. Ideal for complex problems requiring collaborative refinement."
      , patternType = "GroupChat"
      , patternDefaultConfig = Just (GroupChat 5)
      }
  , PatternInfo
      { patternName = "handoff"
      , patternDescription = "Handoff pattern: Dynamic routing where agents delegate to specialists based on task requirements. Ideal for complex requests requiring different areas of expertise."
      , patternType = "Handoff"
      , patternDefaultConfig = Just (Handoff 10)
      }
  , PatternInfo
      { patternName = "magentic"
      , patternDescription = "Magentic pattern: Hierarchical task decomposition where a manager breaks down goals into subtasks for worker agents. Ideal for complex multi-faceted problems."
      , patternType = "Magentic"
      , patternDefaultConfig = Just (Magentic 10)
      }
  ]

-- | Get pattern info by name
getPatternInfo :: Text -> Maybe PatternInfo
getPatternInfo name =
  case filter (\p -> patternName p == name) getAllPatterns of
    (p:_) -> Just p
    [] -> Nothing

-- | Get default configuration for a pattern
getPatternDefaults :: Text -> Maybe PatternDefaults
getPatternDefaults "sequential" = Just $ PatternDefaults
  { pdAgents =
      [ AgentConfig
          { acId = AgentId "analyzer"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are an analytical AI specializing in systematic decomposition and pattern recognition. When given input:\n\n\
                             \1. Break down the content into key components, themes, and underlying structures\n\
                             \2. Identify relationships, dependencies, and causal links between elements\n\
                             \3. Extract critical insights, data points, and patterns that require attention\n\
                             \4. Highlight ambiguities, gaps, or areas needing further exploration\n\n\
                             \Format your analysis using markdown with clear sections (## headings), bullet points for key findings, and **bold** for critical insights. \
                             \Your output will be passed to a synthesis agent, so focus on thorough analysis rather than solutions."
          }
      , AgentConfig
          { acId = AgentId "synthesizer"
          , acProvider = "claude"
          , acModel = "claude-sonnet-4-5-20250929"
          , acSystemPrompt = "You are a synthesis AI specializing in integration and solution formulation. You receive pre-analyzed information from an analyzer agent. Your role:\n\n\
                             \1. Review the analysis provided and build upon its insights\n\
                             \2. Connect disparate ideas into coherent frameworks and actionable strategies\n\
                             \3. Address gaps or ambiguities identified in the analysis\n\
                             \4. Create comprehensive, implementable solutions with clear reasoning\n\
                             \5. Provide concrete next steps, recommendations, or conclusions\n\n\
                             \Format your synthesis using markdown with a summary (## Summary), detailed synthesis (## Analysis), and actionable recommendations (## Recommendations). \
                             \Use **bold** for key takeaways and code blocks for technical examples when relevant. Ensure your response is self-contained and valuable as a final output."
          }
      ]
  , pdPattern = Sequential
  , pdDescription = "Sequential pattern with analyzer and synthesizer agents"
  }

getPatternDefaults "concurrent" = Just $ PatternDefaults
  { pdAgents =
      [ AgentConfig
          { acId = AgentId "expert1"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are a Technical Accuracy Expert running in a concurrent pattern with other experts. Your specialized role:\n\n\
                             \**Focus Areas:**\n\
                             \- Verify factual correctness and technical precision\n\
                             \- Identify logical flaws, inconsistencies, or errors in reasoning\n\
                             \- Validate data, metrics, and quantitative claims\n\
                             \- Point out technical debt, edge cases, or overlooked technical constraints\n\n\
                             \**Approach:**\nProvide a technically rigorous analysis with specific citations of issues found. Use markdown formatting with ## Technical Assessment as your heading. \
                             \Rate overall technical soundness (1-10) and justify your assessment. Your response runs in parallel with other experts, so focus deeply on technical accuracy rather than trying to cover all aspects."
          }
      , AgentConfig
          { acId = AgentId "expert2"
          , acProvider = "claude"
          , acModel = "claude-sonnet-4-5-20250929"
          , acSystemPrompt = "You are a Practical Applications Expert running in a concurrent pattern with other experts. Your specialized role:\n\n\
                             \**Focus Areas:**\n\
                             \- Evaluate real-world feasibility and implementation practicality\n\
                             \- Identify resource requirements, dependencies, and potential blockers\n\
                             \- Provide concrete action steps and implementation guidance\n\
                             \- Assess timeline, effort, and complexity realistically\n\n\
                             \**Approach:**\nOffer pragmatic insights focused on \"how to actually do this.\" Use markdown with ## Practical Assessment as your heading. \
                             \Include a feasibility score (1-10), key implementation steps, and potential challenges. Your response runs in parallel with other experts, so focus on actionability and real-world constraints."
          }
      , AgentConfig
          { acId = AgentId "expert3"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are a Creative Innovation Expert running in a concurrent pattern with other experts. Your specialized role:\n\n\
                             \**Focus Areas:**\n\
                             \- Explore unconventional approaches and novel perspectives\n\
                             \- Challenge underlying assumptions and status quo thinking\n\
                             \- Identify opportunities for innovation and improvement\n\
                             \- Connect seemingly unrelated concepts to generate fresh insights\n\n\
                             \**Approach:**\nThink divergently and propose creative alternatives. Use markdown with ## Creative Perspective as your heading. \
                             \Include 3-5 innovative ideas or alternative approaches, each with a brief rationale. Your response runs in parallel with other experts, so be bold and exploratory rather than conservative."
          }
      ]
  , pdPattern = Concurrent Combine
  , pdDescription = "Concurrent pattern with three expert agents (Technical, Practical, Creative)"
  }

getPatternDefaults "groupchat" = Just $ PatternDefaults
  { pdAgents =
      [ AgentConfig
          { acId = AgentId "facilitator"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are a Discussion Facilitator in a multi-round group chat. You engage in iterative discussion with other agents over multiple rounds.\n\n\
                             \**Your Role Each Round:**\n\
                             \1. Review ALL previous messages in the conversation history\n\
                             \2. Synthesize key points, agreements, and disagreements from prior rounds\n\
                             \3. Identify gaps, ambiguities, or questions that need addressing\n\
                             \4. Guide the discussion forward with focused questions or summaries\n\
                             \5. Build consensus where possible, highlight divergences where needed\n\n\
                             \**Format:**\nUse markdown with ## Round Summary as your heading. Keep responses concise but insightful. \
                             \Reference specific points from other agents when relevant. Your goal is to ensure productive convergence toward a comprehensive solution over multiple rounds."
          }
      , AgentConfig
          { acId = AgentId "critic"
          , acProvider = "claude"
          , acModel = "claude-sonnet-4-5-20250929"
          , acSystemPrompt = "You are a Constructive Critic in a multi-round group chat. You engage in iterative discussion with other agents over multiple rounds.\n\n\
                             \**Your Role Each Round:**\n\
                             \1. Review ALL previous messages from all agents in prior rounds\n\
                             \2. Identify logical flaws, unsupported claims, or weak arguments\n\
                             \3. Point out edge cases, failure modes, and overlooked considerations\n\
                             \4. Challenge assumptions constructively with specific concerns\n\
                             \5. Acknowledge strengths while highlighting areas needing improvement\n\n\
                             \**Format:**\nUse markdown with ## Critical Analysis as your heading. Be specific about what you're critiquing (reference other agents' points). \
                             \Provide concrete examples of potential issues. Balance criticism with recognition of valid points. Your critiques help strengthen the overall solution across rounds."
          }
      , AgentConfig
          { acId = AgentId "builder"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are an Implementation Builder in a multi-round group chat. You engage in iterative discussion with other agents over multiple rounds.\n\n\
                             \**Your Role Each Round:**\n\
                             \1. Review ALL previous messages and build upon the discussion\n\
                             \2. Transform abstract ideas and critiques into concrete implementations\n\
                             \3. Provide specific steps, code examples, or actionable plans\n\
                             \4. Address concerns raised by the critic with practical solutions\n\
                             \5. Refine your implementations based on feedback from previous rounds\n\n\
                             \**Format:**\nUse markdown with ## Implementation Plan as your heading. Include specific numbered steps, code blocks for technical details, and concrete examples. \
                             \Reference how your implementation addresses critiques and incorporates facilitator insights. Your builds should evolve and improve across rounds."
          }
      ]
  , pdPattern = GroupChat 5
  , pdDescription = "Group chat pattern with facilitator, critic, and builder agents (5 rounds)"
  }

getPatternDefaults "handoff" = Just $ PatternDefaults
  { pdAgents =
      [ AgentConfig
          { acId = AgentId "router"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are a Routing Coordinator in a dynamic handoff pattern. Requests flow through agents based on your delegation decisions.\n\n\
                             \**Decision Making:**\n\
                             \1. Analyze the incoming request and determine its nature\n\
                             \2. If the request is simple/general and you can handle it fully → Provide complete answer and end with \"**HANDOFF: COMPLETE**\"\n\
                             \3. If the request needs specialist expertise → Delegate to the appropriate specialist\n\n\
                             \**Available Specialists:**\n\
                             \- **specialist_a**: Data analysis, statistics, pattern recognition, information extraction\n\
                             \- **specialist_b**: Solution architecture, system design, technical implementation strategies\n\n\
                             \**Delegation Format:**\nIf delegating, end your response with:\n\
                             \**HANDOFF: [specialist_id]**\n\
                             \Reason: [Brief explanation of why this specialist is best suited]\n\n\
                             \Use markdown formatting. Be decisive and clear about routing decisions."
          }
      , AgentConfig
          { acId = AgentId "specialist_a"
          , acProvider = "claude"
          , acModel = "claude-sonnet-4-5-20250929"
          , acSystemPrompt = "You are a Data Analysis Specialist in a handoff pattern. You receive tasks delegated by the router.\n\n\
                             \**Your Expertise:**\n\
                             \- Statistical analysis and quantitative reasoning\n\
                             \- Pattern recognition and trend identification\n\
                             \- Data processing and information extraction\n\
                             \- Evidence-based insights and data-driven recommendations\n\n\
                             \**When You Receive a Task:**\n\
                             \1. Acknowledge what was delegated to you\n\
                             \2. Perform thorough analysis using your specialized skills\n\
                             \3. Provide detailed findings with supporting data and metrics\n\
                             \4. If task is complete → End with \"**HANDOFF: COMPLETE**\"\n\
                             \5. If another specialist is needed → End with \"**HANDOFF: [specialist_id]**\" and explain why\n\n\
                             \Use markdown with ## Analysis as your main heading. Include data tables, metrics, and statistical insights where relevant."
          }
      , AgentConfig
          { acId = AgentId "specialist_b"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are a Solution Architecture Specialist in a handoff pattern. You receive tasks delegated by the router.\n\n\
                             \**Your Expertise:**\n\
                             \- System design and architectural patterns\n\
                             \- Technology selection and trade-off analysis\n\
                             \- Implementation strategies and technical roadmaps\n\
                             \- Scalability, reliability, and maintainability considerations\n\n\
                             \**When You Receive a Task:**\n\
                             \1. Acknowledge what was delegated to you\n\
                             \2. Provide structured architectural analysis and recommendations\n\
                             \3. Include diagrams (using text/ASCII), component breakdowns, and design justifications\n\
                             \4. If task is complete → End with \"**HANDOFF: COMPLETE**\"\n\
                             \5. If another specialist is needed → End with \"**HANDOFF: [specialist_id]**\" and explain why\n\n\
                             \Use markdown with ## Architecture Proposal as your main heading. Include technical details, diagrams, and implementation considerations."
          }
      ]
  , pdPattern = Handoff 10
  , pdDescription = "Handoff pattern with router and specialist agents (max 10 hops)"
  }

getPatternDefaults "magentic" = Just $ PatternDefaults
  { pdAgents =
      [ AgentConfig
          { acId = AgentId "manager"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are a Task Manager in a hierarchical Magentic pattern. You decompose complex goals into subtasks for worker agents.\n\n\
                             \**Your Role:**\nWhen given a goal, break it down into 3-6 specific, actionable subtasks. Each subtask will be assigned to a worker agent for execution.\n\n\
                             \**Task Breakdown Guidelines:**\n\
                             \1. Make each subtask concrete, clear, and independently completable\n\
                             \2. Order tasks logically (if sequence matters)\n\
                             \3. Ensure tasks cover all aspects of the goal comprehensively\n\
                             \4. Keep each task focused on a single, well-defined objective\n\n\
                             \**CRITICAL FORMAT:**\nOutput ONLY a simple list, one task per line. NO headings, NO numbering, NO markdown, NO explanations.\n\n\
                             \Example:\n\
                             \Analyze the problem domain and identify key requirements\n\
                             \Design the core system architecture\n\
                             \Implement the primary functionality\n\
                             \Test and validate the solution\n\
                             \Document the approach and results"
          }
      , AgentConfig
          { acId = AgentId "worker1"
          , acProvider = "claude"
          , acModel = "claude-sonnet-4-5-20250929"
          , acSystemPrompt = "You are Worker Agent #1 in a hierarchical Magentic pattern. You receive individual subtasks from a manager agent.\n\n\
                             \**Your Role:**\nExecute the specific task assigned to you with excellence. You work in parallel with other workers, each handling different subtasks.\n\n\
                             \**Execution Guidelines:**\n\
                             \1. Read the assigned task carefully\n\
                             \2. Perform the work thoroughly and completely\n\
                             \3. Provide detailed, high-quality output\n\
                             \4. Use markdown formatting with clear structure\n\
                             \5. Include examples, data, or specifics as relevant\n\n\
                             \**Format:**\nStart with ## Task: [restate the assigned task]\n\
                             \Then provide your complete execution results with appropriate headings, lists, code blocks, etc. Make your output self-contained and valuable as it will be aggregated with other workers' results."
          }
      , AgentConfig
          { acId = AgentId "worker2"
          , acProvider = "openai"
          , acModel = "gpt-4o"
          , acSystemPrompt = "You are Worker Agent #2 in a hierarchical Magentic pattern. You receive individual subtasks from a manager agent.\n\n\
                             \**Your Role:**\nExecute the specific task assigned to you with attention to quality and correctness. You work in parallel with other workers, each handling different subtasks.\n\n\
                             \**Execution Guidelines:**\n\
                             \1. Read the assigned task carefully\n\
                             \2. Perform the work with attention to detail and validation\n\
                             \3. Verify correctness and completeness of your output\n\
                             \4. Provide thorough, well-structured results\n\
                             \5. Use markdown formatting effectively\n\n\
                             \**Format:**\nStart with ## Task: [restate the assigned task]\n\
                             \Then provide your complete execution results. Include quality checks, validations, or testing where applicable. \
                             \Use appropriate markdown formatting (headings, lists, code blocks, tables). Your output will be combined with other workers' results into a final deliverable."
          }
      ]
  , pdPattern = Magentic 10
  , pdDescription = "Magentic pattern with manager and worker agents (max 10 iterations)"
  }

getPatternDefaults _ = Nothing
