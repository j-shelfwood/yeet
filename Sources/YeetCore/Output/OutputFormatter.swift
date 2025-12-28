import Foundation

/// Formats collected context for output
///
/// Main orchestrator for output formatting, delegating to specialized
/// formatters for text, JSON, tree, and history displays.
public struct OutputFormatter {
    private let configuration: CollectorConfiguration

    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
    }

    /// Format file contents as text output
    ///
    /// Assembles complete text output including optional tree,
    /// file contents, git history, and summary statistics.
    ///
    /// - Parameters:
    ///   - files: Array of file contents to format
    ///   - totalTokens: Total token count across all files
    ///   - gitHistory: Optional git commit history
    /// - Returns: Complete formatted text output
    public func formatText(
        files: [FileContent],
        totalTokens: Int,
        gitHistory: [Commit]? = nil
    ) -> String {
        var output = ""

        // Directory tree (if enabled)
        if configuration.showTree {
            output += TreeGenerator.generate(for: files)
            output += "\n"
        }

        // File contents
        output += TextFormatter.formatFileContents(files: files)

        // Git history
        if let history = gitHistory, !history.isEmpty {
            output += "\n"
            output += HistoryFormatter.format(history)
        }

        // Summary statistics
        output += TextFormatter.formatSummary(fileCount: files.count, totalTokens: totalTokens)

        return output
    }

    /// Format file contents WITHOUT summary (for token counting)
    ///
    /// Assembles text output including optional tree, file contents,
    /// and git history, but excludes the summary section. This allows
    /// counting tokens of the content before generating the summary.
    ///
    /// - Parameters:
    ///   - files: Array of file contents to format
    ///   - gitHistory: Optional git commit history
    /// - Returns: Formatted text output without summary
    public func formatTextWithoutSummary(
        files: [FileContent],
        gitHistory: [Commit]? = nil
    ) -> String {
        var output = ""

        // Directory tree (if enabled)
        if configuration.showTree {
            output += TreeGenerator.generate(for: files)
            output += "\n"
        }

        // File contents
        output += TextFormatter.formatFileContents(files: files)

        // Git history
        if let history = gitHistory, !history.isEmpty {
            output += "\n"
            output += HistoryFormatter.format(history)
        }

        return output
    }

    /// Format file contents as JSON output
    ///
    /// - Parameters:
    ///   - files: Array of file contents to format
    ///   - totalTokens: Total token count across all files
    /// - Returns: JSON-formatted string
    public func formatJSON(files: [FileContent], totalTokens: Int) -> String {
        JSONFormatter.format(files: files, totalTokens: totalTokens)
    }

    /// Format file list for --list-only mode
    ///
    /// - Parameter files: Array of file contents to list
    /// - Returns: Formatted file list with token counts
    public func formatFileList(files: [FileContent]) -> String {
        TextFormatter.formatFileList(files: files)
    }

    /// Generate directory tree structure
    ///
    /// - Parameter files: Array of file contents to visualize
    /// - Returns: Formatted tree structure
    public func generateTree(for files: [FileContent]) -> String {
        TreeGenerator.generate(for: files)
    }
}
