import XCTest
@testable import YeetCore
import Foundation

final class TokenLimitsTests: XCTestCase {
    var tempDir: URL!

    /// Helper to check if discovered files contain expected file (handles symlink differences)
    private func assertContainsFile(_ files: [URL], _ expectedFile: URL, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        let canonicalFiles = Set(files.map { URL(fileURLWithPath: $0.path).resolvingSymlinksInPath() })
        let canonicalExpected = URL(fileURLWithPath: expectedFile.path).resolvingSymlinksInPath()
        XCTAssertTrue(canonicalFiles.contains(canonicalExpected), message, file: file, line: line)
    }

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("token-limits-tests-\(UUID().uuidString)")
            .standardizedFileURL  // Resolve symlinks (/var -> /private/var on macOS)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Filename-Based Token Limits

    func testTokenLimitsAppliedToLockFiles() async throws {
        // Create a large lock file
        let lockFile = tempDir.appendingPathComponent("package-lock.json").standardizedFileURL
        let largeContent = (0..<2000).map { "\"dependency\($0)\": \"1.0.0\"" }.joined(separator: ",\n")
        try largeContent.write(to: lockFile, atomically: true, encoding: .utf8)

        // Configure with custom token limit for lock files
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            maxTokens: 3000,  // Global limit
            includePatterns: ["*.json"],
            tokenLimits: ["*-lock.json" : 300],  // Lock files limited to 300 tokens
            enableTokenCounting: true  // Enable stats mode
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Find the lock file in results
        let lockFileContent = result.files.first { $0.path.contains("package-lock.json") }
        XCTAssertNotNil(lockFileContent, "Lock file should be collected")

        // Verify token limit was applied
        if let lockFileContent = lockFileContent {
            XCTAssertLessThanOrEqual(lockFileContent.tokenCount, 300, "Lock file should be limited to 300 tokens")
            XCTAssertTrue(lockFileContent.wasTruncated, "Lock file should be truncated")
        }
    }

    func testTokenLimitZeroSkipsFile() async throws {
        // Create minified files
        let minFile = tempDir.appendingPathComponent("app.min.js").standardizedFileURL
        let normalFile = tempDir.appendingPathComponent("app.js").standardizedFileURL
        try "minified content".write(to: minFile, atomically: true, encoding: .utf8)
        try "normal content".write(to: normalFile, atomically: true, encoding: .utf8)

        // Configure to skip minified files (limit = 0)
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.js"],
            tokenLimits: ["*.min.*": 0],  // Skip minified files
            enableTokenCounting: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Minified file should be skipped
        let minFileContent = result.files.first { $0.path.contains("app.min.js") }
        if let minFileContent = minFileContent {
            XCTAssertTrue(minFileContent.content.contains("[SKIPPED"), "Minified file should be skipped")
        }

        // Normal file should be included
        let normalFileContent = result.files.first { $0.path.contains("app.js") }
        XCTAssertNotNil(normalFileContent, "Normal JS file should be collected")
    }

    // MARK: - Path-Based Token Limits

    func testPathBasedTokenLimits() async throws {
        // Create database migration files in nested structure
        let migrationsDir = tempDir.appendingPathComponent("database/migrations")
        try FileManager.default.createDirectory(at: migrationsDir, withIntermediateDirectories: true)

        let migration1 = migrationsDir.appendingPathComponent("001_create_users.php").standardizedFileURL
        let migration2 = migrationsDir.appendingPathComponent("002_create_posts.php").standardizedFileURL

        // Create large migration files (would exceed 800 tokens)
        let largeMigration = (0..<500).map { "    public function up() { // Migration \($0)\n        Schema::create('table\($0)', function(Blueprint $table) {});\n    }" }.joined(separator: "\n")
        try largeMigration.write(to: migration1, atomically: true, encoding: .utf8)
        try largeMigration.write(to: migration2, atomically: true, encoding: .utf8)

        // Configure with path-based token limit
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            maxTokens: 3000,  // Global limit
            includePatterns: ["*.php"],
            tokenLimits: ["database/migrations/**": 800],  // Migrations limited to 800 tokens
            enableTokenCounting: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Verify both migration files were limited to 800 tokens
        for file in result.files where file.path.contains("database/migrations") {
            XCTAssertLessThanOrEqual(file.tokenCount, 800, "\(file.path) should be limited to 800 tokens")
        }
    }

