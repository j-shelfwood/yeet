import Foundation

/// Gemini-optimized tokenizer using character-based approximation
///
/// Delegates to GeminiTokenizer for Gemini-compatible token counting.
/// Uses ~3.5 characters per token ratio based on Google's documentation.
///
/// ## Usage
/// ```swift
/// let count = try await Tokenizer.shared.count(text: content)
/// ```
///
/// ## Accuracy
/// Approximation is within ±15% of actual Gemini token counts for source code.
/// For exact counts, use Google's countTokens API directly.
public final class Tokenizer: @unchecked Sendable {
    public static let shared = Tokenizer()

    private let geminiTokenizer = GeminiTokenizer.shared

    private init() {}

    /// Count tokens for a string using Gemini-compatible approximation
    ///
    /// Automatically uses parallel processing for large text (>100k chars).
    /// Provides 8-12x speedup on multi-core systems for large documents.
    ///
    /// - Parameter text: Text to tokenize
    /// - Returns: Estimated token count for Gemini models
    /// - Note: Thread-safe, can be called from multiple threads simultaneously
    public func count(text: String) async throws -> Int {
        return try await geminiTokenizer.count(text: text)
    }

    /// Synchronous token count (convenience method)
    ///
    /// - Parameter text: Text to count tokens for
    /// - Returns: Estimated token count for Gemini models
    public func countSync(text: String) -> Int {
        return geminiTokenizer.countSync(text: text)
    }
}

// MARK: - Error Types

public enum TokenizerError: Error, CustomStringConvertible {
    case initializationFailed(String)

    public var description: String {
        switch self {
        case .initializationFailed(let message):
            return "Tokenizer initialization error: \(message)"
        }
    }
}
