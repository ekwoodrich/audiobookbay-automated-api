# API Testing Cheatsheet

Quick reference for testing the AudiobookBay API with the mock server.

## 🚀 Quick Commands

### Basic Tests

```bash
# Default test (query: "test")
python3 test-api.py

# Specific query
python3 test-api.py "crime and punishment"
python3 test-api.py "holy bible"
python3 test-api.py "christmas carol"
```

### Error Simulation

```bash
# Rate limiting (507)
python3 test-api.py "test" --error 507

# Too many requests (429)
python3 test-api.py "test" --error 429

# Not found (404)
python3 test-api.py "test" --error 404

# Server error (500)
python3 test-api.py "test" --error 500

# Timeout (20 second delay)
python3 test-api.py "test" --error timeout
```

### Response Delay

```bash
# Add 3 second delay
python3 test-api.py "test" --delay 3

# Add 10 second delay
python3 test-api.py "test" --delay 10
```

### For Agentic Tools / Scripts

```bash
# Raw JSON output (no formatting)
python3 test-api.py "test" --raw

# Parse with jq
python3 test-api.py "test" --raw | jq '.result_count'

# Get first result title
python3 test-api.py "test" --raw | jq -r '.results[0].title'

# Check for errors
python3 test-api.py "test" --error 507 --raw | jq '.error'
```

## 📊 Expected Responses

### Successful Search (200)

```json
{
  "query": "test",
  "result_count": 43,
  "results": [
    {
      "title": "Book Title",
      "link": "http://...",
      "cover": "http://...",
      "language": "English",
      "post_date": "22 Nov 2025",
      "format": "M4B",
      "bitrate": "64 Kbps",
      "file_size": "265.79 MBs"
    }
  ]
}
```

### Rate Limit Error (507)

```bash
python3 test-api.py "test" --error 507 --raw
```

Response body will contain error message from the main app.

### No Results

```bash
python3 test-api.py "unknownquery12345" --raw
```

```json
{
  "query": "unknownquery12345",
  "result_count": 0,
  "results": []
}
```

## 🔧 Advanced Usage

### Custom Host

```bash
# Test against different port
python3 test-api.py "test" --host localhost:8080

# Test against production (be careful!)
python3 test-api.py "test" --host your-domain.com:5078
```

### Environment Variable Override

```bash
# Use environment variable for host
export ABB_API_HOST=localhost:8080
python3 test-api.py "test"
```

### Bash Script Version

```bash
# Simple test
./test-api.sh

# With query
./test-api.sh "crime and punishment"

# With error
./test-api.sh "test" 507

# With delay
./test-api.sh "test" "" 3
```

## 🤖 Integration Examples

### In Python Scripts

```python
import subprocess
import json

# Run test and get JSON
result = subprocess.run(
    ['python3', 'test-api.py', 'test', '--raw'],
    capture_output=True,
    text=True
)

data = json.loads(result.stdout)
print(f"Found {data['result_count']} results")
```

### In Bash Scripts

```bash
#!/bin/bash

# Get result count
RESULT=$(python3 test-api.py "test" --raw)
COUNT=$(echo "$RESULT" | jq -r '.result_count')

echo "Found $COUNT results"

# Test for error
if echo "$RESULT" | jq -e '.error' > /dev/null; then
    echo "Error occurred"
    exit 1
fi
```

### As Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Testing API..."
python3 test-api.py "test" --raw > /dev/null

if [ $? -ne 0 ]; then
    echo "API test failed!"
    exit 1
fi

echo "API test passed!"
```

## 📝 All Available Queries

Mock server has pre-captured responses for:

- `test` (43 results, 2 pages)
- `crime and punishment` (multiple results, 2 pages)
- `holy bible` (multiple results, 2 pages)
- `christmas carol` (multiple results, 2 pages)
- Any other query returns no results

## 🎯 Testing Checklist

Use this checklist when testing changes:

```bash
# ✓ Normal search works
python3 test-api.py "test"

# ✓ No results handled
python3 test-api.py "unknownquery"

# ✓ Rate limit error (507)
python3 test-api.py "test" --error 507

# ✓ Too many requests (429)
python3 test-api.py "test" --error 429

# ✓ Not found (404)
python3 test-api.py "test" --error 404

# ✓ Server error (500)
python3 test-api.py "test" --error 500

# ✓ Timeout handling
python3 test-api.py "test" --error timeout

# ✓ Response delay
python3 test-api.py "test" --delay 3
```

## 📚 Help

```bash
# Get full help
python3 test-api.py --help

# View this cheatsheet
cat TEST_API_CHEATSHEET.md

# View full documentation
cat MOCK_SERVER.md
```
