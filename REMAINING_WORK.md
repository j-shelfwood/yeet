# Yeet - Remaining Work Plan

**Current Status**: Core functionality complete (~60%), major features missing
**Goal**: Production-ready v1.0.0 with feature parity to Python version

---

## Phase 1: Validation & Safety (HIGH PRIORITY)
**Goal**: Ensure existing code works and won't crash/hang
**Estimated Time**: 4-6 hours

### 1.1 Test Existing CLI Flags (2h)

**Untested flags that have code:**
- [ ] `--files-from FILE` - Test with actual file
- [ ] `--files-from -` - Test stdin input (critical path)
- [ ] `--exclude DIR` - Test additional directory exclusions
- [ ] `--root PATH` - Test base directory resolution
- [ ] Multiple `--include` patterns - Test combination
- [ ] Multiple `--type` patterns - Test combination

**Test Plan:**
```bash
# Test --files-from
echo "Sources/YeetCore/Tokenizer.swift" > /tmp/files.txt
echo "Package.swift" >> /tmp/files.txt
yeet --files-from /tmp/files.txt

# Test stdin
find Sources -name "*.swift" | yeet --files-from -

# Test --exclude
mkdir -p test-project/src test-project/build
touch test-project/src/app.swift test-project/build/app.swift
yeet --exclude build test-project/

# Test --root
cd /tmp
yeet --root ~/projects/yeet Sources/YeetCore/Tokenizer.swift

# Test multiple patterns
yeet --include "*.swift" --include "*.md" .
yeet --type "*.swift" --type "*.md" .
```

**Create tests:**
```swift
// Tests/YeetCoreTests/CLIIntegrationTests.swift
- testFilesFromFile()
- testFilesFromStdin()
- testExcludeDirectories()
- testRootDirectory()
- testMultipleIncludePatterns()
```

### 1.2 Add Safety Limits (1-2h)

**Prevent crashes/hangs:**
- [ ] Max files limit (default: 10,000)
- [ ] Max file size (default: 100MB)
- [ ] Max total tokens (default: 1,000,000)
- [ ] Timeout for operations (optional)

**Implementation:**
```swift
// Sources/YeetCore/SafetyLimits.swift
public struct SafetyLimits {
    public static let maxFiles = 10_000
    public static let maxFileSize = 100 * 1024 * 1024  // 100MB
    public static let maxTotalTokens = 1_000_000
}

// In FileDiscovery.swift
if allFiles.count > SafetyLimits.maxFiles {
    throw YeetError.tooManyFiles(allFiles.count)
}

// In FileReader.swift
let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
if fileSize > SafetyLimits.maxFileSize {
    return FileContent(
        path: url.path,
        content: "[SKIPPED - File too large: \(fileSize / 1024 / 1024)MB]",
        tokenCount: 0,
        ...
    )
}
```

**Add CLI flags:**
```swift
@Option(name: .long, help: "Maximum number of files (default: 10000)")
var maxFiles: Int = 10000

@Option(name: .long, help: "Maximum file size in MB (default: 100)")
var maxFileSize: Int = 100
```

### 1.3 Real-World Testing (1-2h)

**Test on actual projects:**
- [ ] Test on yeet itself (small: ~15 files)
- [ ] Test on a medium project (100-500 files)
- [ ] Test on a large project (1000+ files)
- [ ] Test with TypeScript/React project (node_modules test)
- [ ] Test with Python project
- [ ] Test with mono-repo structure

**Commands to run:**
```bash
# Test on yeet
cd ~/projects/yeet
yeet .

# Test on a large project (e.g., if you have one)
cd ~/projects/large-app
yeet --list-only .  # Count files first
yeet --max-tokens 5000 src/

# Test edge cases
yeet /nonexistent/path
yeet /etc/hosts  # Permission denied
yeet ~  # Home directory (many files)
```

**Document results:**
- Performance metrics (time, memory)
- Any crashes or hangs
- Unexpected behavior

---

## Phase 2: Git Integration (HIGH PRIORITY)
**Goal**: Implement git features from Python version
**Estimated Time**: 6-8 hours

### 2.1 Git Repository Detection (1h)

**Files to create:**
```
Sources/YeetCore/GitRepository.swift
```

