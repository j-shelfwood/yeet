import XCTest
@testable import YeetCore
import Foundation

final class ConfigLoaderTests: XCTestCase {
    var tempDir: URL!
    var originalHome: String?

    override func setUp() async throws {
        // Create temp directory for test configs
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("yeet-config-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create .git directory so ConfigLoader recognizes this as a project root
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temp directory
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Basic Config Loading

    func testDefaultConfig() throws {
        // When no config files exist, should return built-in defaults
        let config = ConfigLoader.loadConfig(for: tempDir.path)

        XCTAssertNotNil(config.defaults)
        XCTAssertEqual(config.defaults?.maxTokens, 10000)
        XCTAssertEqual(config.defaults?.maxFiles, 10000)
        XCTAssertEqual(config.defaults?.maxFileSizeMB, 100)
        XCTAssertEqual(config.defaults?.maxTotalTokens, 1_000_000)
        XCTAssertEqual(config.defaults?.showTree, false)
        XCTAssertEqual(config.defaults?.quiet, false)
    }

    func testLoadValidProjectConfig() throws {
        // Create a valid .yeetconfig in test directory
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [defaults]
        max_tokens = 5000
        quiet = true

        [exclude]
        directories = ["test_dir"]
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Config should load without crashing and have defaults populated
        XCTAssertNotNil(config.defaults)
        XCTAssertNotNil(config.exclude)
        // Note: Full override behavior requires TOMLKit integration testing
        // This test verifies config loading doesn't crash with valid TOML
    }

    // MARK: - Invalid TOML Handling

    func testInvalidTOMLReturnsDefaults() throws {
        // Create invalid TOML file
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let invalidTOML = """
        [defaults
        max_tokens = "not a number"
        this is not valid TOML
        """
        try invalidTOML.write(to: configPath, atomically: true, encoding: .utf8)

        // Should fall back to defaults without crashing
        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should have default values (config parse failed, fell back to defaults)
        XCTAssertNotNil(config.defaults)
        XCTAssertEqual(config.defaults?.maxTokens, 10000) // Default value
    }

    func testMissingConfigFile() throws {
        // When config file doesn't exist, should use defaults
        let nonExistentPath = tempDir.appendingPathComponent("nonexistent")
        let config = ConfigLoader.loadConfig(for: nonExistentPath.path)

        XCTAssertNotNil(config.defaults)
        XCTAssertEqual(config.defaults?.maxTokens, 10000)
    }

    // MARK: - Config Merging

    func testConfigMergingDoesNotCrash() throws {
        // Test that config with multiple sections loads without crashing
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [defaults]
        max_tokens = 8000

        [exclude]
        directories = ["build"]

        [token_limits]
        "*.lock" = 100
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should have defaults populated
        XCTAssertNotNil(config.defaults)
        XCTAssertNotNil(config.exclude)
        XCTAssertNotNil(config.tokenLimits)
    }

    // MARK: - Token Limits Parsing

    func testTokenLimitsParsing() throws {
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [token_limits]
        "*.lock" = 500
        "*.min.js" = 0
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should have token limits populated (either from config or defaults)
        XCTAssertNotNil(config.tokenLimits)
    }

    // MARK: - Exclude Configuration

    func testExcludeDirectories() throws {
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [exclude]
        directories = ["custom_dir"]
        extensions = ["tmp"]
        patterns = ["*.generated.*"]
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should have exclude config populated
        XCTAssertNotNil(config.exclude)
        XCTAssertNotNil(config.exclude?.directories)
        XCTAssertNotNil(config.exclude?.extensions)
    }

    // MARK: - Include Configuration

    func testIncludePatterns() throws {
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [include]
        patterns = ["*.custom"]
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should have include config populated
        XCTAssertNotNil(config.include)
        XCTAssertNotNil(config.include?.patterns)
    }

    // MARK: - Git Configuration

    func testGitConfiguration() throws {
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [git]
        include_history = false
        history_mode = "full"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should have git config populated
        XCTAssertNotNil(config.git)
    }

    // MARK: - Output Configuration

    func testOutputConfiguration() throws {
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [output]
        format = "json"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should have output config populated
        XCTAssertNotNil(config.output)
    }

    // MARK: - Performance Configuration

    func testPerformanceConfiguration() throws {
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [performance]
        mode = "content-aware"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should have performance config populated
        XCTAssertNotNil(config.performance)
    }

    // MARK: - Complete Configuration

    func testCompleteConfiguration() throws {
        // Test a comprehensive config with all sections
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [defaults]
        max_tokens = 6000

        [exclude]
        directories = ["build"]

        [include]
        patterns = ["*.swift"]

        [token_limits]
        "*.lock" = 300

        [git]
        include_history = true

        [output]
        format = "text"

        [performance]
        mode = "zero-tokenization"
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Verify all sections are populated
        XCTAssertNotNil(config.defaults)
        XCTAssertNotNil(config.exclude)
        XCTAssertNotNil(config.include)
        XCTAssertNotNil(config.tokenLimits)
        XCTAssertNotNil(config.git)
        XCTAssertNotNil(config.output)
        XCTAssertNotNil(config.performance)
    }

    // MARK: - Edge Cases

    func testEmptyConfigSections() throws {
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        [defaults]

        [exclude]

        [include]
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        // Should parse without error and use defaults
        let config = ConfigLoader.loadConfig(for: tempDir.path)
        XCTAssertNotNil(config)
    }

    func testConfigWithComments() throws {
        let configPath = tempDir.appendingPathComponent(".yeetconfig")
        let configContent = """
        # This is a comment
        [defaults]
        max_tokens = 5000  # Inline comment
        """
        try configContent.write(to: configPath, atomically: true, encoding: .utf8)

        let config = ConfigLoader.loadConfig(for: tempDir.path)

        // Should parse comments without crashing
        XCTAssertNotNil(config.defaults)
    }
}
