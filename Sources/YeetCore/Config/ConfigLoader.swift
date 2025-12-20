import Foundation
import TOMLKit

/// Loads and merges .yeetconfig files from multiple locations
///
/// Priority order (highest to lowest):
/// 1. Command-line flags
/// 2. ./.yeetconfig (project root)
/// 3. ~/.yeetconfig (user home)
/// 4. Built-in defaults
public struct ConfigLoader {

    /// Load merged configuration from all sources
    ///
    /// Searches for .yeetconfig files in:
    /// - User home directory (~/.yeetconfig)
    /// - Project root (closest .git directory or CWD)
    ///
    /// - Parameter basePath: Starting path for project config search
    /// - Returns: Merged configuration (user defaults + project overrides)
    public static func loadConfig(for basePath: String = ".") -> YeetConfig {
        var merged = YeetConfig.defaultUserConfig

        // 1. Load user-level config (~/.yeetconfig)
        if let userConfig = loadUserConfig() {
            merged = merge(base: merged, override: userConfig)
        }

        // 2. Load project-level config (.yeetconfig in project root)
        if let projectConfig = loadProjectConfig(basePath: basePath) {
            merged = merge(base: merged, override: projectConfig)
        }

        return merged
    }

    /// Load user-level config from ~/.yeetconfig
    private static func loadUserConfig() -> YeetConfig? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configPath = homeDir.appendingPathComponent(".yeetconfig")
        return loadConfigFile(at: configPath)
    }

    /// Load project-level config from .yeetconfig in project root
    ///
    /// Searches upward from basePath to find project root:
    /// 1. Closest directory containing .git
    /// 2. Falls back to basePath if no .git found
    private static func loadProjectConfig(basePath: String) -> YeetConfig? {
        let projectRoot = findProjectRoot(from: basePath) ?? basePath
        let configPath = URL(fileURLWithPath: projectRoot)
            .appendingPathComponent(".yeetconfig")
        return loadConfigFile(at: configPath)
    }

    /// Find project root by searching for .git directory
    private static func findProjectRoot(from path: String) -> String? {
        var currentPath = URL(fileURLWithPath: path).standardized

        while currentPath.path != "/" {
            let gitPath = currentPath.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitPath.path) {
                return currentPath.path
            }
            currentPath = currentPath.deletingLastPathComponent()
        }

        return nil
    }

    /// Load and parse TOML config file
    private static func loadConfigFile(at url: URL) -> YeetConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let tomlString = try String(contentsOf: url, encoding: .utf8)
            let tomlTable = try TOMLTable(string: tomlString)

            // Parse TOML into YeetConfig
            return try parseYeetConfig(from: tomlTable)
        } catch {
            // Log warning but don't fail - just skip this config file
            // Use ANSI color codes for better visibility
            let yellow = "\u{001B}[1;33m"
            let reset = "\u{001B}[0m"
            let bold = "\u{001B}[1m"

            fputs("\n\(yellow)⚠ Warning:\(reset) Failed to parse config file\n", stderr)
            fputs("  \(bold)File:\(reset) \(url.path)\n", stderr)
            fputs("  \(bold)Error:\(reset) \(error.localizedDescription)\n", stderr)
            fputs("  \(bold)→\(reset) Using built-in defaults instead\n", stderr)
            fputs("  \(bold)Tip:\(reset) Validate TOML syntax at https://www.toml-lint.com\n\n", stderr)
            return nil
        }
    }

    /// Parse TOML table into YeetConfig
    private static func parseYeetConfig(from table: TOMLTable) throws -> YeetConfig {
        // Helper to safely extract TOMLTable from nested sections
        func getTable(_ key: String) -> TOMLTable? {
            return table[key]?.table
        }

        return YeetConfig(
            defaults: try? parseDefaultsConfig(from: getTable("defaults")),
            exclude: try? parseExcludeConfig(from: getTable("exclude")),
            include: try? parseIncludeConfig(from: getTable("include")),
            tokenLimits: parseTokenLimits(from: getTable("token_limits")),
            git: try? parseGitConfig(from: getTable("git")),
            output: try? parseOutputConfig(from: getTable("output")),
            performance: try? parsePerformanceConfig(from: getTable("performance"))
        )
    }

    private static func parseDefaultsConfig(from table: TOMLTable?) throws -> DefaultsConfig? {
        guard let table = table else { return nil }
        return DefaultsConfig(
            maxTokens: table["max_tokens"]?.int,
            maxFiles: table["max_files"]?.int,
            maxFileSizeMB: table["max_file_size_mb"]?.int,
            maxTotalTokens: table["max_total_tokens"]?.int,
            showTree: table["show_tree"]?.bool,
            quiet: table["quiet"]?.bool
        )
    }

    private static func parseExcludeConfig(from table: TOMLTable?) throws -> ExcludeConfig? {
        guard let table = table else { return nil }
        return ExcludeConfig(
            directories: table["directories"]?.array?.compactMap { $0.string },
            extensions: table["extensions"]?.array?.compactMap { $0.string },
            patterns: table["patterns"]?.array?.compactMap { $0.string }
        )
    }

    private static func parseIncludeConfig(from table: TOMLTable?) throws -> IncludeConfig? {
        guard let table = table else { return nil }
        return IncludeConfig(
            patterns: table["patterns"]?.array?.compactMap { $0.string },
            types: table["types"]?.array?.compactMap { $0.string }
        )
    }

    private static func parseTokenLimits(from table: TOMLTable?) -> [String: Int]? {
        guard let table = table else { return nil }
        var limits: [String: Int] = [:]
        for (key, value) in table {
            if let intValue = value.int {
                limits[key] = intValue
            }
        }
        return limits.isEmpty ? nil : limits
    }

    private static func parseGitConfig(from table: TOMLTable?) throws -> GitConfig? {
        guard let table = table else { return nil }
        return GitConfig(
            includeHistory: table["include_history"]?.bool,
            historyMode: table["history_mode"]?.string,
            historyCount: table["history_count"]?.int
        )
    }

    private static func parseOutputConfig(from table: TOMLTable?) throws -> OutputConfig? {
        guard let table = table else { return nil }
        return OutputConfig(
            format: table["format"]?.string,
            includeTree: table["include_tree"]?.bool
        )
    }

    private static func parsePerformanceConfig(from table: TOMLTable?) throws -> PerformanceConfig? {
        guard let table = table else { return nil }
        return PerformanceConfig(
            mode: table["mode"]?.string
        )
    }

    /// Merge two configs (override takes precedence for non-nil values)
    private static func merge(base: YeetConfig, override: YeetConfig) -> YeetConfig {
        return YeetConfig(
            defaults: merge(base: base.defaults, override: override.defaults),
            exclude: merge(base: base.exclude, override: override.exclude),
            include: merge(base: base.include, override: override.include),
            tokenLimits: mergeDictionaries(base: base.tokenLimits, override: override.tokenLimits),
            git: merge(base: base.git, override: override.git),
            output: merge(base: base.output, override: override.output),
            performance: merge(base: base.performance, override: override.performance)
        )
    }

    private static func merge(base: DefaultsConfig?, override: DefaultsConfig?) -> DefaultsConfig? {
        guard let base = base else { return override }
        guard let override = override else { return base }

        return DefaultsConfig(
            maxTokens: override.maxTokens ?? base.maxTokens,
            maxFiles: override.maxFiles ?? base.maxFiles,
            maxFileSizeMB: override.maxFileSizeMB ?? base.maxFileSizeMB,
            maxTotalTokens: override.maxTotalTokens ?? base.maxTotalTokens,
            showTree: override.showTree ?? base.showTree,
            quiet: override.quiet ?? base.quiet
        )
    }

    private static func merge(base: ExcludeConfig?, override: ExcludeConfig?) -> ExcludeConfig? {
        guard let base = base else { return override }
        guard let override = override else { return base }

        return ExcludeConfig(
            directories: mergeArrays(base: base.directories, override: override.directories),
            extensions: mergeArrays(base: base.extensions, override: override.extensions),
            patterns: mergeArrays(base: base.patterns, override: override.patterns)
        )
    }

    private static func merge(base: IncludeConfig?, override: IncludeConfig?) -> IncludeConfig? {
        guard let base = base else { return override }
        guard let override = override else { return base }

        return IncludeConfig(
            patterns: mergeArrays(base: base.patterns, override: override.patterns),
            types: mergeArrays(base: base.types, override: override.types)
        )
    }

    private static func merge(base: GitConfig?, override: GitConfig?) -> GitConfig? {
        guard let base = base else { return override }
        guard let override = override else { return base }

        return GitConfig(
            includeHistory: override.includeHistory ?? base.includeHistory,
            historyMode: override.historyMode ?? base.historyMode,
            historyCount: override.historyCount ?? base.historyCount
        )
    }

    private static func merge(base: OutputConfig?, override: OutputConfig?) -> OutputConfig? {
        guard let base = base else { return override }
        guard let override = override else { return base }

        return OutputConfig(
            format: override.format ?? base.format,
            includeTree: override.includeTree ?? base.includeTree
        )
    }

    private static func merge(base: PerformanceConfig?, override: PerformanceConfig?) -> PerformanceConfig? {
        guard let base = base else { return override }
        guard let override = override else { return base }

        return PerformanceConfig(
            mode: override.mode ?? base.mode
        )
    }

    /// Merge arrays (override replaces base entirely if provided)
    private static func mergeArrays<T>(base: [T]?, override: [T]?) -> [T]? {
        return override ?? base
    }

    /// Merge dictionaries (override wins for conflicts, combines keys)
    private static func mergeDictionaries<K, V>(base: [K: V]?, override: [K: V]?) -> [K: V]? {
        guard let base = base else { return override }
        guard let override = override else { return base }

        var merged = base
        for (key, value) in override {
            merged[key] = value
        }
        return merged
    }
}

// Note: TOML parsing now handled by TOMLKit dependency