**Implementation:**
```swift
public struct GitRepository {
    public let rootPath: String

    // Detect if path is in a git repo
    public static func find(for path: String) -> GitRepository? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--show-toplevel"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }

            return GitRepository(rootPath: output)
        } catch {
            return nil
        }
    }
}
```

**Tests:**
```swift
func testGitRepositoryDetection()
func testNonGitDirectoryReturnsNil()
```

### 2.2 Git File Listing (2h)

**Use git ls-files for file discovery:**

```swift
extension GitRepository {
    // Get tracked files from git
    public func listTrackedFiles() throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: rootPath)

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw YeetError.gitCommandFailed("ls-files failed")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }
}
```

**Update FileDiscovery:**
```swift
public func discoverFiles() throws -> [URL] {
    // Try git-aware discovery first
    if let gitRepo = GitRepository.find(for: configuration.paths[0]) {
        return try discoverFilesGitAware(gitRepo: gitRepo)
    }

    // Fall back to regular file system walking
    return try discoverFilesRegular()
}

private func discoverFilesGitAware(gitRepo: GitRepository) throws -> [URL] {
    let trackedFiles = try gitRepo.listTrackedFiles()
    let baseURL = URL(fileURLWithPath: gitRepo.rootPath)

    return trackedFiles
        .map { baseURL.appendingPathComponent($0) }
        .filter { shouldInclude($0) }
}
```

### 2.3 Git Diff Mode (2h)

**Implementation:**
```swift
extension GitRepository {
    public struct FileChange {
        public let status: String  // M, A, D, R
        public let path: String
    }

    public func getDiff() throws -> [FileChange] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--name-status", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: rootPath)

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> FileChange? in
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return FileChange(
                    status: String(parts[0]),
                    path: String(parts[1])
                )
            }
    }
}
```

**Update ContextCollector:**
```swift
public func collect() throws -> CollectionResult {
    let fileURLs: [URL]

    if configuration.diffMode {
        fileURLs = try collectDiffFiles()
    } else {
        fileURLs = try discovery.discoverFiles()
    }

    // ... rest of collection logic
}

private func collectDiffFiles() throws -> [URL] {
    guard let gitRepo = GitRepository.find(for: configuration.paths[0]) else {
        throw YeetError.gitCommandFailed("Not in a git repository")
    }

    let changes = try gitRepo.getDiff()
    let baseURL = URL(fileURLWithPath: gitRepo.rootPath)

    return changes
        .filter { $0.status != "D" }  // Skip deleted files
        .map { baseURL.appendingPathComponent($0.path) }
}
```

### 2.4 Git History Collection (3h)

**Implementation:**
```swift
extension GitRepository {
    public struct Commit {
        public let hash: String
        public let shortHash: String
        public let author: String
        public let email: String
        public let date: String
        public let subject: String
        public let body: String
        public let files: [FileChange]
        public let stats: String
    }

    public func getHistory(count: Int = 5, mode: String = "summary") throws -> [Commit] {
        // Get commit list
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "log",
            "-n", "\(count)",
            "--format=%H|%h|%an|%ae|%ai|%s|%b",
            "--name-status"
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: rootPath)

        // ... parse output into Commit objects
    }
}
```

**Update OutputFormatter:**
```swift
public func formatText(files: [FileContent], totalTokens: Int, gitHistory: [GitRepository.Commit]?) -> String {
    var output = ""

    // File contents
    for fileContent in files {
        output += formatFileHeader(fileContent)
        output += fileContent.content
        output += "\n"
        output += formatFileFooter(fileContent)
        output += "\n"
    }

    // Git history
    if let history = gitHistory, !history.isEmpty {
        output += "\n\n"
        output += formatGitHistory(history)
    }

    // Summary
    output += formatSummary(fileCount: files.count, totalTokens: totalTokens)

    return output
}

private func formatGitHistory(_ history: [GitRepository.Commit]) -> String {
    var output = ""
    output += String(repeating: "=", count: 80) + "\n"
    output += "GIT HISTORY (Last \(history.count) commits)\n"
    output += String(repeating: "=", count: 80) + "\n\n"

    for commit in history {
        output += "Commit: \(commit.shortHash)\n"
        output += "Author: \(commit.author) <\(commit.email)>\n"
        output += "Date: \(commit.date)\n"
        output += "Subject: \(commit.subject)\n"
        if !commit.body.isEmpty {
            output += "\n\(commit.body)\n"
        }
        output += "\nFiles Changed:\n"
        for file in commit.files {
            output += "  \(file.status) \(file.path)\n"
        }
        output += "\n" + String(repeating: "-", count: 80) + "\n\n"
    }

    return output
}
```

