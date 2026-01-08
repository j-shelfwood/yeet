import Foundation

/// File truncation strategies for token limit enforcement
///
/// Uses character-based truncation with Gemini token approximation.
/// Attempts to break at line boundaries for cleaner output.
public struct TruncationStrategy {

    /// Characters per token ratio (matches GeminiTokenizer)
    private static let charsPerToken: Double = 3.5

    /// Reserved tokens for truncation marker overhead
    /// Marker format: "\n\n[... TRUNCATED - ~X tokens omitted ...]\n\n" (~55 chars = ~16 tokens)
    private static let markerOverheadTokens: Int = 20

    /// Result of truncation operation
    public struct TruncationResult {
        public let content: String
        public let tokenCount: Int
        public let originalTokenCount: Int
        public let wasTruncated: Bool
    }

    /// Truncate content using head + tail strategy
    ///
    /// Preserves beginning and end of file for better context.
    /// Uses 75% from head, 25% from tail.
    ///
    /// - Parameters:
    ///   - content: Original file content
    ///   - limit: Maximum token count
    /// - Returns: Truncation result with content and token counts
    ///
    /// ## Strategy
    ///
    /// Head+tail truncation provides better context than head-only:
    /// - Preserves imports and declarations (head)
    /// - Preserves closing code and exports (tail)
    /// - Shows file structure more completely
    public static func truncateHeadTail(_ content: String, limit: Int) async throws -> TruncationResult {
        let originalTokenCount = estimateTokens(content)

        // Fast path: Already under limit
        if originalTokenCount <= limit {
            return TruncationResult(
                content: content,
                tokenCount: originalTokenCount,
                originalTokenCount: originalTokenCount,
                wasTruncated: false
            )
        }

        // Reserve space for truncation marker overhead
        let effectiveLimit = max(1, limit - markerOverheadTokens)

        // Convert token limit to character limit
        let charLimit = Int(Double(effectiveLimit) * charsPerToken)

        // 75% from head, 25% from tail
        let headCharLimit = Int(Double(charLimit) * 0.75)
        let tailCharLimit = Int(Double(charLimit) * 0.25)

        // Extract head (try to break at line boundary)
        let headText = extractHead(from: content, charLimit: headCharLimit)

        // Extract tail (try to break at line boundary)
        let tailText = extractTail(from: content, charLimit: tailCharLimit)

        // Calculate omitted content
        let headEndIndex = content.index(content.startIndex, offsetBy: min(headText.count, content.count))
        let tailStartIndex = content.index(content.endIndex, offsetBy: -min(tailText.count, content.count))

        let omittedCount = content.distance(from: headEndIndex, to: tailStartIndex)
        let omittedTokens = max(0, Int(ceil(Double(omittedCount) / charsPerToken)))

        let truncationMarker = "\n\n[... TRUNCATED - ~\(omittedTokens) tokens omitted ...]\n\n"

        // Combine head + marker + tail
        let truncatedContent = headText + truncationMarker + tailText
        let finalTokenCount = estimateTokens(truncatedContent)

        return TruncationResult(
            content: truncatedContent,
            tokenCount: finalTokenCount,
            originalTokenCount: originalTokenCount,
            wasTruncated: true
        )
    }

    /// Truncate content using head-only strategy
    ///
    /// Simpler strategy that only preserves beginning of file.
    ///
    /// - Parameters:
    ///   - content: Original file content
    ///   - limit: Maximum token count
    /// - Returns: Truncation result with content and token counts
    public static func truncateHeadOnly(_ content: String, limit: Int) async throws -> TruncationResult {
        let originalTokenCount = estimateTokens(content)

        // Fast path: Already under limit
        if originalTokenCount <= limit {
            return TruncationResult(
                content: content,
                tokenCount: originalTokenCount,
                originalTokenCount: originalTokenCount,
                wasTruncated: false
            )
        }

        // Reserve space for truncation marker overhead
        let effectiveLimit = max(1, limit - markerOverheadTokens)

        // Convert token limit to character limit
        let charLimit = Int(Double(effectiveLimit) * charsPerToken)

        // Extract head (try to break at line boundary)
        let headText = extractHead(from: content, charLimit: charLimit)
        let finalTokenCount = estimateTokens(headText)

        let omittedTokens = originalTokenCount - finalTokenCount
        let truncatedContent = headText + "\n\n[... TRUNCATED - ~\(omittedTokens) tokens omitted ...]"

        return TruncationResult(
            content: truncatedContent,
            tokenCount: finalTokenCount,
            originalTokenCount: originalTokenCount,
            wasTruncated: true
        )
    }

    // MARK: - Private Helpers

    /// Estimate token count for content
    private static func estimateTokens(_ content: String) -> Int {
        guard !content.isEmpty else { return 0 }
        return Int(ceil(Double(content.utf8.count) / charsPerToken))
    }

    /// Extract head portion, breaking at line boundary if possible
    private static func extractHead(from content: String, charLimit: Int) -> String {
        guard charLimit > 0, !content.isEmpty else { return "" }

        let safeLimit = min(charLimit, content.count)
        let endIndex = content.index(content.startIndex, offsetBy: safeLimit)
        var headText = String(content[..<endIndex])

        // Try to break at last newline for cleaner output
        if let lastNewline = headText.lastIndex(of: "\n"),
           headText.distance(from: headText.startIndex, to: lastNewline) > charLimit / 2 {
            headText = String(headText[...lastNewline])
        }

        return headText
    }

    /// Extract tail portion, breaking at line boundary if possible
    private static func extractTail(from content: String, charLimit: Int) -> String {
        guard charLimit > 0, !content.isEmpty else { return "" }

        let safeLimit = min(charLimit, content.count)
        let startIndex = content.index(content.endIndex, offsetBy: -safeLimit)
        var tailText = String(content[startIndex...])

        // Try to break at first newline for cleaner output
        if let firstNewline = tailText.firstIndex(of: "\n"),
           tailText.distance(from: firstNewline, to: tailText.endIndex) > charLimit / 2 {
            tailText = String(tailText[tailText.index(after: firstNewline)...])
        }

        return tailText
    }
}
