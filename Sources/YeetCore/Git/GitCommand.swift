import Foundation

/// Shared git command execution
enum GitCommand {
    /// Execute git command and return stdout
    static func execute(_ args: [String], in directory: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory] + args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Read stdout and stderr concurrently to avoid deadlock
        // This is critical for commands that produce large output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: stderrData, encoding: .utf8) ?? ""
            throw YeetError.gitCommandFailed("git \(args.joined(separator: " ")) failed: \(errorMessage)")
        }

        return String(data: stdoutData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Execute git command, return lines
    static func executeLines(_ args: [String], in directory: String) throws -> [String] {
        try execute(args, in: directory)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
    }

    /// Resolve directory from file or directory path
    static func resolveDirectory(from path: String) -> String {
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            return isDirectory.boolValue ? path : (path as NSString).deletingLastPathComponent
        }

        return path
    }
}
