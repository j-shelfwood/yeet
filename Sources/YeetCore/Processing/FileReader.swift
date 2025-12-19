import Foundation

/// Reads and processes file contents (ZERO-TOKENIZATION ARCHITECTURE)
///
/// ## Performance Optimization Strategy
///
/// **Old approach:** Tokenize each file individually (3000+ FFI calls)
/// **New approach:** Read all files, tokenize final concatenated output ONCE (1 FFI call)
///
/// This eliminates 99.97% of FFI overhead by deferring tokenization until
/// the final output string is constructed.
public struct FileReader: Sendable {
    private let maxFileSize: Int
    private let tokenLimits: [String: Int]?

    public init(maxTokens: Int, maxFileSize: Int = SafetyLimits.default.maxFileSize, tokenLimits: [String: Int]? = nil) {
        // Note: maxTokens parameter kept for API compatibility but unused
        self.maxFileSize = maxFileSize
        self.tokenLimits = tokenLimits
    }

    /// Read a file and return its content WITHOUT tokenization
    ///
    /// **CRITICAL PERFORMANCE CHANGE:**
    /// - Does NOT count tokens per file
    /// - Does NOT truncate individual files
    /// - Returns tokenCount = 0 (computed later for entire output)
    ///
    /// This approach trades per-file token control for massive FFI reduction.
    public func readFile(at url: URL) async throws -> FileContent {
        let fileName = url.lastPathComponent

        // Check file size limit (only safety check performed)
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

        // Skip minified files based on filename pattern (check both custom and default patterns)
        if FilePatterns.getTokenLimit(for: fileName, defaultLimit: 1, customLimits: tokenLimits) == 0 {
            return FileContent(
                path: url.path,
                content: "[SKIPPED - Pattern-excluded file]",
                tokenCount: 0,
                originalTokenCount: 0,
                wasTruncated: false
            )
        }

        // Read file content with binary detection
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw YeetError.fileReadError(url.path)
        }
        defer { try? handle.close() }

        // Read first 1KB to check for binary content
        guard let preamble = try? handle.read(upToCount: 1024) else {
            throw YeetError.fileReadError(url.path)
        }

        // Binary detection: Check for null bytes (0x00)
        if preamble.contains(0) {
            return FileContent(
                path: url.path,
                content: "[SKIPPED - Binary file detected]",
                tokenCount: 0,
                originalTokenCount: 0,
                wasTruncated: false
            )
        }

        // Read the rest of the file
        let rest = (try? handle.readToEnd()) ?? Data()
        let fullData = preamble + rest

        // Try to decode as UTF-8
        guard let content = String(data: fullData, encoding: .utf8) else {
            return FileContent(
                path: url.path,
                content: "[SKIPPED - Invalid UTF-8 encoding]",
                tokenCount: 0,
                originalTokenCount: 0,
                wasTruncated: false
            )
        }

        // ZERO-TOKENIZATION: Return content without counting tokens
        // Token counting happens once for entire output in ContextCollector
        return FileContent(
            path: url.path,
            content: content,
            tokenCount: 0,  // Will be computed for entire output
            originalTokenCount: 0,
            wasTruncated: false
        )
    }
}
