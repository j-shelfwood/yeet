import Foundation

/// Text output formatting for file contents and summaries
public struct TextFormatter {

    /// Format file list for --list-only mode
    public static func formatFileList(files: [FileContent]) -> String {
        var output = ""

        output += "Files to be collected (\(files.count) total):\n"
        output += String(repeating: "-", count: 60) + "\n"

        for file in files {
            let relativePath = file.path
            let tokens = file.tokenCount
            let truncatedMark = file.wasTruncated ? " [TRUNCATED]" : ""
            output += String(format: "%6d tokens: %@%@\n", tokens, relativePath, truncatedMark)
        }

        output += String(repeating: "-", count: 60) + "\n"
        output += String(format: "Total: %d files, ~%d tokens\n",
                        files.count,
                        files.reduce(0) { $0 + $1.tokenCount })

        return output
    }

    /// Format file header with path and token count
    public static func formatFileHeader(_ file: FileContent) -> String {
        var header = ""
        header += "Path: \(file.path)\n"
        header += String(repeating: "=", count: 80) + "\n"
        header += "(\(file.tokenCount) tokens"
        if file.wasTruncated {
            header += ", truncated from \(file.originalTokenCount)"
        }
        header += ")\n"
        return header
    }

    /// Format file footer with truncation info if applicable
    public static func formatFileFooter(_ file: FileContent) -> String {
        var footer = ""
        if file.wasTruncated {
            footer += "\n[TRUNCATED - Original: \(file.originalTokenCount) tokens, "
            footer += "showing first \(file.tokenCount) tokens]\n"
        }
        footer += String(repeating: "=", count: 80) + "\n"
        return footer
    }

    /// Format summary statistics
    public static func formatSummary(fileCount: Int, totalTokens: Int) -> String {
        var summary = ""
        summary += "\n"
        summary += String(repeating: "=", count: 80) + "\n"
        summary += "SUMMARY\n"
        summary += String(repeating: "=", count: 80) + "\n"
        summary += "Total files: \(fileCount)\n"
        summary += "Total tokens (approx): \(totalTokens)\n"
        summary += String(repeating: "=", count: 80) + "\n"
        return summary
    }

    /// Format enhanced summary with detailed statistics
    public static func formatEnhancedSummary(
        files: [FileContent],
        totalTokens: Int,
        budget: Int? = nil
    ) -> String {
        var summary = ""
        summary += "\n"
        summary += String(repeating: "╔", count: 1) + String(repeating: "═", count: 78) + String(repeating: "╗", count: 1) + "\n"
        summary += "║" + String(repeating: " ", count: 25) + "COLLECTION SUMMARY" + String(repeating: " ", count: 35) + "║\n"
        summary += String(repeating: "╠", count: 1) + String(repeating: "═", count: 78) + String(repeating: "╣", count: 1) + "\n"

        // File statistics
        let truncatedCount = files.filter { $0.wasTruncated }.count
        let truncatedPercent = files.isEmpty ? 0.0 : Double(truncatedCount) / Double(files.count) * 100

        summary += String(format: "║ Files Collected      %-55d ║\n", files.count)
        if truncatedCount > 0 {
            summary += String(format: "║ Files Truncated      %-44d (%.1f%%) ║\n",
                            truncatedCount,
                            truncatedPercent)
        }

        // Token statistics
        summary += "║" + String(repeating: " ", count: 78) + "║\n"

        if let budget = budget {
            let percentage = Double(totalTokens) / Double(budget) * 100
            let budgetStatus = totalTokens <= budget ? "✓" : "⚠️"
            let padding = String(repeating: " ", count: max(0, 30 - "\(totalTokens)".count - "\(budget)".count))
            summary += String(format: "║ Token Usage          %d / %d (%.1f%%) %@ %@║\n",
                            totalTokens,
                            budget,
                            percentage,
                            budgetStatus,
                            padding)
        } else {
            summary += String(format: "║ Token Usage          %-55d ║\n", totalTokens)
        }

        // Savings from truncation
        if truncatedCount > 0 {
            let originalTokens = files.reduce(0) { $0 + $1.originalTokenCount }
            let saved = originalTokens - totalTokens
            summary += String(format: "║ Original Tokens      %-28d → Saved %d tokens ║\n",
                            originalTokens,
                            saved)
        }

        // File size statistics
        if !files.isEmpty {
            let tokenCounts = files.map { $0.tokenCount }.sorted()
            let largest = tokenCounts.last ?? 0
            let average = totalTokens / files.count
            let median = tokenCounts[tokenCounts.count / 2]

            summary += "║" + String(repeating: " ", count: 78) + "║\n"
            summary += String(format: "║ Largest File         %-55d ║\n", largest)
            summary += String(format: "║ Average File         %-55d ║\n", average)
            summary += String(format: "║ Median File          %-55d ║\n", median)
        }

        summary += String(repeating: "╚", count: 1) + String(repeating: "═", count: 78) + String(repeating: "╝", count: 1) + "\n"

        // Budget warning
        if let budget = budget, totalTokens > budget {
            summary += "\n⚠️  Warning: Total tokens exceed max_total_tokens limit\n"
            summary += "💡 Tip: Reduce max_tokens or add patterns to [token_limits]\n"
        }

        return summary
    }

