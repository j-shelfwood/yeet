import Foundation

/// Represents the content of a file with token information
public struct FileContent: Hashable, Sendable {
    public let path: String
    public let content: String
    public let tokenCount: Int
    public let originalTokenCount: Int
    public let wasTruncated: Bool

    public init(
        path: String,
        content: String,
        tokenCount: Int,
        originalTokenCount: Int,
        wasTruncated: Bool
    ) {
        self.path = path
        self.content = content
        self.tokenCount = tokenCount
        self.originalTokenCount = originalTokenCount
        self.wasTruncated = wasTruncated
    }
}
