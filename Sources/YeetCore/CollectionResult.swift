import Foundation

/// Result of a context collection operation
public struct CollectionResult {
    public let fileCount: Int
    public let totalTokens: Int
    public let fileList: String
    public let files: [FileContent]
    public let output: String

    public init(fileCount: Int, totalTokens: Int, fileList: String, files: [FileContent], output: String) {
        self.fileCount = fileCount
        self.totalTokens = totalTokens
        self.fileList = fileList
        self.files = files
        self.output = output
    }

    /// Copy the collected context to the system clipboard
    public func copyToClipboard() throws {
        #if os(macOS)
        try runClipboardCommand("/usr/bin/pbcopy", args: [])
        #elseif os(Linux)
        // Try Wayland first, then X11 tools
        let candidates: [(String, [String])] = [
            ("/usr/bin/wl-copy", []),
            ("/usr/local/bin/wl-copy", []),
            ("/usr/bin/xclip", ["-selection", "clipboard"]),
            ("/usr/local/bin/xclip", ["-selection", "clipboard"]),
            ("/usr/bin/xsel", ["--clipboard", "--input"]),
            ("/usr/local/bin/xsel", ["--clipboard", "--input"]),
        ]
        for (path, args) in candidates {
            if FileManager.default.fileExists(atPath: path) {
                try runClipboardCommand(path, args: args)
                return
            }
        }
        throw YeetError.unsupportedPlatform
        #else
        throw YeetError.unsupportedPlatform
        #endif
    }

    private func runClipboardCommand(_ executablePath: String, args: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = args

        let pipe = Pipe()
        task.standardInput = pipe

        try task.run()

        pipe.fileHandleForWriting.write(output.data(using: .utf8)!)
        try pipe.fileHandleForWriting.close()

        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw YeetError.clipboardFailed
        }
    }
}
