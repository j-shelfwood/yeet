import XCTest
@testable import YeetCore

final class FilePatternsTests: XCTestCase {
    func testDefaultPatternsIncludesCommonTypes() {
        XCTAssertTrue(FilePatterns.defaultPatterns.contains("*.swift"))
        XCTAssertTrue(FilePatterns.defaultPatterns.contains("*.ts"))
        XCTAssertTrue(FilePatterns.defaultPatterns.contains("*.py"))
        XCTAssertTrue(FilePatterns.defaultPatterns.contains("*.rs"))
    }

    func testExcludedDirectoriesIncludesCommon() {
        XCTAssertTrue(FilePatterns.excludedDirectories.contains("node_modules"))
        XCTAssertTrue(FilePatterns.excludedDirectories.contains(".git"))
        XCTAssertTrue(FilePatterns.excludedDirectories.contains("build"))
    }

    func testSimplePatternMatching() {
        XCTAssertTrue(FilePatterns.matches(fileName: "test.swift", pattern: "*.swift"))
        XCTAssertTrue(FilePatterns.matches(fileName: "package.json", pattern: "*.json"))
        XCTAssertFalse(FilePatterns.matches(fileName: "test.swift", pattern: "*.py"))
    }

    func testPathExclusion() {
        XCTAssertTrue(FilePatterns.isExcluded(path: "src/node_modules/package"))
        XCTAssertTrue(FilePatterns.isExcluded(path: ".git/objects/abc"))
        XCTAssertFalse(FilePatterns.isExcluded(path: "src/main.swift"))
    }

    func testTokenLimitPatterns() {
        XCTAssertEqual(FilePatterns.getTokenLimit(for: "package-lock.json", defaultLimit: 10000), 500)
        XCTAssertEqual(FilePatterns.getTokenLimit(for: "mock-data.json", defaultLimit: 10000), 1000)
        XCTAssertEqual(FilePatterns.getTokenLimit(for: "app.min.js", defaultLimit: 10000), 0)
        XCTAssertEqual(FilePatterns.getTokenLimit(for: "main.swift", defaultLimit: 10000), 10000)
    }

    // MARK: - Glob Pattern Matching Tests (v1.1.0)

    func testMatchesPathWithSingleStar() {
        // Single * matches anything except /
        XCTAssertTrue(FilePatterns.matchesPath(path: "src/test.swift", pattern: "src/*.swift"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "src/app.swift", pattern: "src/*.swift"))
        XCTAssertFalse(FilePatterns.matchesPath(path: "src/nested/test.swift", pattern: "src/*.swift"))

        // Multiple single stars
        XCTAssertTrue(FilePatterns.matchesPath(path: "src/app/test.swift", pattern: "src/*/test.swift"))
        XCTAssertFalse(FilePatterns.matchesPath(path: "src/app/nested/test.swift", pattern: "src/*/test.swift"))
    }

    func testMatchesPathWithDoubleStar() {
        // ** matches zero or more path components
        XCTAssertTrue(FilePatterns.matchesPath(path: "instance/site1/content/uploads/image.php", pattern: "instance/*/content/**"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "instance/site2/content/doc.php", pattern: "instance/*/content/**"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "instance/site3/content/nested/deep/file.php", pattern: "instance/*/content/**"))

        // Should not match if path doesn't start with pattern prefix
        XCTAssertFalse(FilePatterns.matchesPath(path: "instance/config.php", pattern: "instance/*/content/**"))
        XCTAssertFalse(FilePatterns.matchesPath(path: "src/app.php", pattern: "instance/*/content/**"))
    }

    func testMatchesPathWithDoubleStarAtEnd() {
        // **/*.ext pattern
        XCTAssertTrue(FilePatterns.matchesPath(path: "src/app/File.generated.swift", pattern: "**/*.generated.*"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "tests/mocks/User.generated.swift", pattern: "**/*.generated.*"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "User.generated.swift", pattern: "**/*.generated.*"))

        XCTAssertFalse(FilePatterns.matchesPath(path: "src/User.swift", pattern: "**/*.generated.*"))
        XCTAssertFalse(FilePatterns.matchesPath(path: "src/generated.swift", pattern: "**/*.generated.*"))
    }

