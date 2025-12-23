# Yeet

Package your codebase for AI consumption in seconds.

A Swift CLI tool that aggregates source code and git history into clipboard-ready format optimized for Large Language Models.

## Installation

### Homebrew (macOS ARM64)

```bash
brew install j-shelfwood/tap/yeet
```

> **Note:** Use the fully qualified name to avoid conflict with another package in homebrew-core.

### Building from Source

```bash
git clone https://github.com/j-shelfwood/yeet
cd yeet
swift build -c release
cp .build/release/yeet /usr/local/bin/
```

**Requirements:**
- macOS 13.0+
- Swift 5.9+
- Xcode 14.0+ (for building from source)

## Usage

```bash
# Copy current directory
yeet

# Copy specific paths
yeet Sources/ Tests/

# Preview without copying
yeet --list-only

# Include git history
yeet --history-count 10

# Only uncommitted changes
yeet --diff

# Quiet mode with JSON output
yeet --quiet --json > context.json
```

## Key Features

- **Fast**: Git-aware discovery using `git ls-files`
- **Smart**: Intelligent file truncation preserving structure
- **Safe**: Configurable limits for files, tokens, and size
- **Git Integration**: History collection and diff mode
- **Flexible**: Glob patterns, file lists, and multiple output formats

## Common Options

```bash
--max-tokens N          # Max tokens per file (default: 10000)
--max-total-tokens N    # Max total tokens (default: 1000000)
--max-files N           # Max file count (default: 10000)
--type PATTERN          # Filter by pattern (e.g., "*.swift")
--include PATTERN       # Add pattern to defaults
--exclude DIR           # Exclude directory
--quiet                 # No progress output
--json                  # JSON output format
--no-tree               # Skip directory tree
```

## Configuration

Yeet supports hierarchical configuration through `.yeetconfig` files (TOML format):

**Priority (highest to lowest):**
1. Command-line flags
2. `./.yeetconfig` (project root)
3. `~/.yeetconfig` (user home)
4. Built-in defaults

**Quick Start:**

```bash
# Create user-level defaults
cp .yeetconfig.template ~/.yeetconfig

# Create project-specific config
cp .yeetconfig.template .yeetconfig
```

**Example config:**

```toml
[defaults]
max_tokens = 8000
quiet = true

[exclude]
directories = ["node_modules", "dist", "coverage"]
patterns = ["public/**", "*.min.*"]

[include]
patterns = ["*.swift", "*.ts", "*.php"]

[token_limits]
# Filename-based limits
"*.lock" = 500                  # Limit lock files
"*-lock.json" = 400             # Specific lock file pattern
"*.min.*" = 0                   # Skip minified files (limit=0)

# Path-based limits (supports ** for recursion)
"database/migrations/**" = 800  # Limit migration files
"lang/*.json" = 600             # Limit translation files
"tests/**/*.php" = 1000         # Limit test files

[performance]
mode = "content-aware"          # Enable per-file token limits

[git]
include_history = true
history_mode = "summary"
history_count = 5
```

### Token Limits

Control per-file token budgets with the `[token_limits]` section. Useful for:
- Large configuration files (lock files, package manifests)
- Generated code (migrations, mocks)
- Localization files (translations)

**Filename patterns:**
```toml
"*.lock" = 500          # Match by extension
"package-lock.json" = 400  # Match specific filename
```

**Path patterns:**
```toml
"database/migrations/**" = 800   # Recursive directory matching
"lang/*.json" = 600               # Single-level wildcard
"tests/**/*.spec.ts" = 1000      # Combined pattern
```

**Special value:**
- `limit = 0` - Skip file entirely (useful for excluding without removing from git)

**Notes:**
- Requires `--stats` flag to see per-file token counts
- Path patterns are checked before filename patterns
- Paths are relative to repository/scan root

For complete reference, see:
- [CONFIGURATION.md](CONFIGURATION.md) - Full configuration guide
- [CLI_AND_CONFIG_REFERENCE.md](CLI_AND_CONFIG_REFERENCE.md) - CLI options reference

## Default File Types

Web: `*.ts`, `*.js`, `*.html`, `*.css`, `*.astro`
Backend: `*.php`, `*.py`, `*.rb`, `*.java`, `*.kt`
Systems: `*.cpp`, `*.h`, `*.rs`, `*.swift`, `*.lua`
Config: `*.json`, `*.yaml`, `*.toml`, `*.xml`

## Documentation

- [CONFIGURATION.md](CONFIGURATION.md) - Configuration file reference
- [CLI_AND_CONFIG_REFERENCE.md](CLI_AND_CONFIG_REFERENCE.md) - Complete CLI options
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design and components
- [TESTING.md](TESTING.md) - Testing strategy and examples

## Development

```bash
swift build          # Build debug
swift test           # Run tests
swift build -c release  # Build release
```

## License

MIT License - see LICENSE file for details
