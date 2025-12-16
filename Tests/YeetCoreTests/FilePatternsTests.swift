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
}
