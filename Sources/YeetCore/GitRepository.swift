import Foundation

/// Represents a Git repository and provides git operations
public struct GitRepository {
    public let rootPath: String

    public init(rootPath: String) {
        self.rootPath = rootPath
    }

    // MARK: - Repository Detection

    /// Find the git repository root for a given path
    public static func find(for path: String) -> GitRepository? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path, "rev-parse", "--show-toplevel"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else {
                return nil
            }

            return GitRepository(rootPath: output)
        } catch {
            return nil
        }
    }

    // MARK: - File Listing

    /// Get tracked and untracked files from git
    public func listTrackedFiles() throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-C", rootPath,
            "ls-files",
            "--cached",           // Tracked files
            "--others",           // Untracked files
            "--exclude-standard"  // Respect .gitignore
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw YeetError.gitCommandFailed("git ls-files failed")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }

    // MARK: - Diff Operations

    /// Represents a file change in git
    public struct FileChange {
        public let status: String  // M (modified), A (added), D (deleted), R (renamed)
        public let path: String

        public init(status: String, path: String) {
            self.status = status
            self.path = path
        }
    }

    /// Get working tree changes (uncommitted)
    public func getDiff() throws -> [FileChange] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-C", rootPath,
            "diff",
            "--name-status",
            "HEAD"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw YeetError.gitCommandFailed("git diff failed")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

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

    // MARK: - History Operations

    /// Represents a git commit
    public struct Commit {
        public let hash: String
        public let shortHash: String
        public let author: String
        public let email: String
        public let date: String
        public let subject: String
        public let body: String
        public let files: [FileChange]
        public let stats: String

        public init(
            hash: String,
            shortHash: String,
            author: String,
            email: String,
            date: String,
            subject: String,
            body: String,
            files: [FileChange],
            stats: String
        ) {
            self.hash = hash
            self.shortHash = shortHash
            self.author = author
            self.email = email
            self.date = date
            self.subject = subject
            self.body = body
            self.files = files
            self.stats = stats
        }
    }

    /// Get commit history
    public func getHistory(count: Int = 5, includeStats: Bool = true) throws -> [Commit] {
        var commits: [Commit] = []

        // Get commit hashes and metadata
        let logProcess = Process()
        logProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        logProcess.arguments = [
            "-C", rootPath,
            "log",
            "-n", "\(count)",
            "--format=%H|%h|%an|%ae|%ai|%s|%b|END_COMMIT"
        ]

        let logPipe = Pipe()
        logProcess.standardOutput = logPipe
        logProcess.standardError = Pipe()

        try logProcess.run()
        logProcess.waitUntilExit()

        guard logProcess.terminationStatus == 0 else {
            throw YeetError.gitCommandFailed("git log failed")
        }

        let logData = logPipe.fileHandleForReading.readDataToEndOfFile()
        let logOutput = String(data: logData, encoding: .utf8) ?? ""

        // Parse commits
        let commitBlocks = logOutput.components(separatedBy: "|END_COMMIT\n")
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

    private func getFilesForCommit(hash: String) throws -> [FileChange] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-C", rootPath,
            "show",
            "--name-status",
            "--format=",
            hash
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

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

    private func getStatsForCommit(hash: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-C", rootPath,
            "show",
            "--shortstat",
            "--format=",
            hash
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
