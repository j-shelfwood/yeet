# Gemini Tokenizer Model

This directory should contain `tokenizer.model` for accurate Gemini token counting.

## Setup Instructions

1. Visit https://huggingface.co/google/gemma-2b
2. Accept Google's license agreement
3. Download `tokenizer.model` from the Files tab
4. Place it in this directory as `tokenizer.model`

Or run the setup script:
```bash
./scripts/download-tokenizer.sh
```

## Without tokenizer.model

If no model file is present, yeet falls back to character-based approximation
(~3.5 chars per token), which is typically within ±15% of actual counts.
