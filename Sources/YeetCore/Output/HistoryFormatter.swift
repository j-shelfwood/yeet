import Foundation

/// Git commit history formatting
public struct HistoryFormatter {

    /// Format git commit history for display
    ///
    /// Creates a detailed view of recent commits including author,
    /// date, message, file changes, and statistics.
    ///
    /// - Parameter history: Array of commits to format
    /// - Returns: Formatted history string
    ///
    /// ## Example Output
    ///
    /// ```
    /// ===============================================================================
    /// GIT HISTORY (Last 5 commits)
    /// ===============================================================================
    ///
    /// Commit: abc123f
    /// Author: John Doe <john@example.com>
    /// Date: 2025-12-16 10:30:00
    ///
    ///     Add new feature
    ///
    /// Files Changed:
    ///   M  src/feature.swift
    ///   A  tests/feature_test.swift
    ///
    /// 2 files changed, 45 insertions(+), 3 deletions(-)
    /// ```
    public static func format(_ history: [Commit]) -> String {
        var output = ""
        output += String(repeating: "=", count: 80) + "\n"
        output += "GIT HISTORY (Last \(history.count) commits)\n"
        output += String(repeating: "=", count: 80) + "\n\n"

        for commit in history {
            output += "Commit: \(commit.shortHash)\n"
            output += "Author: \(commit.author) <\(commit.email)>\n"
            output += "Date: \(commit.date)\n"
            output += "\n    \(commit.subject)\n"

            // Format commit body if present
            if !commit.body.isEmpty {
                let bodyLines = commit.body.components(separatedBy: .newlines)
                for line in bodyLines where !line.isEmpty {
                    output += "    \(line)\n"
                }
            }

            // Format file changes
            if !commit.files.isEmpty {
                output += "\nFiles Changed:\n"
                for file in commit.files {
                    output += "  \(file.status)  \(file.path)\n"
                }
            }

            // Format statistics
            if !commit.stats.isEmpty {
                output += "\n\(commit.stats)\n"
            }

            output += "\n" + String(repeating: "-", count: 80) + "\n\n"
        }

        return output
    }
}