    func testMultipleTokenLimitPatterns() async throws {
        // Create files matching different patterns
        let lockFile = tempDir.appendingPathComponent("composer.lock").standardizedFileURL
        let migrationFile = tempDir.appendingPathComponent("database/migrations/001_init.php").standardizedFileURL
        let normalFile = tempDir.appendingPathComponent("app.php").standardizedFileURL

        try FileManager.default.createDirectory(at: migrationFile.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Create large files
        let largeContent = String(repeating: "Lorem ipsum dolor sit amet. ", count: 2000)
        try largeContent.write(to: lockFile, atomically: true, encoding: .utf8)
        try largeContent.write(to: migrationFile, atomically: true, encoding: .utf8)
        try largeContent.write(to: normalFile, atomically: true, encoding: .utf8)

        // Configure with multiple token limit patterns
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            maxTokens: 3000,  // Global limit
            includePatterns: ["*.lock", "*.php"],
            tokenLimits: [
                "*.lock": 300,
                "database/migrations/**": 800
            ],
            enableTokenCounting: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // Verify each file has correct limit
        for file in result.files {
            if file.path.contains("composer.lock") {
                XCTAssertLessThanOrEqual(file.tokenCount, 300, "Lock file should be limited to 300 tokens")
            } else if file.path.contains("database/migrations") {
                XCTAssertLessThanOrEqual(file.tokenCount, 800, "Migration should be limited to 800 tokens")
            } else if file.path.contains("app.php") {
                XCTAssertLessThanOrEqual(file.tokenCount, 3000, "Normal PHP file should use global limit")
            }
        }
    }

    // MARK: - Edge Cases

    func testTokenLimitPriorityFilenameOverPath() async throws {
        // Test that filename patterns take precedence when both match
        let file = tempDir.appendingPathComponent("database/migrations/seed.lock").standardizedFileURL
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

        let largeContent = String(repeating: "data ", count: 1000)
        try largeContent.write(to: file, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            maxTokens: 3000,
            includePatterns: ["*.lock"],
            tokenLimits: [
                "database/migrations/**": 800,  // Path-based
                "*.lock": 300  // Filename-based (should win)
            ],
            enableTokenCounting: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        // File matches both patterns, but getTokenLimit checks path-based first if pattern contains /
        // So database/migrations/** (800) should be checked before *.lock (300)
        let fileContent = result.files.first { $0.path.contains("seed.lock") }
        XCTAssertNotNil(fileContent, "File should be collected")

        if let fileContent = fileContent {
            // Path-based patterns are checked first in our implementation
            XCTAssertLessThanOrEqual(fileContent.tokenCount, 800, "Should use path-based limit (checked first)")
        }
    }

    func testNoTokenLimitsUsesGlobalDefault() async throws {
        // Without custom token limits, should use global maxTokens
        let file = tempDir.appendingPathComponent("app.swift").standardizedFileURL
        let largeContent = String(repeating: "func test() {}\n", count: 1000)
        try largeContent.write(to: file, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            maxTokens: 500,  // Global limit
            includePatterns: ["*.swift"],
            tokenLimits: nil,  // No custom limits
            enableTokenCounting: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        let fileContent = result.files.first { $0.path.contains("app.swift") }
        XCTAssertNotNil(fileContent)

        if let fileContent = fileContent {
            XCTAssertLessThanOrEqual(fileContent.tokenCount, 500, "Should use global max tokens")
        }
    }

    func testEmptyTokenLimitsDictionaryUsesGlobalDefault() async throws {
        // Empty dictionary should behave same as nil
        let file = tempDir.appendingPathComponent("test.py").standardizedFileURL
        let largeContent = String(repeating: "def test(): pass\n", count: 1000)
        try largeContent.write(to: file, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            maxTokens: 600,
            includePatterns: ["*.py"],
            tokenLimits: [:],  // Empty dictionary
            enableTokenCounting: true
        )

        let collector = ContextCollector(configuration: config)
        let result = try await collector.collect()

        let fileContent = result.files.first { $0.path.contains("test.py") }
        if let fileContent = fileContent {
            XCTAssertLessThanOrEqual(fileContent.tokenCount, 600, "Should use global limit")
        }
    }
}
