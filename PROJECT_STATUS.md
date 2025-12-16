# Yeet - Project Status

**Status**: Initial scaffolding complete ✓
**Date**: 2025-12-16
**Swift Version**: 6.2
**Build Status**: ✓ Compiling
**Tests**: ✓ 7/7 passing

---

## What's Been Built

### 1. Project Structure ✓

```
yeet/
├── Package.swift              # Modern SPM manifest with dual targets
├── README.md                  # Full specification (1149 lines)
├── PROJECT_STATUS.md          # This file
├── Sources/
│   ├── yeet/
│   │   └── yeet.swift        # ArgumentParser CLI (187 lines)
│   └── YeetCore/
│       ├── CollectorConfiguration.swift
│       ├── CollectionResult.swift
│       ├── ContextCollector.swift (stub)
│       ├── FilePatterns.swift
│       ├── YeetError.swift
│       └── Resources/        # (empty - tokenizer pending)
└── Tests/
    └── YeetCoreTests/
        ├── ContextCollectorTests.swift
        └── FilePatternsTests.swift
```

### 2. CLI Interface ✓

**ArgumentParser Integration**: Full command-line interface with:
- Input sources: paths, `--files-from`, stdin support
- Token limits: `--max-tokens` (default: 10000)
- Pattern filtering: `--include`, `--exclude`, `--type`
- Git integration: `--diff`, `--without-history`, `--history-mode`
- Output options: `--json`, `--list-only`, `--tree`
- Advanced: `--root`, `--encoding-path`

**Usage**:
```bash
.build/debug/yeet --help
.build/debug/yeet --version  # → 1.0.0
.build/debug/yeet --list-only  # (stub implementation)
```

### 3. YeetCore Library ✓

**Configuration System**:
- `CollectorConfiguration`: 15 configurable parameters
- Immutable struct design for thread safety

**Pattern Matching**:
- 48+ default file type patterns (*.swift, *.ts, *.py, etc.)
- 25+ excluded directories (node_modules, .git, build, etc.)
- 15+ ignored binary extensions
- Glob pattern matching with regex conversion
- Low-value pattern detection for token budgets

**Error Handling**:
- Custom `YeetError` enum
- Localized error descriptions
- Platform-specific error cases

**Tests**: All passing (7/7)
- Configuration defaults validation
- Pattern matching (glob wildcards)
- Path exclusion logic
- Token limit detection

---

## What's NOT Implemented (TODO)

### Phase 1: Core Collection Logic

**File Discovery**:
- [ ] Path resolution (expand globs, handle ~, relative paths)
- [ ] Directory walking (recursive traversal)
- [ ] Git-aware file enumeration (`git ls-files`)
- [ ] Pattern matching against discovered files
- [ ] Binary file detection
- [ ] File size pre-filtering

**File Processing**:
- [ ] Safe UTF-8 file reading
- [ ] Line-based truncation
- [ ] Token counting (see Phase 2)
- [ ] Adaptive token limits per file
- [ ] Truncation markers in output

### Phase 2: Tokenization

**Critical Component**: BPE tokenizer (cl100k_base)

**Options**:
1. **Pure Swift implementation** (recommended)
   - Port tiktoken's BPE algorithm
   - Embed token ranks as Swift resource
   - Zero external dependencies
   - Estimated: 500-1000 LOC

2. **Python bridge** (temporary)
   - Call `tiktoken` via Process
   - Fast prototype
   - Requires Python + tiktoken installed

3. **Estimated token count** (fallback)
   - ~4 chars = 1 token heuristic
   - Good enough for MVP
   - No encoding file needed

**Tasks**:
- [ ] Choose tokenization strategy
- [ ] Implement token counting
- [ ] Add tokenizer tests
- [ ] Embed cl100k_base.tiktoken resource (if needed)

### Phase 3: Git Integration

**Git Commands**:
- [ ] `git ls-files` - Tracked file enumeration
- [ ] `git rev-parse --show-toplevel` - Repository root detection
- [ ] `git log --oneline` - Commit history
- [ ] `git diff HEAD` - Working tree changes
- [ ] `git diff --name-status` - File change status

**Features**:
- [ ] GitRepository abstraction
- [ ] Commit parsing
- [ ] Diff parsing
- [ ] LRU cache for git roots
- [ ] Error handling for non-git directories

### Phase 4: Output Formatting

