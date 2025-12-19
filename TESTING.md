# Testing

## Test Structure

```
Tests/
└── YeetCoreTests/
    ├── ContextCollectorTests.swift
    ├── FilePatternsTests.swift
    ├── IntegrationTests.swift
    └── PathResolverTests.swift
```

## Running Tests

```bash
# All tests
swift test

# Specific test
swift test --filter FileReaderTests

# With verbose output
swift test --verbose

# Parallel execution
swift test --parallel
```

## Unit Testing

### Pattern Matching

```swift
import XCTest
@testable import YeetCore

final class PatternMatcherTests: XCTestCase {
    func testSwiftFileIncluded() {
        let config = CollectorConfiguration(
            paths: ["."],
            includePatterns: ["*.swift"]
        )
        let matcher = PatternMatcher(configuration: config)
        let url = URL(fileURLWithPath: "/path/to/File.swift")

        XCTAssertTrue(matcher.shouldInclude(url))
    }

    func testExcludedDirectory() {
        let config = CollectorConfiguration(
            paths: ["."],
            excludeDirectories: ["build"]
        )
        let matcher = PatternMatcher(configuration: config)
        let url = URL(fileURLWithPath: "/path/build/output.txt")

        XCTAssertFalse(matcher.shouldInclude(url))
    }
}
```

### File Reading

```swift
final class FileReaderTests: XCTestCase {
    func testSmallFileNoTruncation() throws {
        let reader = FileReader(maxTokens: 10000, maxFileSize: 100_000_000)
        let tempFile = createTempFile(content: "let x = 42\n")

        let result = try reader.readFile(at: tempFile)

        XCTAssertFalse(result.wasTruncated)
        XCTAssertEqual(result.content, "let x = 42\n")
    }

    func testLargeFileTruncation() throws {
        let reader = FileReader(maxTokens: 100, maxFileSize: 100_000_000)
        let content = String(repeating: "x", count: 1000)
        let tempFile = createTempFile(content: content)

        let result = try reader.readFile(at: tempFile)

        XCTAssertTrue(result.wasTruncated)
        XCTAssertLessThan(result.tokenCount, 150)
    }
}
```

### Git Operations

```swift
final class GitRepositoryTests: XCTestCase {
    func testListTrackedFiles() throws {
        let tempRepo = createTempGitRepo()
        addCommit(to: tempRepo, files: ["test.swift"])

        let repo = GitRepository(rootPath: tempRepo.path)
        let files = try repo.listTrackedFiles()

        XCTAssertTrue(files.contains("test.swift"))
    }

    func testDetectNotGitRepo() {
        let tempDir = createTempDirectory()

        XCTAssertFalse(GitRepository.isGitRepository(at: tempDir.path))
    }
}
```

## Integration Testing

### End-to-End Collection

```bash
# Create test project
mkdir -p /tmp/test-project
cd /tmp/test-project
git init
echo "print('hello')" > main.swift
git add main.swift
git commit -m "Initial commit"

# Test yeet
yeet --list-only

# Expected output:
# Files to be collected (1 total):
# ------------------------------------------------------------
#     12 tokens: /tmp/test-project/main.swift
# ------------------------------------------------------------
# Total: 1 files, ~12 tokens
```

### Performance Testing

```bash
# Large project test
yeet ~/Projects/prj-more-apartments --list-only --quiet | grep "Total:"

# Expected: < 3 seconds, 1000+ files
# Total: 1031 files, ~717530 tokens
```

### Edge Cases

```bash
# Non-git directory
mkdir /tmp/no-git && cd /tmp/no-git
echo "test" > file.txt
yeet --list-only
# Should fall back to filesystem walker

# Empty directory
mkdir /tmp/empty && cd /tmp/empty
yeet --list-only
# Should report 0 files

# Binary files
echo -e "\x00\x01\x02" > /tmp/binary.bin
yeet /tmp/binary.bin --list-only
# Should skip binary files

# Symlinks
ln -s /etc/hosts /tmp/link
yeet /tmp/link --list-only
# Should resolve and read if text
```

## Manual Testing Checklist

### Basic Functionality
- [ ] `yeet` copies current directory to clipboard
- [ ] `yeet path1 path2` collects specific paths
- [ ] `yeet --list-only` shows preview without copying
- [ ] `yeet --quiet` suppresses progress output
- [ ] `yeet --json` outputs valid JSON

### Git Integration
- [ ] `yeet --history-count 5` includes last 5 commits
- [ ] `yeet --diff` shows only uncommitted changes
- [ ] `yeet --without-history` excludes git history
- [ ] Works in non-git directories (fallback)
- [ ] Respects `.gitignore` automatically

### Pattern Filtering
- [ ] `yeet --type "*.swift"` filters to Swift files only
- [ ] `yeet --include "*.md"` adds markdown to defaults
- [ ] `yeet --exclude build` skips build directory
- [ ] Default patterns match expected file types

### Safety Limits
- [ ] `--max-files 100` enforces file count limit
- [ ] `--max-tokens 5000` truncates large files
- [ ] `--max-total-tokens 10000` stops at token limit
- [ ] `--max-file-size 10` skips files over 10MB

### Error Handling
- [ ] Nonexistent path shows clear error
- [ ] Permission denied shows clear error
- [ ] Invalid git repo fails gracefully
- [ ] Exceeding limits shows clear message

## Performance Benchmarks

```bash
# Benchmark script
time yeet ~/Projects/small-project --list-only --quiet
time yeet ~/Projects/medium-project --list-only --quiet
time yeet ~/Projects/large-project --list-only --quiet

# Compare with copy_context.py
time python3 copy_context.py ~/Projects/large-project
```

Expected results:
- Small (100 files): < 0.2s
- Medium (1000 files): < 1s
- Large (5000 files): < 3s

## Debugging

### Enable Debug Output

Temporarily add debug statements:

```swift
// In GitDiscovery.swift
fputs("[DEBUG] Starting discovery\n", stderr)
```

### Check Git Commands

```bash
# See what git commands yeet runs
/usr/bin/git -C /path/to/repo ls-files --cached --others --exclude-standard
```

### Inspect JSON Output

```bash
yeet --json | jq '.files[] | select(.wasTruncated == true) | .path'
```

## Known Issues

### Case Sensitivity

PathNormalizer assumes case-insensitive filesystem (macOS default). On case-sensitive systems, paths like `/Users/foo/Projects` and `/Users/foo/projects` are treated as identical.

### Large Output Handling

Git commands with 1000+ file output now handled correctly via pipe draining before `waitUntilExit()`. Previously caused deadlocks.

## CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: swift build
      - name: Run tests
        run: swift test
      - name: Integration test
        run: |
          .build/debug/yeet --list-only
          test -f /tmp/yeet_output.txt
```
