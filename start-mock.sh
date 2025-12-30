#!/bin/bash
# Quick start script for mock server development

set -e

# Function to list available queries
list_queries() {
    echo "============================================"
    echo "  Available Mock Queries"
    echo "============================================"
    echo ""

    if [ -f "app/mock_abb.py" ]; then
        echo "Known queries with cached responses:"
        echo ""
        grep -A 100 "^KNOWN_QUERIES = {" app/mock_abb.py | grep '".*":' | sed 's/^[[:space:]]*//' | while read -r line; do
            if [[ $line =~ \"([^\"]+)\" ]]; then
                query="${BASH_REMATCH[1]}"
                echo "  • $query"
            fi
        done
        echo ""
        echo "Any other query will return 'no results'"
    else
        echo "Error: mock_abb.py not found"
        exit 1
    fi
    echo ""
    echo "============================================"
}

# Function to check container status
check_status() {
    echo "============================================"
    echo "  Mock Server Container Status"
    echo "============================================"
    echo ""

    # Check main app container
    if docker ps --format '{{.Names}}' | grep -q '^audiobookbay-automated$'; then
        status=$(docker ps --filter "name=^audiobookbay-automated$" --format "{{.Status}}")
        echo "  ✓ Main App (audiobookbay-automated): Running"
        echo "    Status: $status"

        # Check configuration
        mock_mode=$(docker exec audiobookbay-automated env 2>/dev/null | grep "^ABB_MOCK_MODE=" | cut -d= -f2)
        hostname=$(docker exec audiobookbay-automated env 2>/dev/null | grep "^ABB_HOSTNAME=" | cut -d= -f2)

        if [ "$mock_mode" == "true" ]; then
            echo "    Mode: Mock (→ $hostname)"
        else
            echo "    Mode: Production (→ $hostname)"
        fi
    else
        echo "  ✗ Main App (audiobookbay-automated): Not running"
    fi

    echo ""

    # Check mock server container
    if docker ps --format '{{.Names}}' | grep -q '^mock-audiobookbay$'; then
        status=$(docker ps --filter "name=^mock-audiobookbay$" --format "{{.Status}}")
        echo "  ✓ Mock Server (mock-audiobookbay): Running"
        echo "    Status: $status"
    else
        echo "  ✗ Mock Server (mock-audiobookbay): Not running"
    fi

    echo ""
    echo "============================================"
    echo ""

    # Show access points if running
    if docker ps --format '{{.Names}}' | grep -q '^audiobookbay-automated$'; then
        echo "Access Points:"
        echo "  Main App:     http://localhost:5078"

        if docker ps --format '{{.Names}}' | grep -q '^mock-audiobookbay$'; then
            echo "  Mock Server:  http://localhost:9999"
            echo "  Health Check: http://localhost:9999/health"
        fi
        echo ""
    fi
}

# Check for flags
if [ "$1" == "--list" ] || [ "$1" == "-l" ]; then
    list_queries
    exit 0
fi

if [ "$1" == "--check" ] || [ "$1" == "-c" ]; then
    check_status
    exit 0
fi

# Check if --force flag is provided
FORCE_RESTART=false
if [ "$1" == "--force" ] || [ "$1" == "-f" ]; then
    FORCE_RESTART=true
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose not found. Please install docker-compose."
    exit 1
fi

# Check if containers are already running (unless --force)
if [ "$FORCE_RESTART" == "false" ]; then
    MAIN_RUNNING=$(docker ps --format '{{.Names}}' | grep -c '^audiobookbay-automated$' || true)
    MOCK_RUNNING=$(docker ps --format '{{.Names}}' | grep -c '^mock-audiobookbay$' || true)

    if [ "$MAIN_RUNNING" -eq 1 ] && [ "$MOCK_RUNNING" -eq 1 ]; then
        echo "============================================"
        echo "  Mock Server Already Running"
        echo "============================================"
        echo ""

        # Check configuration
        mock_mode=$(docker exec audiobookbay-automated env 2>/dev/null | grep "^ABB_MOCK_MODE=" | cut -d= -f2)
        hostname=$(docker exec audiobookbay-automated env 2>/dev/null | grep "^ABB_HOSTNAME=" | cut -d= -f2)

        echo "  ✓ Main App (audiobookbay-automated): Running"
        if [ "$mock_mode" == "true" ]; then
            echo "    Mode: Mock (→ $hostname)"
        else
            echo "    Mode: Production (→ $hostname)"
            echo "    ⚠️  WARNING: Running in production mode, not mock!"
        fi
        echo ""
        echo "  ✓ Mock Server (mock-audiobookbay): Running"
        echo ""
        echo "============================================"
        echo ""
        echo "Containers are running normally."
        echo "(use --force to force kill for a clean restart)"
        echo ""
        echo "Access Points:"
        echo "  Main App:     http://localhost:5078"
        echo "  Mock Server:  http://localhost:9999"
        echo "  Health Check: http://localhost:9999/health"
        echo ""
        echo "Commands:"
        echo "  Check status:       ./start-mock.sh --check"
        echo "  List queries:       ./start-mock.sh --list"
        echo "  Force restart:      ./start-mock.sh --force"
        echo "  View logs:          docker-compose -f docker-compose.mock.yml logs -f"
        echo ""
        exit 0
    elif [ "$MAIN_RUNNING" -eq 1 ] || [ "$MOCK_RUNNING" -eq 1 ]; then
        echo "============================================"
        echo "  ⚠️  Partial Deployment Detected"
        echo "============================================"
        echo ""

        if [ "$MAIN_RUNNING" -eq 1 ]; then
            echo "  ✓ Main App (audiobookbay-automated): Running"
        else
            echo "  ✗ Main App (audiobookbay-automated): Not running"
        fi

        if [ "$MOCK_RUNNING" -eq 1 ]; then
            echo "  ✓ Mock Server (mock-audiobookbay): Running"
        else
            echo "  ✗ Mock Server (mock-audiobookbay): Not running"
        fi

        echo ""
        echo "Some containers are running but not all."
        echo "Use --force to clean up and restart everything."
        echo ""
        echo "  ./start-mock.sh --force"
        echo ""
        exit 1
    fi
fi

echo "============================================"
echo "  AudiobookBay Mock Server Quick Start"
echo "============================================"
echo ""

echo "Cleaning up existing containers..."
echo ""

# Stop and remove any existing containers that might conflict
# Using || true to continue even if containers don't exist
docker stop audiobookbay-automated 2>/dev/null || true
docker rm audiobookbay-automated 2>/dev/null || true
docker stop mock-audiobookbay 2>/dev/null || true
docker rm mock-audiobookbay 2>/dev/null || true

# Also clean up any containers from docker-compose.mock.yml
docker-compose -f docker-compose.mock.yml down 2>/dev/null || true

echo "✓ Cleanup complete"
echo ""
echo "Starting mock server and main app..."
echo ""

# Start services
docker-compose -f docker-compose.mock.yml up --build -d

echo ""
echo "✓ Services started!"
echo ""
echo "============================================"
echo "  Access Points"
echo "============================================"
echo ""
echo "  Main App:     http://localhost:5078"
echo "  Mock Server:  http://localhost:9999"
echo "  Health Check: http://localhost:9999/health"
echo ""
echo "============================================"
echo "  Available Test Queries"
echo "============================================"
echo ""

# Dynamically list queries from mock_abb.py
if [ -f "app/mock_abb.py" ]; then
    grep -A 100 "^KNOWN_QUERIES = {" app/mock_abb.py | grep '".*":' | sed 's/^[[:space:]]*//' | while read -r line; do
        if [[ $line =~ \"([^\"]+)\" ]]; then
            query="${BASH_REMATCH[1]}"
            echo "  • $query"
        fi
    done
else
    echo "  (unable to load query list)"
fi

echo ""
echo "  Note: Any other query will return 'no results'"
echo ""

echo "============================================"
echo "  Error Simulation Examples"
echo "============================================"
echo ""
echo "  Rate limit:  search for 'test _mock_error=507'"
echo "  Not found:   search for 'test _mock_error=404'"
echo "  Timeout:     search for 'test _mock_error=timeout'"
echo ""
echo "============================================"
echo "  Useful Commands"
echo "============================================"
echo ""
echo "  View logs:        docker-compose -f docker-compose.mock.yml logs -f"
echo "  Stop services:    docker-compose -f docker-compose.mock.yml down"
echo "  Restart:          docker-compose -f docker-compose.mock.yml restart"
echo ""
echo "Press Ctrl+C to stop viewing logs (services will keep running)"
echo ""

# Follow logs
docker-compose -f docker-compose.mock.yml logs -f
