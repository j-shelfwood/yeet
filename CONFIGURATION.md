# Yeet Configuration Guide

## Overview

Yeet supports hierarchical configuration through `.yeetconfig` files and command-line options.

**Configuration Priority (highest to lowest):**
1. **Command-line flags** - Explicit options passed to `yeet`
2. **`.yeetconfig`** - Project-specific config in repository root
3. **`~/.yeetconfig`** - User-level defaults in home directory
4. **Built-in defaults** - Hardcoded sensible defaults

## Quick Start

### 1. Create User Defaults

```bash
# Copy template to home directory
cp .yeetconfig.template ~/.yeetconfig

# Edit to taste
$EDITOR ~/.yeetconfig
```

### 2. Create Project Config

```bash
# In your project root
cp .yeetconfig.template .yeetconfig

# Customize for this project
$EDITOR .yeetconfig
```

### 3. Use Yeet

```bash
# Uses config files + defaults
yeet

# Override specific options
yeet --max-tokens 5000 --exclude dist
```

---

## Configuration Reference

### `[defaults]` - General Settings

```toml
[defaults]
max_tokens = 10000              # Max tokens per file before truncation
max_files = 10000               # Max files to collect (safety limit)
max_file_size_mb = 100          # Max file size in MB
max_total_tokens = 1000000      # Max total tokens across all files
show_tree = false               # Include directory tree in output
quiet = false                   # Suppress progress messages
```

**CLI Overrides:**
- `--max-tokens <n>`
- `--max-files <n>`
- `--max-file-size-mb <n>`
- `--max-total-tokens <n>`
- `--tree` / `--no-tree`
- `--quiet`

---

### `[exclude]` - File Filtering

```toml
[exclude]
# Directory names to skip
directories = ["node_modules", "vendor", ".git"]

# File extensions to skip
extensions = ["zip", "pyc", "so", "db"]

# Glob patterns to skip
patterns = ["*.min.*"]
```

**CLI Overrides:**
- `--exclude <dir>` - Add directories to exclude list (repeatable)

**Common Exclusions:**
- **Node.js:** `node_modules`, `dist`, `.next`
- **PHP:** `vendor`, `storage`
- **Python:** `venv`, `.env`, `__pycache__`
- **Rust:** `target`
- **Swift:** `.build`, `.swiftpm`
- **Java:** `target`, `build`

---

### `[include]` - File Selection

```toml
[include]
# File patterns to include when walking directories
patterns = ["*.swift", "*.ts", "*.py", "Makefile"]

# Specific file types (used with --type flag)
types = []
```

**CLI Overrides:**
- `-i <pattern>`, `--include <pattern>` - Add patterns (repeatable)
- `-t <type>`, `--type <type>` - Filter by type (repeatable)

**Example Patterns:**
```toml
patterns = [
    "*.swift", "*.h", "*.m",           # Swift/Objective-C
    "*.ts", "*.tsx", "*.js", "*.jsx",  # TypeScript/JavaScript
    "*.py",                            # Python
    "*.rs",                            # Rust
    "*.go",                            # Go
    "Makefile", "Dockerfile",          # Build files
    ".gitignore",                      # Config files
]
```

---

### `[token_limits]` - Content-Aware Truncation

**Purpose:** Apply different token limits to different file types.

```toml
[token_limits]
# Lock files - just show a preview
"*.lock" = 500
"package-lock.json" = 500

# Minified files - skip entirely
"*.min.*" = 0
"*.bundle.js" = 0

# Mock data - limit verbosity
"**/mocks/**" = 1000
"*mock*.json" = 1000

# Large auto-generated files
"*api*.json" = 2000
"schema.graphql" = 3000
```

**Behavior:**
- `0` = Skip file entirely
- `N` = Limit file to N tokens (truncate if larger)
- If not matched, uses `defaults.max_tokens`

**Pattern Matching:**
- Supports glob syntax: `*`, `**`, `?`, `[abc]`
- Matches against full file path
- First matching pattern wins

---

### `[git]` - Git Integration

```toml
[git]
include_history = true          # Include recent commits
history_mode = "summary"        # Detail level
history_count = 5               # Number of commits
```

**CLI Overrides:**
- `--without-history` - Exclude git history
- `--history-mode <mode>` - Options: `none`, `summary`, `full`
- `--history-count <n>` - Number of commits

**History Modes:**
- **`none`**: Skip git history entirely
- **`summary`**: Commit metadata + file list (no diffs)
- **`full`**: Full diffs for each commit (verbose)

---

### `[output]` - Output Formatting

```toml
[output]
format = "text"                 # Output format
include_tree = false            # Directory structure
```

**CLI Overrides:**
- `--json` - Output as JSON
- `--tree` / `--no-tree` - Toggle directory tree

**Formats:**
- **`text`**: Human-readable, clipboard-friendly
- **`json`**: Machine-readable for tooling

---

### `[performance]` - Performance Tuning

```toml
[performance]
mode = "zero-tokenization"      # Tokenization strategy
```

**Modes:**
- **`zero-tokenization`** (default): Single tokenization of final output
  - **Pros:** 73% faster CPU usage, 3000+ → 1 FFI call
  - **Cons:** Ignores `[token_limits]` patterns

- **`content-aware`**: Apply `[token_limits]` per file
  - **Pros:** Respects truncation patterns, cleaner output
  - **Cons:** Slower (multiple FFI calls for truncated files)

---

## Command-Line Reference

### Input Sources

```bash
# Current directory
yeet

# Specific paths
yeet src/ README.md

# Read from file
yeet --files-from paths.txt

# Read from stdin
find . -name "*.swift" | yeet --files-from -
```

### Filtering