    /// Format all file contents with headers and footers
    public static func formatFileContents(files: [FileContent]) -> String {
        var output = ""

        for fileContent in files {
            output += formatFileHeader(fileContent)
            output += fileContent.content
            output += "\n"
            output += formatFileFooter(fileContent)
            output += "\n"
        }

        return output
    }

    /// Format token statistics for files
    public static func formatStats(files: [FileContent], showAll: Bool = false) -> String {
        var output = ""
        output += "\nToken Statistics:\n"
        output += String(repeating: "━", count: 80) + "\n"

        // Sort by token count (descending)
        let sorted = files.sorted { $0.tokenCount > $1.tokenCount }
        let filesToShow = showAll ? sorted : Array(sorted.prefix(20))

        for file in filesToShow {
            let truncatedMark = file.wasTruncated ? " [T]" : ""
            let originalInfo = file.wasTruncated ? " (was \(file.originalTokenCount))" : ""
            output += String(format: "%8d tokens  %@%@%@\n",
                           file.tokenCount,
                           file.path,
                           truncatedMark,
                           originalInfo)
        }

        if !showAll && sorted.count > 20 {
            output += String(format: "... %d more files\n", sorted.count - 20)
        }

        output += String(repeating: "━", count: 80) + "\n"
        output += "[T] = Truncated\n"

        return output
    }

    /// Format token statistics grouped by directory
    public static func formatStatsByDirectory(files: [FileContent]) -> String {
        var output = ""
        output += "\nToken Distribution by Directory:\n"
        output += String(repeating: "━", count: 80) + "\n"

        // Find common path prefix to extract relative paths
        let commonPrefix = findCommonPathPrefix(paths: files.map { $0.path })

        // Aggregate by top-level directory
        var dirStats: [String: (files: Int, tokens: Int, truncated: Int)] = [:]

        for file in files {
            // Extract relative path from common prefix
            var relativePath = file.path
            if !commonPrefix.isEmpty && file.path.hasPrefix(commonPrefix) {
                relativePath = String(file.path.dropFirst(commonPrefix.count))
                if relativePath.hasPrefix("/") {
                    relativePath = String(relativePath.dropFirst())
                }
            }

            let components = relativePath.split(separator: "/")
            let topDir = components.isEmpty ? "." : String(components[0])

            if dirStats[topDir] == nil {
                dirStats[topDir] = (files: 0, tokens: 0, truncated: 0)
            }

            dirStats[topDir]!.files += 1
            dirStats[topDir]!.tokens += file.tokenCount
            if file.wasTruncated {
                dirStats[topDir]!.truncated += 1
            }
        }

        // Calculate total for percentages
        let totalTokens = files.reduce(0) { $0 + $1.tokenCount }

        // Sort by token count
        let sorted = dirStats.sorted { $0.value.tokens > $1.value.tokens }

        for (dir, stats) in sorted {
            let percentage = totalTokens > 0 ? Double(stats.tokens) / Double(totalTokens) * 100 : 0
            let truncInfo = stats.truncated > 0 ? " (\(stats.truncated) truncated)" : ""
            let paddedDir = (dir + "/").padding(toLength: 30, withPad: " ", startingAt: 0)

            output += String(format: "%8d tokens (%5.1f%%)  %@  %d files%@\n",
                           stats.tokens,
                           percentage,
                           paddedDir,
                           stats.files,
                           truncInfo)
        }

        output += String(repeating: "━", count: 80) + "\n"
        output += String(format: "Total: %d tokens across %d directories\n",
                        totalTokens,
                        dirStats.count)

        return output
    }

    /// Find common path prefix for a list of paths
    private static func findCommonPathPrefix(paths: [String]) -> String {
        guard !paths.isEmpty else { return "" }
        guard paths.count > 1 else { return "" }

        // Split all paths into components
        let allComponents = paths.map { $0.split(separator: "/").map(String.init) }

        // Find shortest path length
        guard let minLength = allComponents.map({ $0.count }).min() else { return "" }

        // Find common prefix components
        var commonComponents: [String] = []
        for i in 0..<minLength {
            let component = allComponents[0][i]
            if allComponents.allSatisfy({ $0[i] == component }) {
                commonComponents.append(component)
            } else {
                break
            }
        }

        // Reconstruct path from components
        if commonComponents.isEmpty {
            return ""
        }

        let prefix = "/" + commonComponents.joined(separator: "/")
        return prefix
    }
}
