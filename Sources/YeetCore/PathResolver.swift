import Foundation

/// Resolves and expands file paths
public struct PathResolver {
    private let fileManager = FileManager.default

    public init() {}

    /// Resolve a path string to an absolute URL
    public func resolve(_ pathString: String, relativeTo base: String? = nil) throws -> URL {
        var path = pathString

        // Expand tilde
        if path.hasPrefix("~") {
            path = NSString(string: path).expandingTildeInPath
        }

        let url: URL
        if path.hasPrefix("/") {
            // Already absolute
            url = URL(fileURLWithPath: path)
        } else {
            // Relative path
            let baseURL: URL
            if let base = base {
                baseURL = URL(fileURLWithPath: base)
            } else {
                baseURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            }
            url = baseURL.appendingPathComponent(path)
        }

        // Resolve symlinks and standardize
        return url.standardizedFileURL
    }

    /// Expand glob patterns in a path
    public func expandGlob(_ pattern: String, relativeTo base: String? = nil) throws -> [URL] {
        // If no wildcards, just resolve the path
        if !pattern.contains("*") && !pattern.contains("?") {
            let resolved = try resolve(pattern, relativeTo: base)
            return [resolved]
        }

        // Check if pattern is absolute
        let isAbsolute = pattern.hasPrefix("/")

        // Split pattern into directory and filename parts
        let components = pattern.split(separator: "/").map(String.init)
        var searchBase = ""
        var patternStart = 0

        // Find the first component with wildcards
        for (index, component) in components.enumerated() {
            if component.contains("*") || component.contains("?") {
                patternStart = index
                break
            }
            if searchBase.isEmpty {
                searchBase = component
            } else {
                searchBase += "/" + component
            }
        }

        // Add leading slash back for absolute paths
        if isAbsolute && !searchBase.isEmpty {
            searchBase = "/" + searchBase
        }

        // Resolve the base directory
        let baseURL = try resolve(searchBase.isEmpty ? "." : searchBase, relativeTo: base)

        guard fileManager.fileExists(atPath: baseURL.path) else {
            return []
        }

        // For simple patterns like "*.swift" in current dir
        if patternStart == components.count - 1 {
            return try simpleGlob(in: baseURL, pattern: components[patternStart])
        }

        // For complex patterns, recursively search
        return try recursiveGlob(
            in: baseURL,
            patternComponents: Array(components[patternStart...])
        )
    }

    // MARK: - Private Methods

    private func simpleGlob(in directory: URL, pattern: String) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        var matches: [URL] = []

        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent
            if FilePatterns.matches(fileName: fileName, pattern: pattern) {
                matches.append(fileURL)
            }
        }

        return matches.sorted { $0.path < $1.path }
    }

    private func recursiveGlob(
        in directory: URL,
        patternComponents: [String]
    ) throws -> [URL] {
        guard !patternComponents.isEmpty else {
            return [directory]
        }

        let currentPattern = patternComponents[0]
        let remainingPatterns = Array(patternComponents.dropFirst())

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var matches: [URL] = []

        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent

            if FilePatterns.matches(fileName: fileName, pattern: currentPattern) {
                if remainingPatterns.isEmpty {
                    // Leaf pattern - this is a match
                    matches.append(fileURL)
                } else {
                    // Intermediate pattern - recurse
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    if resourceValues?.isDirectory == true {
                        let subMatches = try recursiveGlob(
                            in: fileURL,
                            patternComponents: remainingPatterns
                        )
                        matches.append(contentsOf: subMatches)
                    }
                }
            }
        }

        return matches.sorted { $0.path < $1.path }
    }
}