---

## Phase 3: Missing Features (MEDIUM PRIORITY)
**Goal**: Complete feature set
**Estimated Time**: 4-6 hours

### 3.1 Directory Tree Generation (2h)

**Implement tree visualization:**

```swift
// Sources/YeetCore/TreeGenerator.swift
public struct TreeGenerator {
    public static func generate(for files: [FileContent], rootPath: String) -> String {
        // Build tree structure
        var tree: [String: Any] = [:]

        for file in files {
            let relativePath = file.path.replacingOccurrences(of: rootPath + "/", with: "")
            let components = relativePath.split(separator: "/").map(String.init)

            var current = tree
            for (index, component) in components.enumerated() {
                if index == components.count - 1 {
                    // Leaf node (file)
                    current[component] = nil
                } else {
                    // Directory node
                    if current[component] == nil {
                        current[component] = [String: Any]()
                    }
                    current = current[component] as! [String: Any]
                }
            }
        }

        // Render tree
        return renderTree(tree, prefix: "", isLast: true)
    }

    private static func renderTree(
        _ node: [String: Any],
        prefix: String,
        isLast: Bool
    ) -> String {
        var output = ""
        let sorted = node.keys.sorted()

        for (index, key) in sorted.enumerated() {
            let isLastItem = index == sorted.count - 1
            let connector = isLastItem ? "└── " : "├── "
            let childPrefix = prefix + (isLastItem ? "    " : "│   ")

            output += prefix + connector + key + "\n"

            if let children = node[key] as? [String: Any] {
                output += renderTree(children, prefix: childPrefix, isLast: isLastItem)
            }
        }

        return output
    }
}
```

**Update OutputFormatter:**
```swift
public func generateTree(for files: [FileContent]) -> String {
    guard !files.isEmpty else {
        return "No files collected.\n"
    }

    // Find common root
    let paths = files.map { $0.path }
    let commonRoot = findCommonRoot(paths)

    var output = ""
    output += "\nDirectory Structure:\n"
    output += String(repeating: "-", count: 60) + "\n"
    output += TreeGenerator.generate(for: files, rootPath: commonRoot)
    output += String(repeating: "-", count: 60) + "\n"

    return output
}
```

### 3.2 Better Error Messages (1h)

**Improve error descriptions:**

```swift
public enum YeetError: LocalizedError {
    case clipboardFailed
    case unsupportedPlatform
    case invalidPath(String)
    case tokenizerNotFound
    case gitCommandFailed(String)
    case fileReadError(String, underlying: Error?)
    case tooManyFiles(Int)
    case fileTooLarge(String, size: Int)
    case permissionDenied(String)

    public var errorDescription: String? {
        switch self {
        case .clipboardFailed:
            return "Failed to copy output to clipboard. Please ensure pbcopy is available."
        case .unsupportedPlatform:
            return "Clipboard operations are only supported on macOS."
        case .invalidPath(let path):
            return "Invalid path: '\(path)'. Please check the path exists and is accessible."
        case .tokenizerNotFound:
            return "Tokenizer encoding file not found."
        case .gitCommandFailed(let message):
            return "Git command failed: \(message)\nEnsure git is installed and you're in a git repository."
        case .fileReadError(let path, let underlying):
            if let error = underlying {
                return "Failed to read file '\(path)': \(error.localizedDescription)"
            }
            return "Failed to read file: '\(path)'"
        case .tooManyFiles(let count):
            return "Too many files (\(count)). Maximum is \(SafetyLimits.maxFiles). Use --max-files to increase."
        case .fileTooLarge(let path, let size):
            return "File too large: '\(path)' (\(size / 1024 / 1024)MB). Maximum is \(SafetyLimits.maxFileSize / 1024 / 1024)MB."
        case .permissionDenied(let path):
            return "Permission denied: '\(path)'. Check file permissions."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .tooManyFiles:
            return "Try filtering with --type or --include patterns, or use --max-files flag."
        case .fileTooLarge:
            return "Skip large files with exclusion patterns or increase limit with --max-file-size."
        case .gitCommandFailed:
            return "Run 'git status' to verify repository state, or use without --diff flag."
        default:
            return nil
        }
    }
}
```