```bash
# Include patterns
yeet -i "*.swift" -i "*.ts"

# Type filter (shorthand)
yeet -t "*.py"

# Exclude directories
yeet --exclude node_modules --exclude dist
```

### Git Operations

```bash
# Only uncommitted changes
yeet --diff

# No history
yeet --without-history

# Full history with diffs
yeet --history-mode full --history-count 10
```

### Output Control

```bash
# JSON output
yeet --json

# Include directory tree
yeet --tree

# List files only (no clipboard)
yeet --list-only

# Quiet mode (no progress)
yeet --quiet
```

### Advanced

```bash
# Custom root directory
# Note: --root affects both input paths AND config discovery
# ConfigLoader will search for .yeetconfig starting from --root directory
yeet --root ~/projects/my-app

# Custom tokenizer
yeet --encoding-path ~/custom.tiktoken

# Safety limits
yeet --max-files 5000 --max-total-tokens 500000
```

**`--root` Flag Behavior:**

The `--root` flag serves two purposes:
1. **Input resolution**: Makes all relative input paths relative to `--root` instead of CWD
2. **Config discovery**: ConfigLoader searches for `.yeetconfig` starting from `--root` directory

Example:
```bash
# From ~/projects/webapp, collect ~/projects/backend using backend's config
yeet --root ~/projects/backend

# This will:
# 1. Look for ~/projects/backend/.yeetconfig (or nearest parent with .git)
# 2. Use that config for collection
# 3. Resolve input paths relative to ~/projects/backend
```

### Performance

```bash
# Benchmark mode (3 iterations)
yeet --benchmark

# Override performance mode
# (Not yet implemented - requires config file)
```

---

## Examples

### Example 1: Web Project with Sensible Defaults

**`~/projects/webapp/.yeetconfig`:**
```toml
[defaults]
max_tokens = 8000               # Smaller context for web files

[exclude]
directories = ["node_modules", "dist", "coverage", ".next"]
extensions = ["map", "lock"]    # Skip source maps and lock files

[include]
patterns = ["*.ts", "*.tsx", "*.css", "*.json", "package.json"]

[token_limits]
"package-lock.json" = 0         # Skip entirely
"*.test.ts" = 2000              # Limit test files
```

**Usage:**
```bash
cd ~/projects/webapp
yeet                            # Uses project config
yeet src/                       # Specific directory
yeet --diff                     # Just changes
```

---

### Example 2: Swift Project

**`~/.yeetconfig`** (user defaults for all Swift projects):
```toml
[include]
patterns = ["*.swift", "Package.swift", "*.md"]

[exclude]
directories = [".build", ".swiftpm", "DerivedData"]

[git]
include_history = true
history_mode = "summary"
```

**Usage:**
```bash
yeet                            # Collects all Swift files
yeet --history-mode full        # Override for detailed history
```

---

### Example 3: Python Project with Mock Data

**`.yeetconfig`:**
```toml
[include]
patterns = ["*.py", "*.yaml", "*.toml", "requirements.txt"]

[exclude]
directories = ["venv", ".env", "__pycache__", ".pytest_cache"]

[token_limits]
"**/mocks/**" = 500             # Limit mock JSON files
"*test*.py" = 3000              # Limit test files
```

---

## Troubleshooting

### Config Not Loading

```bash
# Check which config files exist
ls -la ~/.yeetconfig
ls -la .yeetconfig

# Verify config syntax (must be valid TOML)
cat ~/.yeetconfig
```

### Unexpected Behavior

```bash
# See what files are being collected
yeet --list-only

# Check with quiet mode off
yeet

# Benchmark performance
yeet --benchmark
```

### Performance Issues

```bash
# Try zero-tokenization mode (edit config)
[performance]
mode = "zero-tokenization"

# Or reduce file count
[defaults]
max_files = 1000
max_total_tokens = 500000
```

---

## Best Practices

1. **Start with user defaults:** Create `~/.yeetconfig` for your common workflow
2. **Project-specific overrides:** Add `.yeetconfig` for unusual projects
3. **Version control:** Commit `.yeetconfig` to share team settings
4. **Use token limits:** Control verbosity of auto-generated files
5. **Benchmark:** Use `--benchmark` to measure impact of changes

---

## Example Configurations

Ready-to-use configuration examples for common project types:

### Minimal Configuration

**`examples/minimal.yeetconfig`** - Quick start with essential settings:
```bash
cp examples/minimal.yeetconfig ~/.yeetconfig
```

### Swift Projects

**`examples/swift-package.yeetconfig`** - Swift Package Manager projects:
- Excludes `.build`, `.swiftpm`, `DerivedData`
- Limits `Package.resolved` to 500 tokens
- Includes Swift files, headers, and Package.swift

### TypeScript/React Projects

**`examples/typescript-react.yeetconfig`** - Modern web applications:
- Excludes `node_modules`, `dist`, `.next`, `coverage`
- Skips lock files and minified files entirely
- Limits test files to 2000 tokens
- Shows directory tree for structure visibility

### Python/Django Projects

**`examples/python-django.yeetconfig`** - Django web apps:
- Excludes `venv`, `__pycache__`, migrations
- Limits Django migrations to 500 tokens
- Limits test files to 3000 tokens

### Rust Projects

**`examples/rust-cargo.yeetconfig`** - Cargo-based projects:
- Excludes `target` directory
- Limits `Cargo.lock` to 500 tokens
- Full git history mode (10 commits)

---

## Future Enhancements

- [ ] Config generation wizard (`yeet --init`)
- [ ] Per-directory token limits (e.g., `src/**` vs `tests/**`)
- [ ] Custom truncation strategies
- [ ] Config file merging strategies (append vs replace)
