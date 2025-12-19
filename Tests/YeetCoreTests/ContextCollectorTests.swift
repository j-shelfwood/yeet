import XCTest
@testable import YeetCore

final class ContextCollectorTests: XCTestCase {
    func testBasicCollection() async throws {
        // Arrange
        let config = CollectorConfiguration(
            paths: ["."],
            maxTokens: 5000
        )
        let collector = ContextCollector(configuration: config)

        // Act
        let result = try await collector.collect()

        // Assert
        XCTAssertGreaterThanOrEqual(result.fileCount, 0)
        XCTAssertGreaterThanOrEqual(result.totalTokens, 0)
    }

    func testConfigurationDefaults() {
        // Arrange & Act
        let config = CollectorConfiguration(paths: ["."])

        // Assert
        XCTAssertEqual(config.maxTokens, 10000)
        XCTAssertEqual(config.historyMode, "summary")
        XCTAssertEqual(config.historyCount, 5)
        XCTAssertFalse(config.diffMode)
        XCTAssertTrue(config.includeHistory)
    }
}
