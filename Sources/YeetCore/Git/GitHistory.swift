import Foundation

/// Git history operations for collecting commit information
public struct GitHistory {
    private let rootPath: String

    /// Creates a history operation handler
    ///
    /// - Parameter rootPath: Absolute path to repository root
    public init(rootPath: String) {
        self.rootPath = rootPath
    }

    /// Get commit history
    ///
    /// Retrieves recent commit history with full metadata including
    /// author, date, message, file changes, and statistics.
    ///
    /// - Parameters:
    ///   - count: Number of commits to retrieve (default: 5)
    ///   - includeStats: Include commit statistics (additions/deletions)
    /// - Returns: Array of commits with metadata
    /// - Throws: YeetError.gitCommandFailed if git command fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let history = GitHistory(rootPath: "/path/to/repo")
    /// let commits = try history.getCommits(count: 10, includeStats: true)
    /// for commit in commits {
    ///     print("\(commit.shortHash) \(commit.subject)")
    /// }
    /// ```
    public func getCommits(count: Int = 5, includeStats: Bool = true) throws -> [Commit] {
        var commits: [Commit] = []

        // Get commit hashes and metadata
        let output = try GitCommand.execute(
            [
                "log",
                "-n", "\(count)",
                "--format=%H|%h|%an|%ae|%ai|%s|%b|END_COMMIT"
            ],
            in: rootPath
        )

        // Parse commits
        let commitBlocks = output.components(separatedBy: "|END_COMMIT\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for block in commitBlocks {
            let lines = block.components(separatedBy: "\n")
            guard !lines.isEmpty else { continue }

            let metadata = lines[0].components(separatedBy: "|")
            guard metadata.count >= 6 else { continue }

            let hash = metadata[0]
            let shortHash = metadata[1]
            let author = metadata[2]
            let email = metadata[3]
            let date = metadata[4]
            let subject = metadata[5]
            let body = metadata.count > 6 ? metadata[6...].joined(separator: "|") : ""

            // Get file changes for this commit
            let files = try getFilesForCommit(hash: hash)

            // Get stats
            let stats = includeStats ? try getStatsForCommit(hash: hash) : ""

            let commit = Commit(
                hash: hash,
                shortHash: shortHash,
                author: author,
                email: email,
                date: date,
                subject: subject,
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                files: files,
                stats: stats
            )

            commits.append(commit)
        }

        return commits
    }

    /// Get file changes for a specific commit
    private func getFilesForCommit(hash: String) throws -> [FileChange] {
        let output = try GitCommand.execute(
            [
                "show",
                "--name-status",
                "--format=",
                hash
            ],
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

    /// Get statistics for a specific commit
    private func getStatsForCommit(hash: String) throws -> String {
        do {
            return try GitCommand.execute(
                [
                    "show",
                    "--shortstat",
                    "--format=",
                    hash
                ],
                in: rootPath
            )
        } catch {
            // Stats are optional, return empty string on failure
            return ""
        }
    }
}
