#!/usr/bin/env python3
"""
Quick API test script for AudiobookBay mock server

Usage:
    python test-api.py                              # Test with default query "test"
    python test-api.py "crime and punishment"       # Test specific query
    python test-api.py "test" --error 507           # Simulate rate limiting
    python test-api.py "test" --error 429           # Simulate too many requests
    python test-api.py "test" --delay 3             # Add 3 second delay
    python test-api.py "test" --host localhost:5078 # Custom host
    python test-api.py --help                       # Show help
"""

import sys
import argparse
import json
import requests
from urllib.parse import urlencode

# ANSI color codes
GREEN = '\033[92m'
YELLOW = '\033[93m'
RED = '\033[91m'
BLUE = '\033[94m'
CYAN = '\033[96m'
BOLD = '\033[1m'
RESET = '\033[0m'


def color_text(text, color):
    """Wrap text in color codes"""
    return f"{color}{text}{RESET}"


def print_header(text):
    """Print a header with decoration"""
    print(f"\n{BLUE}{'='*50}{RESET}")
    print(f"{BLUE}{text:^50}{RESET}")
    print(f"{BLUE}{'='*50}{RESET}\n")


def test_api(query, host="localhost:5078", mock_error=None, mock_delay=None, raw=False):
    """
    Test the AudiobookBay JSON API

    Args:
        query: Search query string
        host: API host (default: localhost:5078)
        mock_error: Error code to simulate (507, 429, 404, 500, timeout)
        mock_delay: Delay in seconds
        raw: If True, print raw JSON only
    """
    # Build URL
    params = {"q": query}

    if mock_error:
        params["_mock_error"] = mock_error

    if mock_delay:
        params["_mock_delay"] = mock_delay

    url = f"http://{host}/api/search?{urlencode(params)}"

    if not raw:
        print_header("AudiobookBay API Test")
        print(f"{CYAN}Query:{RESET}      {query}")
        print(f"{CYAN}Host:{RESET}       {host}")
        print(f"{CYAN}URL:{RESET}        {url}")

        if mock_error:
            print(f"{YELLOW}Mock Error:{RESET} {mock_error}")

        if mock_delay:
            print(f"{YELLOW}Mock Delay:{RESET} {mock_delay}s")

        print()

    try:
        # Make request
        response = requests.get(url, timeout=30)
        status_code = response.status_code

        if not raw:
            # Show status
            if status_code == 200:
                print(f"{GREEN}✓ HTTP {status_code}{RESET}\n")
            else:
                print(f"{RED}✗ HTTP {status_code}{RESET}\n")

        # Parse JSON
        try:
            data = response.json()

            if raw:
                # Raw JSON output for machine parsing
                print(json.dumps(data, indent=2))
            else:
                # Pretty formatted output
                print(json.dumps(data, indent=2))
                print()

                # Show summary
                print(f"{BLUE}{'='*50}{RESET}")
                print(f"{CYAN}{BOLD}Summary:{RESET}")

                result_count = data.get('result_count', 0)
                print(f"  Results: {GREEN}{result_count}{RESET}")

                # Show first result
                if result_count > 0:
                    first = data['results'][0]
                    print(f"\n{CYAN}{BOLD}First Result:{RESET}")
                    print(f"  Title:    {first.get('title', 'N/A')}")
                    print(f"  Format:   {first.get('format', 'N/A')}")
                    print(f"  Size:     {first.get('file_size', 'N/A')}")
                    print(f"  Language: {first.get('language', 'N/A')}")

                # Show warning if present
                if 'warning' in data:
                    print(f"\n{YELLOW}⚠ Warning: {data['warning']}{RESET}")

                # Show error if present
                if 'error' in data:
                    print(f"\n{RED}✗ Error: {data['error']}{RESET}")

                print(f"{BLUE}{'='*50}{RESET}\n")

            return 0

        except json.JSONDecodeError:
            # Not JSON
            if not raw:
                print(f"{RED}✗ Invalid JSON response{RESET}")
                print(f"\n{YELLOW}Response body:{RESET}")
                print(response.text[:500])
            else:
                print(response.text)
            return 1

    except requests.exceptions.Timeout:
        if not raw:
            print(f"{RED}✗ Request timeout{RESET}")
        else:
            print(json.dumps({"error": "Request timeout"}))
        return 1

    except requests.exceptions.ConnectionError:
        if not raw:
            print(f"{RED}✗ Connection failed{RESET}")
            print(f"\nIs the server running on {host}?")
            print(f"Try: docker-compose -f docker-compose.mock.yml up")
        else:
            print(json.dumps({"error": "Connection failed"}))
        return 1

    except Exception as e:
        if not raw:
            print(f"{RED}✗ Error: {e}{RESET}")
        else:
            print(json.dumps({"error": str(e)}))
        return 1


def main():
    parser = argparse.ArgumentParser(
        description='Test AudiobookBay JSON API with mock server',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                              # Test with default query "test"
  %(prog)s "crime and punishment"       # Test specific query
  %(prog)s "test" --error 507           # Simulate rate limiting
  %(prog)s "test" --error 429           # Simulate too many requests
  %(prog)s "test" --delay 3             # Add 3 second delay
  %(prog)s "test" --host localhost:5078 # Custom host
  %(prog)s "test" --raw                 # Raw JSON output (for scripts)

Error Codes:
  507      - Rate limit (Insufficient Storage)
  429      - Too Many Requests
  404      - Not Found
  500      - Server Error
  timeout  - Timeout (20 second delay)
        """
    )

    parser.add_argument('query', nargs='?', default='test',
                        help='Search query (default: test)')
    parser.add_argument('--host', default='localhost:5078',
                        help='API host (default: localhost:5078)')
    parser.add_argument('--error', dest='mock_error',
                        help='Simulate error (507, 429, 404, 500, timeout)')
    parser.add_argument('--delay', type=int, dest='mock_delay',
                        help='Add response delay in seconds')
    parser.add_argument('--raw', action='store_true',
                        help='Output raw JSON only (for machine parsing)')

    args = parser.parse_args()

    return test_api(
        query=args.query,
        host=args.host,
        mock_error=args.mock_error,
        mock_delay=args.mock_delay,
        raw=args.raw
    )


if __name__ == '__main__':
    sys.exit(main())
