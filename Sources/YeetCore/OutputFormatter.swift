import Foundation

/// Formats collected context for output
public struct OutputFormatter {
    private let configuration: CollectorConfiguration

    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
    }

    /// Format file contents as text output
    public func formatText(
        files: [FileContent],
        totalTokens: Int,
        gitHistory: [GitRepository.Commit]? = nil
    ) -> String {
        var output = ""

        // File contents
        for fileContent in files {
            output += formatFileHeader(fileContent)
            output += fileContent.content
            output += "\n"
            output += formatFileFooter(fileContent)
            output += "\n"
        }

        // Git history
        if let history = gitHistory, !history.isEmpty {
            output += "\n"
            output += formatGitHistory(history)
        }

        // Summary statistics
        output += formatSummary(fileCount: files.count, totalTokens: totalTokens)

        return output
    }

    /// Format file contents as JSON output
    public func formatJSON(files: [FileContent], totalTokens: Int) -> String {
        let jsonData: [String: Any] = [
            "fileCount": files.count,
            "totalTokens": totalTokens,
            "files": files.map { file in
                [
                    "path": file.path,
                    "tokenCount": file.tokenCount,
                    "originalTokenCount": file.originalTokenCount,
                    "wasTruncated": file.wasTruncated,
                    "content": file.content
                ]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to serialize JSON\"}"
        }

        return jsonString
    }

    /// Format file list for --list-only mode
    public func formatFileList(files: [FileContent]) -> String {
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

    // MARK: - Private Formatting Methods

    private func formatFileHeader(_ file: FileContent) -> String {
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

    private func formatFileFooter(_ file: FileContent) -> String {
        var footer = ""
        if file.wasTruncated {
            footer += "\n[TRUNCATED - Original: \(file.originalTokenCount) tokens, "
            footer += "showing first \(file.tokenCount) tokens]\n"
        }
        footer += String(repeating: "=", count: 80) + "\n"
        return footer
    }

    private func formatSummary(fileCount: Int, totalTokens: Int) -> String {
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

    /// Generate directory tree structure
    public func generateTree(for files: [FileContent]) -> String {
        guard !files.isEmpty else {
            return "No files collected.\n"
        }

        // Group files by directory
        var tree = ""
        tree += "\nDirectory Structure:\n"
        tree += String(repeating: "-", count: 60) + "\n"

        let paths = files.map { $0.path }.sorted()
        var lastComponents: [String] = []

        for path in paths {
            let components = path.split(separator: "/").map(String.init)

            // Find common prefix
            var commonPrefix = 0
            for (i, component) in components.enumerated() {
                if i < lastComponents.count && lastComponents[i] == component {
                    commonPrefix += 1
                } else {
                    break
                }
            }

            // Print new components
            for (i, component) in components.enumerated() {
                if i >= commonPrefix {
                    let indent = String(repeating: "  ", count: i)
                    let isLast = i == components.count - 1
                    let prefix = isLast ? "├── " : "└── "
                    tree += indent + prefix + component + "\n"
                }
            }

            lastComponents = components
        }

        tree += String(repeating: "-", count: 60) + "\n"
        return tree
    }

    /// Format git history
    private func formatGitHistory(_ history: [GitRepository.Commit]) -> String {
        var output = ""
        output += String(repeating: "=", count: 80) + "\n"
        output += "GIT HISTORY (Last \(history.count) commits)\n"
        output += String(repeating: "=", count: 80) + "\n\n"

        for commit in history {
            output += "Commit: \(commit.shortHash)\n"
            output += "Author: \(commit.author) <\(commit.email)>\n"
            output += "Date: \(commit.date)\n"
            output += "\n    \(commit.subject)\n"

            if !commit.body.isEmpty {
                let bodyLines = commit.body.components(separatedBy: .newlines)
                for line in bodyLines where !line.isEmpty {
                    output += "    \(line)\n"
                }
            }

            if !commit.files.isEmpty {
                output += "\nFiles Changed:\n"
                for file in commit.files {
                    output += "  \(file.status)  \(file.path)\n"
                }
            }

            if !commit.stats.isEmpty {
                output += "\n\(commit.stats)\n"
            }

            output += "\n" + String(repeating: "-", count: 80) + "\n\n"
        }

        return output
    }
}
