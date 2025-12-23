import XCTest
@testable import YeetCore
import Foundation

final class PatternMatcherTests: XCTestCase {
    var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pattern-matcher-tests-\(UUID().uuidString)")
            .standardizedFileURL  // Resolve symlinks (/var -> /private/var on macOS)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Exclude Pattern Tests (v1.1.0)

    func testMatchesExcludePatternWithDoubleStarGlobs() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            excludePatterns: ["instance/*/content/**", "**/*.generated.*"]
        )
        let matcher = PatternMatcher(configuration: config)

        // Should match instance/*/content/** pattern
        let instanceFile1 = tempDir.appendingPathComponent("instance/site1/content/uploads/image.jpg")
        XCTAssertTrue(matcher.matchesExcludePattern(instanceFile1), "Should match instance/*/content/**")

        let instanceFile2 = tempDir.appendingPathComponent("instance/production/content/cache/data.bin")
        XCTAssertTrue(matcher.matchesExcludePattern(instanceFile2), "Should match instance/*/content/**")

        // Should NOT match - not in content subdirectory
        let instanceConfig = tempDir.appendingPathComponent("instance/site1/config.php")
        XCTAssertFalse(matcher.matchesExcludePattern(instanceConfig), "Should not match - not in content/")

        // Should match **/*.generated.* pattern
        let generatedFile = tempDir.appendingPathComponent("app/Models/User.generated.php")
        XCTAssertTrue(matcher.matchesExcludePattern(generatedFile), "Should match **/*.generated.*")

        // Should NOT match - no .generated. in name
        let normalFile = tempDir.appendingPathComponent("app/Models/User.php")
        XCTAssertFalse(matcher.matchesExcludePattern(normalFile), "Should not match - not generated file")
    }

    func testMatchesExcludePatternWithDirectoryGlobs() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            excludePatterns: ["database/factories/**", "build/**"]
        )
        let matcher = PatternMatcher(configuration: config)

        // Should match database/factories/**
        let factoryFile = tempDir.appendingPathComponent("database/factories/UserFactory.php")
        XCTAssertTrue(matcher.matchesExcludePattern(factoryFile), "Should match database/factories/**")

        let nestedFactory = tempDir.appendingPathComponent("database/factories/nested/PostFactory.php")
        XCTAssertTrue(matcher.matchesExcludePattern(nestedFactory), "Should match nested factory file")

        // Should NOT match - different directory
        let migration = tempDir.appendingPathComponent("database/migrations/001_create_users.php")
        XCTAssertFalse(matcher.matchesExcludePattern(migration), "Should not match - migrations not excluded")

        // Should match build/**
        let buildFile = tempDir.appendingPathComponent("build/output/app.js")
        XCTAssertTrue(matcher.matchesExcludePattern(buildFile), "Should match build/**")
    }

    func testMatchesExcludePatternEmptyPatterns() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            excludePatterns: []
        )
        let matcher = PatternMatcher(configuration: config)

        let anyFile = tempDir.appendingPathComponent("src/app.swift")
        XCTAssertFalse(matcher.matchesExcludePattern(anyFile), "Should not match any file when no patterns")
    }

    func testMatchesExcludePatternMultiplePatterns() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            excludePatterns: [
                "**/*.test.*",
                "**/*.spec.*",
                "**/mocks/**",
                "vendor/**"
            ]
        )
        let matcher = PatternMatcher(configuration: config)

        // Test files
        XCTAssertTrue(matcher.matchesExcludePattern(tempDir.appendingPathComponent("src/App.test.tsx")))
        XCTAssertTrue(matcher.matchesExcludePattern(tempDir.appendingPathComponent("tests/User.spec.js")))

        // Mock files
        XCTAssertTrue(matcher.matchesExcludePattern(tempDir.appendingPathComponent("tests/mocks/api.json")))
        XCTAssertTrue(matcher.matchesExcludePattern(tempDir.appendingPathComponent("src/test/mocks/data.php")))

        // Vendor files
        XCTAssertTrue(matcher.matchesExcludePattern(tempDir.appendingPathComponent("vendor/package/File.php")))

        // Regular files should not match
        XCTAssertFalse(matcher.matchesExcludePattern(tempDir.appendingPathComponent("src/App.tsx")))
        XCTAssertFalse(matcher.matchesExcludePattern(tempDir.appendingPathComponent("lib/utils.js")))
    }

    // MARK: - Exclude Directory Tests

    func testIsInExcludedDirectory() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            excludeDirectories: ["node_modules", "build", ".git"]
        )
        let matcher = PatternMatcher(configuration: config)

        // Should be excluded
        XCTAssertTrue(matcher.isInExcludedDirectory(tempDir.appendingPathComponent("node_modules/package/file.js")))
        XCTAssertTrue(matcher.isInExcludedDirectory(tempDir.appendingPathComponent("build/output/app.js")))
        XCTAssertTrue(matcher.isInExcludedDirectory(tempDir.appendingPathComponent(".git/objects/abc")))

        // Nested excluded directories
        XCTAssertTrue(matcher.isInExcludedDirectory(tempDir.appendingPathComponent("src/node_modules/pkg/file.js")))

        // Should NOT be excluded
        XCTAssertFalse(matcher.isInExcludedDirectory(tempDir.appendingPathComponent("src/app.js")))
        XCTAssertFalse(matcher.isInExcludedDirectory(tempDir.appendingPathComponent("tests/unit/test.js")))
    }

    func testIsInExcludedDirectoryEmptyList() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            excludeDirectories: []
        )
        let matcher = PatternMatcher(configuration: config)

        let anyFile = tempDir.appendingPathComponent("node_modules/package/file.js")
        XCTAssertFalse(matcher.isInExcludedDirectory(anyFile), "Should not exclude when no directories specified")
    }

    // MARK: - Include Pattern Tests

    func testShouldInclude() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.swift", "*.ts", "*.tsx"]
        )
        let matcher = PatternMatcher(configuration: config)

        // Should include
        XCTAssertTrue(matcher.shouldInclude(tempDir.appendingPathComponent("src/App.swift")))
        XCTAssertTrue(matcher.shouldInclude(tempDir.appendingPathComponent("components/Button.tsx")))
        XCTAssertTrue(matcher.shouldInclude(tempDir.appendingPathComponent("utils/helper.ts")))

        // Should NOT include
        XCTAssertFalse(matcher.shouldInclude(tempDir.appendingPathComponent("README.md")))
        XCTAssertFalse(matcher.shouldInclude(tempDir.appendingPathComponent("package.json")))
        XCTAssertFalse(matcher.shouldInclude(tempDir.appendingPathComponent("app.py")))
    }

    func testShouldIncludeEmptyPatterns() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: []
        )
        let matcher = PatternMatcher(configuration: config)

        // When no patterns specified, should use default patterns (not include everything)
        // Default patterns include *.swift and *.md (but NOT *.txt)
        XCTAssertTrue(matcher.shouldInclude(tempDir.appendingPathComponent("file.swift")), ".swift is in default patterns")
        XCTAssertTrue(matcher.shouldInclude(tempDir.appendingPathComponent("README.md")), ".md is in default patterns")

        // But shouldn't include extensions not in default patterns
        XCTAssertFalse(matcher.shouldInclude(tempDir.appendingPathComponent("file.xyz")), ".xyz not in default patterns")
    }

    // MARK: - Type Filter Tests

    func testTypeFilters() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            typeFilters: ["*.swift", "*.rs"]
        )
        let matcher = PatternMatcher(configuration: config)

        XCTAssertTrue(matcher.shouldInclude(tempDir.appendingPathComponent("main.swift")))
        XCTAssertTrue(matcher.shouldInclude(tempDir.appendingPathComponent("lib.rs")))
        XCTAssertFalse(matcher.shouldInclude(tempDir.appendingPathComponent("app.ts")))
    }

    // MARK: - Integration Tests (Exclude Directory + Pattern + Include)

    func testCombinedFiltering() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.swift", "*.ts"],
            excludeDirectories: ["node_modules", "build"],
            excludePatterns: ["**/*.test.*", "**/*.generated.*"]
        )
        let matcher = PatternMatcher(configuration: config)

        // Should be excluded by directory
        let nodeModulesFile = tempDir.appendingPathComponent("node_modules/pkg/lib.ts")
        XCTAssertTrue(matcher.isInExcludedDirectory(nodeModulesFile))
        XCTAssertFalse(matcher.matchesExcludePattern(nodeModulesFile))  // Pattern doesn't match, but directory does

        // Should be excluded by pattern
        let testFile = tempDir.appendingPathComponent("src/App.test.swift")
        XCTAssertFalse(matcher.isInExcludedDirectory(testFile))
        XCTAssertTrue(matcher.matchesExcludePattern(testFile))

        let generatedFile = tempDir.appendingPathComponent("models/User.generated.ts")
        XCTAssertFalse(matcher.isInExcludedDirectory(generatedFile))
        XCTAssertTrue(matcher.matchesExcludePattern(generatedFile))

        // Should be included (not excluded by directory or pattern, and matches include)
        let normalFile = tempDir.appendingPathComponent("src/App.swift")
        XCTAssertFalse(matcher.isInExcludedDirectory(normalFile))
        XCTAssertFalse(matcher.matchesExcludePattern(normalFile))
        XCTAssertTrue(matcher.shouldInclude(normalFile))

        // Should be excluded (doesn't match include patterns)
        let markdownFile = tempDir.appendingPathComponent("README.md")
        XCTAssertFalse(matcher.isInExcludedDirectory(markdownFile))
        XCTAssertFalse(matcher.matchesExcludePattern(markdownFile))
        XCTAssertFalse(matcher.shouldInclude(markdownFile))
    }

    // MARK: - Edge Cases

    func testPathNormalization() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            excludePatterns: ["build/**"]
        )
        let matcher = PatternMatcher(configuration: config)

        // Test with trailing slash
        let pathWithSlash = tempDir.appendingPathComponent("build/output/")
        XCTAssertTrue(matcher.matchesExcludePattern(pathWithSlash))

        // Test with relative path components (../)
        // Pattern matcher should work with normalized paths
        let normalPath = tempDir.appendingPathComponent("build/nested/../output/file.js")
        XCTAssertTrue(matcher.matchesExcludePattern(normalPath))
    }

    func testCaseSensitivity() {
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            excludePatterns: ["Build/**"]  // Capital B
        )
        let matcher = PatternMatcher(configuration: config)

        // Patterns should be case-sensitive
        let lowerCase = tempDir.appendingPathComponent("build/file.js")
        XCTAssertFalse(matcher.matchesExcludePattern(lowerCase), "Pattern matching should be case-sensitive")

        let upperCase = tempDir.appendingPathComponent("Build/file.js")
        XCTAssertTrue(matcher.matchesExcludePattern(upperCase), "Should match exact case")
    }
}
