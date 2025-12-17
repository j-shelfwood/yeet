import Foundation

/// Represents a file change in git
public struct FileChange {
    public let status: String  // M, A, D, R
    public let path: String

    public init(status: String, path: String) {
        self.status = status
        self.path = path
    }
}

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
