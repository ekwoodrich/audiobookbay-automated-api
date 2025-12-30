#!/usr/bin/env python3
"""
Mock AudiobookBay Server for Testing

This mock server simulates the audiobookbay.lu website for testing purposes
without hitting rate limits. It serves captured HTML responses and can simulate
various error conditions.

Usage:
    python mock_abb.py                    # Start on default port 9999
    python mock_abb.py --port 8888        # Start on custom port

Error Simulation:
    Add query parameters to trigger errors:
    - ?s=test&_mock_error=507         # Rate limit (507 Insufficient Storage)
    - ?s=test&_mock_error=429         # Too Many Requests
    - ?s=test&_mock_error=404         # Not Found
    - ?s=test&_mock_error=500         # Server Error
    - ?s=test&_mock_error=timeout     # Simulate timeout (hangs for 20s)
    - ?s=test&_mock_delay=3           # Add 3 second delay to response
"""

import os
import time
import argparse
from flask import Flask, request, send_file, abort, Response
from pathlib import Path

app = Flask(__name__)

# Configuration
MOCK_DATA_DIR = Path(__file__).parent / "mock_data"
SEARCH_DIR = MOCK_DATA_DIR / "search"
DETAIL_DIR = MOCK_DATA_DIR / "detail"

# Known queries mapping (query -> file prefix)
KNOWN_QUERIES = {
    "christmas carol": "christmas_carol",
    "crime and punishment": "crime_and_punishment",
    "holy bible": "holy_bible",
    "test": "test",
}

# Color codes for terminal output
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BLUE = "\033[94m"
RESET = "\033[0m"


def log_request(status_code, method, path, message=""):
    """Log requests with color coding"""
    if status_code < 300:
        color = GREEN
    elif status_code < 400:
        color = YELLOW
    else:
        color = RED

    print(f"{color}[{status_code}]{RESET} {method} {path} {message}")


def normalize_query(query):
    """Normalize query string for file matching"""
    return query.lower().strip().replace(" ", "_").replace("+", "_")


def get_search_file(query, page=1):
    """Find the appropriate search result file for a query and page"""
    normalized = normalize_query(query)

    # Check if we have this query in our known queries
    for known_query, file_prefix in KNOWN_QUERIES.items():
        if normalized == normalize_query(known_query):
            file_path = SEARCH_DIR / f"{file_prefix}_page{page}.html"
            if file_path.exists():
                return file_path

    # If no match or file doesn't exist, return no_results
    return SEARCH_DIR / "no_results.html"


def get_detail_file(url_path):
    """Find the appropriate detail page file"""
    # For now, we have one detail page
    # In future, could extract slug and match to specific files
    detail_file = DETAIL_DIR / "crime_and_punishment_detail.html"
    if detail_file.exists():
        return detail_file

    # If no detail file exists, return 404
    return None


@app.route('/page/<int:page>/')
def search_page(page):
    """Handle search requests: /page/{page}/?s={query}"""
    query = request.args.get('s', '')

    # Check for error simulation
    mock_error = request.args.get('_mock_error')
    mock_delay = request.args.get('_mock_delay')

    # Add delay if requested
    if mock_delay:
        try:
            delay = int(mock_delay)
            log_request(200, "GET", request.path, f"(delaying {delay}s)")
            time.sleep(delay)
        except ValueError:
            pass

    # Simulate timeout
    if mock_error == 'timeout':
        log_request(408, "GET", request.path, f"?s={query} (timeout simulation - hanging for 20s)")
        time.sleep(20)
        abort(408)

    # Simulate rate limiting (507 Insufficient Storage)
    if mock_error == '507':
        log_request(507, "GET", request.path, f"?s={query} (rate limit)")
        abort(507)

    # Simulate too many requests
    if mock_error == '429':
        log_request(429, "GET", request.path, f"?s={query} (too many requests)")
        abort(429)

    # Simulate not found
    if mock_error == '404':
        log_request(404, "GET", request.path, f"?s={query} (not found)")
        abort(404)

    # Simulate server error
    if mock_error == '500':
        log_request(500, "GET", request.path, f"?s={query} (server error)")
        abort(500)

    # Get the appropriate file
    file_path = get_search_file(query, page)

    if not file_path.exists():
        log_request(404, "GET", request.path, f"?s={query} (file not found)")
        abort(404)

    log_request(200, "GET", request.path, f"?s={query} page={page}")
    return send_file(file_path, mimetype='text/html')


