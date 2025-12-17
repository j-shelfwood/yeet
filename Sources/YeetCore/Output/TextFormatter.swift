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
}
