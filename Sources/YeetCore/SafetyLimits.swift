import Foundation

/// Safety limits to prevent crashes and hangs
public struct SafetyLimits: Sendable {
    /// Maximum number of files to collect (default: 100,000)
    public let maxFiles: Int

    /// Maximum size per file in bytes (default: 100MB)
    public let maxFileSize: Int

    /// Maximum total tokens across all files (default: 1,000,000)
    public let maxTotalTokens: Int

    public static let `default` = SafetyLimits(
        maxFiles: 100_000,
        maxFileSize: 100 * 1024 * 1024,  // 100MB
        maxTotalTokens: 1_000_000
    )

    public init(maxFiles: Int, maxFileSize: Int, maxTotalTokens: Int) {
        self.maxFiles = maxFiles
        self.maxFileSize = maxFileSize
        self.maxTotalTokens = maxTotalTokens
    }
}