@app.route('/audio-books/<path:book_slug>')
@app.route('/abss/<path:book_slug>')
def book_detail(book_slug):
    """Handle book detail pages"""

    # Check for error simulation
    mock_error = request.args.get('_mock_error')
    mock_delay = request.args.get('_mock_delay')

    # Add delay if requested
    if mock_delay:
        try:
            delay = int(mock_delay)
            log_request(200, "GET", request.path, f"(delaying {delay}s)")
            time.sleep(delay)
        except ValueError:
            pass

    # Simulate errors
    if mock_error == 'timeout':
        log_request(408, "GET", request.path, f"{book_slug} (timeout simulation - hanging for 20s)")
        time.sleep(20)
        abort(408)

    if mock_error == '507':
        log_request(507, "GET", request.path, f"{book_slug} (rate limit)")
        abort(507)

    if mock_error == '429':
        log_request(429, "GET", request.path, f"{book_slug} (too many requests)")
        abort(429)

    if mock_error == '404':
        log_request(404, "GET", request.path, f"{book_slug} (not found)")
        abort(404)

    if mock_error == '500':
        log_request(500, "GET", request.path, f"{book_slug} (server error)")
        abort(500)

    # Get detail file
    file_path = get_detail_file(book_slug)

    if not file_path or not file_path.exists():
        log_request(404, "GET", request.path, f"{book_slug} (no detail file)")
        abort(404)

    log_request(200, "GET", request.path, f"{book_slug}")
    return send_file(file_path, mimetype='text/html')


@app.route('/health')
def health():
    """Health check endpoint"""
    return {"status": "ok", "mock": True, "available_queries": list(KNOWN_QUERIES.keys())}


@app.route('/')
def index():
    """Show available test queries"""
    queries_list = "\n".join([f"  - {q}" for q in KNOWN_QUERIES.keys()])

    help_text = f"""
Mock AudiobookBay Server is Running!

Available test queries:
{queries_list}
  - (any other query will return no results)

Example URLs:
  - http://localhost:{{port}}/page/1/?s=test
  - http://localhost:{{port}}/page/1/?s=crime+and+punishment
  - http://localhost:{{port}}/audio-books/some-book-slug

Error Simulation:
  Add _mock_error parameter to simulate errors:
  - http://localhost:{{port}}/page/1/?s=test&_mock_error=507    (Rate limit)
  - http://localhost:{{port}}/page/1/?s=test&_mock_error=429    (Too many requests)
  - http://localhost:{{port}}/page/1/?s=test&_mock_error=404    (Not found)
  - http://localhost:{{port}}/page/1/?s=test&_mock_error=500    (Server error)
  - http://localhost:{{port}}/page/1/?s=test&_mock_error=timeout (Timeout - 20s)

  Add _mock_delay parameter to add response delay:
  - http://localhost:{{port}}/page/1/?s=test&_mock_delay=3      (3 second delay)

Health Check:
  - http://localhost:{{port}}/health

Configuration:
  Set ABB_HOSTNAME=localhost:{{port}} in your .env to use this mock server
  Set ABB_MOCK_MODE=true to enable mock mode in the main app
"""
    return Response(help_text, mimetype='text/plain')


def main():
    parser = argparse.ArgumentParser(description='Mock AudiobookBay Server')
    parser.add_argument('--port', type=int, default=9999, help='Port to run on (default: 9999)')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to (default: 0.0.0.0)')
    args = parser.parse_args()

    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}Mock AudiobookBay Server{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    print(f"Running on: {GREEN}http://{args.host}:{args.port}{RESET}")
    print(f"Health check: {GREEN}http://localhost:{args.port}/health{RESET}")
    print(f"\nAvailable test queries:")
    for query in KNOWN_QUERIES.keys():
        print(f"  {GREEN}✓{RESET} {query}")
    print(f"\n{YELLOW}Tip: Add ?_mock_error=507 to simulate rate limiting{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

    app.run(host=args.host, port=args.port, debug=False)


if __name__ == '__main__':
    main()
