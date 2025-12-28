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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")

        let pipe = Pipe()
        task.standardInput = pipe

        try task.run()

        pipe.fileHandleForWriting.write(output.data(using: .utf8)!)
        try pipe.fileHandleForWriting.close()

        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw YeetError.clipboardFailed
        }
        #else
        throw YeetError.unsupportedPlatform
        #endif
    }
}
