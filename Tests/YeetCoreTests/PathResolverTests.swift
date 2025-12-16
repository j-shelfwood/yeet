import XCTest
@testable import YeetCore
import Foundation

final class PathResolverTests: XCTestCase {
    var tempDir: URL!
    let resolver = PathResolver()

    override func setUp() async throws {
        // Create temp directory
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yeet-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test files
        let testFile1 = tempDir.appendingPathComponent("test.swift")
        let testFile2 = tempDir.appendingPathComponent("test.ts")
        let subdir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let testFile3 = subdir.appendingPathComponent("app.ts")

        try "content1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "content2".write(to: testFile2, atomically: true, encoding: .utf8)
        try "content3".write(to: testFile3, atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testSimpleGlobPattern() throws {
        let pattern = tempDir.path + "/*.swift"
        let results = try resolver.expandGlob(pattern)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].lastPathComponent == "test.swift")
    }

    func testMultipleFilesGlob() throws {
        let pattern = tempDir.path + "/*.ts"
        let results = try resolver.expandGlob(pattern)

        XCTAssertEqual(results.count, 1, "Should find test.ts in root, got: \(results.map { $0.lastPathComponent })")
        if results.count > 0 {
            XCTAssertTrue(results[0].lastPathComponent == "test.ts")
        }
    }

    func testWildcardInMiddle() throws {
        let pattern = tempDir.path + "/src/*.ts"
        let results = try resolver.expandGlob(pattern)

        XCTAssertEqual(results.count, 1, "Should find app.ts in src/")
        XCTAssertTrue(results[0].lastPathComponent == "app.ts")
    }
}
