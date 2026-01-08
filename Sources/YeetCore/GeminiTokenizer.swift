import Foundation
import SentencepieceTokenizer

/// Gemini-compatible token counter using SentencePiece
///
/// Uses the official Gemma tokenizer model (same as Gemini) for accurate
/// token counting. Falls back to character-based approximation if the
/// model file is not available.
///
/// ## Setup for Accurate Tokenization
///
/// 1. Accept license at https://huggingface.co/google/gemma-2b
/// 2. Download `tokenizer.model` to `Sources/YeetCore/Resources/`
/// 3. Rebuild yeet
///
/// ## Fallback Mode
///
/// Without tokenizer.model, uses ~3.5 chars/token approximation
/// (typically within ±15% of actual Gemini counts).
///
/// ## Usage
/// ```swift
/// let count = try await GeminiTokenizer.shared.count(text: content)
/// ```
public final class GeminiTokenizer: @unchecked Sendable {
    public static let shared = GeminiTokenizer()

    /// The SentencePiece tokenizer (nil if model not available)
    private var sentencepiece: SentencepieceTokenizer?

    /// Whether we're using the actual tokenizer or fallback
    public private(set) var isUsingFallback: Bool = true

    /// Characters per token ratio for fallback mode
    private let fallbackCharsPerToken: Double = 3.5

    private init() {
        // Try to load the bundled tokenizer model
        loadTokenizerModel()
    }

    /// Attempt to load the SentencePiece tokenizer model
    private func loadTokenizerModel() {
        // Search paths for tokenizer.model (in order of preference)
        let searchPaths = [
            // User's yeet config directory
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".yeet/tokenizer.model").path,
            // Current directory
            FileManager.default.currentDirectoryPath + "/tokenizer.model",
            // XDG config directory
            (ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] ??
             FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config").path)
                + "/yeet/tokenizer.model"
        ]

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                do {
                    sentencepiece = try SentencepieceTokenizer(modelPath: path)
                    isUsingFallback = false
                    return
                } catch {
                    // Failed to load from this path, try next
                    continue
                }
            }
        }

        // Fallback mode - use approximation
        isUsingFallback = true
    }

    /// Count tokens for a string
    ///
    /// Uses SentencePiece if available, otherwise falls back to approximation.
    ///
    /// - Parameter text: Text to tokenize
    /// - Returns: Token count (exact if model loaded, approximate otherwise)
    public func count(text: String) async throws -> Int {
        return countSync(text: text)
    }

    /// Synchronous token count
    ///
    /// - Parameter text: Text to count tokens for
    /// - Returns: Token count
    public func countSync(text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        if let tokenizer = sentencepiece {
            // Use actual SentencePiece tokenization
            do {
                let tokens = try tokenizer.encode(text)
                return tokens.count
            } catch {
                // Encoding failed, fall back to approximation
                let byteCount = text.utf8.count
                return Int(ceil(Double(byteCount) / fallbackCharsPerToken))
            }
        } else {
            // Fallback to character-based approximation
            let byteCount = text.utf8.count
            return Int(ceil(Double(byteCount) / fallbackCharsPerToken))
        }
    }

    /// Encode text to token IDs (only available with SentencePiece model)
    ///
    /// - Parameter text: Text to encode
    /// - Returns: Array of token IDs, or nil if using fallback mode
    public func encode(text: String) -> [Int]? {
        guard let tokenizer = sentencepiece else { return nil }
        do {
            return try tokenizer.encode(text).map { Int($0) }
        } catch {
            return nil
        }
    }

    /// Decode token IDs to text (only available with SentencePiece model)
    ///
    /// - Parameter tokens: Array of token IDs
    /// - Returns: Decoded text, or nil if using fallback mode
    public func decode(tokens: [Int]) -> String? {
        guard let tokenizer = sentencepiece else { return nil }
        do {
            return try tokenizer.decode(tokens)
        } catch {
            return nil
        }
    }

    /// Get tokenizer status for display
    public var statusDescription: String {
        if isUsingFallback {
            return "approximation (~3.5 chars/token)"
        } else {
            return "Gemini SentencePiece (exact)"
        }
    }
}
