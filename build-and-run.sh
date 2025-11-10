#!/usr/bin/env bash
set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}LLM Orchestration Patterns - Build & Run${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Pull latest changes from git
echo -e "${YELLOW}[1/4] Pulling latest changes from git...${NC}"
git pull
echo -e "${GREEN}✓ Git pull completed${NC}"
echo ""

# Step 2: Clean build artifacts
echo -e "${YELLOW}[2/4] Cleaning build artifacts...${NC}"
cabal clean
echo -e "${GREEN}✓ Clean completed${NC}"
echo ""

# Step 3: Build all projects
echo -e "${YELLOW}[3/4] Building all projects...${NC}"
if cabal build all; then
    echo -e "${GREEN}✓ Build completed successfully${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi
echo ""

# Step 4: Run tests
echo -e "${YELLOW}[4/4] Running tests...${NC}"
if cabal test; then
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo -e "${RED}✗ Tests failed${NC}"
    exit 1
fi
echo ""

# Step 5: Launch UI
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}All checks passed! Launching UI...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Starting server on http://localhost:8080${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

# Find and run the UI executable
UI_EXECUTABLE=$(find dist-newstyle -name "llm-patterns-ui" -type f -executable | head -n 1)

if [ -z "$UI_EXECUTABLE" ]; then
    echo -e "${RED}✗ Could not find llm-patterns-ui executable${NC}"
    exit 1
fi

cd llm-patterns-ui
"../$UI_EXECUTABLE"
