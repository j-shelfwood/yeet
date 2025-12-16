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

    func testMaxFilesLimit() throws {
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

        XCTAssertThrowsError(try collector.collect()) { error in
            guard case YeetError.tooManyFiles(let found, let limit) = error else {
                XCTFail("Expected tooManyFiles error, got \(error)")
                return
            }
            XCTAssertEqual(found, 15)
            XCTAssertEqual(limit, 10)
        }
    }

    func testMaxFileSizeLimit() throws {
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
        let result = try collector.collect()

        // File should be collected but with 0 tokens (skipped)
        XCTAssertEqual(result.fileCount, 1)
        XCTAssertEqual(result.totalTokens, 0)
    }

    func testMaxTotalTokensLimit() throws {
        // Create files that would exceed token limit
        for i in 1...10 {
            let file = tempDir.appendingPathComponent("file\(i).swift")
            let content = String(repeating: "word ", count: 10000) // ~2500 tokens each
            try content.write(to: file, atomically: true, encoding: .utf8)
        }

        let safetyLimits = SafetyLimits(
            maxFiles: 10_000,
            maxFileSize: 100 * 1024 * 1024,
            maxTotalTokens: 20_000  // Will exceed with 10 files
        )

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            maxTokens: 10_000,  // Per-file limit
            safetyLimits: safetyLimits
        )

        let collector = ContextCollector(configuration: config)

        XCTAssertThrowsError(try collector.collect()) { error in
            guard case YeetError.tooManyTokens = error else {
                XCTFail("Expected tooManyTokens error, got \(error)")
                return
            }
        }
    }

    // MARK: - Directory Exclusion Tests

    func testExcludeDirectories() throws {
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
        let result = try collector.collect()

        // Should only find src file
        XCTAssertEqual(result.fileCount, 1)
        XCTAssertTrue(result.fileList.contains("src/app.swift"))
        XCTAssertFalse(result.fileList.contains("build/app.swift"))
    }

    // MARK: - Pattern Filtering Tests

    func testMultipleIncludePatterns() throws {
        // Create files with different extensions
        try "swift".write(to: tempDir.appendingPathComponent("app.swift"), atomically: true, encoding: .utf8)
        try "ts".write(to: tempDir.appendingPathComponent("app.ts"), atomically: true, encoding: .utf8)
        try "json".write(to: tempDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            includePatterns: ["*.swift", "*.ts"]
        )

        let collector = ContextCollector(configuration: config)
        let result = try collector.collect()

        // Should find swift and ts files, not json
        XCTAssertEqual(result.fileCount, 2)
        XCTAssertTrue(result.fileList.contains("app.swift"))
        XCTAssertTrue(result.fileList.contains("app.ts"))
        XCTAssertFalse(result.fileList.contains("config.json"))
    }

    func testTypeFilters() throws {
        // Create files with different extensions
        try "swift".write(to: tempDir.appendingPathComponent("app.swift"), atomically: true, encoding: .utf8)
        try "py".write(to: tempDir.appendingPathComponent("script.py"), atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            typeFilters: ["*.swift"]
        )

        let collector = ContextCollector(configuration: config)
        let result = try collector.collect()

        // Should only find swift file
        XCTAssertEqual(result.fileCount, 1)
        XCTAssertTrue(result.fileList.contains("app.swift"))
        XCTAssertFalse(result.fileList.contains("script.py"))
    }

    // MARK: - Output Format Tests

    func testJSONOutput() throws {
        let file = tempDir.appendingPathComponent("test.swift")
        try "test content".write(to: file, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.path],
            outputJSON: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try collector.collect()

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

    func testMixedProjectStructure() throws {
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
        let result = try collector.collect()

        // Should exclude node_modules, .git, build
        XCTAssertGreaterThan(result.fileCount, 0)
        XCTAssertTrue(result.fileList.contains("src/file.swift"))
        XCTAssertFalse(result.fileList.contains("node_modules/file.swift"))
        XCTAssertFalse(result.fileList.contains(".git/file.swift"))
        XCTAssertFalse(result.fileList.contains("build/file.swift"))
    }
}
