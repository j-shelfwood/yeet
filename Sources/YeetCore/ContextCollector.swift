import Foundation

/// Main context collection orchestrator.
///
/// `ContextCollector` is the primary interface for gathering source code files,
/// applying token limits, and formatting output for LLM consumption.
///
/// ## Overview
///
/// The collector performs the following steps:
/// 1. **Discovery**: Finds files matching patterns (with optional git-aware discovery)
/// 2. **Reading**: Reads file contents with safety limits and intelligent truncation
/// 3. **Git History**: Optionally collects commit history
/// 4. **Formatting**: Formats output as text or JSON with optional directory tree
///
/// ## Usage
///
/// ```swift
/// let config = CollectorConfiguration(
///     paths: ["Sources"],
///     maxTokens: 10000,
///     includeHistory: true
/// )
///
/// let collector = ContextCollector(configuration: config)
/// let result = try collector.collect()
///
/// print("Collected \(result.fileCount) files with \(result.totalTokens) tokens")
/// try result.copyToClipboard()
/// ```
///
/// ## Error Handling
///
/// Throws ``YeetError`` for various failure conditions:
/// - `tooManyFiles`: Discovered files exceed safety limit
/// - `fileTooLarge`: Individual file exceeds size limit
/// - `tooManyTokens`: Total tokens exceed limit
/// - `gitCommandFailed`: Git operations fail
///
/// - SeeAlso: ``CollectorConfiguration``
/// - SeeAlso: ``CollectionResult``
public class ContextCollector {
    private let configuration: CollectorConfiguration
    private let discovery: FileDiscovery
    private let processor: FileProcessor
    private let formatter: OutputFormatter

    /// Creates a new context collector with the specified configuration.
    ///
    /// - Parameter configuration: Configuration controlling collection behavior
    public init(configuration: CollectorConfiguration) {
        self.configuration = configuration
        self.discovery = FileDiscovery(configuration: configuration)
        self.processor = FileProcessor(
            maxTokens: configuration.maxTokens,
            safetyLimits: configuration.safetyLimits,
            tokenLimits: configuration.tokenLimits
        )
        self.formatter = OutputFormatter(configuration: configuration)
    }

    /// Executes the context collection process.
    ///
    /// Performs file discovery, reads contents in parallel, collects git history (if enabled),
    /// and formats the output according to configuration settings.
    ///
    /// Progress indicators are displayed to stderr unless ``CollectorConfiguration/quiet`` is enabled.
    ///
    /// - Returns: A ``CollectionResult`` containing file count, token count, and formatted output
    /// - Throws: ``YeetError`` if safety limits are exceeded or operations fail
    public func collect() async throws -> CollectionResult {
        // Step 1: Discover files (handle diff mode if enabled)
        progress("Discovering files...")
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

        progress("Found \(fileURLs.count) files")

        // Step 2: Read and process files in parallel (NO TOKENIZATION YET)
        progress("Reading files...")
        let fileContents = try await processor.processFiles(fileURLs)

        progress("Processed \(fileContents.count) files")

        // Step 3: Collect git history if enabled
        var gitHistory: [Commit]? = nil
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

        // Step 4: Format output (still no tokenization)
        let output: String
        let fileList: String

        if configuration.listOnly {
            fileList = formatter.formatFileList(files: fileContents)
            output = fileList
        } else {
            if configuration.outputJSON {
                // For JSON, format without token count first
                output = formatter.formatJSON(files: fileContents, totalTokens: 0)
            } else {
                // For text, format without token count first
                output = formatter.formatText(
                    files: fileContents,
                    totalTokens: 0,
                    gitHistory: gitHistory
                )
            }

            fileList = formatter.formatFileList(files: fileContents)
        }

        // Step 5: SINGLE TOKENIZATION of final output (THE ONLY FFI CALL)
        progress("Counting tokens...")
        let totalTokens = try await Tokenizer.shared.count(text: output)

        // Step 6: Verify total tokens within safety limit
        if totalTokens > configuration.safetyLimits.maxTotalTokens {
            throw YeetError.tooManyTokens(
                total: totalTokens,
                limit: configuration.safetyLimits.maxTotalTokens
            )
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

    // MARK: - Progress Reporting

    /// Print progress message to stderr unless quiet mode is enabled
    private func progress(_ message: String) {
        guard !configuration.quiet else { return }

        // Write to stderr so it doesn't interfere with output redirection
        if let data = (message + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}
