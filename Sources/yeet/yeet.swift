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
        """,
        version: "1.0.0"
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
        // Determine final paths
        let finalPaths: [String]
        if let filesFromPath = filesFrom {
            finalPaths = try loadPathsFromFile(filesFromPath)
        } else if !paths.isEmpty {
            finalPaths = paths
        } else {
            finalPaths = ["."]
        }

        // Configure safety limits
        let safetyLimits = SafetyLimits(
            maxFiles: maxFiles,
            maxFileSize: maxFileSizeMB * 1024 * 1024,  // Convert MB to bytes
            maxTotalTokens: maxTotalTokens
        )

        // Configure collector
        let config = CollectorConfiguration(
            paths: finalPaths,
            maxTokens: maxTokens,
            includePatterns: include,
            excludeDirectories: exclude,
            typeFilters: type,
            diffMode: diff,
            includeHistory: !withoutHistory,
            historyMode: historyMode,
            historyCount: historyCount,
            outputJSON: json,
            listOnly: listOnly,
            showTree: tree,
            quiet: quiet,
            rootDirectory: root,
            encodingPath: encodingPath,
            safetyLimits: safetyLimits
        )

        // Execute collection
        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        if listOnly {
            print(result.fileList)
        } else {
            try result.copyToClipboard()
            print("✓ Context copied to clipboard!")
            print("  Files: \(result.fileCount)")
            print("  Tokens: \(result.totalTokens)")
        }
    }

    // MARK: - Helpers

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
