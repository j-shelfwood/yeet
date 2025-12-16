# Yeet - AI Context Aggregator

> Swift port of `copy_context.py` - Intelligent codebase context collector for AI agents

## Overview

**Yeet** is a command-line tool that aggregates source code and project context into a clipboard-ready format optimized for Large Language Model consumption. It performs intelligent file discovery, token-aware truncation, and git integration to package relevant codebase information within LLM context limits.

### Original Implementation

Python script located at `~/.shelfwood/scripts/copy_context.py` (858 lines)

### Purpose

Enable efficient AI-powered development by:
- Collecting relevant source files based on configurable patterns
- Tokenizing content using GPT-4's cl100k_base encoding
- Applying adaptive truncation to stay within context limits
- Integrating git history and diff information
- Copying consolidated output to clipboard for AI agent consumption
- Operating entirely offline using local tokenizer file

---

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────┐
│ CLI INTERFACE                                        │
│ ├─ Argument parsing (ArgumentParser)                │
│ └─ Multi-source input (files/stdin/globs)           │
├─────────────────────────────────────────────────────┤
│ PATH RESOLUTION                                      │
│ ├─ Entry resolution (files/dirs/patterns)           │
│ ├─ Glob pattern expansion                           │
│ └─ Path normalization (relative/absolute)           │
├─────────────────────────────────────────────────────┤
│ FILE DISCOVERY ENGINE                                │
│ ├─ Directory walker (recursive traversal)           │
│ ├─ Git-aware filtering (ls-files integration)       │
│ ├─ Pattern matching (fnmatch)                       │
│ └─ Exclusion logic (dirs/extensions)                │
├─────────────────────────────────────────────────────┤
│ TOKENIZATION SYSTEM                                  │
│ ├─ cl100k_base encoder (tiktoken)                   │
│ ├─ Adaptive token limits (size/pattern-based)       │
│ ├─ Content truncation (preserve first N tokens)     │
│ └─ Safe UTF-8 file reading                          │
├─────────────────────────────────────────────────────┤
│ GIT INTEGRATION                                      │
│ ├─ Repository detection (git rev-parse)             │
│ ├─ Commit history extraction (git log)              │
│ ├─ Diff mode (git diff HEAD)                        │
│ └─ File change tracking (--name-status)             │
├─────────────────────────────────────────────────────┤
│ OUTPUT FORMATTER                                     │
│ ├─ Structured text assembly                         │
│ ├─ Summary generation (human/JSON)                  │
│ ├─ Directory tree visualization (tree command)      │
│ └─ Clipboard integration (pbcopy)                   │
└─────────────────────────────────────────────────────┘
```

### Data Flow

```
Input Sources → Path Resolution → File Discovery → Content Reading
      ↓                                                     ↓
CLI args/stdin/files                              Tokenization & Truncation
                                                            ↓
Git Integration ←──────────────────────────── Context Assembly
      ↓                                                     ↓
History/Diff Extraction                          Output Formatting
      ↓                                                     ↓
      └──────────────────────────────→ Clipboard (pbcopy)
```

---

## Key Features

### 1. Offline Tokenization

**Implementation:** Lines 433-465 in Python version

Loads GPT-4's cl100k_base tokenizer from local disk:
- **File:** `scripts/cl100k_base.tiktoken` (base64-encoded token ranks)
- **Format:** `<base64_token> <rank>` per line
- **Special tokens:** endoftext, fim_prefix, fim_middle, fim_suffix, endofprompt

**Benefits:**
- Zero network latency
- Works in air-gapped environments
- No API costs for token counting
- Deterministic token counts matching GPT-4

**Swift Consideration:** Requires BPE (Byte Pair Encoding) implementation or FFI to tiktoken

### 2. Adaptive Truncation

**Implementation:** Lines 468-501 (`get_max_tokens_for_file`)

**Three-tier strategy:**

#### Tier 1: Pattern-Based Limits
```
LOW_VALUE_PATTERNS = {
    "*.lock": 500,          # Package lock files
    "*-lock.json": 500,     # npm/yarn/composer locks
    "*.resolved": 500,      # Package.resolved (Swift)
    "*mock*.xml": 1000,     # Mock data files
    "*mock*.json": 1000,    # Mock JSON data
    "*api*.json": 2000,     # API schemas/specs
    "*-api-*.md": 2000,     # API documentation
    "*.min.*": 0,           # Minified files → SKIP
}
```

#### Tier 2: Directory Context
```
if path contains "mocks" AND "resources":
    max_tokens = 1000
