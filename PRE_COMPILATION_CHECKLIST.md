# Pre-Compilation Checklist

## Module Exposure and Dependencies

1. ✓ **All new modules listed in cabal exposed-modules**
   - LLMPatterns.PatternDefaults ✓
   - LLMPatterns.Logging ✓
   - Langchain.LLM.Retry ✓

2. ✓ **All required dependencies in build-depends**
   - fast-logger >= 3.0 ✓
   - aeson, text, containers, bytestring ✓
   - http-client, http-conduit, http-client-tls ✓

## Language Extensions

3. ✓ **Required LANGUAGE pragmas present**
   - LLMPatterns.Logging.hs: OverloadedStrings, RecordWildCards ✓
   - LLMPatterns.PatternDefaults.hs: OverloadedStrings, DeriveGeneric, DeriveAnyClass, DerivingStrategies ✓
   - Langchain.LLM.Retry.hs: OverloadedStrings, ScopedTypeVariables, RecordWildCards ✓

## Import Statements

4. ✓ **No unused imports**
   - Removed Data.Text.IO from Logging.hs ✓
   - Removed Data.Time.Clock from Logging.hs ✓
   - Removed Data.Time.Format from Logging.hs ✓

5. ✓ **All required imports present**
   - LLMPatterns imports in API.hs ✓
   - LLMPatterns.PatternDefaults imports in Server.hs ✓
   - Langchain.LLM.Retry imports in Core.hs ✓

## Type Signatures

6. ✓ **Proper type signatures with ScopedTypeVariables**
   - withRetry has `forall a.` quantifier ✓
   - Internal `go` function has explicit type signature ✓
   - Removed problematic explicit type annotation on `try action` ✓

7. ✓ **Pattern matching with RecordWildCards**
   - calculateDelay uses RecordWildCards correctly ✓
   - logMessage uses RecordWildCards correctly ✓

## Data Types and Constructors

8. ✓ **AgentId constructor used consistently**
   - All acId fields wrapped: `acId = AgentId "name"` ✓
   - Checked in PatternDefaults.hs for all patterns ✓

9. ✓ **Aeson instances for JSON serialization**
   - ProviderInfo has FromJSON/ToJSON ✓
   - PatternInfo has FromJSON/ToJSON ✓
   - PatternDefaults has FromJSON/ToJSON ✓
   - ValidationResponse has FromJSON/ToJSON ✓

## API Endpoints

10. ✓ **Servant API type definition matches handlers**
    - patternsHandler :: Handler [PatternInfo] ✓
    - patternDefaultsHandler :: Text -> Handler PatternDefaults ✓
    - providersHandler :: Handler [ProviderInfo] ✓
    - validateAgentHandler :: AgentConfig -> Handler ValidationResponse ✓

11. ✓ **Server implementation has all handlers in correct order**
    - Order matches API type definition ✓
    - All 8 handlers present (4 new + 2 existing + ws + static) ✓

## Module Exports

12. ✓ **All necessary functions exported from modules**
    - PatternDefaults exports: getAllProviders, getAllPatterns, getPatternDefaults ✓
    - Retry exports: RetryConfig, defaultRetryConfig, withRetry ✓
    - Logging exports: LogLevel, Logger, withLogger, all log functions ✓

## Error Handling

13. ✓ **Proper error handling with Either types**
    - withRetry returns IO (Either String a) ✓
    - makeOpenAIRequest returns IO (Either String Text) ✓
    - makeClaudeRequest returns IO (Either String Text) ✓
    - fromConfig returns Either OrchestrationError (IO Agent) ✓

## Frontend Integration

14. ✓ **JavaScript matches new API endpoints**
    - loadProviders() fetches from /api/providers ✓
    - loadPatternDefaults() fetches from /api/patterns/:name ✓
    - defaultAgents variable changed from const to let ✓
    - providerModels variable changed from const to let ✓
