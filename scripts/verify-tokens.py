#!/usr/bin/env python3
"""
Verify token count between yeet and Gemini API.

Usage:
    export GOOGLE_API_KEY=your_key_here
    pbpaste | python3 scripts/verify-tokens.py

Or with a file:
    python3 scripts/verify-tokens.py < somefile.txt
"""

import sys
import os

def main():
    content = sys.stdin.read()
    bytes_count = len(content.encode('utf-8'))

    print(f"Content size: {bytes_count:,} bytes")
    print(f"Content size: {len(content):,} characters")

    api_key = os.environ.get('GOOGLE_API_KEY')
    if not api_key:
        print("\nSet GOOGLE_API_KEY to verify against Gemini API")
        print("Estimated tokens (at 4 chars/token): {:,}".format(len(content) // 4))
        print("Estimated tokens (at 3.5 bytes/token): {:,}".format(int(bytes_count / 3.5)))
        return

    try:
        import google.generativeai as genai
        genai.configure(api_key=api_key)

        model = genai.GenerativeModel('gemini-1.5-flash')
        result = model.count_tokens(content)

        print(f"\nGemini API token count: {result.total_tokens:,}")
        print(f"Bytes per token: {bytes_count / result.total_tokens:.2f}")
        print(f"Chars per token: {len(content) / result.total_tokens:.2f}")

    except ImportError:
        print("\nInstall google-generativeai: pip install google-generativeai")
    except Exception as e:
        print(f"\nAPI error: {e}")

if __name__ == "__main__":
    main()
