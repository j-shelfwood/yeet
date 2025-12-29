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

    // MARK: - Enhanced CLI Output

    /// Format enhanced CLI output with visual statistics
    public static func formatEnhancedCLIOutput(
        files: [FileContent],
        totalTokens: Int,
        budget: Int,
        listOnly: Bool
    ) -> String {
        var output = ""

        // Header
        output += "\n"
        if listOnly {
            output += "📋 File List Preview\n"
        } else {
            output += "✓ Context copied to clipboard!\n"
        }
        output += String(repeating: "─", count: 60) + "\n\n"

        // Token budget visualization
        let percentage = Double(totalTokens) / Double(budget) * 100
        let barWidth = 40
        let filledWidth = min(Int(Double(barWidth) * percentage / 100.0), barWidth)
        let bar = String(repeating: "█", count: filledWidth) + String(repeating: "░", count: barWidth - filledWidth)

        let budgetStatus = totalTokens <= budget ? "✓" : "⚠️"
        output += String(format: "Tokens:  %@ %@ %.1f%%\n", bar, budgetStatus, percentage)
        output += String(format: "         %@ / %@ tokens\n\n",
                        formatNumber(totalTokens),
                        formatNumber(budget))

        // File and truncation stats
        let truncatedCount = files.filter { $0.wasTruncated }.count
        output += String(format: "Files:   %d collected", files.count)
        if truncatedCount > 0 {
            let truncatedPercent = Double(truncatedCount) / Double(files.count) * 100
            output += String(format: " (%d truncated, %.1f%%)", truncatedCount, truncatedPercent)
        }
        output += "\n\n"

        // Directory breakdown with spark bars
        if !files.isEmpty {
            output += formatDirectoryBreakdown(files: files, totalTokens: totalTokens)
            output += "\n"
        }

        // Top 5 largest files
        if !files.isEmpty {
            output += formatTopFiles(files: files, count: 5)
            output += "\n"
        }

        // Truncation savings
        if truncatedCount > 0 {
            let originalTokens = files.reduce(0) { $0 + $1.originalTokenCount }
            let fileTokens = files.reduce(0) { $0 + $1.tokenCount }
            let saved = originalTokens - fileTokens
            output += String(format: "💾 Saved %@ tokens through truncation (%.1f%%)\n",
                           formatNumber(saved),
                           Double(saved) / Double(originalTokens) * 100)
        }

        return output
    }

    /// Format directory breakdown with spark bars
    private static func formatDirectoryBreakdown(files: [FileContent], totalTokens: Int) -> String {
        var output = ""
        output += "📁 Token Distribution\n"
        output += String(repeating: "─", count: 60) + "\n"

        // Calculate total file tokens (excluding git history/summary)
        let fileTokenSum = files.reduce(0) { $0 + $1.tokenCount }

        // Special case: single file - show filename
        if files.count == 1 {
            let file = files[0]
            let filename = (file.path as NSString).lastPathComponent
            let sparkBar = createSparkBar(value: file.tokenCount, max: file.tokenCount)
            let displayName = filename.padding(toLength: 35, withPad: " ", startingAt: 0)
            output += String(format: "%@ %@ %2d files • %@ tokens • 100.0%%\n",
                           displayName,
                           sparkBar,
                           1,
                           formatNumber(file.tokenCount))
            return output
        }

        // Find common path prefix
        let commonPrefix = findCommonPathPrefix(paths: files.map { $0.path })

        // Aggregate by top-level directory
        var dirStats: [String: (files: Int, tokens: Int, isDirectory: Bool)] = [:]

        for file in files {
            var relativePath = file.path
            if !commonPrefix.isEmpty && file.path.hasPrefix(commonPrefix) {
                relativePath = String(file.path.dropFirst(commonPrefix.count))
                if relativePath.hasPrefix("/") {
                    relativePath = String(relativePath.dropFirst())
                }
            }

            let components = relativePath.split(separator: "/")

            // For files in root, use filename; otherwise use first directory
            let topDir: String
            if components.isEmpty {
                topDir = (file.path as NSString).lastPathComponent
            } else if components.count == 1 {
                // Single component - it's the filename itself
                topDir = String(components[0])
            } else {
                // Multiple components - use first directory
                topDir = String(components[0])
            }

            if dirStats[topDir] == nil {
                dirStats[topDir] = (files: 0, tokens: 0, isDirectory: components.count > 1)
            }

            dirStats[topDir]!.files += 1
            dirStats[topDir]!.tokens += file.tokenCount
        }

        // Sort by token count and take top 10
        let sorted = dirStats.sorted { $0.value.tokens > $1.value.tokens }.prefix(10)
        let maxTokens = sorted.first?.value.tokens ?? 1

        for (dir, stats) in sorted {
            // Calculate percentage based on file tokens, not total output tokens
            let percentage = fileTokenSum > 0 ? Double(stats.tokens) / Double(fileTokenSum) * 100 : 0

            // Spark bar (scaled relative to max in this list)
            let sparkBar = createSparkBar(value: stats.tokens, max: maxTokens)

            // Format directory name with padding (add / suffix only for actual directories)
            let suffix = stats.isDirectory ? "/" : ""
            let dirName = (dir + suffix).padding(toLength: 35, withPad: " ", startingAt: 0)

            output += String(format: "%@ %@ %2d files • %@ tokens • %.1f%%\n",
                           dirName,
                           sparkBar,
                           stats.files,
                           formatNumber(stats.tokens),
                           percentage)
        }

        if dirStats.count > 10 {
            output += String(format: "   ... %d more directories\n", dirStats.count - 10)
        }

        return output
    }

    /// Format top N files by token count
    private static func formatTopFiles(files: [FileContent], count: Int) -> String {
        var output = ""
        output += "🔝 Largest Files\n"
        output += String(repeating: "─", count: 60) + "\n"

        let sorted = files.sorted { $0.tokenCount > $1.tokenCount }.prefix(count)
        let maxTokens = sorted.first?.tokenCount ?? 1

        for file in sorted {
            let truncatedMark = file.wasTruncated ? " [T]" : ""

            // Spark bar
            let sparkBar = createSparkBar(value: file.tokenCount, max: maxTokens)

            // Extract filename from path
            let filename = (file.path as NSString).lastPathComponent
            let displayName = filename.padding(toLength: 35, withPad: " ", startingAt: 0)

            output += String(format: "%@ %@ %@%@\n",
                           displayName,
                           sparkBar,
                           formatNumber(file.tokenCount),
                           truncatedMark)
        }

        return output
    }

    /// Create spark bar for visualization
    private static func createSparkBar(value: Int, max: Int) -> String {
        let blocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        let barLength = 8

        var bar = ""
        for i in 0..<barLength {
            let threshold = Double(i + 1) / Double(barLength)
            let valueRatio = Double(value) / Double(max)

            if valueRatio >= threshold {
                bar += blocks[7]
            } else if valueRatio >= threshold - (1.0 / Double(barLength)) {
                let subIndex = Int((valueRatio - (threshold - (1.0 / Double(barLength)))) * Double(barLength) * 8)
                bar += blocks[min(subIndex, 7)]
            } else {
                bar += blocks[0]
            }
        }

        return bar
    }

    /// Format number with k/M suffixes for readability
    private static func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1_000 {
            return String(format: "%.1fk", Double(number) / 1_000.0)
        } else {
            return String(number)
        }
    }
}