### 3.3 Progress Indicators (1-2h)

**Add progress reporting for large operations:**

```swift
// Sources/YeetCore/ProgressReporter.swift
public protocol ProgressReporter {
    func reportDiscovery(filesFound: Int)
    func reportReading(file: String, current: Int, total: Int)
    func reportComplete(files: Int, tokens: Int)
}

public struct ConsoleProgressReporter: ProgressReporter {
    public func reportDiscovery(filesFound: Int) {
        print("📁 Discovered \(filesFound) files...", terminator: "\r")
        fflush(stdout)
    }

    public func reportReading(file: String, current: Int, total: Int) {
        let percent = (current * 100) / total
        print("📖 Reading files... \(current)/\(total) (\(percent)%)", terminator: "\r")
        fflush(stdout)
    }

    public func reportComplete(files: Int, tokens: Int) {
        print("\n✓ Context copied to clipboard!")
        print("  Files: \(files)")
        print("  Tokens: \(tokens)")
    }
}
```

**Add to CLI:**
```swift
@Flag(name: .long, help: "Show progress while collecting")
var progress: Bool = false

// In run():
let progressReporter: ProgressReporter? = progress ? ConsoleProgressReporter() : nil
```

---

## Phase 4: Polish & Documentation (MEDIUM PRIORITY)
**Goal**: Production-ready user experience
**Estimated Time**: 3-4 hours

### 4.1 Inline Documentation (1h)

**Add DocC comments:**

```swift
/// AI context aggregator for source code
///
/// Yeet collects source code files, applies intelligent truncation based on
/// token limits, and formats the output for use with Large Language Models.
///
/// ## Usage
///
/// ```swift
/// let config = CollectorConfiguration(paths: ["src/"])
/// let collector = ContextCollector(configuration: config)
/// let result = try collector.collect()
/// try result.copyToClipboard()
/// ```
public class ContextCollector {
    // ...
}
```

### 4.2 Usage Examples (1h)

**Create examples directory:**
```
Examples/
├── basic-usage.sh
├── advanced-filtering.sh
├── git-integration.sh
└── ci-integration.sh
```

**basic-usage.sh:**
```bash
#!/bin/bash
# Basic Yeet usage examples

# Collect current directory
yeet

# Collect specific files
yeet src/main.swift README.md

# Collect with glob patterns
yeet "src/**/*.swift"

# Filter by type
yeet --type "*.ts" --type "*.tsx" src/

# Limit token count
yeet --max-tokens 5000 src/

# Output as JSON
yeet --json src/ > context.json
```

### 4.3 Installation Guide (1h)

**Update README with:**
- [ ] Homebrew installation (when ready)
- [ ] Manual installation steps
- [ ] Building from source
- [ ] System requirements
- [ ] Quick start guide

### 4.4 Migration Guide (1h)

**Create MIGRATION.md:**
```markdown
# Migrating from Python copy_context.py

## Command Equivalents

| Python | Swift |
|--------|-------|
| `copy_context` | `yeet` |
| `copy_context --without-history` | `yeet --without-history` |
| `copy_context --diff` | `yeet --diff` |
| `copy_context --max-tokens 5000` | `yeet --max-tokens 5000` |

## Differences

- Clipboard: macOS only (vs universal)
- Performance: ~10x faster
- Token accuracy: 60% (heuristic) vs 100% (BPE)
```

---

## Phase 5: Performance & Optimization (LOW PRIORITY)
**Goal**: Handle large projects efficiently
**Estimated Time**: 4-6 hours

### 5.1 Concurrent File Reading (3h)

**Use Swift Concurrency:**

```swift
public func collect() async throws -> CollectionResult {
    let fileURLs = try discovery.discoverFiles()

    // Read files concurrently
    let fileContents = try await withThrowingTaskGroup(
        of: FileContent.self,
        returning: [FileContent].self
    ) { group in
        for url in fileURLs {
            group.addTask {
                try self.reader.readFile(at: url)
            }
        }

        var results: [FileContent] = []
        for try await content in group {
            results.append(content)
        }
        return results.sorted { $0.path < $1.path }
    }

    // ... rest of logic
}
```

**Update CLI:**
```swift
@main
struct Yeet: AsyncParsableCommand {
    mutating func run() async throws {
        // ... async execution
    }
}
```

### 5.2 Memory Optimization (1-2h)

**Stream output instead of buffering:**
- Don't load all files into memory
- Write directly to clipboard/file
- Use generators/AsyncSequence

### 5.3 Performance Benchmarks (1-2h)

**Create benchmark suite:**
```swift
// Tests/YeetCoreTests/PerformanceTests.swift
func testPerformanceLargeProject() {
    measure {
        // Collect 1000 files
    }
}

