# Yeet CLI and Configuration Reference

## Complete System Overview

Yeet provides a comprehensive configuration system combining:
- **Command-line flags** for immediate control
- **Project configs** (`.yeetconfig`) for team defaults
- **User configs** (`~/.yeetconfig`) for personal preferences
- **Built-in defaults** for zero-configuration usage

---

## Configuration Hierarchy

```
Priority (highest → lowest):
┌─────────────────────────────────────┐
│ 1. CLI Flags                        │ ← yeet --max-tokens 5000
├─────────────────────────────────────┤
│ 2. .yeetconfig (project root)       │ ← Team settings
├─────────────────────────────────────┤
│ 3. ~/.yeetconfig (user home)        │ ← Personal defaults
├─────────────────────────────────────┤
│ 4. Built-in Defaults                │ ← Sensible fallbacks
└─────────────────────────────────────┘
```

---

## Complete CLI Options Reference

### Input Sources

| Flag | Default | Description |
|------|---------|-------------|
| `<paths>` | `["."]` | Files, directories, or glob patterns |
| `--files-from <path>` | - | Read paths from file (`-` for stdin) |
| `--root <dir>` | - | Base directory for relative paths |

**Examples:**
```bash
yeet                          # Current directory
yeet src/ tests/              # Multiple paths
yeet --files-from files.txt   # From file
git ls-files | yeet --files-from -  # From stdin
```

---

### Token & Truncation Control

| Flag | Default | Config Key | Description |
|------|---------|------------|-------------|
| `--max-tokens <n>` | 10000 | `defaults.max_tokens` | Max tokens per file |
| `--max-files <n>` | 10000 | `defaults.max_files` | Max files to collect |
| `--max-file-size-mb <n>` | 100 | `defaults.max_file_size_mb` | Max file size (MB) |
| `--max-total-tokens <n>` | 1000000 | `defaults.max_total_tokens` | Max total tokens |

**Examples:**
```bash
yeet --max-tokens 5000              # Smaller files
yeet --max-files 500                # Safety limit
yeet --max-total-tokens 500000      # Smaller context
```

---

### Pattern Filtering

| Flag | Default | Config Key | Description |
|------|---------|------------|-------------|
| `-i <pattern>`, `--include <pattern>` | - | `include.patterns` | File patterns to include |
| `-t <type>`, `--type <type>` | - | `include.types` | Filter by file type |
| `--exclude <dir>` | - | `exclude.directories` | Additional directories to exclude |

**Examples:**
```bash
yeet -i "*.swift" -i "*.ts"         # Multiple patterns
yeet -t "*.py"                      # Python files only
yeet --exclude node_modules --exclude dist
```

---

### Git Integration

| Flag | Default | Config Key | Description |
|------|---------|------------|-------------|
| `--diff` | false | - | Collect only uncommitted changes |
| `--without-history` | false | `git.include_history` | Exclude git history |
| `--history-mode <mode>` | `summary` | `git.history_mode` | Detail level: `none`, `summary`, `full` |
| `--history-count <n>` | 5 | `git.history_count` | Number of commits |

**Examples:**
```bash
yeet --diff                          # Only changes
yeet --without-history               # Skip history
yeet --history-mode full             # Full diffs
yeet --history-count 10              # More commits
```

---

### Output Format

| Flag | Default | Config Key | Description |
|------|---------|------------|-------------|
| `--json` | false | `output.format` | Output as JSON |
| `--tree` / `--no-tree` | `--no-tree` | `output.include_tree` | Show directory structure |
| `--list-only` | false | - | List files without copying |
| `--quiet` | false | `defaults.quiet` | Suppress progress |

**Examples:**
```bash
yeet --json                          # Machine-readable
yeet --tree                          # Include structure
yeet --list-only                     # Dry run
yeet --quiet                         # Silent
```

---

### Advanced

| Flag | Default | Description |
|------|---------|-------------|
| `--benchmark` | false | Run 3-iteration performance test |
| `--encoding-path <path>` | - | Custom tokenizer file |
| `--version` | - | Show version |
| `-h`, `--help` | - | Show help |

**Examples:**
```bash
yeet --benchmark                     # Performance test
yeet --encoding-path ~/custom.tiktoken
```

---

## Configuration File Format

### File Locations

```
~/.yeetconfig           ← User-wide defaults
.yeetconfig             ← Project-specific (git tracked)
```

### Complete .yeetconfig Schema

```toml
# Defaults Section
[defaults]
max_tokens = 10000
max_files = 10000
max_file_size_mb = 100
max_total_tokens = 1000000
show_tree = false
quiet = false

# Exclusion Rules
[exclude]
directories = ["node_modules", "vendor", ".git"]
extensions = ["zip", "pyc", "so", "lock"]
patterns = ["*.min.*"]

# Inclusion Rules
[include]
patterns = ["*.swift", "*.ts", "*.py", "Makefile"]
types = []

# Pattern-Based Token Limits (Content-Aware Truncation)
[token_limits]
"*.lock" = 500                # Lock files
"*.min.*" = 0                 # Skip minified (0 = skip)
"**/mocks/**" = 1000          # Mock data
"*api*.json" = 2000           # API schemas

# Git Integration
[git]
include_history = true
history_mode = "summary"      # none|summary|full
history_count = 5

# Output Formatting
[output]
format = "text"               # text|json
include_tree = false

# Performance Tuning
[performance]
mode = "zero-tokenization"    # zero-tokenization|content-aware
```

---

## Configuration Use Cases

### Use Case 1: Web Developer (TypeScript + React)

