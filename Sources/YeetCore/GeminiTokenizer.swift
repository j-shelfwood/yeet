import Foundation
import SentencepieceTokenizer

/// Actor to manage concurrent access to the tokenizer
/// Limits parallelism to prevent thread contention
private actor TokenizerQueue {
    private let maxConcurrency: Int
    private var activeTasks = 0
    private var waitingTasks: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrency: Int) {
        self.maxConcurrency = maxConcurrency
    }

    func acquire() async {
        if activeTasks < maxConcurrency {
            activeTasks += 1
            return
        }

        await withCheckedContinuation { continuation in
            waitingTasks.append(continuation)
        }
        activeTasks += 1
    }

    func release() {
        activeTasks -= 1
        if !waitingTasks.isEmpty {
            let continuation = waitingTasks.removeFirst()
            continuation.resume()
        }
    }
}

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

    /// Actor to limit concurrent tokenization tasks
    /// Prevents thread contention on the underlying C++ tokenizer
    private let tokenizerQueue: TokenizerQueue

    private init() {
        // Limit to CPU core count for optimal throughput
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        self.tokenizerQueue = TokenizerQueue(maxConcurrency: coreCount)

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

    /// Count tokens for a string using parallel processing
    ///
    /// Splits large text into chunks and processes them concurrently for significant
    /// speedup on multi-core systems. For small text (<1M chars), uses direct counting.
    ///
    /// - Parameter text: Text to tokenize
    /// - Returns: Token count (exact if model loaded, approximate otherwise)
    public func count(text: String) async throws -> Int {
        // For small/medium text, use direct counting (parallel overhead not worth it)
        guard text.count > 1_000_000 else {
            return countSync(text: text)
        }

        // For very large text, use parallel chunked processing
        return try await countParallel(text: text, chunkSize: 500_000)
    }

    /// Count tokens in parallel by chunking text
    ///
    /// Splits text into ~100KB chunks and processes them concurrently.
    /// Uses an actor to prevent thread contention on the tokenizer.
    ///
    /// - Parameters:
    ///   - text: Text to tokenize
    ///   - chunkSize: Target size per chunk in characters (default: 100,000)
    /// - Returns: Total token count
    private func countParallel(text: String, chunkSize: Int = 100_000) async throws -> Int {
        let chunks = chunkText(text, chunkSize: chunkSize)

        return try await withThrowingTaskGroup(of: Int.self) { group in
            for chunk in chunks {
                group.addTask {
                    // Acquire slot before tokenizing
                    await self.tokenizerQueue.acquire()
                    defer { Task { await self.tokenizerQueue.release() } }

                    return self.countSync(text: chunk)
                }
            }

            // Sum all chunk token counts
            var totalTokens = 0
            for try await count in group {
                totalTokens += count
            }
            return totalTokens
        }
    }

    /// Split text into chunks respecting UTF-8 boundaries
    ///
    /// Ensures chunks are split at safe character boundaries to avoid
    /// corrupting multi-byte UTF-8 sequences.
    ///
    /// - Parameters:
    ///   - text: Text to split
    ///   - chunkSize: Target chunk size in characters
    /// - Returns: Array of text chunks
    private func chunkText(_ text: String, chunkSize: Int) -> [String] {
        guard text.count > chunkSize else {
            return [text]
        }

        var chunks: [String] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            // Calculate end index for this chunk
            let distance = text.distance(from: currentIndex, to: text.endIndex)
            let chunkLength = min(chunkSize, distance)

            guard let endIndex = text.index(currentIndex, offsetBy: chunkLength, limitedBy: text.endIndex) else {
                // Remaining text is smaller than chunk size
                chunks.append(String(text[currentIndex..<text.endIndex]))
                break
            }

            // Extract chunk
            chunks.append(String(text[currentIndex..<endIndex]))
            currentIndex = endIndex
        }

        return chunks
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
