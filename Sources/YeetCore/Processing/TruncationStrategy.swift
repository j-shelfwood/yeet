import Foundation

/// File truncation strategies for token limit enforcement
public struct TruncationStrategy {

    /// Truncate content using head + tail strategy (TOKEN-BASED - ZERO LINE-BY-LINE FFI)
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
    ///
    /// ## Performance Optimization (CRITICAL)
    ///
    /// **SINGLE FFI CALL APPROACH:**
    /// 1. Tokenize entire file ONCE → `[UInt32]` token array
    /// 2. Slice token array (pure array operations, no FFI)
    /// 3. Decode head and tail slices back to text (2 FFI calls total)
    ///
    /// **Old approach:** 1000 lines = 2000+ FFI calls (line-by-line)
    /// **New approach:** Any file = 3 FFI calls (encode, decode head, decode tail)
    ///
    /// This eliminates "FFI Marshaling Death" - the primary performance bottleneck.
    public static func truncateHeadTail(_ content: String, limit: Int) async throws -> String {
        // SINGLE FFI CALL: Encode entire file to tokens
        let allTokens = try await Tokenizer.shared.encode(text: content)

        // Fast path: Already under limit
        if allTokens.count <= limit {
            return content
        }

        // 75% tokens from head, 25% from tail
        let headTokenLimit = Int(Double(limit) * 0.75)
        let tailTokenLimit = Int(Double(limit) * 0.25)

        // PURE ARRAY SLICING (no FFI)
        let headTokens = Array(allTokens.prefix(headTokenLimit))
        let tailTokens = Array(allTokens.suffix(tailTokenLimit))

        // Decode head and tail (2 FFI calls)
        let headText = try await Tokenizer.shared.decode(tokens: headTokens)
        let tailText = try await Tokenizer.shared.decode(tokens: tailTokens)

        // Calculate omitted tokens for marker
        let omittedTokens = allTokens.count - headTokens.count - tailTokens.count
        let truncationMarker = "\n\n[... TRUNCATED - \(omittedTokens) tokens omitted ...]\n\n"

        // Combine head + marker + tail
        return headText + truncationMarker + tailText
    }

    /// Truncate content using head-only strategy (TOKEN-BASED - ZERO LINE-BY-LINE FFI)
    ///
    /// Simpler strategy that only preserves beginning of file.
    ///
    /// - Parameters:
    ///   - content: Original file content
    ///   - limit: Maximum token count
    /// - Returns: Truncated content
    ///
    /// ## Performance Optimization
    ///
    /// **Old approach:** N lines = N FFI calls
    /// **New approach:** 2 FFI calls (encode once, decode once)
    public static func truncateHeadOnly(_ content: String, limit: Int) async throws -> String {
        // SINGLE FFI CALL: Encode entire file
        let allTokens = try await Tokenizer.shared.encode(text: content)

        // Fast path: Already under limit
        if allTokens.count <= limit {
            return content
        }

        // PURE ARRAY SLICING (no FFI)
        let headTokens = Array(allTokens.prefix(limit))

        // SINGLE FFI CALL: Decode head
        return try await Tokenizer.shared.decode(tokens: headTokens)
    }
}
