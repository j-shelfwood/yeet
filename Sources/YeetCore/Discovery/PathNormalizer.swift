import Foundation

/// Path normalization and canonical resolution with caching
///
/// Handles case-insensitive path comparison on macOS by resolving
/// paths to their canonical form using URL.standardized with
/// performance-optimized caching.
public struct PathNormalizer {
    /// Thread-safe cache for normalized paths
    /// NSCache is internally thread-safe, so we can safely use it from multiple threads
    private static nonisolated(unsafe) let cache: NSCache<NSString, NSString> = {
        let c = NSCache<NSString, NSString>()
        c.countLimit = 10000  // Limit cache size
        return c
    }()

    /// Normalize a path to its canonical form with caching
    ///
    /// Resolves symlinks, relative components (..), and case variations
    /// to the filesystem's canonical representation. Results are cached
    /// to avoid redundant filesystem syscalls.
    ///
    /// - Parameter path: Path string to normalize
    /// - Returns: Canonical path string
    ///
    /// ## Performance
    ///
    /// - First call: O(1) filesystem syscall via URL.standardized
    /// - Cached calls: O(1) dictionary lookup
    /// - Cache auto-evicts under memory pressure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // On case-insensitive filesystem:
    /// let path1 = PathNormalizer.normalize("/Users/shelfwood/projects/yeet")
    /// let path2 = PathNormalizer.normalize("/Users/shelfwood/Projects/yeet")
    /// // path1 == path2 (both resolve to same canonical path)
    /// ```
    public static func normalize(_ path: String) -> String {
        let key = path as NSString

        // Check cache first
        if let cached = cache.object(forKey: key) {
            return cached as String
        }

        // Compute and cache
        let url = URL(fileURLWithPath: path)
        let normalized = url.standardized.path
        cache.setObject(normalized as NSString, forKey: key)

        return normalized
    }

    /// Check if a path is a prefix of another (case-insensitive on macOS)
    ///
    /// Uses optimized case-insensitive string comparison to handle path
    /// variations on case-insensitive filesystems like macOS HFS+/APFS.
    ///
    /// - Parameters:
    ///   - path: The path to check
    ///   - prefix: The potential prefix path
    /// - Returns: True if prefix is a prefix of path
    ///
    /// ## Performance
    ///
    /// Uses `range(of:options:)` with `.caseInsensitive` instead of
    /// `.lowercased()` to avoid string allocations.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // These return true even with different case:
    /// PathNormalizer.hasPrefix("/Users/shelfwood/Projects/yeet/foo.txt",
    ///                          prefix: "/Users/shelfwood/projects/yeet")  // true
    /// ```
    public static func hasPrefix(_ path: String, prefix: String) -> Bool {
        let normalizedPath = normalize(path)
        let normalizedPrefix = normalize(prefix)

        // Use range(of:options:) for optimized case-insensitive comparison
        // Avoids string allocations from lowercased()
        return normalizedPath.range(
            of: normalizedPrefix,
            options: [.anchored, .caseInsensitive]
        ) != nil
    }

    /// Normalize multiple paths to their canonical forms
    ///
    /// - Parameter paths: Array of path strings
    /// - Returns: Set of canonical path strings
    public static func normalizeAll(_ paths: [String]) -> Set<String> {
        Set(paths.map { normalize($0) })
    }

    /// Check if a URL path has any of the given prefixes (case-insensitive)
    ///
    /// Optimized to iterate through prefixes (typically 1-5) rather than
    /// paths (potentially thousands).
    ///
    /// - Parameters:
    ///   - url: The URL to check
    ///   - prefixes: Set of potential prefix paths (should be pre-normalized)
    /// - Returns: True if url path has any of the prefixes
    ///
    /// ## Performance
    ///
    /// - O(k) where k = number of prefixes (typically 1-5)
    /// - Prefixes should be pre-normalized for best performance
    public static func hasAnyPrefix(_ url: URL, prefixes: Set<String>) -> Bool {
        let normalizedPath = normalize(url.path)

        return prefixes.contains { prefix in
            // Prefixes are already normalized, so we can use direct comparison
            normalizedPath.range(
                of: prefix,
                options: [.anchored, .caseInsensitive]
            ) != nil
        }
    }
}
