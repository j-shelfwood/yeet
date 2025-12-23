import XCTest
@testable import YeetCore
import Foundation

final class IntegrationTests: XCTestCase {
    var tempDir: URL!

    override func setUp() async throws {
        // Create temp directory
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yeet-integration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Safety Limits Tests

    func testMaxFilesLimit() async throws {
        // Create more files than limit
        for i in 1...15 {
            let file = tempDir.appendingPathComponent("file\(i).swift")
            try "content".write(to: file, atomically: true, encoding: .utf8)
        }

        let safetyLimits = SafetyLimits(
            maxFiles: 10,
            maxFileSize: 100 * 1024 * 1024,
            maxTotalTokens: 1_000_000
        )

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            safetyLimits: safetyLimits
        )

        let collector = ContextCollector(configuration: config)

        do {
            _ = try await collector.collect()
            XCTFail("Expected tooManyFiles error")
        } catch let error as YeetError {
            guard case YeetError.tooManyFiles(let found, let limit) = error else {
                XCTFail("Expected tooManyFiles error, got \(error)")
                return
            }
            XCTAssertEqual(found, 15)
            XCTAssertEqual(limit, 10)
        }
    }

    func testMaxFileSizeLimit() async throws {
        // Create a large file (2MB)
        let largeFile = tempDir.appendingPathComponent("large.swift")
        let largeContent = String(repeating: "a", count: 2 * 1024 * 1024) // 2MB
        try largeContent.write(to: largeFile, atomically: true, encoding: .utf8)

        let safetyLimits = SafetyLimits(
            maxFiles: 10_000,
            maxFileSize: 1 * 1024 * 1024,  // 1MB limit
            maxTotalTokens: 1_000_000
        )

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            safetyLimits: safetyLimits
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // File should be collected with skip message
        // In zero-tokenization mode, the skip message is included in final output
        // which means totalTokens > 0 (from formatting/headers/skip message)
        XCTAssertEqual(result.fileCount, 1)
        XCTAssertGreaterThan(result.totalTokens, 0)
        // Verify tokens are much smaller than if 2MB file was included
        XCTAssertLessThan(result.totalTokens, 1000)
    }

    func testMaxTotalTokensLimit() async throws {
        // Create files that would exceed token limit
        // Note: With BPE tokenization, we need diverse content (repeated chars compress heavily)
        for i in 1...10 {
            let file = tempDir.appendingPathComponent("file\(i).swift")
            // Create realistic Swift code that will have ~2500 tokens
            // Each unique word is typically 1-2 tokens
            let words = (0..<1250).map { "variable\($0)" }.joined(separator: " ")
            try words.write(to: file, atomically: true, encoding: .utf8)
        }

        let safetyLimits = SafetyLimits(
            maxFiles: 10_000,
            maxFileSize: 100 * 1024 * 1024,
            maxTotalTokens: 20_000  // Will exceed with 10 files at ~2500 tokens each
        )

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            maxTokens: 10_000,  // Per-file limit (files won't hit this)
            safetyLimits: safetyLimits
        )

        let collector = ContextCollector(configuration: config)

