# Mock Server Quick Start Guide

## 🚀 Fastest Way to Start

```bash
./start-mock.sh
```

**Smart behavior:**
- ✅ **If already running**: Shows status and exits (safe!)
- ✅ **If not running**: Cleans up and starts containers
- ✅ Lists all available test queries when starting
- ✅ Prevents accidental restarts

The mock server and main app are now running.

- **Main App**: http://localhost:5078
- **Mock Server**: http://localhost:9999

### 🔍 Quick Commands

```bash
# Start (or check if already running)
./start-mock.sh

# Force restart (skip running check)
./start-mock.sh --force

# Check container status
./start-mock.sh --check

# List available queries
./start-mock.sh --list

# Start production mode
./start-prod.sh

# Force restart production
./start-prod.sh --force
```

## 📋 What You Can Do

### Search for Test Queries

Open http://localhost:5078 and search for:
- `test`
- `crime and punishment`
- `holy bible`
- `christmas carol`

### Test Error Handling (Without Editing Config!)

Just include the error code in your search:

| Search Query | What It Does |
|--------------|--------------|
| `test _mock_error=507` | Simulates rate limiting |
| `test _mock_error=429` | Simulates too many requests |
| `test _mock_error=404` | Simulates page not found |
| `test _mock_error=500` | Simulates server error |
| `test _mock_error=timeout` | Simulates timeout (20s) |
| `test _mock_delay=5` | Adds 5 second delay |

**Example**: Search for `test _mock_error=507` in the web UI and you'll see the rate limit error message without actually hitting any limits!

## 🧪 How Testing Works

When you run `./start-mock.sh`, here's the flow:

```
test-api.py "test"
    ↓
localhost:5078 (main app with ABB_MOCK_MODE=true)
    ↓
mock-abb:9999 (mock server - returns cached HTML)
    ↓
Main app parses HTML → Returns JSON
```

**You're always testing through the main app**, which routes to the mock server automatically. No rate limits! 🎉

## 🔄 Switching Between Mock and Production

### Use Mock Server (Development)

```bash
# Option 1: Use start-mock.sh (recommended - handles cleanup)
./start-mock.sh

# Option 2: Use docker-compose directly
docker-compose -f docker-compose.mock.yml up --build -d

# Option 3: Update .env file
cp .env.mock .env
# Then restart your containers
```

### Use Real AudiobookBay (Production)

```bash
# Option 1: Use start-prod.sh (recommended - handles cleanup)
./start-prod.sh

# Option 2: Use docker-compose directly
docker-compose -f docker-compose.prod.yml up --build -d

# Option 3: Update .env file manually
cp .env.prod .env
# Then restart your containers
docker-compose -f docker-compose.prod.yml up -d
```

**⚠️ WARNING:** Production mode connects to the real audiobookbay.lu server. Be careful of rate limits!

## 🛠️ Common Commands

### Mock Mode (Development)

```bash
# Start mock server + app
./start-mock.sh

# Stop services
docker-compose -f docker-compose.mock.yml down

# View logs
docker-compose -f docker-compose.mock.yml logs -f

# Restart after code changes
docker-compose -f docker-compose.mock.yml up --build

# Check mock server health
curl http://localhost:9999/health
```

### Production Mode (Real Server)

```bash
# Start in production mode
./start-prod.sh

# Stop service
docker-compose -f docker-compose.prod.yml down

# View logs
docker logs -f audiobookbay-automated

# Restart
docker-compose -f docker-compose.prod.yml restart
```

### Quick Mode Switching

```bash
# Switch to mock (safe for testing)
./start-mock.sh

# Switch to production (⚠️ rate limits apply)
./start-prod.sh
```

## 🔄 Adding New Test Queries

Want to add more queries to the mock server? Follow this workflow:

### Step 1: Capture Real Responses

```bash
# Start in production mode with debug enabled
echo "DEBUG_RESPONSES=true" >> .env
./start-prod.sh

# Make searches through web UI or API
# Each search saves HTML + metadata to debug/
```

### Step 2: Sync to Mock Server

```bash
# Sync captured data to mock server
./sync-mock.sh
```

