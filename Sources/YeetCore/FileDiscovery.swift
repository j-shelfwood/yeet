import Foundation

/// Discovers files based on patterns and exclusions
public struct FileDiscovery {
    private let fileManager = FileManager.default
    private let configuration: CollectorConfiguration

    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
    }

    /// Discover all files matching the configuration
    public func discoverFiles() throws -> [URL] {
        // Try git-aware discovery first
        if let gitRepo = GitRepository.find(for: configuration.paths.first ?? ".") {
            return try discoverFilesGitAware(gitRepo: gitRepo)
        }

        // Fall back to regular file system walking
        return try discoverFilesRegular()
    }

    // MARK: - Git-Aware Discovery

    private func discoverFilesGitAware(gitRepo: GitRepository) throws -> [URL] {
        let trackedFiles = try gitRepo.listTrackedFiles()
        let baseURL = URL(fileURLWithPath: gitRepo.rootPath)

        var allFiles = trackedFiles
            .map { baseURL.appendingPathComponent($0) }

        // If specific paths provided, filter to those
        if configuration.paths.count > 0 && configuration.paths.first != "." {
            let requestedPaths = Set(configuration.paths.map { path in
                if path.hasPrefix("/") {
                    return path
                } else {
                    return baseURL.appendingPathComponent(path).path
                }
            })

            allFiles = allFiles.filter { url in
                requestedPaths.contains { requested in
                    url.path.hasPrefix(requested)
                }
            }
        }

        // Remove duplicates and sort
        let uniqueFiles = Array(Set(allFiles)).sorted { $0.path < $1.path }

        // Filter by patterns and exclusions
        let filtered = uniqueFiles.filter { url in
            shouldInclude(url)
        }

        // Check safety limit
        if filtered.count > configuration.safetyLimits.maxFiles {
            throw YeetError.tooManyFiles(
                found: filtered.count,
                limit: configuration.safetyLimits.maxFiles
            )
        }

        return filtered
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
                allFiles.append(contentsOf: try collectFiles(from: url))
            }
        }

        // Remove duplicates and sort
        let uniqueFiles = Array(Set(allFiles)).sorted { $0.path < $1.path }

        // Filter by patterns and exclusions
        let filtered = uniqueFiles.filter { url in
            shouldInclude(url)
        }

        // Check safety limit
        if filtered.count > configuration.safetyLimits.maxFiles {
            throw YeetError.tooManyFiles(
                found: filtered.count,
                limit: configuration.safetyLimits.maxFiles
            )
        }

        return filtered
    }

    // MARK: - Private Methods

    private func collectFiles(from url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }

        if isDirectory.boolValue {
            return try walkDirectory(url)
        } else {
            return [url]
        }
    }

    private func walkDirectory(_ directory: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []

        for case let fileURL as URL in enumerator {
            // Skip excluded directories
            if FilePatterns.isExcluded(path: fileURL.path) {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                   resourceValues.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Check for additional excluded directories
            if isInExcludedDirectory(fileURL) {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                   resourceValues.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Only collect files, not directories
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory != true {
                files.append(fileURL)
            }
        }

        return files
    }

    private func shouldInclude(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension

        // Skip ignored extensions
        if FilePatterns.ignoredExtensions.contains(fileExtension) {
            return false
        }

        // Skip excluded paths
        if FilePatterns.isExcluded(path: url.path) {
            return false
        }

        // Check type filters if specified
        if !configuration.typeFilters.isEmpty {
            let matchesType = configuration.typeFilters.contains { pattern in
                FilePatterns.matches(fileName: fileName, pattern: pattern)
            }
            if !matchesType {
                return false
            }
        }

        // Check include patterns
        let patterns = configuration.includePatterns.isEmpty
            ? FilePatterns.defaultPatterns
            : Set(configuration.includePatterns)

        let matchesPattern = patterns.contains { pattern in
            FilePatterns.matches(fileName: fileName, pattern: pattern)
        }

        return matchesPattern
    }

    private func isInExcludedDirectory(_ url: URL) -> Bool {
        let pathComponents = url.pathComponents
        for component in pathComponents {
            if configuration.excludeDirectories.contains(component) {
                return true
            }
        }
        return false
    }
}