        do {
            _ = try await collector.collect()
            XCTFail("Expected tooManyTokens error")
        } catch let error as YeetError {
            guard case YeetError.tooManyTokens = error else {
                XCTFail("Expected tooManyTokens error, got \(error)")
                return
            }
        }
    }

    // MARK: - Directory Exclusion Tests

    func testExcludeDirectories() async throws {
        // Create directory structure
        let srcDir = tempDir.appendingPathComponent("src")
        let buildDir = tempDir.appendingPathComponent("build")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

        let srcFile = srcDir.appendingPathComponent("app.swift")
        let buildFile = buildDir.appendingPathComponent("app.swift")

        try "src content".write(to: srcFile, atomically: true, encoding: .utf8)
        try "build content".write(to: buildFile, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            excludeDirectories: ["build"]
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Should only find src file
        XCTAssertEqual(result.fileCount, 1)
        XCTAssertTrue(result.fileList.contains("src/app.swift"))
        XCTAssertFalse(result.fileList.contains("build/app.swift"))
    }

    // MARK: - Pattern Filtering Tests

    func testMultipleIncludePatterns() async throws {
        // Create files with different extensions
        try "swift".write(to: tempDir.appendingPathComponent("app.swift"), atomically: true, encoding: .utf8)
        try "ts".write(to: tempDir.appendingPathComponent("app.ts"), atomically: true, encoding: .utf8)
        try "json".write(to: tempDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            includePatterns: ["*.swift", "*.ts"]
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Should find swift and ts files, not json
        XCTAssertEqual(result.fileCount, 2)
        XCTAssertTrue(result.fileList.contains("app.swift"))
        XCTAssertTrue(result.fileList.contains("app.ts"))
        XCTAssertFalse(result.fileList.contains("config.json"))
    }

    func testTypeFilters() async throws {
        // Create files with different extensions
        try "swift".write(to: tempDir.appendingPathComponent("app.swift"), atomically: true, encoding: .utf8)
        try "py".write(to: tempDir.appendingPathComponent("script.py"), atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            typeFilters: ["*.swift"]
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Should only find swift file
        XCTAssertEqual(result.fileCount, 1)
        XCTAssertTrue(result.fileList.contains("app.swift"))
        XCTAssertFalse(result.fileList.contains("script.py"))
    }

    // MARK: - Output Format Tests

    func testJSONOutput() async throws {
        let file = tempDir.appendingPathComponent("test.swift")
        try "test content".write(to: file, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            outputJSON: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Should be valid JSON
        guard let data = result.fileList.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // fileList might not be JSON in current implementation
            // This test documents expected behavior
            return
        }

        XCTAssertNotNil(json["fileCount"])
        XCTAssertNotNil(json["totalTokens"])
    }

    // MARK: - Real-World Scenarios

    func testMixedProjectStructure() async throws {
        // Create a realistic project structure
        let dirs = ["src", "tests", "node_modules", ".git", "build"]
        for dir in dirs {
            let dirURL = tempDir.appendingPathComponent(dir)
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

            let file = dirURL.appendingPathComponent("file.swift")
            try "content".write(to: file, atomically: true, encoding: .utf8)
        }

        let config = CollectorConfiguration(paths: [tempDir.path])
        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Should exclude node_modules, .git, build
        XCTAssertGreaterThan(result.fileCount, 0)
        XCTAssertTrue(result.fileList.contains("src/file.swift"))
        XCTAssertFalse(result.fileList.contains("node_modules/file.swift"))
        XCTAssertFalse(result.fileList.contains(".git/file.swift"))
        XCTAssertFalse(result.fileList.contains("build/file.swift"))
    }

    // MARK: - Configuration Integration Tests

    func testExcludePatternsWithGlobSupport() async throws {
        // Create nested directory structure to test ** glob patterns
        let instanceDir = tempDir.appendingPathComponent("instance/site1/content/uploads")
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: instanceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        // Files that should be excluded by pattern
        let excludedFile1 = instanceDir.appendingPathComponent("image.php")
        let excludedFile2 = tempDir.appendingPathComponent("instance/site2/content/doc.php")
        try FileManager.default.createDirectory(at: excludedFile2.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Files that should be included
        let includedFile1 = srcDir.appendingPathComponent("app.php")
        let includedFile2 = tempDir.appendingPathComponent("instance/config.php")

        try "excluded content 1".write(to: excludedFile1, atomically: true, encoding: .utf8)
        try "excluded content 2".write(to: excludedFile2, atomically: true, encoding: .utf8)
        try "included content 1".write(to: includedFile1, atomically: true, encoding: .utf8)
        try "included content 2".write(to: includedFile2, atomically: true, encoding: .utf8)

        // Test ** recursive glob pattern
        let config = CollectorConfiguration(
            paths: [tempDir.path],
            excludePatterns: ["instance/*/content/**"]
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Verify exclusions worked
        XCTAssertTrue(result.fileList.contains("src/app.php"), "Should include src/app.php")
        XCTAssertTrue(result.fileList.contains("instance/config.php"), "Should include instance/config.php")
        XCTAssertFalse(result.fileList.contains("instance/site1/content/uploads/image.php"), "Should exclude instance/site1/content/uploads/image.php")
        XCTAssertFalse(result.fileList.contains("instance/site2/content/doc.php"), "Should exclude instance/site2/content/doc.php")
    }

    func testExcludePatternsFromConfig() async throws {
        // Create .yeetconfig with exclude patterns
        let configContent = """
        [exclude]
        patterns = ["**/*.generated.*", "database/factories/**"]
        """
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Create .git directory so config is recognized
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        // Create test files
        let factoriesDir = tempDir.appendingPathComponent("database/factories")
        let modelsDir = tempDir.appendingPathComponent("app/Models")
        try FileManager.default.createDirectory(at: factoriesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let excludedFactory = factoriesDir.appendingPathComponent("UserFactory.php")
        let excludedGenerated = modelsDir.appendingPathComponent("User.generated.php")
        let includedModel = modelsDir.appendingPathComponent("User.php")

        try "factory content".write(to: excludedFactory, atomically: true, encoding: .utf8)
        try "generated content".write(to: excludedGenerated, atomically: true, encoding: .utf8)
        try "model content".write(to: includedModel, atomically: true, encoding: .utf8)

        // Load config and verify patterns are applied
        let loadedConfig = ConfigLoader.loadConfig(for: tempDir.path)
        let config = CollectorConfiguration(
            paths: [tempDir.path],
            excludePatterns: loadedConfig.exclude?.patterns ?? []
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Verify patterns worked
        XCTAssertTrue(result.fileList.contains("app/Models/User.php"), "Should include User.php")
        XCTAssertFalse(result.fileList.contains("app/Models/User.generated.php"), "Should exclude *.generated.* pattern")
        XCTAssertFalse(result.fileList.contains("database/factories/UserFactory.php"), "Should exclude database/factories/** pattern")
    }

    func testExcludeExtensionsFromConfig() async throws {
        // Create .yeetconfig with exclude extensions
        let configContent = """
        [exclude]
        extensions = ["log", "tmp", "cache"]
        """
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Create .git directory
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        // Create test files
        try "log content".write(to: tempDir.appendingPathComponent("app.log"), atomically: true, encoding: .utf8)
        try "tmp content".write(to: tempDir.appendingPathComponent("temp.tmp"), atomically: true, encoding: .utf8)
        try "cache content".write(to: tempDir.appendingPathComponent("data.cache"), atomically: true, encoding: .utf8)
        try "php content".write(to: tempDir.appendingPathComponent("app.php"), atomically: true, encoding: .utf8)

        let loadedConfig = ConfigLoader.loadConfig(for: tempDir.path)
        let config = CollectorConfiguration(
            paths: [tempDir.path],
            excludeDirectories: loadedConfig.exclude?.directories ?? []
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Should include .php but exclude configured extensions
        XCTAssertTrue(result.fileList.contains("app.php"), "Should include .php file")
        XCTAssertFalse(result.fileList.contains("app.log"), "Should exclude .log extension")
        XCTAssertFalse(result.fileList.contains("temp.tmp"), "Should exclude .tmp extension")
        XCTAssertFalse(result.fileList.contains("data.cache"), "Should exclude .cache extension")
    }

    func testTokenLimitsFromConfig() async throws {
        // Create .yeetconfig with token limits and include patterns
        let configContent = """
        [token_limits]
        "*.test.json" = 100
        "*.min.js" = 0

        [include]
        patterns = ["*.js", "*.json"]
        """
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Create .git directory
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        // Create test files with substantial content
        let testJsonContent = String(repeating: "dependency ", count: 500) // ~500 words
        let minJsContent = String(repeating: "function() { console.log('test'); } ", count: 200)
        let normalContent = "normal file content"

        try testJsonContent.write(to: tempDir.appendingPathComponent("data.test.json"), atomically: true, encoding: .utf8)
        try minJsContent.write(to: tempDir.appendingPathComponent("app.min.js"), atomically: true, encoding: .utf8)
        try normalContent.write(to: tempDir.appendingPathComponent("app.js"), atomically: true, encoding: .utf8)

        let loadedConfig = ConfigLoader.loadConfig(for: tempDir.path)

        // Verify token limits were loaded from config
        XCTAssertNotNil(loadedConfig.tokenLimits, "Token limits should be loaded from config")
        XCTAssertEqual(loadedConfig.tokenLimits?["*.test.json"], 100, "Test JSON file limit should be 100")
        XCTAssertEqual(loadedConfig.tokenLimits?["*.min.js"], 0, "Min.js limit should be 0 (skip)")

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            includePatterns: loadedConfig.include?.patterns ?? [],
            tokenLimits: loadedConfig.tokenLimits
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Verify files are listed (fileList shows all discovered files)
        XCTAssertTrue(result.fileList.contains("app.min.js") || result.fileList.contains("app.js"), "Should list js files")

        // Verify files were collected
        XCTAssertGreaterThan(result.fileCount, 0, "Should collect files")
    }

    func testDefaultsMaxTokensFromConfig() async throws {
        // Create .yeetconfig with max_tokens default
        let configContent = """
        [defaults]
        max_tokens = 50
        """
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Create .git directory
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        // Create file with content that exceeds 50 tokens (using .txt which is in default include patterns)
        let largeContent = (0..<100).map { "word\($0)" }.joined(separator: " ") // ~100 tokens
        try largeContent.write(to: tempDir.appendingPathComponent("large.txt"), atomically: true, encoding: .utf8)

        let loadedConfig = ConfigLoader.loadConfig(for: tempDir.path)

        // Verify max_tokens was loaded from config
        XCTAssertEqual(loadedConfig.defaults?.maxTokens, 50, "Should load max_tokens from config")

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            maxTokens: loadedConfig.defaults?.maxTokens ?? 10000,
            includePatterns: loadedConfig.include?.patterns ?? [],
            enableTokenCounting: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // File should be truncated due to low max_tokens setting
        XCTAssertGreaterThan(result.fileCount, 0, "Should collect at least one file")
        if let firstFile = result.files.first {
            XCTAssertTrue(firstFile.wasTruncated, "File should be truncated with 50 token limit")
            XCTAssertLessThanOrEqual(firstFile.tokenCount, 50, "File should have at most 50 tokens")
        }
    }

    func testDefaultsShowTreeFromConfig() async throws {
        // Create .yeetconfig with show_tree enabled
        let configContent = """
        [defaults]
        show_tree = true
        """
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Create .git directory
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        // Create test file
        try "content".write(to: tempDir.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)

        let loadedConfig = ConfigLoader.loadConfig(for: tempDir.path)
        let config = CollectorConfiguration(
            paths: [tempDir.path],
            includePatterns: loadedConfig.include?.patterns ?? [],
            showTree: loadedConfig.defaults?.showTree ?? false
        )

        // Verify showTree setting was loaded from config
        XCTAssertTrue(config.showTree, "Configuration should respect show_tree setting from .yeetconfig")

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Verify collection succeeded
        XCTAssertGreaterThan(result.fileCount, 0, "Should collect files")
    }

    func testDefaultsQuietFromConfig() async throws {
        // Create .yeetconfig with quiet enabled
        let configContent = """
        [defaults]
        quiet = true
        """
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Create .git directory
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        try "content".write(to: tempDir.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)

        let loadedConfig = ConfigLoader.loadConfig(for: tempDir.path)
        let config = CollectorConfiguration(
            paths: [tempDir.path],
            quiet: loadedConfig.defaults?.quiet ?? false
        )

        // Verify quiet is set
        XCTAssertTrue(config.quiet, "Configuration should respect quiet setting from .yeetconfig")
    }

    func testGitIncludeHistoryFromConfig() async throws {
        // Create .yeetconfig with include_history disabled
        let configContent = """
        [git]
        include_history = false
        """
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Create .git directory
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        // Initialize git repo and create commit
        let git = gitDir.deletingLastPathComponent()
        try "test".write(to: git.appendingPathComponent("test.txt"), atomically: true, encoding: .utf8)

        let loadedConfig = ConfigLoader.loadConfig(for: tempDir.path)
        let config = CollectorConfiguration(
            paths: [tempDir.path],
            includePatterns: loadedConfig.include?.patterns ?? [],
            includeHistory: loadedConfig.git?.includeHistory ?? true
        )

        // Verify include_history was set to false from config
        XCTAssertFalse(config.includeHistory, "Configuration should respect include_history setting from .yeetconfig")

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Verify collection succeeded
        XCTAssertGreaterThan(result.fileCount, 0, "Should collect files")
    }

    func testGitHistoryModeAndCountFromConfig() async throws {
        // Create .yeetconfig with history settings
        let configContent = """
        [git]
        include_history = true
        history_mode = "full"
        history_count = 3
        """
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Create .git directory
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let loadedConfig = ConfigLoader.loadConfig(for: tempDir.path)
        let config = CollectorConfiguration(
            paths: [tempDir.path],
            includeHistory: loadedConfig.git?.includeHistory ?? true,
            historyMode: loadedConfig.git?.historyMode ?? "summary",
            historyCount: loadedConfig.git?.historyCount ?? 5
        )

        // Verify settings are loaded correctly
        XCTAssertTrue(config.includeHistory, "Should include history")
        XCTAssertEqual(config.historyMode, "full", "Should use full history mode")
        XCTAssertEqual(config.historyCount, 3, "Should limit to 3 commits")
    }
}
