import Foundation

/// Pattern matching for file inclusion and exclusion
public struct PatternMatcher {
    private let configuration: CollectorConfiguration

    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
    }

    /// Check if a file should be included based on patterns and exclusions
    ///
    /// - Parameter url: File URL to check
    /// - Returns: True if file should be included
    public func shouldInclude(_ url: URL) -> Bool {
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

    /// Check if a URL is in an excluded directory
    ///
    /// - Parameter url: File URL to check
    /// - Returns: True if URL is within an excluded directory
    public func isInExcludedDirectory(_ url: URL) -> Bool {
        let pathComponents = url.pathComponents
        for component in pathComponents {
            if configuration.excludeDirectories.contains(component) {
                return true
            }
        }
        return false
    }
}
