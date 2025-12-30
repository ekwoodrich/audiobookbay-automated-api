# Mock AudiobookBay Server Documentation

## Overview

The Mock AudiobookBay Server simulates the audiobookbay.lu website for development and testing purposes. It eliminates the risk of hitting rate limits while developing new features or testing the application.

## Features

✅ **No Rate Limits** - Test freely without 24-hour lockouts
✅ **Error Simulation** - Test error handling with simple query parameters
✅ **Fast Responses** - Instant responses from local files
✅ **Offline Development** - Works without internet connection
✅ **Easy Toggle** - Switch between mock and real server with one env var

## Quick Start

### Option 1: Docker Compose (Recommended)

Start both the mock server and main app in mock mode:

```bash
docker-compose -f docker-compose.mock.yml up --build
```

This will:
- Start mock server on port 9999
- Start main app on port 5078 (configured to use mock server)
- Create a Docker network for communication

Access the app at http://localhost:5078

### Option 2: Run Mock Server Standalone

```bash
# From the app directory
cd app
python3 mock_abb.py

# Or on a custom port
python3 mock_abb.py --port 8888
```

Then configure your main app to use it:

```bash
# In .env file
ABB_MOCK_MODE=true
ABB_HOSTNAME=localhost:9999
ABB_SCHEME=http
```

### Option 3: Local Development (No Docker)

```bash
# Terminal 1: Start mock server
cd app
python3 mock_abb.py

# Terminal 2: Start main app with mock mode
cd app
export ABB_MOCK_MODE=true
export ABB_HOSTNAME=localhost:9999
export ABB_SCHEME=http
python3 app.py
```

## Available Test Queries

The mock server has pre-captured responses for these queries:

| Query | Results | Pages |
|-------|---------|-------|
| `test` | 43 books | 2 pages |
| `crime and punishment` | Multiple | 2 pages |
| `holy bible` | Multiple | 2 pages |
| `christmas carol` | Multiple | 2 pages |
| Any other query | No results | 1 page |

## Error Simulation

Test error handling by adding `_mock_error` parameter to any search query:

### Rate Limiting (507 Insufficient Storage)

This simulates the AudiobookBay rate limit error:

```bash
# Via curl
curl "http://localhost:5078/api/search?q=test&_mock_error=507"

# Via web UI - search for:
test _mock_error=507
```

**Expected Response:**
```
HTTP 507 Insufficient Storage
```

The main app will show: *"AudiobookBay is currently experiencing server issues (507 error). This may be due to rate limiting or server maintenance."*

### Too Many Requests (429)

```bash
curl "http://localhost:5078/api/search?q=test&_mock_error=429"
```

**Expected Response:**
```
HTTP 429 Too Many Requests
```

The main app will show: *"Rate limit exceeded. Please wait a few minutes before searching again."*

### Not Found (404)

```bash
curl "http://localhost:5078/api/search?q=test&_mock_error=404"
```

**Expected Response:**
```
HTTP 404 Not Found
```

The main app will show: *"The requested page was not found on AudiobookBay."*

### Server Error (500)

```bash
curl "http://localhost:5078/api/search?q=test&_mock_error=500"
```

**Expected Response:**
```
HTTP 500 Internal Server Error
```

The main app will show: *"Failed to connect to AudiobookBay: 500 Server Error"*

### Timeout

Simulates a slow/hanging request (delays 20 seconds then times out):

```bash
curl "http://localhost:5078/api/search?q=test&_mock_error=timeout"
```

**Note:** This will hang for 20 seconds before returning a timeout error.

The main app will show: *"Request timed out. AudiobookBay may be slow or unreachable."*

## Response Delay Simulation

Add artificial delays to test loading states:

```bash
# Add 3 second delay
curl "http://localhost:5078/api/search?q=test&_mock_delay=3"

# Add 10 second delay
curl "http://localhost:5078/api/search?q=test&_mock_delay=10"
```

## Direct Mock Server Testing

Test the mock server directly without the main app:

### Health Check

```bash
curl http://localhost:9999/health
```

**Response:**
```json
{
  "status": "ok",
  "mock": true,
  "available_queries": ["test", "crime and punishment", "holy bible", "christmas carol"]
}
```

### Search Endpoint

```bash
# Regular search
curl "http://localhost:9999/page/1/?s=test"

# With error simulation
curl "http://localhost:9999/page/1/?s=test&_mock_error=507"
```

### Detail Page

```bash
curl "http://localhost:9999/audio-books/crime-and-punishment"

# With error
curl "http://localhost:9999/audio-books/some-book?_mock_error=429"
```

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ABB_MOCK_MODE` | `false` | Enable mock mode |
| `ABB_HOSTNAME` | `audiobookbay.lu` | Set to `localhost:9999` for mock |
| `ABB_SCHEME` | `https` | Set to `http` for mock |

### .env File Example (Mock Mode)

```env
# Mock Server Configuration
ABB_MOCK_MODE=true
ABB_HOSTNAME=localhost:9999
ABB_SCHEME=http

# Other settings remain the same
DOWNLOAD_CLIENT=qbittorrent
DL_HOST=10.0.0.130
DL_PORT=4512
DL_USERNAME=admin
DL_PASSWORD=yourpassword
DL_CATEGORY=abb-downloader
SAVE_PATH_BASE=/audiobooks
PAGE_LIMIT=5
FLASK_PORT=5078
```

### .env File Example (Production Mode)

```env
# Production Configuration (real audiobookbay.lu)
ABB_MOCK_MODE=false
ABB_HOSTNAME=audiobookbay.lu
ABB_SCHEME=https

