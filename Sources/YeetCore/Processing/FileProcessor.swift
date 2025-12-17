import Foundation

/// Concurrent file processor using Swift actors
///
/// Processes multiple files in parallel while maintaining thread safety
/// and respecting token limits.
public actor FileProcessor {
    private let reader: FileReader
    private let safetyLimits: SafetyLimits

    public init(maxTokens: Int, safetyLimits: SafetyLimits) {
        self.reader = FileReader(maxTokens: maxTokens, maxFileSize: safetyLimits.maxFileSize)
        self.safetyLimits = safetyLimits
    }

    /// Process files concurrently with parallel execution
    ///
    /// Uses TaskGroup for efficient concurrent processing while maintaining
    /// safety limits and error handling.
    ///
    /// - Parameter fileURLs: Array of file URLs to process
    /// - Returns: Array of processed file contents
    /// - Throws: YeetError if safety limits exceeded
    public func processFiles(_ fileURLs: [URL]) async throws -> [FileContent] {
        var fileContents: [FileContent] = []
        var totalTokens = 0

        // Process files concurrently in batches
        try await withThrowingTaskGroup(of: (Int, FileContent?).self) { group in
            for (index, url) in fileURLs.enumerated() {
                group.addTask {
                    do {
                        let content = try self.reader.readFile(at: url)
                        return (index, content)
                    } catch {
                        // Log error but continue processing other files
                        return (index, nil)
                    }
                }
            }

            // Collect results in order
            var results: [(Int, FileContent)] = []
            for try await (index, content) in group {
                if let content = content {
                    results.append((index, content))
                }
            }

            // Sort by index to maintain order
            results.sort { $0.0 < $1.0 }

            // Build final array and check limits
            for (_, content) in results {
                fileContents.append(content)
                totalTokens += content.tokenCount

                // Check total token limit
                if totalTokens > safetyLimits.maxTotalTokens {
                    throw YeetError.tooManyTokens(
                        total: totalTokens,
                        limit: safetyLimits.maxTotalTokens
                    )
                }
            }
        }

        return fileContents
    }
}
