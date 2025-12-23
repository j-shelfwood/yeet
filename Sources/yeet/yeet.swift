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
        version: "1.0.1"
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
        help: "Show per-file token statistics"
    )
    var stats: Bool = false

    @Flag(
        name: .long,
        help: "Group statistics by directory (requires --stats)"
    )
    var statsByDir: Bool = false

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
        help: "Maximum number of files to collect (default: 10000)"
    )
    var maxFiles: Int = 10_000

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
        let effectiveMaxFiles = maxFiles != 10_000 ? maxFiles : (loadedConfig.defaults?.maxFiles ?? 10_000)
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
        let config = CollectorConfiguration(
            paths: finalPaths,
            maxTokens: effectiveMaxTokens,
            includePatterns: effectiveIncludePatterns,
            excludeDirectories: effectiveExcludeDirectories,
            excludePatterns: effectiveExcludePatterns,
            typeFilters: effectiveTypeFilters,
            tokenLimits: loadedConfig.tokenLimits,
            diffMode: diff,
            includeHistory: effectiveIncludeHistory,
            historyMode: effectiveHistoryMode,
            historyCount: effectiveHistoryCount,
            outputJSON: json,
            listOnly: listOnly,
            showTree: effectiveShowTree,
            quiet: effectiveQuiet,
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

            if listOnly {
                print(result.fileList)
            } else {
                try result.copyToClipboard()
                print("✓ Context copied to clipboard!")
                print("  Files: \(result.fileCount)")
                print("  Tokens: \(result.totalTokens)")
            }

            // Show statistics if requested
            if stats {
                // Enhanced summary
                print(TextFormatter.formatEnhancedSummary(
                    files: result.files,
                    totalTokens: result.totalTokens,
                    budget: effectiveMaxTotalTokens
                ))

                // Per-file or per-directory stats
                if statsByDir {
                    print(TextFormatter.formatStatsByDirectory(files: result.files))
                } else {
                    print(TextFormatter.formatStats(files: result.files, showAll: false))
                }
            }
        }
    }

    // MARK: - Helpers

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
