import Foundation

/// Main context collection orchestrator
public class ContextCollector {
    private let configuration: CollectorConfiguration
    private let discovery: FileDiscovery
    private let reader: FileReader
    private let formatter: OutputFormatter

    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
        self.discovery = FileDiscovery(configuration: configuration)
        self.reader = FileReader(
            maxTokens: configuration.maxTokens,
            maxFileSize: configuration.safetyLimits.maxFileSize
        )
        self.formatter = OutputFormatter(configuration: configuration)
    }

    /// Execute the context collection process
    public func collect() throws -> CollectionResult {
        // Step 1: Discover files (handle diff mode if enabled)
        let fileURLs: [URL]
        if configuration.diffMode {
            fileURLs = try collectDiffFiles()
        } else {
            fileURLs = try discovery.discoverFiles()
        }

        guard !fileURLs.isEmpty else {
            return CollectionResult(
                fileCount: 0,
                totalTokens: 0,
                fileList: "No files found matching criteria",
                output: "No files found matching criteria\n"
            )
        }

        // Step 2: Read and process files
        var fileContents: [FileContent] = []
        var totalTokens = 0

        for url in fileURLs {
            do {
                let content = try reader.readFile(at: url)
                fileContents.append(content)
                totalTokens += content.tokenCount

                // Check total token limit
                if totalTokens > configuration.safetyLimits.maxTotalTokens {
                    throw YeetError.tooManyTokens(
                        total: totalTokens,
                        limit: configuration.safetyLimits.maxTotalTokens
                    )
                }
            } catch let error as YeetError {
                // Rethrow YeetError (including limit errors)
                throw error
            } catch {
                // Log other errors but continue processing
                print("Warning: Failed to read \(url.path): \(error.localizedDescription)")
            }
        }

        // Step 3: Collect git history if enabled
        var gitHistory: [GitRepository.Commit]? = nil
        if configuration.includeHistory && !configuration.outputJSON {
            if let gitRepo = GitRepository.find(for: configuration.paths.first ?? ".") {
                do {
                    let includeStats = configuration.historyMode != "none"
                    gitHistory = try gitRepo.getHistory(
                        count: configuration.historyCount,
                        includeStats: includeStats
                    )
                } catch {
                    // Don't fail collection if git history fails
                    print("Warning: Failed to collect git history: \(error.localizedDescription)")
                }
            }
        }

        // Step 4: Format output
        let output: String
        let fileList: String

        if configuration.listOnly {
            fileList = formatter.formatFileList(files: fileContents)
            output = fileList
        } else {
            if configuration.outputJSON {
                output = formatter.formatJSON(files: fileContents, totalTokens: totalTokens)
            } else {
                output = formatter.formatText(
                    files: fileContents,
                    totalTokens: totalTokens,
                    gitHistory: gitHistory
                )
            }

            fileList = formatter.formatFileList(files: fileContents)
        }

        return CollectionResult(
            fileCount: fileContents.count,
            totalTokens: totalTokens,
            fileList: fileList,
            output: output
        )
    }

    // MARK: - Diff Mode

    private func collectDiffFiles() throws -> [URL] {
        guard let gitRepo = GitRepository.find(for: configuration.paths.first ?? ".") else {
            throw YeetError.gitCommandFailed("Not in a git repository. Use --diff only in git repositories.")
        }

        let changes = try gitRepo.getDiff()
        let baseURL = URL(fileURLWithPath: gitRepo.rootPath)

        // Filter out deleted files and map to URLs
        return changes
            .filter { $0.status != "D" }
            .map { baseURL.appendingPathComponent($0.path) }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    private let fileManager = FileManager.default
}