This script:
- ✅ Scans `debug/` for new captures
- ✅ Copies HTML files to `app/mock_data/`
- ✅ Updates `KNOWN_QUERIES` in `mock_abb.py`
- ✅ Shows summary of changes

### Step 3: Rebuild and Restart

```bash
# Rebuild mock server with new data
docker-compose -f docker-compose.mock.yml build mock-abb

# Restart mock server
./start-mock.sh

# Verify new queries are available
./start-mock.sh --list
```

### Step 4: Test New Queries

```bash
python3 test-api.py "your new query"
```

## 📝 Testing Workflow

1. **Start mock server** (instant, no rate limits)
2. **Make your changes** to app.py or other files
3. **Test thoroughly** with various error scenarios
4. **When confident**, test with real server (be careful of rate limits!)

## 🎯 Quick API Testing from Terminal

### Using the test-api.py script (Recommended for agentic tools)

```bash
# Simple test
python3 test-api.py

# Test specific query
python3 test-api.py "crime and punishment"

# Test error simulation
python3 test-api.py "test" --error 507      # Rate limit
python3 test-api.py "test" --error 429      # Too many requests
python3 test-api.py "test" --error timeout  # Timeout

# Add response delay
python3 test-api.py "test" --delay 5

# Raw JSON output (for scripts/agentic tools)
python3 test-api.py "test" --raw
python3 test-api.py "test" --error 507 --raw

# Custom host
python3 test-api.py "test" --host localhost:8080
```

### Using the bash script

```bash
# Simple test
./test-api.sh

# Test with query
./test-api.sh "christmas carol"

# Test with error
./test-api.sh "test" 507

# Test with delay
./test-api.sh "test" "" 3
```

### Using curl directly

```bash
# Search API
curl "http://localhost:5078/api/search?q=test" | jq

# Test rate limiting
curl "http://localhost:5078/api/search?q=test&_mock_error=507"

# Download API (won't actually download in mock mode)
curl -X POST http://localhost:5078/api/download \
  -H "Content-Type: application/json" \
  -d '{"link": "http://localhost:9999/audio-books/test", "title": "Test Book"}'
```

## 📊 Mock vs Production Comparison

| Feature | Mock Mode (`./start-mock.sh`) | Production Mode (`./start-prod.sh`) |
|---------|-------------------------------|-------------------------------------|
| **Server** | localhost:9999 (mock) | audiobookbay.lu (real) |
| **Rate Limits** | ✅ None | ❌ Yes (24+ hour lockouts) |
| **Internet Required** | ✅ No | ❌ Yes |
| **Speed** | ✅ Instant | ⏱️ Variable |
| **Error Testing** | ✅ Easy (`?_mock_error=507`) | ❌ Hard to trigger |
| **Data** | 📦 Static/cached | 🔄 Live/current |
| **Best For** | Development, testing, CI/CD | Production use, real downloads |
| **Containers** | Main app + Mock server | Main app only |

## 📚 Full Documentation

For complete documentation, see:
- [MOCK_SERVER.md](MOCK_SERVER.md) - Complete mock server documentation
- [README.md](README.md) - Main project documentation
- [TEST_API_CHEATSHEET.md](TEST_API_CHEATSHEET.md) - API testing reference

## ⚠️ Important Notes

- **Mock data is static** - You're testing with pre-captured HTML responses
- **No real downloads** - The mock server only returns HTML, not actual torrent info
- **Perfect for development** - Iterate quickly without worrying about rate limits
- **Always test production** - Before deploying, verify against real audiobookbay.lu

## 🐛 Troubleshooting

**Services won't start?**
```bash
# Check if ports are in use
docker ps
lsof -i :5078
lsof -i :9999

# Stop any conflicting containers
docker-compose down
```

**Not seeing mock responses?**
```bash
# Verify environment
docker exec audiobookbay-automated env | grep ABB

# Should show:
# ABB_MOCK_MODE=True
# ABB_HOSTNAME=mock-abb:9999
# ABB_SCHEME=http
```

**Need to reset everything?**
```bash
docker-compose -f docker-compose.mock.yml down -v
docker-compose -f docker-compose.mock.yml up --build
```
