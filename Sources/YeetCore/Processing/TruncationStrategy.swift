import Foundation

/// File truncation strategies for token limit enforcement
public struct TruncationStrategy {

    /// Truncate content using head + tail strategy
    ///
    /// Preserves beginning and end of file for better context.
    /// Uses 75% tokens from head, 25% from tail.
    ///
    /// - Parameters:
    ///   - content: Original file content
    ///   - limit: Maximum token count
    /// - Returns: Truncated content with marker
    ///
    /// ## Strategy
    ///
    /// Head+tail truncation provides better context than head-only:
    /// - Preserves imports and declarations (head)
    /// - Preserves closing code and exports (tail)
    /// - Shows file structure more completely
    public static func truncateHeadTail(_ content: String, limit: Int) -> String {
        let lines = content.components(separatedBy: .newlines)

        // 75% tokens from head, 25% from tail
        let headTokenLimit = Int(Double(limit) * 0.75)
        let tailTokenLimit = Int(Double(limit) * 0.25)

        // Find head lines
        var headLines: [String] = []
        var headTokens = 0

        for line in lines {
            let lineTokens = Tokenizer.estimateTokensPerLine(line)
            if headTokens + lineTokens > headTokenLimit {
                break
            }
            headLines.append(line)
            headTokens += lineTokens
        }

        // Find tail lines (work backwards)
        var tailLines: [String] = []
        var tailTokens = 0

        for line in lines.reversed() {
            let lineTokens = Tokenizer.estimateTokensPerLine(line)
            if tailTokens + lineTokens > tailTokenLimit {
                break
            }
            tailLines.insert(line, at: 0)
            tailTokens += lineTokens
        }

        // Ensure no overlap (tail starting before head ends)
        let headEndIndex = headLines.count
        let tailStartIndex = lines.count - tailLines.count

        if headEndIndex >= tailStartIndex {
            // Overlap detected, use head-only truncation
            return headLines.joined(separator: "\n")
        }

        // Calculate omitted lines
        let omittedLines = tailStartIndex - headEndIndex
        let truncationMarker = "\n\n[... TRUNCATED - \(omittedLines) lines omitted ...]\n\n"

        // Combine head + marker + tail
        return headLines.joined(separator: "\n") + truncationMarker + tailLines.joined(separator: "\n")
    }

    /// Truncate content using head-only strategy
    ///
    /// Simpler strategy that only preserves beginning of file.
    ///
    /// - Parameters:
    ///   - content: Original file content
    ///   - limit: Maximum token count
    /// - Returns: Truncated content
    public static func truncateHeadOnly(_ content: String, limit: Int) -> String {
        let lines = content.components(separatedBy: .newlines)
        var result: [String] = []
        var tokenCount = 0

        for line in lines {
            let lineTokens = Tokenizer.estimateTokensPerLine(line)
            if tokenCount + lineTokens > limit {
                break
            }
            result.append(line)
            tokenCount += lineTokens
        }

        return result.joined(separator: "\n")
    }
}
