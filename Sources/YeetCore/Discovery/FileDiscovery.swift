import Foundation

/// Main file discovery orchestrator
///
/// Coordinates git-aware and regular filesystem discovery,
/// delegating to specialized components for pattern matching,
/// path normalization, and directory walking.
public struct FileDiscovery {
    private let configuration: CollectorConfiguration
    private let gitDiscovery: GitDiscovery
    private let directoryWalker: DirectoryWalker
    private let matcher: PatternMatcher

    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
        self.gitDiscovery = GitDiscovery(configuration: configuration)
        self.directoryWalker = DirectoryWalker(configuration: configuration)
        self.matcher = PatternMatcher(configuration: configuration)
    }

    /// Discover all files matching the configuration
    ///
    /// Attempts git-aware discovery first, falling back to
    /// regular filesystem walking if not in a git repository.
    ///
    /// - Returns: Array of discovered file URLs
    /// - Throws: YeetError if safety limits exceeded or operations fail
    public func discoverFiles() throws -> [URL] {
        // Try git-aware discovery first
        let firstPath = configuration.paths.first ?? "."

        if let gitRepo = GitRepository.find(for: firstPath) {
            // Only use git discovery if one of the scan paths is within or is the git repo
            // This prevents using parent repo git when scanning a subdirectory without .git
            let absolutePath: String
            if firstPath.hasPrefix("/") {
                absolutePath = firstPath
            } else {
                absolutePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent(firstPath)
                    .standardizedFileURL
                    .path
            }

            // Check if scan path is within the git repo (or is the git repo)
            if absolutePath.hasPrefix(gitRepo.rootPath) || gitRepo.rootPath.hasPrefix(absolutePath) {
                let files = try gitDiscovery.discoverFiles(gitRepo: gitRepo)
                try checkSafetyLimit(fileCount: files.count)
                return files
            }
        }

        // Fall back to regular file system walking
        let files = try discoverFilesRegular()
        try checkSafetyLimit(fileCount: files.count)
        return files
    }

    // MARK: - Regular Discovery

    private func discoverFilesRegular() throws -> [URL] {
        let resolver = PathResolver()
        var allFiles: [URL] = []

        // Expand all input paths
        for pathString in configuration.paths {
            if pathString.contains("*") || pathString.contains("?") {
                // Glob pattern
                let expanded = try resolver.expandGlob(
                    pathString,
                    relativeTo: configuration.rootDirectory
                )
                allFiles.append(contentsOf: expanded)
            } else {
                // Regular path
                let url = try resolver.resolve(
                    pathString,
                    relativeTo: configuration.rootDirectory
                )
                allFiles.append(contentsOf: try directoryWalker.collectFiles(from: url))
            }
        }

        // Remove duplicates and sort
        let uniqueFiles = Array(Set(allFiles)).sorted { $0.path < $1.path }

        // Filter by patterns and exclusions
        let filtered = uniqueFiles.filter { url in
            matcher.shouldInclude(url)
        }

        return filtered
    }

    // MARK: - Safety Checks

    private func checkSafetyLimit(fileCount: Int) throws {
        if fileCount > configuration.safetyLimits.maxFiles {
            throw YeetError.tooManyFiles(
                found: fileCount,
                limit: configuration.safetyLimits.maxFiles
            )
        }
    }
}
