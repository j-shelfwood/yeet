import Foundation

/// Git-aware file discovery
public struct GitDiscovery {
    private let configuration: CollectorConfiguration
    private let matcher: PatternMatcher

    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
        self.matcher = PatternMatcher(configuration: configuration)
    }

    /// Discover files using git ls-files
    ///
    /// Uses git's file tracking to efficiently discover files while
    /// respecting .gitignore rules. Applies path filtering with
    /// case-insensitive comparison on macOS.
    ///
    /// - Parameter gitRepo: Git repository instance
    /// - Returns: Array of file URLs
    /// - Throws: YeetError if operations fail
    public func discoverFiles(gitRepo: GitRepository) throws -> [URL] {
        let trackedFiles = try gitRepo.listTrackedFiles()

        // OPTIMIZATION: Trust git ls-files output - it returns valid relative paths
        // Construct URLs directly without normalizing (avoids expensive URL.standardized syscalls)
        var allFiles = trackedFiles.map { relativePath -> URL in
            // Fast string concatenation instead of appendingPathComponent + standardized
            let rootPath = gitRepo.rootPath
            let separator = rootPath.hasSuffix("/") ? "" : "/"
            let fullPath = rootPath + separator + relativePath
            return URL(fileURLWithPath: fullPath)
        }

        // If specific paths provided, filter to those (with case-insensitive comparison)
        if configuration.paths.count > 0 && configuration.paths.first != "." {
            let requestedPaths = configuration.paths.map { path -> String in
                if path.hasPrefix("/") {
                    return path
                } else {
                    // Construct absolute path without normalization
                    let rootPath = gitRepo.rootPath
                    let separator = rootPath.hasSuffix("/") ? "" : "/"
                    return rootPath + separator + path
                }
            }

            // FAST PATH: Check if requested path is the repository root
            // If so, skip filtering entirely (common case: yeet ~/path/to/repo)
            let rootPath = gitRepo.rootPath

            let isRequestingRoot = requestedPaths.contains { requested in
                // Simple string prefix check (case-insensitive)
                rootPath.range(
                    of: requested,
                    options: [.anchored, .caseInsensitive]
                ) != nil
            }

            if !isRequestingRoot {
                // Need to filter - only keep files matching requested paths
                // Use string comparison instead of PathNormalizer to avoid syscalls
                allFiles = allFiles.filter { url in
                    let filePath = url.path

                    // Check if file path starts with any requested prefix
                    return requestedPaths.contains { prefix in
                        filePath.range(
                            of: prefix,
                            options: [.anchored, .caseInsensitive]
                        ) != nil
                    }
                }
            }
            // else: requesting root, keep all files (no filtering needed)
        }

        // Remove duplicates and sort
        let uniqueFiles = Array(Set(allFiles)).sorted { $0.path < $1.path }

        // Filter by patterns and exclusions
        let filtered = uniqueFiles.filter { url in
            matcher.shouldInclude(url)
        }

        return filtered
    }
}