```

#### Tier 3: Size-Based Fallback
```
file_size > 100KB → max 2000 tokens
file_size > 50KB  → max 5000 tokens
else              → base_max (10000 default)
```

**Rationale:** AI agents don't need full lock files or minified code

### 3. Git-Aware File Discovery

**Implementation:** Lines 284-333, 389-415

**Strategy:**
1. Detect git repository root: `git rev-parse --show-toplevel`
2. Use `git ls-files --cached --others --exclude-standard`
3. Respect `.gitignore` automatically
4. Cache results per repository (LRU cache)
5. Fall back to `os.walk()` for non-git directories

**Performance:**
- **Without git:** O(total_files) - walks entire tree
- **With git:** O(tracked_files) - single git command
- **Speedup:** 10-100x for projects with node_modules/vendor

**Swift Consideration:** Use `Process` to execute git commands, implement caching

### 4. Git History Extraction

**Implementation:** Lines 543-664 (`collect_git_history`)

**Three modes:**

| Mode    | Behavior                              | Use Case                    |
|---------|---------------------------------------|----------------------------|
| `none`  | Skip history entirely                 | Minimal context            |
| `summary` (default) | Commits + stats (no diffs) | Standard workflow          |
| `full`  | Commits + stats + diffs (500 lines)   | Deep code review           |

**Data collected per commit:**
- Commit hash (short 7-char + full 40-char SHA)
- Author name & email
- ISO 8601 timestamp
- Subject & body
- File change status (A=added, M=modified, D=deleted, R=renamed)
- Shortstat summary (files changed, insertions, deletions)
- Diff preview (full mode only, max 500 lines per commit)

**Commands used:**
```bash
git log -N --pretty=format:'%H%x00%an%x00%ae%x00%ai%x00%s%x00%b%x00' --name-status
git show <hash> --shortstat --format=
git show <hash> --format=  # For diffs in full mode
```

### 5. Multi-Source Input

**Implementation:** Lines 223-237, 149-220

**Input methods (combinable):**

| Method           | Example                                | Priority |
|------------------|----------------------------------------|----------|
| CLI arguments    | `yeet file1.swift dir/ *.ts`           | 1        |
| `--files-from FILE` | Newline-separated list in file      | 2        |
| `--files-from -` | stdin pipe                             | 2        |
| Default          | Current directory (`.`)                | 3        |

**Combination:** All sources merged into single collection (no duplicates)

### 6. Diff Mode

**Implementation:** Lines 667-716 (`run_diff_mode`)

**Flag:** `--diff`

**Behavior:**
1. Execute `git diff --name-status HEAD`
2. Collect only changed files (modified/added/deleted)
3. Mark deleted files: `"FILE DELETED"`
4. Mark missing files: `"FILE NOT FOUND"`
5. Apply token truncation to existing files

**Use case:** Quick context for reviewing uncommitted changes before commit

---

## Configuration

### Default File Patterns (48 types)

```swift
// Python: DEFAULT_PATTERNS (lines 32-78)
let defaultPatterns = [
    // Web & Frontend
    "*.ts", "*.js", "*.html", "*.css", "*.astro",

    // Backend
    "*.php", "*.blade.php", "*.py", "*.rb", "*.java", "*.kt", "*.cs",

    // Systems Programming
    "*.sh", "*.cpp", "*.h", "*.rs", "*.swift", "*.lua",

    // Markup & Config
    "*.md", "*.json", "*.yaml", "*.yml", "*.toml", "*.xml", "*.jsonl",

    // Shaders
    "*.glsl", "*.vsh", "*.fsh",

    // Build Systems
    "*.cmake", "*.make", "Makefile", "*.gradle", "*.groovy",
    "Dockerfile", ".dockerignore",

    // Unity
    "*.unity", "*.meta", "*.asset",

    // Misc
    "*.txt", "*.conf", "*.config",
    ".gitignore", ".gitattributes", "*.resolved"
]
```

### Excluded Directories

```swift
// Python: DEFAULT_EXCLUDE_DIRS (lines 80-95)
let defaultExcludeDirs: Set<String> = [
    // Dependencies
    "node_modules", "vendor",

    // Build Artifacts
    "build", ".build",

    // Version Control
    ".git",

    // IDE
    ".vscode",

    // Swift Package Manager
    ".swiftpm",

    // Python
    "venv", ".env",

    // Laravel/PHP
    "storage", "public/storage",

    // Unity
    "Library", "Temp"
]
```

### Ignored Binary Extensions

```swift
// Python: IGNORED_EXTENSIONS (lines 97-122)
let ignoredExtensions: Set<String> = [
    // Archives
    "zip", "tar", "gz", "rar", "7z",

    // Executables
    "exe", "bin", "dll", "so", "jar",

    // Compiled
    "pyc", "class", "o", "a", "obj", "lib",

    // Fonts
    "woff", "woff2", "eot", "ttf", "otf",

    // Databases
    "db", "sqlite",

    // Lock files (handled separately with token limits)
    "lock"
]
```

### History Configuration

```swift
// Python: Lines 124-126
let defaultHistoryCommits = 5
let maxDiffLinesPerCommit = 500
enum HistoryMode: String {
    case none    // Skip history
    case summary // Commits + stats (default)
    case full    // Commits + stats + diffs
}
```

---

## CLI Interface Specification

### Command Syntax

```
yeet [options] [paths...]
```

### Arguments

| Argument          | Type       | Description                                    |
|-------------------|------------|------------------------------------------------|
| `paths`           | Variadic   | Files, directories, or glob patterns           |

### Options

| Flag                      | Type    | Default | Description                                      |
|---------------------------|---------|---------|--------------------------------------------------|
| `--root <dir>`            | Path    | `pwd`   | Treat relative paths as relative to this dir     |
| `--files-from <file>`     | Path    | -       | Read paths from file (or `-` for stdin)          |
| `--max-tokens <n>`        | Int     | 10000   | Maximum tokens per file before truncation        |
| `--type <pattern>`        | String  | -       | Filter to files matching glob pattern            |
| `--include <pattern>`     | Array   | -       | Add extra patterns (repeatable)                  |
| `--exclude <dir>`         | Array   | -       | Exclude directories (repeatable)                 |
| `--diff`                  | Flag    | false   | Copy git diff (HEAD) instead of traversing paths |
| `--json`                  | Flag    | false   | Emit JSON summary to stdout                      |
| `--no-structure`          | Flag    | false   | Skip directory tree in output                    |
| `--list-only`             | Flag    | false   | List files without reading/copying               |
| `--encoding-path <file>`  | Path    | auto    | Override tokenizer file location                 |
| `--without-history`       | Flag    | false   | Exclude git history from output                  |
| `--history-mode <mode>`   | Enum    | summary | History detail: none/summary/full                |

### Usage Examples

```bash
# Basic: collect current directory
yeet

