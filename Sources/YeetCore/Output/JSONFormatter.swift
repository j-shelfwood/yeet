import Foundation

/// JSON output formatting for structured data export
public struct JSONFormatter {

    /// Format file contents as JSON output
    ///
    /// Creates a structured JSON representation including file metadata
    /// and content for programmatic consumption.
    ///
    /// - Parameters:
    ///   - files: Array of file contents to format
    ///   - totalTokens: Total token count across all files
    /// - Returns: Pretty-printed JSON string
    ///
    /// ## Example Output
    ///
    /// ```json
    /// {
    ///   "fileCount": 2,
    ///   "totalTokens": 1500,
    ///   "files": [
    ///     {
    ///       "path": "src/main.swift",
    ///       "tokenCount": 800,
    ///       "wasTruncated": false,
    ///       "content": "..."
    ///     }
    ///   ]
    /// }
    /// ```
    public static func format(files: [FileContent], totalTokens: Int) -> String {
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
}
