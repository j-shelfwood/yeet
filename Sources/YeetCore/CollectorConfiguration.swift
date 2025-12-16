import Foundation

/// Configuration for the context collection process
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
        self.rootDirectory = rootDirectory
        self.encodingPath = encodingPath
        self.safetyLimits = safetyLimits
    }
}