# Specific paths
yeet src/ tests/ README.md

# Glob patterns
yeet "*.swift" "Sources/**/*.swift"

# Git diff mode
yeet --diff

# Custom token limit
yeet --max-tokens 5000 Sources/

# Exclude directories
yeet --exclude build --exclude .build

# Type filter
yeet --type "*.swift"

# Add patterns to defaults
yeet --include "*.astro" --include "*.svelte"

# From file list
find . -name "*.swift" > files.txt
yeet --files-from files.txt

# From stdin pipeline
git diff --name-only HEAD~5 | yeet --files-from -

# Multiple projects
yeet ~/project1/Sources ~/project2/Sources

# JSON output
yeet --json > context.json

# List only (dry run)
yeet --list-only

# Full history with diffs
yeet --history-mode full

# No history
yeet --without-history
```

---

## Output Format Specification

### Standard Output (Clipboard)

```
Path: /absolute/path/to/File1.swift
========
(1234 tokens)
<file content here>
========

Path: /absolute/path/to/File2.swift
========
(567 tokens)
<file content here>
[TRUNCATED - Original: 15000 tokens, showing first 10000 tokens]
========

=== Git History (Last 5 Commits) ===

Commit: abc1234
Author: John Doe <john@example.com>
Date: 2025-12-15T14:23:45-08:00
Subject: Fix authentication bug

Files Changed:
  M Sources/Auth/Login.swift
  M Tests/AuthTests.swift
  A Sources/Auth/TokenManager.swift

Summary: 3 files changed, 45 insertions(+), 12 deletions(-)
---

