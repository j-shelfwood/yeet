import Foundation

/// Configuration for the context collection process.
///
/// `CollectorConfiguration` encapsulates all settings that control how files are
/// discovered, processed, and formatted during context collection.
///
/// ## Example
///
/// ```swift
/// let config = CollectorConfiguration(
///     paths: ["Sources", "Tests"],
///     maxTokens: 10000,
///     includePatterns: ["*.swift"],
///     excludeDirectories: ["build", ".build"],
///     diffMode: false,
///     includeHistory: true,
///     historyCount: 10,
///     safetyLimits: SafetyLimits(
///         maxFiles: 10_000,
///         maxFileSize: 100 * 1024 * 1024,
///         maxTotalTokens: 1_000_000
///     )
/// )
/// ```
///
/// ## Configuration Groups
///
/// ### Input Sources
/// - ``paths``: Files, directories, or glob patterns to process
/// - ``maxTokens``: Maximum tokens per file before truncation
///
/// ### Pattern Filtering
/// - ``includePatterns``: Whitelist patterns (e.g., "*.swift")
/// - ``excludeDirectories``: Directories to skip
/// - ``typeFilters``: File type filters
///
/// ### Git Integration
/// - ``diffMode``: Collect only git diff (uncommitted changes)
/// - ``includeHistory``: Include git commit history
/// - ``historyMode``: History detail level (none/summary/full)
/// - ``historyCount``: Number of commits to include
///
/// ### Output Options
/// - ``outputJSON``: Format output as JSON instead of text
/// - ``listOnly``: Preview files without collecting
/// - ``showTree``: Display directory tree structure
/// - ``quiet``: Suppress progress indicators
///
/// ### Safety Limits
/// - ``safetyLimits``: Protection against excessive resource usage
///
/// - SeeAlso: ``SafetyLimits``
/// - SeeAlso: ``ContextCollector``
public struct CollectorConfiguration {
    // MARK: - Input Sources

    public let paths: [String]
    public let maxTokens: Int

    // MARK: - Pattern Filtering

    public let includePatterns: [String]
    public let excludeDirectories: [String]
    public let typeFilters: [String]

    // MARK: - Git Integration

    public let diffMode: Bool
    public let includeHistory: Bool
    public let historyMode: String
    public let historyCount: Int

    // MARK: - Output Options

    public let outputJSON: Bool
    public let listOnly: Bool
    public let showTree: Bool
    public let quiet: Bool

    // MARK: - Advanced

    public let rootDirectory: String?
    public let encodingPath: String?
    public let safetyLimits: SafetyLimits

    // MARK: - Initialization

    public init(
        paths: [String],
        maxTokens: Int = 10000,
        includePatterns: [String] = [],
        excludeDirectories: [String] = [],
        typeFilters: [String] = [],
        diffMode: Bool = false,
        includeHistory: Bool = true,
        historyMode: String = "summary",
        historyCount: Int = 5,
        outputJSON: Bool = false,
        listOnly: Bool = false,
        showTree: Bool = true,
        quiet: Bool = false,
        rootDirectory: String? = nil,
        encodingPath: String? = nil,
        safetyLimits: SafetyLimits = .default
    ) {
        self.paths = paths
        self.maxTokens = maxTokens
        self.includePatterns = includePatterns
        self.excludeDirectories = excludeDirectories
        self.typeFilters = typeFilters
        self.diffMode = diffMode
        self.includeHistory = includeHistory
        self.historyMode = historyMode
        self.historyCount = historyCount
        self.outputJSON = outputJSON
        self.listOnly = listOnly
        self.showTree = showTree
        self.quiet = quiet
        self.rootDirectory = rootDirectory
        self.encodingPath = encodingPath
        self.safetyLimits = safetyLimits
    }
}
