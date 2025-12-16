import Foundation

/// Simple tokenizer using character-based estimation
/// Future: Replace with proper BPE tokenizer (cl100k_base)
public enum Tokenizer {
    /// Estimate token count using 4-character heuristic
    /// This is a rough approximation: ~4 chars = 1 token
    public static func estimateTokens(for text: String) -> Int {
        // Filter out whitespace for more accurate counting
        let significantChars = text.filter { !$0.isWhitespace }
        let baseEstimate = significantChars.count / 4

        // Add tokens for whitespace runs (newlines, spaces)
        let whitespaceTokens = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count / 10

        return max(1, baseEstimate + whitespaceTokens)
    }

    /// Estimate tokens per line (for truncation purposes)
    public static func estimateTokensPerLine(_ line: String) -> Int {
        let chars = line.filter { !$0.isWhitespace }.count
        return max(1, chars / 4)
    }
}

// TODO: Implement proper BPE tokenizer
// Reference: https://github.com/openai/tiktoken
//
// Steps:
// 1. Load cl100k_base.tiktoken (token ranks)
// 2. Implement BPE merge algorithm
// 3. Add caching for common tokens
// 4. Performance: Aim for < 10ms per file
// Test comment
