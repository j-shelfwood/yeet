#!/bin/bash
# Verify token count using Gemini API
# Usage: pbpaste | ./scripts/verify-tokens.sh
# Or: cat file.txt | ./scripts/verify-tokens.sh
#
# Requires GOOGLE_API_KEY environment variable

set -e

if [ -z "$GOOGLE_API_KEY" ]; then
    echo "Error: Set GOOGLE_API_KEY environment variable"
    echo "Get a key from https://makersuite.google.com/app/apikey"
    exit 1
fi

# Read content from stdin
CONTENT=$(cat)
BYTES=$(echo -n "$CONTENT" | wc -c | tr -d ' ')

echo "Content size: $BYTES bytes"

# Create JSON payload (escape content for JSON)
JSON_CONTENT=$(echo -n "$CONTENT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

# Call Gemini countTokens API
RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:countTokens?key=$GOOGLE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"contents\":[{\"parts\":[{\"text\":$JSON_CONTENT}]}]}")

TOKENS=$(echo "$RESPONSE" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("totalTokens", "ERROR"))')

if [ "$TOKENS" = "ERROR" ]; then
    echo "API Error: $RESPONSE"
    exit 1
fi

RATIO=$(python3 -c "print(f'{$BYTES / $TOKENS:.2f}')")

echo "Gemini API tokens: $TOKENS"
echo "Bytes per token: $RATIO"
