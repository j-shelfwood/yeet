import Foundation

/// Configuration loaded from .yeetconfig files
///
/// Supports hierarchical config loading:
/// 1. ~/.yeetconfig (user global defaults)
/// 2. .yeetconfig (project-specific overrides)
/// 3. Command-line flags (highest priority)
public struct YeetConfig: Codable, Sendable {
    /// Default values for command-line options
    public var defaults: DefaultsConfig?

    /// File and directory exclusion rules
    public var exclude: ExcludeConfig?

    /// File and directory inclusion patterns
    public var include: IncludeConfig?

    /// Pattern-based token limits for content-aware truncation
    /// Maps glob patterns to token limits (0 = skip file entirely)
    public var tokenLimits: [String: Int]?

    /// Git integration settings
    public var git: GitConfig?

    /// Output formatting preferences
    public var output: OutputConfig?

    /// Performance tuning options
    public var performance: PerformanceConfig?

    public init(
        defaults: DefaultsConfig? = nil,
        exclude: ExcludeConfig? = nil,
        include: IncludeConfig? = nil,
        tokenLimits: [String: Int]? = nil,
        git: GitConfig? = nil,
        output: OutputConfig? = nil,
        performance: PerformanceConfig? = nil
    ) {
        self.defaults = defaults
        self.exclude = exclude
        self.include = include
        self.tokenLimits = tokenLimits
        self.git = git
        self.output = output
        self.performance = performance
    }
}

// MARK: - Sub-Configurations

public struct DefaultsConfig: Codable, Sendable {
    /// Maximum tokens per file before truncation
    public var maxTokens: Int?

    /// Maximum number of files to collect
    public var maxFiles: Int?

    /// Maximum file size in MB
    public var maxFileSizeMB: Int?

    /// Maximum total tokens across all files
    public var maxTotalTokens: Int?

    /// Show directory tree in output
    public var showTree: Bool?

    /// Suppress progress indicators
    public var quiet: Bool?

    public init(
        maxTokens: Int? = nil,
        maxFiles: Int? = nil,
        maxFileSizeMB: Int? = nil,
        maxTotalTokens: Int? = nil,
        showTree: Bool? = nil,
        quiet: Bool? = nil
    ) {
        self.maxTokens = maxTokens
        self.maxFiles = maxFiles
        self.maxFileSizeMB = maxFileSizeMB
        self.maxTotalTokens = maxTotalTokens
        self.showTree = showTree
        self.quiet = quiet
    }
}

public struct ExcludeConfig: Codable, Sendable {
    /// Directory names to exclude (e.g., ["node_modules", "vendor"])
    public var directories: [String]?

    /// File extensions to exclude (e.g., ["zip", "pyc", "so"])
    public var extensions: [String]?

    /// Glob patterns to exclude (e.g., ["*.min.*", "*.lock"])
    public var patterns: [String]?

    public init(
        directories: [String]? = nil,
        extensions: [String]? = nil,
        patterns: [String]? = nil
    ) {
        self.directories = directories
        self.extensions = extensions
        self.patterns = patterns
    }
}

public struct IncludeConfig: Codable, Sendable {
    /// File patterns to include when walking directories
    /// (e.g., ["*.swift", "*.ts", "*.py", "Makefile"])
    public var patterns: [String]?

    /// Specific file types to prioritize
    public var types: [String]?

    public init(
        patterns: [String]? = nil,
        types: [String]? = nil
    ) {
        self.patterns = patterns
        self.types = types
    }
}

public struct GitConfig: Codable, Sendable {
    /// Include git history by default
    public var includeHistory: Bool?

    /// History detail level: "none", "summary", or "full"
    public var historyMode: String?

    /// Number of commits to include
    public var historyCount: Int?

    public init(
        includeHistory: Bool? = nil,
        historyMode: String? = nil,
        historyCount: Int? = nil
    ) {
        self.includeHistory = includeHistory
        self.historyMode = historyMode
        self.historyCount = historyCount
    }
}

public struct OutputConfig: Codable, Sendable {
    /// Default output format ("text" or "json")
    public var format: String?

    /// Include directory tree
    public var includeTree: Bool?

    public init(
        format: String? = nil,
        includeTree: Bool? = nil
    ) {
        self.format = format
        self.includeTree = includeTree
    }
}

public struct PerformanceConfig: Codable, Sendable {
    /// Performance mode: "zero-tokenization" (fast) or "content-aware" (precise)
    /// - "zero-tokenization": Single FFI call, no per-file limits
    /// - "content-aware": Apply token_limits patterns (slower but respects budgets)
    public var mode: String?

    public init(mode: String? = nil) {
        self.mode = mode
    }
}

// MARK: - Default Config Templates

extension YeetConfig {
    /// Default user-level configuration
    public static let defaultUserConfig = YeetConfig(
        defaults: DefaultsConfig(
            maxTokens: 10000,
            maxFiles: 100000,
            maxFileSizeMB: 100,
            maxTotalTokens: 1_000_000,
            showTree: false,
            quiet: false
        ),
        exclude: ExcludeConfig(
            directories: [
                "node_modules",
                "vendor",
                "build",
                ".build",
                ".git",
                ".vscode",
                ".swiftpm",
                "venv",
                ".env",
                "storage",
                "public/storage",
                "Library",
                "Temp",
                "target",
                "dist",
                "coverage",
                ".next",
                ".nuxt"
            ],
            extensions: [
                "zip", "tar", "gz", "rar", "7z",
                "exe", "bin", "so", "dll", "dylib",
                "jar", "pyc", "class",
                "o", "a", "obj", "lib",
                "woff", "woff2", "eot", "ttf", "otf",
                "db", "sqlite", "lock"
            ],
            patterns: []
        ),
        include: IncludeConfig(
            patterns: [
                "*.swift", "*.h", "*.m",
                "*.ts", "*.tsx", "*.js", "*.jsx",
                "*.py", "*.rb", "*.php",
                "*.rs", "*.go", "*.java", "*.kt",
                "*.c", "*.cpp", "*.cs",
                "*.md", "*.txt",
                "*.json", "*.yaml", "*.yml", "*.toml",
                "*.html", "*.css", "*.scss",
                "*.sh", "*.bash",
                "Makefile", "Dockerfile",
                ".gitignore", ".gitattributes"
            ]
        ),
        tokenLimits: [
            "*.lock": 500,
            "*-lock.json": 500,
            "package-lock.json": 500,
            "composer.lock": 500,
            "Gemfile.lock": 500,
            "*.resolved": 500,
            "*.min.*": 0,
            "*.bundle.*": 0,
            "**/mocks/**": 1000,
            "*mock*.json": 1000,
            "*api*.json": 2000
        ],
        git: GitConfig(
            includeHistory: true,
            historyMode: "summary",
            historyCount: 5
        ),
        output: OutputConfig(
            format: "text",
            includeTree: false
        ),
        performance: PerformanceConfig(
            mode: "zero-tokenization"
        )
    )
}
