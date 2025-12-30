#!/bin/bash
# Sync captured debug responses to mock server data

# Note: Not using set -e to handle edge cases gracefully

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DEBUG_DIR="debug"
MOCK_DATA_DIR="app/mock_data"
MOCK_SEARCH_DIR="${MOCK_DATA_DIR}/search"
MOCK_DETAIL_DIR="${MOCK_DATA_DIR}/detail"
MOCK_ABB_PY="app/mock_abb.py"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Sync Debug Data to Mock Server${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if debug directory exists
if [ ! -d "$DEBUG_DIR" ]; then
    echo -e "${RED}Error: Debug directory not found: $DEBUG_DIR${NC}"
    echo "Run searches with DEBUG_RESPONSES=true first to capture data."
    exit 1
fi

# Create mock_data directories if they don't exist
mkdir -p "$MOCK_SEARCH_DIR"
mkdir -p "$MOCK_DETAIL_DIR"

# Function to normalize query for filename
normalize_query() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/_\+/_/g' | sed 's/^_//g' | sed 's/_$//g'
}

# Track what we find
declare -A queries_found
declare -A details_found
new_queries=0
new_details=0
updated_files=0

echo -e "${CYAN}Scanning debug directory for new captures...${NC}"
echo ""

# Process search results
for metadata_file in ${DEBUG_DIR}/*_search_*_metadata.json; do
    [ -f "$metadata_file" ] || continue

    # Extract query from metadata
    query=$(jq -r '.metadata.query // empty' "$metadata_file" 2>/dev/null)
    page=$(jq -r '.metadata.page // 1' "$metadata_file" 2>/dev/null)

    if [ -z "$query" ] || [ "$query" == "null" ]; then
        continue
    fi

    # Get corresponding HTML file
    html_file="${metadata_file%_metadata.json}.html"

    if [ ! -f "$html_file" ]; then
        echo -e "${YELLOW}Warning: HTML file not found for ${metadata_file}${NC}"
        continue
    fi

    # Normalize query for filename
    normalized=$(normalize_query "$query")

    # Target filename
    target_file="${MOCK_SEARCH_DIR}/${normalized}_page${page}.html"

    # Copy if doesn't exist or is different
    if [ ! -f "$target_file" ] || ! cmp -s "$html_file" "$target_file"; then
        cp "$html_file" "$target_file"
        echo -e "${GREEN}✓${NC} Copied: ${query} (page ${page}) → ${normalized}_page${page}.html"
        queries_found["$query"]="$normalized"
        ((updated_files++))
    fi
done

# Process detail pages
for metadata_file in ${DEBUG_DIR}/*_detail_*_metadata.json; do
    [ -f "$metadata_file" ] || continue

    # Extract URL from metadata
    details_url=$(jq -r '.metadata.details_url // .metadata.url // empty' "$metadata_file" 2>/dev/null)

    if [ -z "$details_url" ] || [ "$details_url" == "null" ]; then
        continue
    fi

    # Get corresponding HTML file
    html_file="${metadata_file%_metadata.json}.html"

    if [ ! -f "$html_file" ]; then
        echo -e "${YELLOW}Warning: HTML file not found for ${metadata_file}${NC}"
        continue
    fi

    # Extract slug from URL (last part of path)
    slug=$(basename "$details_url" | sed 's/[^a-z0-9]/_/g')

    if [ -z "$slug" ]; then
        slug="detail_$(date +%s)"
    fi

    # Target filename
    target_file="${MOCK_DETAIL_DIR}/${slug}_detail.html"

    # Copy if doesn't exist or is different
    if [ ! -f "$target_file" ] || ! cmp -s "$html_file" "$target_file"; then
        cp "$html_file" "$target_file"
        echo -e "${GREEN}✓${NC} Copied: Detail page → ${slug}_detail.html"
        details_found["$slug"]=1
        ((updated_files++))
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${CYAN}Summary:${NC}"
echo -e "  Files updated: ${GREEN}${updated_files}${NC}"
echo -e "  Search queries: ${GREEN}${#queries_found[@]}${NC}"
echo -e "  Detail pages: ${GREEN}${#details_found[@]}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# If we found new queries, update mock_abb.py
if [ ${#queries_found[@]} -gt 0 ]; then
    echo -e "${CYAN}Updating mock_abb.py with new queries...${NC}"
    echo ""

    # Backup original file
    cp "$MOCK_ABB_PY" "${MOCK_ABB_PY}.backup"

    # Build new KNOWN_QUERIES dict
    temp_file=$(mktemp)

    # Start building new dict
    echo "KNOWN_QUERIES = {" > "$temp_file"

    # Add existing queries from original file
    existing_queries=$(grep -A 100 "^KNOWN_QUERIES = {" "$MOCK_ABB_PY" | grep -B 100 "^}" | grep '".*":' | sed 's/^[[:space:]]*//' || true)

    # Parse existing queries into associative array
    declare -A all_queries
    while IFS= read -r line; do
        if [[ $line =~ \"([^\"]+)\":[[:space:]]*\"([^\"]+)\" ]]; then
            query_key="${BASH_REMATCH[1]}"
            query_val="${BASH_REMATCH[2]}"
            all_queries["$query_key"]="$query_val"
        fi
    done <<< "$existing_queries"

    # Add new queries
    for query in "${!queries_found[@]}"; do
        all_queries["$query"]="${queries_found[$query]}"
    done

    # Sort and write all queries
    # Use process substitution to avoid word splitting on spaces
    while IFS= read -r query; do
        normalized="${all_queries[$query]}"
        echo "    \"$query\": \"$normalized\"," >> "$temp_file"
    done < <(printf '%s\n' "${!all_queries[@]}" | sort)

    echo "}" >> "$temp_file"

    # Replace KNOWN_QUERIES in mock_abb.py
    # Find line numbers
    start_line=$(grep -n "^KNOWN_QUERIES = {" "$MOCK_ABB_PY" | cut -d: -f1)
    end_line=$(tail -n +$start_line "$MOCK_ABB_PY" | grep -n "^}" | head -1 | cut -d: -f1)
    end_line=$((start_line + end_line - 1))

    # Create new file
    head -n $((start_line - 1)) "$MOCK_ABB_PY" > "${MOCK_ABB_PY}.new"
    cat "$temp_file" >> "${MOCK_ABB_PY}.new"
    tail -n +$((end_line + 1)) "$MOCK_ABB_PY" >> "${MOCK_ABB_PY}.new"

    # Replace original
    mv "${MOCK_ABB_PY}.new" "$MOCK_ABB_PY"
    rm "$temp_file"

    echo -e "${GREEN}✓${NC} Updated KNOWN_QUERIES in mock_abb.py"
    echo ""
    echo -e "${CYAN}New queries added:${NC}"
    while IFS= read -r query; do
        echo -e "  ${GREEN}•${NC} $query"
    done < <(printf '%s\n' "${!queries_found[@]}" | sort)
    echo ""
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Sync complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo ""

if [ ${#queries_found[@]} -gt 0 ]; then
    echo -e "  1. Rebuild mock server: ${YELLOW}docker-compose -f docker-compose.mock.yml build mock-abb${NC}"
    echo -e "  2. Restart mock server: ${YELLOW}./start-mock.sh${NC}"
    echo -e "  3. Test new queries: ${YELLOW}python3 test-api.py \"<query>\"${NC}"
else
    echo -e "  No new queries found. Mock server is up to date."
fi
echo ""
