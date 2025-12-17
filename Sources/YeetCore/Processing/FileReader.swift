import Foundation

/// Reads and processes file contents
public struct FileReader: Sendable {
    private let maxTokens: Int
    private let maxFileSize: Int

    public init(maxTokens: Int, maxFileSize: Int = SafetyLimits.default.maxFileSize) {
        self.maxTokens = maxTokens
        self.maxFileSize = maxFileSize
    }

    /// Read a file and return its content with token information
    public func readFile(at url: URL) throws -> FileContent {
        let fileName = url.lastPathComponent

        // Check file size limit
        if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           fileSize > maxFileSize {
            let sizeMB = fileSize / 1024 / 1024
            let limitMB = maxFileSize / 1024 / 1024
            return FileContent(
                path: url.path,
                content: "[SKIPPED - File too large: \(sizeMB)MB, limit is \(limitMB)MB]",
                tokenCount: 0,
                originalTokenCount: 0,
                wasTruncated: false
            )
        }

        // Get token limit for this specific file
        let tokenLimit = FilePatterns.getTokenLimit(
            for: fileName,
            defaultLimit: maxTokens
        )

        // Skip files with 0 token limit (e.g., *.min.*)
        guard tokenLimit > 0 else {
            return FileContent(
                path: url.path,
                content: "[SKIPPED - Minified file]",
                tokenCount: 0,
                originalTokenCount: 0,
                wasTruncated: false
            )
        }

        // Read file content
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            throw YeetError.fileReadError(url.path)
        }

        // Count tokens
        let tokenCount = Tokenizer.estimateTokens(for: content)

        // Truncate if necessary
        if tokenCount <= tokenLimit {
            return FileContent(
                path: url.path,
                content: content,
                tokenCount: tokenCount,
                originalTokenCount: tokenCount,
                wasTruncated: false
            )
        } else {
            let truncated = TruncationStrategy.truncateHeadTail(
                content,
                limit: tokenLimit
            )
            let truncatedTokenCount = Tokenizer.estimateTokens(for: truncated)

            return FileContent(
                path: url.path,
                content: truncated,
                tokenCount: truncatedTokenCount,
                originalTokenCount: tokenCount,
                wasTruncated: true
            )
        }
    }
}
