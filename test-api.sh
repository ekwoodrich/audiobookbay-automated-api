#!/bin/bash
# Quick API test script for mock server
# Usage: ./test-api.sh [query] [options]

set -e

# Default values
QUERY="${1:-test}"
HOST="${ABB_API_HOST:-localhost:5078}"
MOCK_ERROR="${2:-}"
MOCK_DELAY="${3:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Build URL
URL="http://${HOST}/api/search?q=$(echo "$QUERY" | sed 's/ /+/g')"

# Add error simulation if provided
if [ -n "$MOCK_ERROR" ]; then
    URL="${URL}&_mock_error=${MOCK_ERROR}"
fi

# Add delay if provided
if [ -n "$MOCK_DELAY" ]; then
    URL="${URL}&_mock_delay=${MOCK_DELAY}"
fi

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}  AudiobookBay API Test${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""
echo -e "${CYAN}Query:${NC} $QUERY"
echo -e "${CYAN}URL:${NC}   $URL"

if [ -n "$MOCK_ERROR" ]; then
    echo -e "${YELLOW}Mock Error:${NC} $MOCK_ERROR"
fi

if [ -n "$MOCK_DELAY" ]; then
    echo -e "${YELLOW}Mock Delay:${NC} ${MOCK_DELAY}s"
fi

echo ""
echo -e "${BLUE}=================================${NC}"
echo ""

# Make request and format output
RESPONSE=$(curl -s -w "\n%{http_code}" "$URL")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Show HTTP status
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ HTTP $HTTP_CODE${NC}"
else
    echo -e "${RED}✗ HTTP $HTTP_CODE${NC}"
fi

echo ""

# Try to pretty print JSON
if command -v jq &> /dev/null; then
    echo "$BODY" | jq '.'

    # Show summary
    echo ""
    echo -e "${BLUE}=================================${NC}"
    echo -e "${CYAN}Summary:${NC}"
    RESULT_COUNT=$(echo "$BODY" | jq -r '.result_count // 0' 2>/dev/null || echo "0")
    echo -e "  Results: ${GREEN}${RESULT_COUNT}${NC}"

    # Show first result if available
    if [ "$RESULT_COUNT" -gt 0 ]; then
        echo ""
        echo -e "${CYAN}First Result:${NC}"
        FIRST_TITLE=$(echo "$BODY" | jq -r '.results[0].title // "N/A"' 2>/dev/null)
        FIRST_FORMAT=$(echo "$BODY" | jq -r '.results[0].format // "N/A"' 2>/dev/null)
        FIRST_SIZE=$(echo "$BODY" | jq -r '.results[0].file_size // "N/A"' 2>/dev/null)
        echo -e "  Title:  ${FIRST_TITLE}"
        echo -e "  Format: ${FIRST_FORMAT}"
        echo -e "  Size:   ${FIRST_SIZE}"
    fi

    # Show warning if present
    WARNING=$(echo "$BODY" | jq -r '.warning // empty' 2>/dev/null)
    if [ -n "$WARNING" ]; then
        echo ""
        echo -e "${YELLOW}⚠ Warning: ${WARNING}${NC}"
    fi

    # Show error if present
    ERROR=$(echo "$BODY" | jq -r '.error // empty' 2>/dev/null)
    if [ -n "$ERROR" ]; then
        echo ""
        echo -e "${RED}✗ Error: ${ERROR}${NC}"
    fi
else
    # No jq, just print raw
    echo "$BODY"
    echo ""
    echo -e "${YELLOW}Tip: Install jq for better formatting${NC}"
fi

echo -e "${BLUE}=================================${NC}"
echo ""

exit 0
