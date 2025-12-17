import Foundation

/// Git diff operations for detecting uncommitted changes
public struct GitDiff {
    private let rootPath: String

    /// Creates a diff operation handler
    ///
    /// - Parameter rootPath: Absolute path to repository root
    public init(rootPath: String) {
        self.rootPath = rootPath
    }

    /// Get working tree changes (uncommitted)
    ///
    /// Returns all files with uncommitted changes in the working directory,
    /// including both staged and unstaged modifications.
    ///
    /// - Returns: Array of file changes with status codes
    /// - Throws: YeetError.gitCommandFailed if git command fails
    ///
    /// ## Status Codes
    /// - M: Modified
    /// - A: Added
    /// - D: Deleted
    /// - R: Renamed
    ///
    /// ## Example
    ///
    /// ```swift
    /// let diff = GitDiff(rootPath: "/path/to/repo")
    /// let changes = try diff.getUncommittedChanges()
    /// for change in changes {
    ///     print("\(change.status) \(change.path)")
    /// }
    /// ```
    public func getUncommittedChanges() throws -> [FileChange] {
        let output = try GitCommand.execute(
            ["diff", "--name-status", "HEAD"],
            in: rootPath
        )

        return output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> FileChange? in
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return FileChange(
                    status: String(parts[0]),
                    path: String(parts[1])
                )
            }
    }
}