<... more commits ...>

Directory Structure:
--- Structure for /project/path ---
.
├── Sources/
│   ├── Yeet/
│   │   ├── CLI.swift
│   │   └── Context.swift
│   └── YeetCore/
│       └── Tokenizer.swift
└── Tests/
    └── YeetTests/
        └── ContextTests.swift

--- Top Files (by token count) ---
      5432 tokens: Sources/Yeet/Context.swift
      3210 tokens: Sources/YeetCore/Tokenizer.swift
      2100 tokens: Package.swift
----------------------------------
Total context token count (approx): 15432
```

### JSON Output Format

```json
{
  "files": [
    {
      "path": "/absolute/path/to/File1.swift",
      "tokens": 1234
    },
    {
      "path": "/absolute/path/to/File2.swift",
      "tokens": 567
    }
  ],
  "total_tokens": 1801
}
```

### Standard Error (Summary)

```
--- Top Files (by token count) ---
      5432 tokens: Sources/Yeet/Context.swift
      3210 tokens: Sources/YeetCore/Tokenizer.swift
      2100 tokens: Package.swift
----------------------------------
Total context token count (approx): 15432
Context copied to clipboard!
```

---

## Algorithm Specifications

### File Discovery Algorithm

```
function discover_files(paths, include_patterns, exclude_dirs, type_filter):
    files = Set()
    dirs = Set()
    patterns = []

    # Phase 1: Classify inputs
    for path in paths:
        expanded = expand_user_path(path)
        if not is_absolute(expanded):
            expanded = resolve_relative_to_base(expanded)

        if is_file(expanded):
            files.add(expanded)
        elif is_dir(expanded):
            dirs.add(expanded)
        else:
            patterns.add(path)

    # Phase 2: Expand glob patterns
    for pattern in patterns:
        matches = glob(pattern)
        for match in matches:
            if is_file(match):
                files.add(match)
            elif is_dir(match):
                dirs.add(match)

    # Phase 3: Walk directories
    effective_patterns = include_patterns + [type_filter] if type_filter else include_patterns
    if empty(effective_patterns):
        effective_patterns = DEFAULT_PATTERNS

    for directory in dirs:
        # Check if directory is in a git repo
        git_root = find_git_root(directory)

        if git_root exists:
            # Use git ls-files for performance
            tracked_files = git_tracked_files(git_root)
            for file in tracked_files:
                if is_descendant_of(file, directory):
                    relative = make_relative(file, directory)
                    if not contains_excluded_dir(relative, exclude_dirs):
                        if not has_ignored_extension(file):
                            if matches_any_pattern(file, effective_patterns):
                                files.add(file)
        else:
            # Fall back to recursive walk
            for root, subdirs, filenames in walk(directory):
                # Filter subdirectories in-place
                subdirs[:] = [d for d in subdirs if d not in exclude_dirs and d != ".git"]

                for filename in filenames:
                    if has_ignored_extension(filename):
                        continue

                    full_path = join(root, filename)
                    relative = make_relative(full_path, directory)

                    if contains_excluded_dir(relative, exclude_dirs):
                        continue

                    if not matches_any_pattern(full_path, effective_patterns):
                        continue

                    files.add(full_path)

    return files
```

### Tokenization & Truncation Algorithm

```
function collect_context(files, encoding, base_max_tokens):
    context_files = []

    for file in sorted(files):
        # Calculate adaptive token limit
        effective_max = calculate_token_limit(file, base_max_tokens)

        # Skip files with 0 limit (e.g., *.min.*)
        if effective_max == 0:
            continue

        # Read file content
        text = read_file_utf8(file)
        if text is None:
            continue

        # Tokenize
        tokens = encoding.encode(text)

        # Truncate if needed
        if len(tokens) > effective_max:
            truncated_tokens = tokens[0:effective_max]
            text = encoding.decode(truncated_tokens)
            text += "\n\n[TRUNCATED - Original: {len(tokens)} tokens, showing first {effective_max} tokens]"
            token_count = effective_max
        else:
            token_count = len(tokens)

        context_files.append({
            path: file,
            tokens: token_count,
            text: text
        })

    return context_files