func testPerformanceGlobExpansion() {
    measure {
        // Expand complex glob pattern
    }
}
```

**Target metrics:**
- 100 files: < 200ms
- 1000 files: < 2s
- 5000 files: < 10s

---

## Phase 6: Distribution (LOW PRIORITY)
**Goal**: Easy installation
**Estimated Time**: 3-4 hours

### 6.1 Homebrew Formula (2h)

**Create tap repository:**
```ruby
# Formula/yeet.rb
class Yeet < Formula
  desc "AI context aggregator for source code"
  homepage "https://github.com/yourusername/yeet"
  url "https://github.com/yourusername/yeet/archive/v1.0.0.tar.gz"
  sha256 "..."
  license "MIT"

  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/yeet"
  end

  test do
    system "#{bin}/yeet", "--version"
  end
end
```

### 6.2 GitHub Actions CI/CD (1-2h)

**.github/workflows/release.yml:**
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: swift build -c release
      - name: Test
        run: swift test
      - name: Create Release
        uses: actions/create-release@v1
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ github.ref }}
          draft: false
          prerelease: false
      - name: Upload Binary
        uses: actions/upload-release-asset@v1
        with:
          upload_url: ${{ steps.create_release.outputs.upload_url }}
          asset_path: .build/release/yeet
          asset_name: yeet
          asset_content_type: application/octet-stream
```

---

## Summary

### Effort Estimates

| Phase | Priority | Time | Completion |
|-------|----------|------|------------|
| Phase 1: Validation & Safety | HIGH | 4-6h | 0% |
| Phase 2: Git Integration | HIGH | 6-8h | 0% |
| Phase 3: Missing Features | MEDIUM | 4-6h | 0% |
| Phase 4: Polish & Documentation | MEDIUM | 3-4h | 0% |
| Phase 5: Performance | LOW | 4-6h | 0% |
| Phase 6: Distribution | LOW | 3-4h | 0% |
| **TOTAL** | | **24-34h** | **0%** |

### Critical Path to v1.0.0

**Minimum for v1.0.0:**
1. Phase 1: Validation & Safety (6h)
2. Phase 2: Git Integration (8h)
3. Phase 4.1-4.3: Basic docs (2h)

**Total: ~16 hours**

### Recommended Approach

**Week 1: Core Completion**
- Day 1-2: Phase 1 (Validation & Safety)
- Day 3-4: Phase 2 (Git Integration)
- Day 5: Testing & bug fixes

**Week 2: Polish & Ship**
- Day 1: Phase 3 (Missing features)
- Day 2: Phase 4 (Documentation)
- Day 3: Final testing
- Day 4: Release v1.0.0

**Future: Optimization**
- Phase 5: Performance (as needed)
- Phase 6: Distribution (Homebrew, etc.)

### Version Roadmap

**v0.9.0 (Current):**
- ✓ Core file collection
- ✓ Pattern matching
- ✓ Basic output
- ✗ No git integration
- ✗ Limited testing

**v1.0.0 (Target):**
- ✓ Full git integration
- ✓ Comprehensive tests
- ✓ Safety limits
- ✓ Good error messages
- ✓ Documentation

**v1.1.0 (Future):**
- ✓ Performance optimizations
- ✓ Progress indicators
- ✓ Tree visualization
- ✓ Concurrent file reading

**v1.2.0 (Future):**
- ✓ BPE tokenizer (95% accuracy)
- ✓ Advanced features
- ✓ Homebrew distribution

---

## Next Steps

**Immediate:**
1. Review this plan
2. Decide on priorities
3. Start with Phase 1.1 (Test existing CLI flags)

**Questions for You:**
- Do you want to prioritize git integration or validation first?
- Is the 16-hour critical path acceptable?
- Any features that should be higher/lower priority?
