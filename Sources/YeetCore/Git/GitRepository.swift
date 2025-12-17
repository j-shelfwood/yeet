import Foundation

/// Represents a Git repository and provides git operations.
///
/// `GitRepository` provides methods for interacting with git repositories,
/// including file discovery, diff operations, and commit history retrieval.
///
/// ## Usage
///
/// ```swift
/// // Find repository for a path
/// guard let repo = GitRepository.find(for: "Sources/MyFile.swift") else {
///     print("Not in a git repository")
///     return
/// }
///
/// // List tracked files
/// let files = try repo.listTrackedFiles()
///
/// // Get uncommitted changes
/// let changes = try repo.getDiff()
///
/// // Collect commit history
/// let commits = try repo.getHistory(count: 10, includeStats: true)
/// ```
///
/// ## Git Operations
///
/// All git operations are performed by spawning the `git` command-line tool
/// using `Process`. This approach provides:
/// - Zero dependencies (uses system git)
/// - Full feature support
/// - Proper error handling
///
/// - Note: Requires git to be installed and accessible at `/usr/bin/git`
/// - SeeAlso: ``Commit``
/// - SeeAlso: ``FileChange``
public struct GitRepository {
    /// The absolute path to the repository root directory
    public let rootPath: String

    /// Creates a git repository instance.
    ///
    /// - Parameter rootPath: Absolute path to repository root
    public init(rootPath: String) {
        self.rootPath = rootPath
    }

    // MARK: - Repository Detection

    /// Finds the git repository root for a given path.
    ///
    /// Works with both file and directory paths. If given a file path,
    /// automatically extracts the directory before querying git.
    ///
    /// - Parameter path: File or directory path to search from
    /// - Returns: GitRepository instance if found, nil otherwise
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Works with directories
    /// let repo1 = GitRepository.find(for: "Sources")
    ///
    /// // Works with files
    /// let repo2 = GitRepository.find(for: "Sources/main.swift")
    ///
    /// // Returns nil if not in a git repo
    /// let repo3 = GitRepository.find(for: "/tmp")  // nil
    /// ```
    public static func find(for path: String) -> GitRepository? {
        let directory = GitCommand.resolveDirectory(from: path)

        do {
            let output = try GitCommand.execute(
                ["rev-parse", "--show-toplevel"],
                in: directory
            )
            return GitRepository(rootPath: output)
        } catch {
            return nil
        }
    }

    // MARK: - File Listing

    /// Get tracked and untracked files from git
    ///
    /// Returns all files known to git, including both tracked files
    /// and untracked files that respect .gitignore rules.
    ///
    /// - Returns: Array of file paths relative to repository root
    /// - Throws: YeetError.gitCommandFailed if git command fails
    public func listTrackedFiles() throws -> [String] {
        try GitCommand.executeLines(
            [
                "ls-files",
                "--cached",           // Tracked files
                "--others",           // Untracked files
                "--exclude-standard"  // Respect .gitignore
            ],
            in: rootPath
        )
    }

    // MARK: - Diff Operations (delegated to GitDiff)

    /// Get working tree changes (uncommitted)
    ///
    /// - Returns: Array of file changes with status codes
    /// - Throws: YeetError.gitCommandFailed if git command fails
    public func getDiff() throws -> [FileChange] {
        let diff = GitDiff(rootPath: rootPath)
        return try diff.getUncommittedChanges()
    }

    // MARK: - History Operations (delegated to GitHistory)

    /// Get commit history
    ///
    /// - Parameters:
    ///   - count: Number of commits to retrieve (default: 5)
    ///   - includeStats: Include commit statistics (default: true)
    /// - Returns: Array of commits with metadata
    /// - Throws: YeetError.gitCommandFailed if git command fails
    public func getHistory(count: Int = 5, includeStats: Bool = true) throws -> [Commit] {
        let history = GitHistory(rootPath: rootPath)
        return try history.getCommits(count: count, includeStats: includeStats)
    }
}
