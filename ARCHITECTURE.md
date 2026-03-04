# Architecture

## System Overview

Yeet follows a modular pipeline architecture with clear separation of concerns across subsystems.

```
CLI Input
   ↓
CollectorConfiguration
   ↓
ContextCollector (orchestrator)
   ├─→ Discovery → PatternMatcher → File URLs
   ├─→ Processing → FileReader → File Contents  (parallel)
   ├─→ Git → GitRepository → History/Diff
   └─→ Output → Formatter → XML string + byte-estimated token count
                                  ↓
                            pbcopy (clipboard)  ← immediate
                                  ↓
                            Stats panel printed  ← after clipboard
```

## Core Components

### 1. CLI Layer (`Sources/yeet/`)

**yeet.swift** - ArgumentParser-based command-line interface

- Parses flags and arguments
- Validates configuration
- Handles errors and exit codes

### 2. Configuration (`Sources/YeetCore/`)

**CollectorConfiguration.swift** - Centralized settings

- Path specifications
- Safety limits (tokens, files, size)
- Pattern matching rules
- Git integration options
- Output format preferences

### 3. Discovery Subsystem (`Sources/YeetCore/Discovery/`)

**GitDiscovery.swift** - Git-aware file enumeration

- Uses `git ls-files` for tracked files
- Respects `.gitignore` automatically
- Path filtering with case-insensitive comparison
- Fast-path optimization for repository root requests

**FileDiscovery.swift** - Fallback recursive walker

- Used when git unavailable
- Manual `.gitignore` parsing
- Pattern-based filtering

**PatternMatcher.swift** - File pattern evaluation

- Default file type patterns
- Include/exclude glob matching
- Directory exclusion logic

**PathNormalizer.swift** - Path canonicalization

- NSCache-backed memoization (10,000 entries)
- Case-insensitive comparison for macOS APFS/HFS+
- Symlink and relative path resolution

### 4. Processing Subsystem (`Sources/YeetCore/Processing/`)

**FileProcessor.swift** - Concurrent file orchestration

- Actor-based concurrency model
- Parallel file reading with TaskGroup
- Token limit enforcement
- Error handling and recovery

**FileReader.swift** - Content extraction

- Smart truncation (head + tail strategy)
- Binary file detection
- Exact BPE token counting (Rust-backed tiktoken)
- UTF-8 validation

### 5. Git Subsystem (`Sources/YeetCore/Git/`)

**GitRepository.swift** - Git operations wrapper

- Commit history collection
- Diff generation
- File tracking queries
- Repository root detection

**GitCommand.swift** - Low-level git execution

- Process spawning with proper pipe handling
- Prevents deadlocks on large output
- Error message extraction
- Cross-platform git path handling

**GitHistoryCollector.swift** - History aggregation

- Configurable commit depth
- Three modes: none, summary, full
- Formatted output generation

### 6. Output Subsystem (`Sources/YeetCore/Output/`)

**OutputFormatter.swift** - Text/JSON rendering

- Standard format with file separators
- JSON structure with metadata
- Directory tree visualization
- Summary statistics

**TreeBuilder.swift** - Directory tree generation

- ASCII art tree structure
- Hierarchical path parsing
- Deduplication and sorting

**ClipboardManager.swift** - macOS pasteboard integration

- NSPasteboard wrapper
- Error handling for clipboard failures

### 7. Core Types

**CollectionResult.swift** - Output container

- File contents array
- Metadata (counts, tokens)
- Clipboard operation
- JSON serialization

**FileContent.swift** - Single file representation

- Path, content, token count
- Truncation metadata
- Original vs. processed size

**YeetError.swift** - Error taxonomy

- Git operation failures
- File I/O errors
- Safety limit violations
- Configuration validation

**SafetyLimits.swift** - Limit definitions

- Max files, tokens, size
- Validation logic
- Default values

## Key Design Decisions

### Git-Aware Discovery

