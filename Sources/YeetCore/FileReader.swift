import Foundation

/// Reads and processes file contents
public struct FileReader {
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
            let truncated = truncateToTokenLimit(content, limit: tokenLimit)
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

    // MARK: - Private Methods

    private func truncateToTokenLimit(_ content: String, limit: Int) -> String {
        // Estimate lines needed based on token limit
        // Assuming ~10 tokens per line on average
        let lines = content.components(separatedBy: .newlines)
        let estimatedLinesNeeded = (limit * 12) / 10 // Add 20% buffer

        if lines.count <= estimatedLinesNeeded {
            return content
        }

        // Take first N lines
        let truncatedLines = Array(lines.prefix(estimatedLinesNeeded))
        var truncated = truncatedLines.joined(separator: "\n")

        // Fine-tune by tokens
        var currentTokens = Tokenizer.estimateTokens(for: truncated)

        if currentTokens > limit {
            // Remove lines until we're under the limit
            var lineCount = truncatedLines.count
            while currentTokens > limit && lineCount > 0 {
                lineCount -= 1
                truncated = truncatedLines.prefix(lineCount).joined(separator: "\n")
                currentTokens = Tokenizer.estimateTokens(for: truncated)
            }
        }

        return truncated
    }
}

/// Represents the content of a file with token information
public struct FileContent {
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
