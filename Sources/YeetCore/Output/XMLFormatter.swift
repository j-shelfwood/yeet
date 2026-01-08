import Foundation

/// XML output formatting for clean, token-efficient LLM context
///
/// Produces semantic XML markup with minimal overhead:
/// ```xml
/// <context>
///   <tree>...</tree>
///   <files>
///     <file path="src/main.swift">
///       content here
///     </file>
///   </files>
///   <git-history>...</git-history>
/// </context>
/// ```
public struct XMLFormatter {

    // MARK: - Main Entry Point

    /// Format complete context as XML for clipboard
    ///
    /// - Parameters:
    ///   - files: Array of file contents to format
    ///   - tree: Optional directory tree string
    ///   - gitHistory: Optional git commit history
    /// - Returns: Complete XML-formatted context string
    public static func format(
        files: [FileContent],
        tree: String? = nil,
        gitHistory: [Commit]? = nil
    ) -> String {
        var output = "<context>\n"

        // Directory tree (if provided)
        if let tree = tree, !tree.isEmpty {
            output += formatTree(tree)
        }

        // Files section
        output += formatFiles(files)

        // Git history (if provided)
        if let history = gitHistory, !history.isEmpty {
            output += formatHistory(history)
        }

        output += "</context>\n"
        return output
    }

    // MARK: - Component Formatters

    /// Format directory tree as XML
    private static func formatTree(_ tree: String) -> String {
        var output = "<tree>\n"
        output += tree
        if !tree.hasSuffix("\n") {
            output += "\n"
        }
        output += "</tree>\n"
        return output
    }

    /// Format all files as XML
    private static func formatFiles(_ files: [FileContent]) -> String {
        var output = "<files>\n"

        for file in files {
            output += formatFile(file)
        }

        output += "</files>\n"
        return output
    }

    /// Format single file as XML element
    ///
    /// Uses CDATA for content to avoid XML escaping issues with code.
    /// Path is stored as attribute for clean parsing.
    private static func formatFile(_ file: FileContent) -> String {
        // Escape any ]]> sequences in content that would break CDATA
        let safeContent = escapeCDATA(file.content)

        var output = "<file path=\"\(escapeXMLAttribute(file.path))\">\n"
        output += "<![CDATA[\n"
        output += safeContent
        if !safeContent.hasSuffix("\n") {
            output += "\n"
        }
        output += "]]>\n"
        output += "</file>\n"
        return output
    }

    /// Format git history as XML
    private static func formatHistory(_ history: [Commit]) -> String {
        var output = "<git-history>\n"

        for commit in history {
            output += "<commit hash=\"\(commit.shortHash)\">\n"
            output += "<author>\(escapeXMLContent(commit.author))</author>\n"
            output += "<email>\(escapeXMLContent(commit.email))</email>\n"
            output += "<date>\(escapeXMLContent(commit.date))</date>\n"
            output += "<subject>\(escapeXMLContent(commit.subject))</subject>\n"

            if !commit.body.isEmpty {
                output += "<body><![CDATA[\n\(commit.body)\n]]></body>\n"
            }

            if !commit.files.isEmpty {
                output += "<files-changed>\n"
                for file in commit.files {
                    output += "<change status=\"\(file.status)\">\(escapeXMLContent(file.path))</change>\n"
                }
                output += "</files-changed>\n"
            }

            if !commit.stats.isEmpty {
                output += "<stats>\(escapeXMLContent(commit.stats))</stats>\n"
            }

            output += "</commit>\n"
        }

        output += "</git-history>\n"
        return output
    }

    // MARK: - XML Escaping Utilities

    /// Escape special characters in XML attribute values
    private static func escapeXMLAttribute(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Escape special characters in XML content
    private static func escapeXMLContent(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Escape CDATA terminator sequences in content
    ///
    /// Replaces `]]>` with `]]]]><![CDATA[>` to safely nest in CDATA
    private static func escapeCDATA(_ string: String) -> String {
        string.replacingOccurrences(of: "]]>", with: "]]]]><![CDATA[>")
    }
}
