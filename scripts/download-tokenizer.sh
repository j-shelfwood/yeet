#!/bin/bash
# Download Gemma tokenizer.model for accurate Gemini token counting
#
# Prerequisites:
# 1. Accept license at https://huggingface.co/google/gemma-2b
# 2. Get HuggingFace token from https://huggingface.co/settings/tokens

set -e

DEST_DIR="$HOME/.yeet"
DEST_FILE="$DEST_DIR/tokenizer.model"
MODEL_URL="https://huggingface.co/google/gemma-2b/resolve/main/tokenizer.model"

echo "Gemini Tokenizer Setup"
echo "======================"
echo ""

# Check if already exists
if [ -f "$DEST_FILE" ]; then
    echo "✓ tokenizer.model already exists at $DEST_FILE"
    exit 0
fi

# Create directory
mkdir -p "$DEST_DIR"

echo "This script downloads the Gemma tokenizer model (~4MB)."
echo "You must first accept Google's license agreement."
echo ""
echo "Steps:"
echo "  1. Visit: https://huggingface.co/google/gemma-2b"
echo "  2. Click 'Agree and access repository'"
echo "  3. Get your token from: https://huggingface.co/settings/tokens"
echo ""

read -p "Enter your HuggingFace token (or press Enter to skip): " HF_TOKEN

if [ -z "$HF_TOKEN" ]; then
    echo ""
    echo "No token provided. You can manually download tokenizer.model from:"
    echo "  https://huggingface.co/google/gemma-2b/blob/main/tokenizer.model"
    echo ""
    echo "Then place it at: $DEST_FILE"
    exit 1
fi

echo ""
echo "Downloading tokenizer.model..."

HTTP_CODE=$(curl -sL -w "%{http_code}" \
    -H "Authorization: Bearer $HF_TOKEN" \
    "$MODEL_URL" \
    -o "$DEST_FILE")

if [ "$HTTP_CODE" -eq 200 ]; then
    SIZE=$(ls -lh "$DEST_FILE" | awk '{print $5}')
    echo "✓ Downloaded tokenizer.model ($SIZE) to $DEST_FILE"
    echo ""
    echo "yeet will now use accurate Gemini tokenization!"
else
    rm -f "$DEST_FILE"
    echo "✗ Download failed (HTTP $HTTP_CODE)"
    echo ""
    if [ "$HTTP_CODE" -eq 401 ]; then
        echo "Authentication failed. Please check:"
        echo "  - Your token is valid"
        echo "  - You've accepted the license at https://huggingface.co/google/gemma-2b"
    fi
    exit 1
fi
