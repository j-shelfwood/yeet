import XCTest
@testable import YeetCore
import Foundation

final class GitDiscoveryTests: XCTestCase {
    var tempDir: URL!
    var gitDir: URL!

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
            .appendingPathComponent("git-discovery-tests-\(UUID().uuidString)")
            .standardizedFileURL  // Resolve symlinks (/var -> /private/var on macOS)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create .git directory to make it a git repo
        gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        // Initialize minimal git repo structure
        let objectsDir = gitDir.appendingPathComponent("objects")
        let refsDir = gitDir.appendingPathComponent("refs")
        try FileManager.default.createDirectory(at: objectsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: refsDir, withIntermediateDirectories: true)

        // Create HEAD file
        try "ref: refs/heads/main".write(to: gitDir.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Critical Bug Fix Tests (v1.1.0)

    func testExcludeDirectoriesRespectedInGitRepos() throws {
        // This tests the CRITICAL bug fix: GitDiscovery now respects configuration.excludeDirectories
        // Bug was: GitDiscovery only checked FilePatterns.excludedDirectories (static list)

        // Create directory structure
        let buildDir = tempDir.appendingPathComponent("build")
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        // Create tracked files
        let buildFile = buildDir.appendingPathComponent("output.js").standardizedFileURL
        let srcFile = srcDir.appendingPathComponent("app.swift").standardizedFileURL
        try "build content".write(to: buildFile, atomically: true, encoding: .utf8)
        try "src content".write(to: srcFile, atomically: true, encoding: .utf8)

        // Simulate git tracking both files (create mock .git/index or use git ls-files simulation)
        // For testing, we'll use actual git commands
        let gitInit = Process()
        gitInit.currentDirectoryURL = tempDir
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        try gitInit.run()
        gitInit.waitUntilExit()

        let gitAdd = Process()
        gitAdd.currentDirectoryURL = tempDir
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        try gitAdd.run()
        gitAdd.waitUntilExit()

        // Configure to exclude "build" directory
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.js", "*.swift"],  // Include patterns for our test files
            excludeDirectories: ["build"]  // User config excludes build
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        // Verify: build directory should be excluded even though git tracks it
        assertNotContainsFile(files, buildFile, "build/output.js should be excluded by configuration")
        assertContainsFile(files, srcFile, "src/app.swift should be included")
    }

    func testExcludePatternsRespectedInGitRepos() throws {
        // Test that exclude patterns work in git repos (v1.1.0 feature)

        // Create nested structure
        let instanceDir = tempDir.appendingPathComponent("instance/site1/content/uploads")
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: instanceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        let instanceFile = instanceDir.appendingPathComponent("image.php").standardizedFileURL
        let srcFile = srcDir.appendingPathComponent("app.php").standardizedFileURL
        try "instance content".write(to: instanceFile, atomically: true, encoding: .utf8)
        try "src content".write(to: srcFile, atomically: true, encoding: .utf8)

        // Initialize git and track files
        let gitInit = Process()
        gitInit.currentDirectoryURL = tempDir
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        try gitInit.run()
        gitInit.waitUntilExit()

        let gitAdd = Process()
        gitAdd.currentDirectoryURL = tempDir
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        try gitAdd.run()
        gitAdd.waitUntilExit()

        // Configure with exclude pattern
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.php"],  // Include PHP files
            excludePatterns: ["instance/*/content/**"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertNotContainsFile(files, instanceFile, "instance/site1/content/uploads/image.php should be excluded by pattern")
        assertContainsFile(files, srcFile, "src/app.php should be included")
    }

    func testCombinedExclusionsInGitRepos() throws {
        // Test that both exclude directories AND patterns work together

        // Create multiple directories
        let buildDir = tempDir.appendingPathComponent("build")
        let srcDir = tempDir.appendingPathComponent("src")
        let modelsDir = tempDir.appendingPathComponent("app/Models")
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        // Create various files
        let buildFile = buildDir.appendingPathComponent("app.js").standardizedFileURL
        let srcFile = srcDir.appendingPathComponent("index.ts").standardizedFileURL
        let generatedFile = modelsDir.appendingPathComponent("User.generated.php").standardizedFileURL
        let normalFile = modelsDir.appendingPathComponent("User.php").standardizedFileURL

        try "build".write(to: buildFile, atomically: true, encoding: .utf8)
        try "src".write(to: srcFile, atomically: true, encoding: .utf8)
        try "generated".write(to: generatedFile, atomically: true, encoding: .utf8)
        try "normal".write(to: normalFile, atomically: true, encoding: .utf8)

        // Initialize git
        let gitInit = Process()
        gitInit.currentDirectoryURL = tempDir
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        try gitInit.run()
        gitInit.waitUntilExit()

        let gitAdd = Process()
        gitAdd.currentDirectoryURL = tempDir
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        try gitAdd.run()
        gitAdd.waitUntilExit()

        // Configure with both exclude directories and patterns
        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.js", "*.ts", "*.php"],  // Include our test file types
            excludeDirectories: ["build"],
            excludePatterns: ["**/*.generated.*"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        // build/app.js excluded by directory
        assertNotContainsFile(files, buildFile, "build file should be excluded by directory")

        // User.generated.php excluded by pattern
        assertNotContainsFile(files, generatedFile, "generated file should be excluded by pattern")

        // These should be included
        assertContainsFile(files, srcFile, "src file should be included")
        assertContainsFile(files, normalFile, "normal model file should be included")
    }

    func testIncludePatternsInGitRepos() throws {
        // Test that include patterns work correctly in git repos

        // Create files with different extensions
        let swiftFile = tempDir.appendingPathComponent("app.swift").standardizedFileURL
        let tsFile = tempDir.appendingPathComponent("index.ts").standardizedFileURL
        let mdFile = tempDir.appendingPathComponent("README.md").standardizedFileURL

        try "swift".write(to: swiftFile, atomically: true, encoding: .utf8)
        try "ts".write(to: tsFile, atomically: true, encoding: .utf8)
        try "md".write(to: mdFile, atomically: true, encoding: .utf8)

        // Initialize git
        let gitInit = Process()
        gitInit.currentDirectoryURL = tempDir
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        try gitInit.run()
        gitInit.waitUntilExit()

        let gitAdd = Process()
        gitAdd.currentDirectoryURL = tempDir
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        try gitAdd.run()
        gitAdd.waitUntilExit()

        // Configure with include patterns (no need to change - already correct)
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

    func testGitRepoWithoutTrackedFiles() throws {
        // Test behavior when git repo exists but has no tracked files

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        // Should return empty array (no tracked files)
        XCTAssertEqual(files.count, 0, "Should find no files in empty git repo")
    }

    // MARK: - Subdirectory Scoping Tests (v1.5.1 bug fix)

    /// Running `yeet` (i.e. paths=["."] ) from a subdirectory inside a git repo must
    /// only return files under that subdirectory, NOT the entire repo.
    func testDotPathScopedToCurrentDirectory() throws {
        // Build repo:  root/subdir/file.swift  and  root/other/file.swift
        let subDir = tempDir.appendingPathComponent("subdir")
        let otherDir = tempDir.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: otherDir, withIntermediateDirectories: true)

        let subFile = subDir.appendingPathComponent("sub.swift").standardizedFileURL
        let otherFile = otherDir.appendingPathComponent("other.swift").standardizedFileURL
        try "sub".write(to: subFile, atomically: true, encoding: .utf8)
        try "other".write(to: otherFile, atomically: true, encoding: .utf8)

        let gitInit = Process(); gitInit.currentDirectoryURL = tempDir
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]; try gitInit.run(); gitInit.waitUntilExit()

        let gitAdd = Process(); gitAdd.currentDirectoryURL = tempDir
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]; try gitAdd.run(); gitAdd.waitUntilExit()

        // Simulate `yeet` run from inside subdir: paths=["."], cwd=subdir
        // FileDiscovery resolves "." against FileManager.currentDirectoryPath, so we
        // pass the subdir as an absolute path (equivalent to cwd="subdir" + path=".").
        let config = CollectorConfiguration(
            paths: [subDir.path],
            includePatterns: ["*.swift"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertContainsFile(files, subFile, "subdir/sub.swift should be included")
        assertNotContainsFile(files, otherFile, "other/other.swift must NOT be returned when scoped to subdir")
    }

    /// Passing an explicit subdirectory path (not ".") must also be scoped correctly.
    func testExplicitSubdirectoryPathScopedCorrectly() throws {
        let featureDir = tempDir.appendingPathComponent("feature")
        let sharedDir = tempDir.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: featureDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        let featureFile = featureDir.appendingPathComponent("Feature.swift").standardizedFileURL
        let sharedFile = sharedDir.appendingPathComponent("Shared.swift").standardizedFileURL
        try "feature".write(to: featureFile, atomically: true, encoding: .utf8)
        try "shared".write(to: sharedFile, atomically: true, encoding: .utf8)

        let gitInit = Process(); gitInit.currentDirectoryURL = tempDir
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]; try gitInit.run(); gitInit.waitUntilExit()

        let gitAdd = Process(); gitAdd.currentDirectoryURL = tempDir
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]; try gitAdd.run(); gitAdd.waitUntilExit()

        let config = CollectorConfiguration(
            paths: [featureDir.path],
            includePatterns: ["*.swift"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertContainsFile(files, featureFile, "feature/Feature.swift should be included")
        assertNotContainsFile(files, sharedFile, "shared/Shared.swift must NOT be returned")
    }

    /// Running `yeet` at the git root must still return ALL files (regression guard).
    func testRootScopeReturnsAllFiles() throws {
        let dirA = tempDir.appendingPathComponent("a")
        let dirB = tempDir.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)

        let fileA = dirA.appendingPathComponent("a.swift").standardizedFileURL
        let fileB = dirB.appendingPathComponent("b.swift").standardizedFileURL
        try "a".write(to: fileA, atomically: true, encoding: .utf8)
        try "b".write(to: fileB, atomically: true, encoding: .utf8)

        let gitInit = Process(); gitInit.currentDirectoryURL = tempDir
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]; try gitInit.run(); gitInit.waitUntilExit()

        let gitAdd = Process(); gitAdd.currentDirectoryURL = tempDir
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]; try gitAdd.run(); gitAdd.waitUntilExit()

        // paths = [repoRoot] — should return everything
        let config = CollectorConfiguration(
            paths: [tempDir.path],
            includePatterns: ["*.swift"]
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        assertContainsFile(files, fileA, "a/a.swift should be included when scoped to root")
        assertContainsFile(files, fileB, "b/b.swift should be included when scoped to root")
    }

    func testStaticExclusionsStillWork() throws {
        // Verify that static exclusions (node_modules, .git, etc.) still work

        let nodeModulesDir = tempDir.appendingPathComponent("node_modules")
        let srcDir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: nodeModulesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        let nodeFile = nodeModulesDir.appendingPathComponent("package.js").standardizedFileURL
        let srcFile = srcDir.appendingPathComponent("app.js").standardizedFileURL
        try "node".write(to: nodeFile, atomically: true, encoding: .utf8)
        try "src".write(to: srcFile, atomically: true, encoding: .utf8)

        // Initialize git
        let gitInit = Process()
        gitInit.currentDirectoryURL = tempDir
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["init"]
        try gitInit.run()
        gitInit.waitUntilExit()

        let gitAdd = Process()
        gitAdd.currentDirectoryURL = tempDir
        gitAdd.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitAdd.arguments = ["add", "."]
        try gitAdd.run()
        gitAdd.waitUntilExit()

        let config = CollectorConfiguration(
            paths: [tempDir.standardizedFileURL.path],
            includePatterns: ["*.js"]  // Include JS files
        )

        let discovery = FileDiscovery(configuration: config)
        let files = try discovery.discoverFiles()

        // node_modules should be excluded by static list
        assertNotContainsFile(files, nodeFile, "node_modules should be excluded by static list")
        assertContainsFile(files, srcFile, "src file should be included")
    }
}