**`~/.yeetconfig`:**
```toml
[defaults]
max_tokens = 8000
quiet = true

[exclude]
directories = ["node_modules", "dist", "coverage", ".next"]
extensions = ["map"]

[include]
patterns = ["*.ts", "*.tsx", "*.css", "*.json", "package.json"]

[token_limits]
"package-lock.json" = 0
"*.test.tsx" = 2000
```

**Usage:**
```bash
yeet                          # Uses config
yeet src/components           # Specific directory
yeet --diff                   # Just changes
```

---

### Use Case 2: Backend Engineer (Python + APIs)

**`.yeetconfig`** (project-specific):
```toml
[include]
patterns = ["*.py", "*.yaml", "requirements.txt", "Dockerfile"]

[exclude]
directories = ["venv", ".env", "__pycache__"]

[token_limits]
"**/migrations/**" = 500      # DB migrations
"**/tests/fixtures/**" = 1000
```

**Usage:**
```bash
yeet                          # Whole project
yeet app/                     # Just app code
yeet --without-history        # Skip git history
```

---

### Use Case 3: iOS Developer (Swift + Xcode)

**`~/.yeetconfig`:**
```toml
[include]
patterns = ["*.swift", "*.h", "*.m", "*.storyboard", "*.xib"]

[exclude]
directories = ["DerivedData", ".build", ".swiftpm", "Pods"]

[token_limits]
"*.storyboard" = 1000         # Limit XML verbosity
"*.xib" = 1000
```

**Usage:**
```bash
yeet MyApp/                   # App target
yeet --include "*.swift"      # Swift only
```

---

## Advanced Workflows

### Workflow 1: Code Review Preparation

```bash
# Get uncommitted changes
yeet --diff --tree

# Get recent history with full diffs
yeet --history-mode full --history-count 3

# Specific files only
yeet src/feature.swift tests/feature-test.swift
```

---

### Workflow 2: Project Handoff Documentation

**Create project snapshot:**
```bash
# Full project with structure and history
yeet --tree --history-mode summary --json > project-context.json

# Markdown version for sharing
yeet --tree > PROJECT_CONTEXT.md
```

**`.yeetconfig` for handoff:**
```toml
[defaults]
max_tokens = 15000              # Larger context

[include]
patterns = ["*.swift", "*.md", "README*", "CONTRIBUTING*"]

[git]
history_mode = "summary"
history_count = 20              # More history
```

---

### Workflow 3: Bug Investigation

```bash
# Start with changed files
yeet --diff

# Then expand to related files
yeet src/buggy-component/ --history-mode full

# Include tests
yeet src/buggy-component/ tests/
```

---

## Performance Modes

### Mode 1: `zero-tokenization` (Default - Fast)

**How it works:**
1. Read all files (no tokenization)
2. Concatenate into single string
3. Tokenize ONCE at the end
4. Return final token count

**Pros:**
- ✅ 73% faster CPU usage
- ✅ 3000+ → 1 FFI call
- ✅ Consistent performance

**Cons:**
- ❌ Ignores `[token_limits]` patterns
- ❌ No per-file truncation

**Best for:**
- Quick context collection
- Large codebases
- When token limits don't matter

---

### Mode 2: `content-aware` (Slower - Precise)

**How it works:**
1. Read all files
2. For each file matching `[token_limits]`:
   - Tokenize file
   - Truncate if over limit
3. Concatenate truncated files
4. Tokenize final output

**Pros:**
- ✅ Respects `[token_limits]`
- ✅ Cleaner output (less noise)
- ✅ Better control

**Cons:**
- ❌ Slower (per-file FFI calls)
- ❌ Variable performance

**Best for:**
- Projects with many lock files
- Need to limit mock data
- Token budget is tight

**Config:**
```toml
[performance]
mode = "content-aware"

[token_limits]
"*.lock" = 500
"*mock*.json" = 1000
```

---

## Migration from copy_context.py

### Feature Parity

| copy_context.py Feature | Yeet Equivalent |
|-------------------------|-----------------|
| `DEFAULT_PATTERNS` | `[include] patterns` |
| `DEFAULT_EXCLUDE_DIRS` | `[exclude] directories` |
| `IGNORED_EXTENSIONS` | `[exclude] extensions` |
| `LOW_VALUE_PATTERNS` | `[token_limits]` |
| `--max-tokens` | `--max-tokens` or `[defaults] max_tokens` |
| `--diff` | `--diff` |
| `--without-history` | `--without-history` |
| `--json` | `--json` |

### Migration Steps

1. **Create base config:**
   ```bash
   cp /path/to/yeet/.yeetconfig.template ~/.yeetconfig
   ```

2. **Port your custom patterns:**
   ```toml
   [exclude]
   directories = ["your", "custom", "excludes"]
   
   [token_limits]
   "*.your-pattern": 500
   ```

3. **Test:**
   ```bash
   yeet --list-only  # Verify files
   yeet --benchmark  # Check performance
   ```

---

## Summary

**Yeet Configuration System:**
- ✅ Hierarchical config (CLI > project > user > defaults)
- ✅ Pattern-based token limits
- ✅ Zero-config usability
- ✅ Drop-in replacement for copy_context.py
- ✅ Performance modes (fast vs precise)

**Next Steps:**
1. Create `~/.yeetconfig` for your workflow
2. Add `.yeetconfig` to projects that need custom settings
3. Use `yeet --list-only` to verify behavior
4. Benchmark with `yeet --benchmark`

See `CONFIGURATION.md` for detailed examples and troubleshooting.
