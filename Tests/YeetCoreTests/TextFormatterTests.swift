import XCTest
@testable import YeetCore

final class TextFormatterTests: XCTestCase {

    // MARK: - Summary Formatting Tests

    func testFormatSummaryContainsTokenCount() {
        let summary = TextFormatter.formatSummary(
            fileCount: 42,
            totalTokens: 12345
        )

        XCTAssertTrue(summary.contains("Total files: 42"), "Summary should contain file count")
        XCTAssertTrue(summary.contains("Total tokens (approx): 12345"), "Summary should contain token count")
        XCTAssertTrue(summary.contains("SUMMARY"), "Summary should contain SUMMARY header")
    }

    func testFormatSummaryWithZeroTokens() {
        let summary = TextFormatter.formatSummary(
            fileCount: 0,
            totalTokens: 0
        )

        XCTAssertTrue(summary.contains("Total files: 0"), "Summary should show 0 files")
        XCTAssertTrue(summary.contains("Total tokens (approx): 0"), "Summary should show 0 tokens for empty collection")
    }

    func testFormatSummaryWithLargeNumbers() {
        let summary = TextFormatter.formatSummary(
            fileCount: 1234,
            totalTokens: 9876543
        )

        XCTAssertTrue(summary.contains("Total files: 1234"), "Summary should handle large file counts")
        XCTAssertTrue(summary.contains("Total tokens (approx): 9876543"), "Summary should handle large token counts")
    }

    // MARK: - File List Formatting Tests

    func testFormatFileListWithMultipleFiles() {
        let files = [
            FileContent(path: "test1.swift", content: "content1", tokenCount: 100, originalTokenCount: 100, wasTruncated: false),
            FileContent(path: "test2.swift", content: "content2", tokenCount: 200, originalTokenCount: 200, wasTruncated: false)
        ]

        let list = TextFormatter.formatFileList(files: files)

        XCTAssertTrue(list.contains("test1.swift"), "List should contain first file")
        XCTAssertTrue(list.contains("test2.swift"), "List should contain second file")
        XCTAssertTrue(list.contains("100 tokens"), "List should show first file token count")
        XCTAssertTrue(list.contains("200 tokens"), "List should show second file token count")
        XCTAssertTrue(list.contains("Total: 2 files"), "List should show total file count")
    }

    func testFormatFileListWithTruncatedFiles() {
        let files = [
            FileContent(path: "large.swift", content: "truncated", tokenCount: 500, originalTokenCount: 1000, wasTruncated: true)
        ]

        let list = TextFormatter.formatFileList(files: files)

        XCTAssertTrue(list.contains("large.swift"), "List should contain file name")
        XCTAssertTrue(list.contains("[TRUNCATED]"), "List should indicate truncation")
    }
}