**Text Format**:
- [ ] File header formatting (`Path: /path/to/file.swift`)
- [ ] Token count annotations
- [ ] Truncation markers
- [ ] Git history section
- [ ] Directory tree generation (`tree` command)
- [ ] Summary statistics

**JSON Format**:
- [ ] Codable output struct
- [ ] Pretty-printed JSON
- [ ] Schema documentation

**Clipboard Integration**:
- [✓] macOS pbcopy (implemented)
- [ ] Error handling improvements

### Phase 5: Polish & Distribution

**Testing**:
- [ ] Integration tests with real files
- [ ] Git integration tests (requires git repo)
- [ ] Tokenization accuracy tests
- [ ] Performance benchmarks
- [ ] CLI parsing tests

**Performance**:
- [ ] Concurrent file reading (Swift Concurrency)
- [ ] Streaming output (avoid buffering entire result)
- [ ] Memory profiling
- [ ] Benchmark against Python version

**Distribution**:
- [ ] Homebrew formula
- [ ] GitHub releases with binaries
- [ ] Installation documentation
- [ ] CI/CD pipeline (GitHub Actions)

**Documentation**:
- [ ] API documentation (DocC)
- [ ] Usage examples
- [ ] Migration guide from copy_context.py
- [ ] Contributing guidelines

---

## Build & Test

### Development

```bash
# Build (debug)
swift build

# Run executable
.build/debug/yeet --help

# Run tests
swift test

# Build (release)
swift build -c release

# Install locally
cp .build/release/yeet /usr/local/bin/
```

### Testing

```bash
# All tests
swift test

# Specific test
swift test --filter ContextCollectorTests

# With coverage (requires Xcode)
swift test --enable-code-coverage
```

### Dependencies

```bash
# Resolve dependencies
swift package resolve

# Update dependencies
swift package update

# Show dependency tree
swift package show-dependencies
```

---

## Architecture Decisions

### Why Dual Targets?

**Executable target** (`yeet`):
- Thin wrapper around ArgumentParser
- Main entry point
- Cannot be tested directly

**Library target** (`YeetCore`):
- All business logic
- Fully testable
- Reusable as Swift package

### Why ArgumentParser?

- Official Apple library
- Declarative syntax
- Auto-generated help
- Type-safe argument parsing
- Validation built-in

### Why Not SwiftPM Plugins?

- Command-line tools need global installation
- Plugins are project-scoped
- Harder to distribute via Homebrew

---

## Next Steps (Recommended Order)

1. **Implement File Discovery** (2-4 hours)
   - Start with simple directory walking
   - Add pattern filtering
   - Add exclusion logic

2. **Simple Tokenization** (1-2 hours)
   - Use 4-char heuristic for MVP
   - Defer BPE implementation

3. **Output Formatting** (2-3 hours)
   - Text format generation
   - Clipboard integration testing

4. **Git Integration** (3-5 hours)
   - Repository detection
   - `git ls-files` for file discovery
   - Basic history collection

5. **BPE Tokenization** (8-12 hours)
   - Port tiktoken algorithm
   - Add token ranks resource
   - Accuracy testing

6. **Performance & Polish** (4-8 hours)
   - Concurrent file reading
   - Memory optimization
   - Error messages

**Total Estimated**: 20-34 hours for full implementation

---

## Resources

- **Original Spec**: `README.md` (1149 lines)
- **Python Source**: `~/.shelfwood/scripts/copy_context.py` (858 lines)
- **ArgumentParser Docs**: https://github.com/apple/swift-argument-parser
- **Swift Package Manager**: https://www.swift.org/package-manager/

---

## Known Issues

1. **Tokenizer missing** - Blocks accurate token counting
2. **ContextCollector.collect()** - Stub implementation only
3. **Git integration** - Not started
4. **Tree generation** - Requires `tree` command or pure Swift impl
5. **Resources directory** - Empty (no tokenizer file)

---

## Success Criteria (MVP)

- [✓] Compiles without errors
- [✓] CLI accepts all arguments
- [✓] Pattern matching works
- [ ] Collects files from directory
- [ ] Applies token truncation
- [ ] Copies to clipboard
- [ ] Works on example project

## Success Criteria (1.0)

- [ ] Feature parity with Python version
- [ ] 3-5x faster than Python
- [ ] Homebrew installable
- [ ] 80%+ test coverage
- [ ] Documentation complete
