import Foundation

/// Directory tree structure generation
public struct TreeGenerator {

    /// Generate directory tree structure from file list
    ///
    /// Creates a visual tree representation of the collected files
    /// showing their hierarchical directory structure.
    ///
    /// - Parameter files: Array of file contents to visualize
    /// - Returns: Formatted tree structure as string
    ///
    /// ## Example Output
    ///
    /// ```
    /// Directory Structure:
    /// ------------------------------------------------------------
    ///   └── Sources
    ///     ├── YeetCore
    ///       ├── FileReader.swift
    ///       └── OutputFormatter.swift
    /// ------------------------------------------------------------
    /// ```
    public static func generate(for files: [FileContent]) -> String {
        guard !files.isEmpty else {
            return "No files collected.\n"
        }

        var tree = ""
        tree += "\nDirectory Structure:\n"
        tree += String(repeating: "-", count: 60) + "\n"

        let paths = files.map { $0.path }.sorted()
        var lastComponents: [String] = []

        for path in paths {
            let components = path.split(separator: "/").map(String.init)

            // Find common prefix with previous path
            var commonPrefix = 0
            for (i, component) in components.enumerated() {
                if i < lastComponents.count && lastComponents[i] == component {
                    commonPrefix += 1
                } else {
                    break
                }
            }

            // Print new components (those not in common prefix)
            for (i, component) in components.enumerated() {
                if i >= commonPrefix {
                    let indent = String(repeating: "  ", count: i)
                    let isFile = i == components.count - 1
                    let prefix = isFile ? "├── " : "└── "
                    tree += indent + prefix + component + "\n"
                }
            }

            lastComponents = components
        }

        tree += String(repeating: "-", count: 60) + "\n"
        return tree
    }
}