function calculate_token_limit(file_path, base_max):
    # Tier 1: Pattern-based limits
    for pattern, max_tokens in LOW_VALUE_PATTERNS:
        if fnmatch(file_path.name, pattern):
            return max_tokens

    # Tier 2: Directory context
    if "mocks" in file_path.parts and "resources" in file_path.parts:
        return 1000

    # Tier 3: Size-based fallback
    file_size = get_file_size(file_path)
    if file_size > 100_000:  # 100KB
        return min(base_max, 2000)
    elif file_size > 50_000:  # 50KB
        return min(base_max, 5000)
    else:
        return base_max
```

### Git History Extraction Algorithm

```
function collect_git_history(num_commits, max_diff_lines, mode):
    if mode == "none":
        return ""

    # Check if in git repo
    if not is_git_repo():
        return ""

    # Get commit log with file statistics
    output = execute([
        "git", "log", "-{num_commits}",
        "--pretty=format:%H%x00%an%x00%ae%x00%ai%x00%s%x00%b%x00",
        "--name-status"
    ])

    if empty(output):
        return ""

    lines = []
    lines.append("=== Git History (Last {num_commits} Commits) ===")
    lines.append("")

    # Parse commit blocks
    commits = split(output, "\n\n")
    for commit_block in commits:
        commit_lines = split(commit_block, "\n")

        # Parse header (null-byte separated)
        header = split(commit_lines[0], "\x00")
        commit_hash = header[0]
        author_name = header[1]
        author_email = header[2]
        date = header[3]
        subject = header[4]
        body = header[5]

        short_hash = commit_hash[0:7]

        # Get file statistics
        stat_output = execute(["git", "show", commit_hash, "--shortstat", "--format="])

        # Format commit info
        lines.append("Commit: {short_hash}")
        lines.append("Author: {author_name} <{author_email}>")
        lines.append("Date: {date}")
        lines.append("Subject: {subject}")
        if not empty(body):
            lines.append("Body: {body}")
        lines.append("")

        # Parse file changes
        file_changes = []
        for line in commit_lines[1:]:
            if contains(line, "\t"):
                status, filepath = split(line, "\t", maxsplit=1)
                status_symbol = status[0]  # A/M/D/R
                file_changes.append("  {status_symbol} {filepath}")

        if not empty(file_changes):
            lines.append("Files Changed:")
            lines.extend(file_changes[0:20])  # Limit to 20 files
            if len(file_changes) > 20:
                lines.append("  ... and {len(file_changes) - 20} more files")
            lines.append("")

        if not empty(stat_output):
            lines.append("Summary: {stat_output}")
            lines.append("")

        # Get diff (full mode only)
        if mode == "full":
            diff_output = execute(["git", "show", commit_hash, "--format="])
            diff_lines = split(diff_output, "\n")

            if len(diff_lines) > max_diff_lines:
                lines.append("Diff Preview (first {max_diff_lines} of {len(diff_lines)} lines):")
                lines.extend(diff_lines[0:max_diff_lines])
                lines.append("[TRUNCATED - Full diff: {len(diff_lines)} lines]")
            else:
                lines.append("Diff:")
                lines.extend(diff_lines)
            lines.append("")

        lines.append("---")
        lines.append("")

    return join(lines, "\n")
```

---

## Swift Implementation Considerations

### Package Structure

```
yeet/
├── Package.swift
├── README.md
├── LICENSE
├── Sources/
│   ├── yeet/                      # Executable target
│   │   └── main.swift
│   ├── YeetCore/                  # Core library
│   │   ├── CLI/
│   │   │   ├── ArgumentParser.swift
│   │   │   └── Commands.swift
│   │   ├── Discovery/
│   │   │   ├── FileDiscovery.swift
│   │   │   ├── GitIntegration.swift
│   │   │   └── PatternMatcher.swift
│   │   ├── Tokenization/
│   │   │   ├── Tokenizer.swift
│   │   │   ├── Encoder.swift
│   │   │   └── TruncationStrategy.swift
│   │   ├── Context/
│   │   │   ├── ContextCollector.swift
│   │   │   ├── ContextFile.swift
│   │   │   └── OutputFormatter.swift
│   │   └── Utilities/
│   │       ├── FileSystem.swift
│   │       ├── ProcessRunner.swift
│   │       └── PathResolution.swift
│   └── YeetTokenizer/             # Separate tokenizer module
│       ├── BPE/
│       │   ├── BytePairEncoder.swift
│       │   └── TokenRank.swift
│       └── Resources/
│           └── cl100k_base.tiktoken
└── Tests/
    ├── YeetTests/
    │   ├── CLITests.swift
    │   ├── DiscoveryTests.swift
    │   └── ContextTests.swift
    └── YeetTokenizerTests/
        └── TokenizerTests.swift