    func testMatchesPathWithDoubleStarDirectory() {
        // directory/** pattern
        XCTAssertTrue(FilePatterns.matchesPath(path: "database/factories/UserFactory.php", pattern: "database/factories/**"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "database/factories/nested/PostFactory.php", pattern: "database/factories/**"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "database/factories/deep/nested/CommentFactory.php", pattern: "database/factories/**"))

        XCTAssertFalse(FilePatterns.matchesPath(path: "database/migrations/001_create_users.php", pattern: "database/factories/**"))
        XCTAssertFalse(FilePatterns.matchesPath(path: "app/Models/User.php", pattern: "database/factories/**"))
    }

    func testMatchesPathMixedPatterns() {
        // Mixing * and **
        XCTAssertTrue(FilePatterns.matchesPath(path: "src/app/components/Button.test.tsx", pattern: "src/**/components/*.tsx"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "src/components/Button.tsx", pattern: "src/**/components/*.tsx"))
        XCTAssertFalse(FilePatterns.matchesPath(path: "tests/Button.tsx", pattern: "src/**/components/*.tsx"))
    }

    func testMatchesPathEdgeCases() {
        // Empty path
        XCTAssertFalse(FilePatterns.matchesPath(path: "", pattern: "*.swift"))

        // Root level file
        XCTAssertTrue(FilePatterns.matchesPath(path: "README.md", pattern: "*.md"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "README.md", pattern: "**/*.md"))

        // Pattern with no wildcards
        XCTAssertTrue(FilePatterns.matchesPath(path: "exact/path/file.txt", pattern: "exact/path/file.txt"))
        XCTAssertFalse(FilePatterns.matchesPath(path: "different/path/file.txt", pattern: "exact/path/file.txt"))

        // Multiple extensions
        XCTAssertTrue(FilePatterns.matchesPath(path: "app.min.js", pattern: "*.min.js"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "vendor.bundle.min.js", pattern: "*.min.js"))
    }

    func testMatchesPathSpecialCharacters() {
        // Dots in path
        XCTAssertTrue(FilePatterns.matchesPath(path: ".github/workflows/ci.yml", pattern: ".github/**"))

        // Hyphens and underscores
        XCTAssertTrue(FilePatterns.matchesPath(path: "src/my-component_v2.tsx", pattern: "src/*.tsx"))

        // Numbers
        XCTAssertTrue(FilePatterns.matchesPath(path: "migrations/001_initial.sql", pattern: "migrations/*.sql"))
    }

    func testMatchesPathPerformanceCritical() {
        // Test patterns that could cause regex backtracking
        let deepPath = "a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/file.txt"

        XCTAssertTrue(FilePatterns.matchesPath(path: deepPath, pattern: "a/**/file.txt"))
        XCTAssertTrue(FilePatterns.matchesPath(path: deepPath, pattern: "**/file.txt"))
        // Pattern that definitely won't match - different filename
        XCTAssertFalse(FilePatterns.matchesPath(path: deepPath, pattern: "z/**/other.txt"))
    }

    func testMatchesPathRealWorldPatterns() {
        // Real patterns from .yeetconfig examples

        // Laravel instance directories
        XCTAssertTrue(FilePatterns.matchesPath(path: "instance/site1/content/uploads/image.jpg", pattern: "instance/*/content/**"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "instance/production/content/cache/data.bin", pattern: "instance/*/content/**"))

        // Generated files
        XCTAssertTrue(FilePatterns.matchesPath(path: "app/Models/User.generated.php", pattern: "**/*.generated.*"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "database/schema/Schema.generated.ts", pattern: "**/*.generated.*"))

        // Test/mock files
        XCTAssertTrue(FilePatterns.matchesPath(path: "tests/mocks/api/UserResponse.json", pattern: "**/mocks/**"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "src/test/mocks/Database.php", pattern: "**/mocks/**"))

        // Build artifacts
        XCTAssertTrue(FilePatterns.matchesPath(path: "dist/assets/main.bundle.js", pattern: "dist/**"))
        XCTAssertTrue(FilePatterns.matchesPath(path: "build/output/app.min.css", pattern: "build/**"))
    }
}
