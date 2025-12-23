import XCTest
@testable import YeetCore
import Foundation

final class DirectoryWalkerTests: XCTestCase {
    var tempDir: URL!

    /// Helper to check if discovered files contain expected file (handles symlink differences)
    private func assertContainsFile(_ files: [URL], _ expectedFile: URL, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        let canonicalFiles = Set(files.map { URL(fileURLWithPath: $0.path).resolvingSymlinksInPath() })
        let canonicalExpected = URL(fileURLWithPath: expectedFile.path).resolvingSymlinksInPath()
        XCTAssertTrue(canonicalFiles.contains(canonicalExpected), message, file: file, line: line)
    }

    /// Helper to check if discovered files do NOT contain expected file (handles symlink differences)
    private func assertNotContainsFile(_ files: [URL], _ expectedFile: URL, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        let canonicalFiles = Set(files.map { URL(fileURLWithPath: $0.path).resolvingSymlinksInPath() })
        let canonicalExpected = URL(fileURLWithPath: expectedFile.path).resolvingSymlinksInPath()
        XCTAssertFalse(canonicalFiles.contains(canonicalExpected), message, file: file, line: line)
    }

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("directory-walker-tests-\(UUID().uuidString)")
            .standardizedFileURL  // Resolve symlinks (/var -> /private/var on macOS)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Do NOT create .git directory - DirectoryWalker is for non-git paths
    }

    override func tearDown() async throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Exclude Directory Tests

    func testExcludeDirectoriesInNonGitRepos() throws {
        // DirectoryWalker should also respect exclude directories configuration

        let buildDir = tempDir.appendingPathComponent("build")
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        let buildFile = buildDir.appendingPathComponent("output.js").standardizedFileURL
        let srcFile = srcDir.appendingPathComponent("app.swift").standardizedFileURL
        try "build content".write(to: buildFile, atomically: true, encoding: .utf8)
        try "src content".write(to: srcFile, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.js", "*.swift"],  // Include our test file types
            excludeDirectories: ["build"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertNotContainsFile(files, buildFile, "build directory should be excluded")
        assertContainsFile(files, srcFile, "src file should be included")
    }

    func testExcludePatternsInNonGitRepos() throws {
        // DirectoryWalker should respect exclude patterns

        let instanceDir = tempDir.appendingPathComponent("instance/site1/content/uploads")
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: instanceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        let instanceFile = instanceDir.appendingPathComponent("image.php").standardizedFileURL
        let srcFile = srcDir.appendingPathComponent("app.php").standardizedFileURL
        try "instance content".write(to: instanceFile, atomically: true, encoding: .utf8)
        try "src content".write(to: srcFile, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.php"],
            excludePatterns: ["instance/*/content/**"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertNotContainsFile(files, instanceFile, "instance/*/content/** should be excluded")
        assertContainsFile(files, srcFile, "src file should be included")
    }

    func testCombinedExclusionsInNonGitRepos() throws {
        // Test both directory and pattern exclusions work together

        let buildDir = tempDir.appendingPathComponent("build")
        let srcDir = tempDir.appendingPathComponent("src")
        let modelsDir = tempDir.appendingPathComponent("app/Models")
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let buildFile = buildDir.appendingPathComponent("app.js").standardizedFileURL
        let srcFile = srcDir.appendingPathComponent("index.ts").standardizedFileURL
        let generatedFile = modelsDir.appendingPathComponent("User.generated.php").standardizedFileURL
        let normalFile = modelsDir.appendingPathComponent("User.php").standardizedFileURL

        try "build".write(to: buildFile, atomically: true, encoding: .utf8)
        try "src".write(to: srcFile, atomically: true, encoding: .utf8)
        try "generated".write(to: generatedFile, atomically: true, encoding: .utf8)
        try "normal".write(to: normalFile, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.js", "*.ts", "*.php"],
            excludeDirectories: ["build"],
            excludePatterns: ["**/*.generated.*"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertNotContainsFile(files, buildFile, "build file should be excluded by directory")
        assertNotContainsFile(files, generatedFile, "generated file should be excluded by pattern")
        assertContainsFile(files, srcFile, "src file should be included")
        assertContainsFile(files, normalFile, "normal file should be included")
    }

    func testIncludePatternsInNonGitRepos() throws {
        // Test include patterns work in directory walking

        let swiftFile = tempDir.appendingPathComponent("app.swift").standardizedFileURL
        let tsFile = tempDir.appendingPathComponent("index.ts").standardizedFileURL
        let mdFile = tempDir.appendingPathComponent("README.md").standardizedFileURL

        try "swift".write(to: swiftFile, atomically: true, encoding: .utf8)
        try "ts".write(to: tsFile, atomically: true, encoding: .utf8)
        try "md".write(to: mdFile, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.swift", "*.ts"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertContainsFile(files, swiftFile, "Swift file should be included")
        assertContainsFile(files, tsFile, "TS file should be included")
        assertNotContainsFile(files, mdFile, "MD file should not be included")
    }

    func testStaticExclusionsInNonGitRepos() throws {
        // Verify static exclusions (node_modules, .git, etc.) work

        let nodeModulesDir = tempDir.appendingPathComponent("node_modules")
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: nodeModulesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        let nodeFile = nodeModulesDir.appendingPathComponent("package.js").standardizedFileURL
        let srcFile = srcDir.appendingPathComponent("app.js").standardizedFileURL
        try "node".write(to: nodeFile, atomically: true, encoding: .utf8)
        try "src".write(to: srcFile, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.php", "*.swift", "*.js", "*.ts", "*.json", "*.md", "*.txt", "*.sql", "*.yml"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertNotContainsFile(files, nodeFile, "node_modules should be excluded")
        assertContainsFile(files, srcFile, "src file should be included")
    }

    func testNestedDirectories() throws {
        // Test walking deeply nested directory structures

        let deepDir = tempDir.appendingPathComponent("level1/level2/level3/level4")
        try FileManager.default.createDirectory(at: deepDir, withIntermediateDirectories: true)

        let deepFile = deepDir.appendingPathComponent("deep.swift").standardizedFileURL
        try "deep content".write(to: deepFile, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.swift"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertContainsFile(files, deepFile, "Should find deeply nested files")
    }

    func testEmptyDirectory() throws {
        // Test behavior with empty directory

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.php", "*.swift", "*.js", "*.ts", "*.json", "*.md", "*.txt", "*.sql", "*.yml"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        XCTAssertEqual(files.count, 0, "Empty directory should return no files")
    }

    func testSymbolicLinks() throws {
        // Test that symbolic links are handled properly

        let realDir = tempDir.appendingPathComponent("real")
        let linkDir = tempDir.appendingPathComponent("link")
        try FileManager.default.createDirectory(at: realDir, withIntermediateDirectories: true)

        let realFile = realDir.appendingPathComponent("file.swift").standardizedFileURL
        try "content".write(to: realFile, atomically: true, encoding: .utf8)

        // Create symbolic link
        try FileManager.default.createSymbolicLink(at: linkDir, withDestinationURL: realDir)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.swift"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        // Should find the file (may find it once or twice depending on symlink handling)
        XCTAssertGreaterThan(files.count, 0, "Should find files through directory walking")
    }

    func testHiddenFiles() throws {
        // Test handling of hidden files (starting with .)

        let normalFile = tempDir.appendingPathComponent("normal.swift").standardizedFileURL
        let hiddenFile = tempDir.appendingPathComponent(".hidden.swift").standardizedFileURL

        try "normal".write(to: normalFile, atomically: true, encoding: .utf8)
        try "hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.swift"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertContainsFile(files, normalFile, "Should find normal files")
        // Hidden files behavior depends on implementation - just verify it doesn't crash
        XCTAssertGreaterThan(files.count, 0, "Should find at least normal file")
    }

    func testLargeNumberOfFiles() throws {
        // Test performance with many files

        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        // Create 100 files
        for i in 0..<100 {
            let file = srcDir.appendingPathComponent("file\(i).swift")
            try "content \(i)".write(to: file, atomically: true, encoding: .utf8)
        }

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.swift"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        XCTAssertEqual(files.count, 100, "Should find all 100 files")
    }

    func testMultipleRootPaths() throws {
        // Test discovering files from multiple root directories

        let dir1 = tempDir.appendingPathComponent("dir1")
        let dir2 = tempDir.appendingPathComponent("dir2")
        try FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)

        let file1 = dir1.appendingPathComponent("app1.swift").standardizedFileURL
        let file2 = dir2.appendingPathComponent("app2.swift").standardizedFileURL
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)

        let config = CollectorConfiguration(
            paths: [dir1.standardizedFileURL.path, dir2.standardizedFileURL.path],
            includePatterns: ["*.swift"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertContainsFile(files, file1, "Should find file in first path")
        assertContainsFile(files, file2, "Should find file in second path")
        XCTAssertEqual(files.count, 2, "Should find files from both paths")
    }
}