```

### Dependencies

```swift
// Package.swift
let package = Package(
    name: "yeet",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        // Consider: swift-algorithms, swift-system
    ],
    targets: [
        .executableTarget(
            name: "yeet",
            dependencies: [
                "YeetCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "YeetCore",
            dependencies: ["YeetTokenizer"]
        ),
        .target(
            name: "YeetTokenizer",
            resources: [.copy("Resources/cl100k_base.tiktoken")]
        ),
        .testTarget(
            name: "YeetTests",
            dependencies: ["YeetCore"]
        )
    ]
)
```

### Key Challenges

#### 1. BPE Tokenizer Implementation

**Options:**
- **Pure Swift:** Implement BPE from scratch (complex, 500+ lines)
- **FFI:** Bridge to Python tiktoken via Process/pipes (simple but slow)
- **C Interop:** Bind to tiktoken C library if available
- **Alternative:** Use GPT-2 tokenizer as approximation (less accurate)

**Recommended:** Pure Swift implementation for performance and zero dependencies

**Resources:**
- tiktoken algorithm: https://github.com/openai/tiktoken
- BPE paper: https://arxiv.org/abs/1508.07909

#### 2. Pattern Matching

Python's `fnmatch` → Swift equivalent:
- Use `NSPredicate` with `LIKE` operator
- Or implement glob pattern matcher using regex
- Consider Foundation's `FileManager.DirectoryEnumerator` with predicates

#### 3. Git Integration

Use `Process` to execute git commands:
```swift
func executeGit(args: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = args

    let pipe = Pipe()
    process.standardOutput = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}
```

#### 4. Clipboard Integration

macOS-specific:
```swift
import AppKit

func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
```

Cross-platform alternative: use `pbcopy` via Process

#### 5. LRU Cache Implementation

Python's `@lru_cache` → Swift equivalent:
```swift
actor LRUCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private var order: [Key] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
    }

    func get(_ key: Key) -> Value? {
        guard let value = cache[key] else { return nil }
        // Move to end (most recent)
        order.removeAll { $0 == key }
        order.append(key)
        return value
    }

    func set(_ key: Key, value: Value) {
        if cache[key] == nil {
            if cache.count >= capacity {
                // Evict least recently used
                if let lru = order.first {
                    cache.removeValue(forKey: lru)
                    order.removeFirst()
                }
            }
        } else {
            order.removeAll { $0 == key }
        }

        cache[key] = value
        order.append(key)
    }
}
```

---

## Performance Targets

### Benchmarks (Python baseline)

| Operation                  | Time (Python) | Target (Swift) |
|----------------------------|---------------|----------------|
| Small project (100 files)  | ~0.5s         | < 0.2s         |
| Medium project (1000 files)| ~2.0s         | < 0.8s         |
| Large project (5000 files) | ~8.0s         | < 3.0s         |
| Git history (5 commits)    | ~0.3s         | < 0.15s        |
| Tokenization (1MB text)    | ~0.2s         | < 0.1s         |

**Swift advantages:**
- Compiled vs interpreted (3-5x faster baseline)
- Better memory management (ARC vs GC)
- Concurrent file reading (async/await)

### Optimization Strategies

1. **Parallel file reading:**
   ```swift
   await withTaskGroup(of: ContextFile?.self) { group in
       for file in files {
           group.addTask {
               await readAndTokenize(file)
           }
       }
   }
   ```

2. **Memory-mapped file I/O for large files**

3. **Lazy tokenization** (only tokenize if needed for truncation)

4. **Cache git operations per repository**

5. **Use `FileManager.enumerator` with shallow traversal**

---

## API Design (Library Usage)

```swift
import YeetCore

// Basic usage
let context = try await ContextCollector()
    .include(paths: ["Sources/", "Tests/"])
    .exclude(directories: ["build", ".build"])
    .maxTokens(10000)
    .collect()

context.copyToClipboard()
print("Total tokens: \(context.totalTokens)")

