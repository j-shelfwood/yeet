import TiktokenSwift
import Foundation

/// Exact BPE tokenizer using Rust-backed TiktokenSwift (Thread-Safe Singleton)
///
/// Thread-safe tokenizer using TiktokenSwift with Rust FFI for performance.
/// No Python dependency - Rust tokenization via UniFFI bindings.
///
/// ## Usage
/// ```swift
/// let count = try await Tokenizer.shared.count(text: content)
/// ```
///
/// ## Performance
/// Rust-backed BPE via UniFFI. Target: ~3× faster than pure Swift.
/// Lock-based thread-safety enables parallel tokenization across multiple files.
public final class Tokenizer: @unchecked Sendable {
    public static let shared = Tokenizer()

    private var encoder: CoreBpe?
    private var initializationError: Error?
    private var isInitializing = false
    private var initializationWaiters: [CheckedContinuation<CoreBpe, Error>] = []
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.yeet.tokenizer", attributes: .concurrent)

    private init() {}

    /// Count tokens for a string using exact BPE tokenization
    ///
    /// - Parameter text: Text to tokenize
    /// - Returns: Exact token count using cl100k_base encoding (GPT-4)
    /// - Throws: TokenizerError if encoder initialization fails
    /// - Note: Thread-safe, can be called from multiple threads simultaneously
    public func count(text: String) async throws -> Int {
        let encoder = try await getEncoder()
        // Parallel access point - multiple threads can encode simultaneously
        let tokens = encoder.encode(text: text, allowedSpecial: [])
        return Int(tokens.count)
    }

    /// Encode text to token array using exact BPE tokenization
    ///
    /// - Parameter text: Text to tokenize
    /// - Returns: Array of token IDs (UInt32)
    /// - Throws: TokenizerError if encoder initialization fails
    /// - Note: Thread-safe, can be called from multiple threads simultaneously
    public func encode(text: String) async throws -> [UInt32] {
        let encoder = try await getEncoder()
        return encoder.encode(text: text, allowedSpecial: [])
    }

    /// Decode token array back to text
    ///
    /// - Parameter tokens: Array of token IDs
    /// - Returns: Decoded text string
    /// - Throws: TokenizerError if encoder initialization fails or decoding fails
    public func decode(tokens: [UInt32]) async throws -> String {
        let encoder = try await getEncoder()
        guard let decoded = try encoder.decode(tokens: tokens) else {
            throw TokenizerError.initializationFailed("Failed to decode tokens")
        }
        return decoded
    }

    /// Get or initialize the encoder (thread-safe with proper gating)
    private func getEncoder() async throws -> CoreBpe {
        // Fast path: encoder already initialized
        if let encoder = encoder {
            return encoder
        }

        // Return cached error if initialization previously failed
        if let error = initializationError {
            throw error
        }

        // Slow path: synchronize initialization
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                lock.lock()

                // Double-check after acquiring lock
                if let encoder = encoder {
                    lock.unlock()
                    continuation.resume(returning: encoder)
                    return
                }

                if let error = initializationError {
                    lock.unlock()
                    continuation.resume(throwing: error)
                    return
                }

                // Check if initialization already in progress
                if isInitializing {
                    // Join waiters queue
                    initializationWaiters.append(continuation)
                    lock.unlock()
                    return
                }

                // Become the initializer
                isInitializing = true
                lock.unlock()

                // Initialize encoder (outside lock to allow async)
                Task {
                    do {
                        let newEncoder = try await CoreBpe.cl100kBase()

                        self.queue.async {
                            self.lock.lock()
                            self.encoder = newEncoder
                            let waiters = self.initializationWaiters
                            self.initializationWaiters = []
                            self.isInitializing = false
                            self.lock.unlock()

                            // Resume all waiters
                            continuation.resume(returning: newEncoder)
                            for waiter in waiters {
                                waiter.resume(returning: newEncoder)
                            }
                        }
                    } catch {
                        let wrappedError = TokenizerError.initializationFailed("Failed to initialize TiktokenSwift: \(error)")

                        self.queue.async {
                            self.lock.lock()
                            self.initializationError = wrappedError
                            let waiters = self.initializationWaiters
                            self.initializationWaiters = []
                            self.isInitializing = false
                            self.lock.unlock()

                            // Resume all waiters with error
                            continuation.resume(throwing: wrappedError)
                            for waiter in waiters {
                                waiter.resume(throwing: wrappedError)
                            }
                        }
                    }
                }
            }
        }
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