# Other settings...
```

## Adding New Test Data

To add new test queries to the mock server:

### 1. Enable Debug Mode and Capture Responses

```env
DEBUG_RESPONSES=true
DEBUG_DIR=debug
ABB_MOCK_MODE=false  # Use real server
```

### 2. Make Searches

Search for the books you want to capture via the web UI or API.

### 3. Organize Captured Files

```bash
# Files are saved to debug/ with timestamps
# Copy them to mock_data with meaningful names:

cp debug/TIMESTAMP_search_QUERY_page1.html app/mock_data/search/QUERY_page1.html
cp debug/TIMESTAMP_detail_SLUG.html app/mock_data/detail/SLUG_detail.html
```

### 4. Update Mock Server

Edit `app/mock_abb.py` and add your query to `KNOWN_QUERIES`:

```python
KNOWN_QUERIES = {
    "test": "test",
    "crime and punishment": "crime_and_punishment",
    "your new query": "your_new_query",  # Add this
}
```

### 5. Rebuild Docker Image

```bash
docker-compose -f docker-compose.mock.yml up --build
```

## Troubleshooting

### Mock server not responding

**Check if it's running:**
```bash
curl http://localhost:9999/health
```

**Check logs:**
```bash
docker logs mock-audiobookbay
```

### Main app still connecting to real audiobookbay.lu

**Verify environment variables:**
```bash
docker exec audiobookbay-automated env | grep ABB
```

Should show:
```
ABB_MOCK_MODE=True
ABB_HOSTNAME=mock-abb:9999
ABB_SCHEME=http
```

### Connection refused errors

If using Docker Compose, ensure both containers are on the same network:
```bash
docker network inspect audiobookbay-automated_abb-network
```

If running locally, ensure mock server is started before main app.

### No results for known queries

**Check mock_data files exist:**
```bash
ls app/mock_data/search/
```

**Check query normalization:**
The mock server normalizes queries (lowercase, replace spaces with underscores). Ensure your files match this pattern.

## Testing Workflow

### Development Workflow

1. **Start in mock mode** for rapid development:
   ```bash
   docker-compose -f docker-compose.mock.yml up
   ```

2. **Make changes** to app.py or other files

3. **Test with various scenarios**:
   - Normal searches
   - Error conditions (`_mock_error=507`, etc.)
   - Edge cases

4. **When ready**, test against real server:
   ```env
   ABB_MOCK_MODE=false
   ```

### Testing Checklist

- [ ] Normal search returns results
- [ ] Search with no results handled correctly
- [ ] Detail page loads and extracts magnet link
- [ ] 507 error shows rate limit message
- [ ] 429 error shows too many requests message
- [ ] 404 error handled gracefully
- [ ] 500 error handled gracefully
- [ ] Timeout handled (15 second timeout)
- [ ] Download workflow works end-to-end

## Quick Testing from Terminal

### Using test-api.py (Recommended)

The easiest way to test the API:

```bash
# Basic test
python3 test-api.py

# Test specific query
python3 test-api.py "crime and punishment"

# Test error scenarios
python3 test-api.py "test" --error 507      # Rate limit
python3 test-api.py "test" --error 429      # Too many requests
python3 test-api.py "test" --error 404      # Not found
python3 test-api.py "test" --error 500      # Server error
python3 test-api.py "test" --error timeout  # Timeout

# Add delay
python3 test-api.py "test" --delay 5

# Raw JSON output (for scripts/agentic tools)
python3 test-api.py "test" --raw

# Get help
python3 test-api.py --help
```

### Using test-api.sh (Bash version)

```bash
# Basic test
./test-api.sh

# Test with query
./test-api.sh "christmas carol"

# Test with error
./test-api.sh "test" 507

# Test with delay
./test-api.sh "test" "" 3
```

## API Examples

### Python

```python
import requests

# Search with mock server
response = requests.get("http://localhost:5078/api/search", params={"q": "test"})
print(response.json())

# Test rate limiting
response = requests.get("http://localhost:5078/api/search",
                       params={"q": "test", "_mock_error": "507"})
print(response.status_code)  # Should be 507
```

### cURL

```bash
# Normal search
curl "http://localhost:5078/api/search?q=test" | jq

# Test error handling
curl -i "http://localhost:5078/api/search?q=test&_mock_error=507"

# Download a book (won't actually download in mock mode)
curl -X POST http://localhost:5078/api/download \
  -H "Content-Type: application/json" \
  -d '{"link": "http://localhost:9999/audio-books/test-book", "title": "Test Book"}'
```

## Architecture

```
┌─────────────────────────────────────┐
│  User / Test Client                 │
└────────────┬────────────────────────┘
             │
             ↓
┌─────────────────────────────────────┐
│  Main App (port 5078)               │
│  - app.py                           │
│  - Checks ABB_MOCK_MODE             │
│  - Routes requests based on mode    │
└────────────┬────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ↓                 ↓
┌─────────┐   ┌──────────────────┐
│  Real   │   │  Mock Server     │
│  ABB    │   │  (port 9999)     │
│  Server │   │  - mock_abb.py   │
└─────────┘   │  - mock_data/    │
              └──────────────────┘
```

## Advantages Over Real Server

| Feature | Real Server | Mock Server |
|---------|-------------|-------------|
| Rate Limits | ❌ Yes (24hr) | ✅ None |
| Requires Internet | ❌ Yes | ✅ No |
| Response Time | ❌ Variable | ✅ Instant |
| Error Testing | ❌ Hard | ✅ Easy |
| Cost | ✅ Free | ✅ Free |
| Real Data | ✅ Yes | ❌ Static |

## License

Same as main project.
