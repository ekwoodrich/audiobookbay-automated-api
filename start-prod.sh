#!/bin/bash
# Start script for production mode (connects to real audiobookbay.lu)

set -e

# Function to check container status
check_status() {
    echo "============================================"
    echo "  Production Server Container Status"
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
        scheme=$(docker exec audiobookbay-automated env 2>/dev/null | grep "^ABB_SCHEME=" | cut -d= -f2)

        if [ "$mock_mode" == "true" ]; then
            echo "    Mode: Mock (→ $hostname)"
            echo "    ⚠️  WARNING: Container is in MOCK mode, not production!"
        else
            echo "    Mode: Production (→ $scheme://$hostname)"
        fi
    else
        echo "  ✗ Main App (audiobookbay-automated): Not running"
    fi

    echo ""

    # Check if mock server is also running (shouldn't be for prod)
    if docker ps --format '{{.Names}}' | grep -q '^mock-audiobookbay$'; then
        status=$(docker ps --filter "name=^mock-audiobookbay$" --format "{{.Status}}")
        echo "  ⚠️  Mock Server (mock-audiobookbay): Running"
        echo "    Status: $status"
        echo "    Note: Mock server not needed in production mode"
    fi

    echo ""
    echo "============================================"
    echo ""

    # Show access points if running
    if docker ps --format '{{.Names}}' | grep -q '^audiobookbay-automated$'; then
        echo "Access Points:"
        echo "  Main App: http://localhost:5078"
        echo ""
    fi
}

# Check for --check flag
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

# Check if container is already running (unless --force)
if [ "$FORCE_RESTART" == "false" ]; then
    MAIN_RUNNING=$(docker ps --format '{{.Names}}' | grep -c '^audiobookbay-automated$' || true)

    if [ "$MAIN_RUNNING" -eq 1 ]; then
        echo "============================================"
        echo "  Production Server Already Running"
        echo "============================================"
        echo ""

        # Check configuration
        mock_mode=$(docker exec audiobookbay-automated env 2>/dev/null | grep "^ABB_MOCK_MODE=" | cut -d= -f2)
        hostname=$(docker exec audiobookbay-automated env 2>/dev/null | grep "^ABB_HOSTNAME=" | cut -d= -f2)
        scheme=$(docker exec audiobookbay-automated env 2>/dev/null | grep "^ABB_SCHEME=" | cut -d= -f2)

        echo "  ✓ Main App (audiobookbay-automated): Running"
        if [ "$mock_mode" == "true" ]; then
            echo "    Mode: Mock (→ $hostname)"
            echo "    ⚠️  WARNING: Running in MOCK mode, not production!"
        else
            echo "    Mode: Production (→ $scheme://$hostname)"
        fi
        echo ""
        echo "============================================"
        echo ""
        echo "Container is running normally."
        echo "(use --force to force kill for a clean restart)"
        echo ""
        echo "Access Points:"
        echo "  Main App: http://localhost:5078"
        echo ""
        echo "Commands:"
        echo "  Check status:       ./start-prod.sh --check"
        echo "  Force restart:      ./start-prod.sh --force"
        echo "  View logs:          docker logs -f audiobookbay-automated"
        echo "  Switch to mock:     ./start-mock.sh --force"
        echo ""
        exit 0
    fi

    # Check if mock server is running (shouldn't be for prod)
    MOCK_RUNNING=$(docker ps --format '{{.Names}}' | grep -c '^mock-audiobookbay$' || true)
    if [ "$MOCK_RUNNING" -eq 1 ]; then
        echo "============================================"
        echo "  ⚠️  Mock Server Running"
        echo "============================================"
        echo ""
        echo "  ⚠️  Mock Server (mock-audiobookbay): Running"
        echo "  ✗ Main App (audiobookbay-automated): Not running"
        echo ""
        echo "Mock server is running but main app is not."
        echo "Use --force to clean up and start in production mode."
        echo ""
        echo "  ./start-prod.sh --force"
        echo ""
        echo "Or switch to mock mode:"
        echo ""
        echo "  ./start-mock.sh"
        echo ""
        exit 1
    fi
fi

echo "============================================"
echo "  AudiobookBay Production Mode"
echo "============================================"
echo ""

echo "⚠️  WARNING: Production Mode"
echo "This will connect to the REAL audiobookbay.lu server."
echo "Be careful of rate limits (24+ hour lockouts)!"
echo ""

# Give user a chance to cancel
echo "Starting in 3 seconds... (Ctrl+C to cancel)"
sleep 3
echo ""

echo "Cleaning up existing containers..."
echo ""

# Stop and remove any existing containers that might conflict
# Using || true to continue even if containers don't exist
docker stop audiobookbay-automated 2>/dev/null || true
docker rm audiobookbay-automated 2>/dev/null || true
docker stop mock-audiobookbay 2>/dev/null || true
docker rm mock-audiobookbay 2>/dev/null || true

# Clean up any docker-compose containers
docker-compose -f docker-compose.mock.yml down 2>/dev/null || true
docker-compose -f docker-compose.prod.yml down 2>/dev/null || true

echo "✓ Cleanup complete"
echo ""
echo "Starting main app in production mode..."
echo ""

# Start services
docker-compose -f docker-compose.prod.yml up --build -d

echo ""
echo "✓ Service started!"
echo ""
echo "============================================"
echo "  Access Points"
echo "============================================"
echo ""
echo "  Main App:  http://localhost:5078"
echo ""
echo "============================================"
echo "  Configuration"
echo "============================================"
echo ""

# Show configuration
docker exec audiobookbay-automated env | grep -E "ABB_MOCK|ABB_HOSTNAME|ABB_SCHEME" || echo "  (using .env file settings)"

echo ""
echo "============================================"
echo "  ⚠️  IMPORTANT REMINDERS"
echo "============================================"
echo ""
echo "  • You are connecting to REAL audiobookbay.lu"
echo "  • Rate limits apply (24+ hour lockouts possible)"
echo "  • Test sparingly to avoid lockouts"
echo "  • Use ./start-mock.sh for development/testing"
echo ""
echo "============================================"
echo "  Useful Commands"
echo "============================================"
echo ""
echo "  View logs:        docker logs -f audiobookbay-automated"
echo "  Stop service:     docker-compose -f docker-compose.prod.yml down"
echo "  Restart:          docker-compose -f docker-compose.prod.yml restart"
echo "  Switch to mock:   ./start-mock.sh"
echo ""
