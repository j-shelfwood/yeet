import ArgumentParser
import YeetCore
import Foundation

@main
struct Yeet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "yeet",
        abstract: "AI context aggregator - Package source code for LLM consumption",
        discussion: """
        Yeet collects source code files, applies intelligent truncation based on token limits,
        and copies the formatted context to your clipboard for use with AI assistants.

        Configuration files (.yeetconfig) provide persistent settings:
          • Project config: ./.yeetconfig (team defaults)
          • User config: ~/.yeetconfig (personal preferences)
          • See CONFIGURATION.md for complete reference
        """,
        version: "1.5.0"
    )

    // MARK: - Input Sources

    @Argument(
        help: "Files, directories, or glob patterns to include (default: current directory)",
        transform: { $0 }
    )
    var paths: [String] = []

    @Option(
        name: .long,
        help: "Read paths from file (one per line, use '-' for stdin)"
    )
    var filesFrom: String?

    // MARK: - Token & Truncation Options

    @Option(
        name: .long,
        help: "Maximum tokens per file (default: 10000)"
    )
    var maxTokens: Int = 10000

    // MARK: - Pattern Filtering

    @Option(
        name: [.short, .long],
        parsing: .upToNextOption,
        help: "File patterns to include (e.g., '*.swift', '*.ts')"
    )
    var include: [String] = []

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "Additional directories to exclude"
    )
    var exclude: [String] = []

    @Option(
        name: [.short, .long],
        parsing: .upToNextOption,
        help: "Filter by specific file types (e.g., '*.swift')"
    )
    var type: [String] = []

    // MARK: - Git Integration

    @Flag(
        name: .long,
        help: "Collect only git diff (uncommitted changes)"
    )
    var diff: Bool = false

    @Flag(
        name: .long,
        help: "Exclude git history from output"
    )
    var withoutHistory: Bool = false

    @Option(
        name: .long,
        help: "Git history mode: 'none', 'summary', or 'full' (default: summary)"
    )
    var historyMode: String = "summary"

    @Option(
        name: .long,
        help: "Number of git commits to include (default: 5)"
    )
    var historyCount: Int = 5

    // MARK: - Output Options

    @Flag(
        name: .long,
        help: "Output as JSON instead of plain text"
    )
    var json: Bool = false

    @Flag(
        name: .long,
        help: "List files that would be collected without copying"
    )
    var listOnly: Bool = false

    @Flag(
        name: .long,
        inversion: .prefixedNo,
        help: "Show directory tree in output"
    )
    var tree: Bool = false

    @Flag(
        name: .long,
        help: "Suppress progress indicators"
    )
    var quiet: Bool = false

    @Flag(
        name: .long,
        help: "Run performance benchmark (3 iterations, reports timing)"
    )
    var benchmark: Bool = false

    @Flag(
        name: .long,
        help: "Print tokenizer status and exit"
    )
    var tokenizerStatus: Bool = false

    // MARK: - Advanced Options

    @Option(
        name: .long,
        help: "Base directory for relative paths"
    )
    var root: String?

    @Option(
        name: .long,
        help: "Path to custom tokenizer encoding file"
    )
    var encodingPath: String?

    // MARK: - Safety Limits

    @Option(
        name: .long,
        help: "Maximum number of files to collect (default: 100000)"
    )
    var maxFiles: Int = 100_000

    @Option(
        name: .long,
        help: "Maximum file size in MB (default: 100)"
    )
    var maxFileSizeMB: Int = 100

    @Option(
        name: .long,
        help: "Maximum total tokens across all files (default: 1000000)"
    )
    var maxTotalTokens: Int = 1_000_000

    // MARK: - Execution

    mutating func run() async throws {
        // Handle tokenizer status flag
        if tokenizerStatus {
            printTokenizerStatus()
            return
        }

        // Determine final paths first
        let finalPaths: [String]
        if let filesFromPath = filesFrom {
            finalPaths = try loadPathsFromFile(filesFromPath)
        } else if !paths.isEmpty {
            finalPaths = paths
        } else {
            finalPaths = ["."]
        }

        // Determine base path for config loading
        // Priority: --root flag > first input path > current directory
        let configBasePath: String
        if let explicitRoot = root {
            configBasePath = explicitRoot
        } else {
            // Use first input path as config base (supports both files and directories)
            configBasePath = finalPaths.first ?? "."
        }

        // Load hierarchical config (.yeetconfig → ~/.yeetconfig → defaults)
        let loadedConfig = ConfigLoader.loadConfig(for: configBasePath)

        // Merge CLI flags with config (CLI takes priority)
        let effectiveMaxTokens = maxTokens != 10000 ? maxTokens : (loadedConfig.defaults?.maxTokens ?? 10000)
        let effectiveMaxFiles = maxFiles != 100_000 ? maxFiles : (loadedConfig.defaults?.maxFiles ?? 100_000)
        let effectiveMaxFileSizeMB = maxFileSizeMB != 100 ? maxFileSizeMB : (loadedConfig.defaults?.maxFileSizeMB ?? 100)
        let effectiveMaxTotalTokens = maxTotalTokens != 1_000_000 ? maxTotalTokens : (loadedConfig.defaults?.maxTotalTokens ?? 1_000_000)
        let effectiveShowTree = tree || (loadedConfig.defaults?.showTree ?? false)
        let effectiveQuiet = quiet || (loadedConfig.defaults?.quiet ?? false)

        // Merge include/exclude patterns
        let effectiveIncludePatterns = !include.isEmpty ? include : (loadedConfig.include?.patterns ?? [])
        let effectiveExcludeDirectories = !exclude.isEmpty ? exclude : (loadedConfig.exclude?.directories ?? [])
        let effectiveExcludePatterns = loadedConfig.exclude?.patterns ?? []
        let effectiveTypeFilters = !type.isEmpty ? type : (loadedConfig.include?.types ?? [])

        // Merge git config
        let effectiveIncludeHistory = withoutHistory ? false : (loadedConfig.git?.includeHistory ?? true)
        let effectiveHistoryMode = historyMode != "summary" ? historyMode : (loadedConfig.git?.historyMode ?? "summary")
        let effectiveHistoryCount = historyCount != 5 ? historyCount : (loadedConfig.git?.historyCount ?? 5)

        // Configure safety limits
        let safetyLimits = SafetyLimits(
            maxFiles: effectiveMaxFiles,
            maxFileSize: effectiveMaxFileSizeMB * 1024 * 1024,  // Convert MB to bytes
            maxTotalTokens: effectiveMaxTotalTokens
        )

        // Configure collector
        let effectivePerformanceMode = loadedConfig.performance?.mode ?? "zero-tokenization"
        let config = CollectorConfiguration(
            paths: finalPaths,
            maxTokens: effectiveMaxTokens,
            includePatterns: effectiveIncludePatterns,
            excludeDirectories: effectiveExcludeDirectories,
            excludePatterns: effectiveExcludePatterns,
            typeFilters: effectiveTypeFilters,
            tokenLimits: loadedConfig.tokenLimits,
            performanceMode: effectivePerformanceMode,
            diffMode: diff,
            includeHistory: effectiveIncludeHistory,
            historyMode: effectiveHistoryMode,
            historyCount: effectiveHistoryCount,
            outputJSON: json,
            listOnly: listOnly,
            showTree: effectiveShowTree,
            quiet: effectiveQuiet,
            enableTokenCounting: true,  // Always enable per-file token counting for statistics
            rootDirectory: root,
            encodingPath: encodingPath,
            safetyLimits: safetyLimits
        )

        // Execute collection
        let collector = ContextCollector(configuration: config)

        if benchmark {
            try await runBenchmark(collector: collector)
        } else {
            let result = try await collector.collect()

            // Copy to clipboard if not list-only mode
            if !listOnly {
                try result.copyToClipboard()
            }

            // Always show enhanced statistics with visual elements
            print(TextFormatter.formatEnhancedCLIOutput(
                files: result.files,
                totalTokens: result.totalTokens,
                budget: effectiveMaxTotalTokens,
                listOnly: listOnly
            ))
        }
    }

    // MARK: - Helpers

    private func printTokenizerStatus() {
        let tokenizer = GeminiTokenizer.shared
        print("=== Tokenizer Status ===")
        print("Mode: \(tokenizer.statusDescription)")
        print("Using fallback: \(tokenizer.isUsingFallback)")

        // Test with sample text
        let sample = "Hello, world! This is a test of the Gemini tokenizer. It should produce accurate token counts."
        let count = tokenizer.countSync(text: sample)
        print("\nSample text (\(sample.count) chars, \(sample.utf8.count) bytes):")
        print("  \"\(sample)\"")
        print("Token count: \(count)")
        print("Ratio (bytes/token): \(String(format: "%.2f", Double(sample.utf8.count) / Double(count)))")

        // Test encode if available
        if let tokens = tokenizer.encode(text: sample) {
            print("\nFirst 20 token IDs: \(Array(tokens.prefix(20)))")
            print("Total tokens from encode: \(tokens.count)")
        } else {
            print("\nToken IDs: N/A (fallback mode - SentencePiece not loaded)")
        }

        // Check model file
        let modelPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".yeet/tokenizer.model").path
        if FileManager.default.fileExists(atPath: modelPath) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: modelPath),
               let size = attrs[.size] as? Int {
                print("\nModel file: \(modelPath)")
                print("Size: \(size) bytes (\(String(format: "%.1f", Double(size) / 1024 / 1024)) MB)")
            }
        } else {
            print("\nModel file not found at: \(modelPath)")
        }

        // Test on a larger sample (Swift code)
        let codeBlock = """
        import Foundation

        public struct Configuration {
            let maxTokens: Int
            let paths: [String]
            var includePatterns: [String] = []

            public init(maxTokens: Int = 10000, paths: [String] = ["."]) {
                self.maxTokens = maxTokens
                self.paths = paths
            }

            func validate() throws {
                guard maxTokens > 0 else {
                    throw ConfigError.invalidTokenLimit
                }
            }
        }
        """
        let codeCount = tokenizer.countSync(text: codeBlock)
        print("\nCode block test (\(codeBlock.utf8.count) bytes):")
        print("Token count: \(codeCount)")
        print("Ratio (bytes/token): \(String(format: "%.2f", Double(codeBlock.utf8.count) / Double(codeCount)))")
    }

    private func runBenchmark(collector: ContextCollector) async throws {
        let iterations = 3
        var times: [Double] = []
        var fileCount = 0
        var tokenCount = 0

        print("🔥 Running benchmark (\(iterations) iterations)...\n")

        for i in 1...iterations {
            let start = Date()
            let result = try await collector.collect()
            let elapsed = Date().timeIntervalSince(start)
            times.append(elapsed)

            fileCount = result.fileCount
            tokenCount = result.totalTokens

            print("  Iteration \(i): \(String(format: "%.3f", elapsed))s")
        }

        let average = times.reduce(0, +) / Double(times.count)
        let min = times.min() ?? 0
        let max = times.max() ?? 0

        print("\n📊 Benchmark Results:")
        print("  Files:     \(fileCount)")
        print("  Tokens:    \(tokenCount)")
        print("  Average:   \(String(format: "%.3f", average))s")
        print("  Best:      \(String(format: "%.3f", min))s")
        print("  Worst:     \(String(format: "%.3f", max))s")
    }

    private func loadPathsFromFile(_ path: String) throws -> [String] {
        let content: String
        if path == "-" {
            // Read from stdin
            var lines: [String] = []
            while let line = readLine() {
                lines.append(line)
            }
            content = lines.joined(separator: "\n")
        } else {
            content = try String(contentsOfFile: path, encoding: .utf8)
        }

        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}
