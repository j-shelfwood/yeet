import Foundation

/// Directory traversal and file collection
public struct DirectoryWalker {
    private let fileManager = FileManager.default
    private let configuration: CollectorConfiguration
    private let matcher: PatternMatcher

    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
        self.matcher = PatternMatcher(configuration: configuration)
    }

    /// Collect files from a URL (file or directory)
    ///
    /// - Parameter url: Starting URL to collect from
    /// - Returns: Array of file URLs
    /// - Throws: YeetError if operations fail
    public func collectFiles(from url: URL) throws -> [URL] {
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

    /// Walk directory recursively
    ///
    /// Traverses directory tree while respecting exclusion rules
    /// and hidden file settings.
    ///
    /// - Parameter directory: Directory URL to walk
    /// - Returns: Array of file URLs found
    /// - Throws: YeetError if operations fail
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
            if matcher.isInExcludedDirectory(fileURL) {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                   resourceValues.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            // Check for exclude patterns
            if matcher.matchesExcludePattern(fileURL) {
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
}