// Advanced usage
let context = try await ContextCollector()
    .root(at: "/path/to/project")
    .include(patterns: ["*.swift", "*.md"])
    .exclude(directories: ["Pods"])
    .maxTokens(5000)
    .historyMode(.full)
    .gitDiffMode(true)
    .collect()

// JSON export
let json = context.toJSON()
print(json)

// Custom output
let formatted = context.format(
    includeStructure: true,
    includeHistory: true
)
```

---

## Testing Strategy

### Unit Tests

```swift
// Discovery tests
func testGitAwareDiscovery()
func testPatternMatching()
func testExclusionLogic()

// Tokenization tests
func testTokenCounting()
func testAdaptiveTruncation()
func testLowValuePatterns()

// Git integration tests
func testHistoryExtraction()
func testDiffMode()
func testRepositoryDetection()

// Path resolution tests
func testRelativePathResolution()
func testGlobExpansion()
func testMultiSourceInput()
```

### Integration Tests

```swift
// End-to-end workflow
func testFullContextCollection()
func testDiffModeWorkflow()
func testMultiProjectAggregation()

// Performance tests
func testLargeProjectPerformance()
func testGitHistoryPerformance()
```

### Test Fixtures

```
Tests/Fixtures/
├── sample-project/
│   ├── Sources/
│   ├── Tests/
│   └── Package.swift
├── git-repo/              # Git repo with history
└── mock-files/            # Various file types
```

---

## Distribution

### Installation Methods

#### Homebrew
```bash
brew tap shelfwood/tap
brew install yeet
```

#### Mint
```bash
mint install shelfwood/yeet
```

#### Manual
```bash
git clone https://github.com/shelfwood/yeet
cd yeet
swift build -c release
cp .build/release/yeet /usr/local/bin/
```

### Release Artifacts

- **Binary:** `yeet` (single executable)
- **Tokenizer data:** Embedded in Resources
- **Manpage:** `yeet.1`
- **Completions:** Bash/Zsh/Fish (via ArgumentParser)

---

## Roadmap

### Phase 1: Core Implementation
- [ ] CLI argument parsing
- [ ] File discovery engine
- [ ] Git integration (basic)
- [ ] Simple output formatting
- [ ] Clipboard integration

### Phase 2: Tokenization
- [ ] BPE tokenizer implementation
- [ ] cl100k_base encoding support
- [ ] Adaptive truncation logic
- [ ] Token counting accuracy

### Phase 3: Advanced Features
- [ ] Git history extraction (all modes)
- [ ] Diff mode
- [ ] JSON output
- [ ] Directory tree integration
- [ ] Pattern-based limits

### Phase 4: Optimization
- [ ] Parallel file reading
- [ ] LRU caching
- [ ] Memory optimization
- [ ] Performance benchmarks

### Phase 5: Distribution
- [ ] Package.swift refinement
- [ ] Documentation
- [ ] Homebrew formula
- [ ] CI/CD (GitHub Actions)
- [ ] Public release

---

## License

**Target:** MIT or Apache 2.0 (permissive open source)

---

## References

- **Original:** `~/.shelfwood/scripts/copy_context.py`
- **tiktoken:** https://github.com/openai/tiktoken
- **BPE Paper:** https://arxiv.org/abs/1508.07909
- **Swift Argument Parser:** https://github.com/apple/swift-argument-parser
- **cl100k_base encoding:** OpenAI GPT-4 tokenizer

---

## Notes for Implementation

### Priority Order

1. **CLI scaffolding** - Get basic argument parsing working
2. **Simple file collection** - Walk directories, collect files
3. **Token counting** - Implement BPE or use approximation
4. **Git integration** - Run git commands via Process
5. **Output formatting** - Assemble final clipboard text
6. **Advanced features** - History, diff mode, adaptive limits

### Development Tips

- Start with **hardcoded patterns** before making configurable
- Use **Swift Testing** framework (Xcode 15+)
- Implement **verbose logging** for debugging
- Create **comprehensive fixtures** for edge cases
- Profile with **Instruments** for optimization

### Potential Pitfalls

- **BPE complexity** - Consider approximation first
- **Git command parsing** - Different versions have different output
- **Path resolution edge cases** - Symlinks, relative paths
- **Large file handling** - Memory-map or stream
- **Cross-platform clipboard** - macOS vs Linux

---

**Status:** Specification document for Swift port of copy_context.py
**Last Updated:** 2025-12-16
**Version:** 1.0