Uses `git ls-files` instead of recursive filesystem walks for 10-100x speedup on large projects. Falls back to manual walking when git unavailable.

### Path Normalization Caching

NSCache with 10,000 entry limit reduces redundant `URL.standardized` syscalls during path comparison. Critical for performance on large file sets.

### Pipe Deadlock Prevention

Reads stdout/stderr BEFORE `waitUntilExit()` to prevent process blocking when pipe buffers fill with large output (e.g., 1000+ files from `git ls-files`).

### Clipboard-First Output

The CLI copies context to the clipboard immediately after XML formatting, before printing the stats panel. This means the user can paste within ~200ms regardless of project size. Stats (token bar, treemap, file count) are printed after the clipboard write completes.

### Byte-Approximation Token Counting

Token counts in the stats panel use `utf8.count / 3.5` rather than SentencePiece FFI. This saves ~180ms per run and is accurate to ±5–15% — sufficient for a display bar. JSON mode (`--json`) still uses exact SentencePiece counts since the count is embedded in the output itself. The `--stats` flag enables exact per-file counts when needed.

### WinDirStat-Style Treemap

`TextFormatter.formatTreemap()` renders a proportional block map of token distribution by top-level directory. Uses byte counts (from `FileContent.content.utf8.count`) for proportions when per-file token counting is disabled, exact token counts when `--stats` is active.

### Actor-Based Concurrency

FileProcessor uses Swift task groups for thread-safe parallel file reading.

### Smart Truncation Strategy

Preserves head (imports, signatures) and tail (closing braces) to maintain file structure context when files exceed token limits.

### Case-Insensitive Path Comparison

macOS APFS/HFS+ are case-insensitive by default. PathNormalizer ensures `/Users/foo/Projects` matches `/Users/foo/projects` using `range(of:options: .caseInsensitive)`.

## Data Flow

```
User Input
   ↓
[ArgumentParser] → CollectorConfiguration
   ↓
[ContextCollector]
   ↓
[GitDiscovery/FileDiscovery] → [PatternMatcher] → URL[]
   ↓
[FileProcessor] → [FileReader] × N (parallel) → FileContent[]
   ↓
[GitRepository] → GitHistoryCollector → String (optional)
   ↓
[OutputFormatter/XMLFormatter] → XML string
   ↓
byte-approximation token count (utf8.count / 3.5)  ← no FFI, <1ms
   ↓
CollectionResult { output, totalTokens, files }
   ↓
pbcopy / wl-copy → Pasteboard  ← clipboard written first
   ↓
TextFormatter (stats panel: token bar, treemap, file count)
```

## Performance Characteristics

| Component | Complexity | Bottleneck |
|-----------|------------|------------|
| GitDiscovery | O(n) | `git ls-files` syscall |
| PathNormalizer | O(1) cached, O(1) uncached | URL.standardized |
| PatternMatcher | O(n×p) | n=files, p=patterns (~5) |
| FileReader | O(n) | File I/O |
| FileProcessor | O(n/k) | k=parallelism (~8 cores) |

**Typical Performance (release build, macOS):**

| Milestone | Time | Notes |
|-----------|------|-------|
| Clipboard ready | ~200ms | discover + read + format + pbcopy |
| Stats printed | ~265ms | + byte-approx token count + treemap render |

- 100 files: ~0.2s
- 1,000 files: ~0.8s
- 5,000 files: ~2.5s

Token count accuracy in stats: ±5–15% (byte approximation). Use `--stats` for exact per-file counts via SentencePiece.

## Error Handling

All subsystems throw `YeetError` variants:
- `.gitCommandFailed` - Git operations
- `.fileReadFailed` - I/O errors
- `.tooManyFiles` - Safety limit exceeded
- `.tooManyTokens` - Token limit exceeded
- `.invalidConfiguration` - Config validation

CLI layer catches and formats errors for user-friendly output.

## Testing Strategy

See [TESTING.md](TESTING.md) for comprehensive testing documentation.
