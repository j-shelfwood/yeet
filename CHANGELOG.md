# Changelog

## [1.2.1] - 2025-12-28

### Fixed
- **CRITICAL**: Summary token count displaying 0 instead of actual value
  - ContextCollector.swift:131 passed hardcoded `totalTokens: 0` to formatter
  - Zero-tokenization optimization calculated tokens AFTER formatting output
  - Output string never updated with correct token count
  - Summary now correctly displays actual token count (e.g., 457923 instead of 0)
  - Added regression test: testSummaryDisplaysCorrectTokenCount()
  - Added 6 unit tests for TextFormatter output validation
- **CRITICAL**: --stats-by-dir segmentation fault (affects 100% of users attempting feature)
  - TextFormatter.swift:216 used `%-30s` format with Swift String (expects C string pointer)
  - TextFormatter.swift:94 used `%s` format with Swift String in budget display
  - Both instances replaced with `%@` format specifier and manual padding
  - Feature now fully operational without crashes
- **Directory grouping logic enhanced**
  - Added common path prefix detection for meaningful directory grouping
  - Previously grouped all files under "Users/" for absolute paths
  - Now correctly groups by project directories (app/, domain/, Infrastructure/, etc.)
  - Shows accurate token distribution across actual codebase structure

### Technical Details
- Token count fix: Split summary generation - format content → count → append summary
- Added OutputFormatter.formatTextWithoutSummary() for content-only formatting
- Made CollectionResult.output public for test verification
- Root cause (segfault): Swift String.format() delegates to NSString/CoreFoundation
- Format specifier %s expects UnsafePointer<Int8> (C string), not Swift String
- Passing Swift String to %s causes SIGSEGV (Segmentation fault: 11)
- Fix: Use %@ for Swift String objects with manual padding via String.padding()
- Added findCommonPathPrefix() helper for relative path extraction

## [1.2.0] - 2025-12-23

### Added
- **Per-file token limit configuration system**
  - Filename-based patterns: `"*.lock" = 500`, `"package-lock.json" = 400`
  - Path-based patterns with recursive matching: `"database/migrations/**" = 800`
  - Combined patterns: `"tests/**/*.spec.ts" = 1000`
  - Special value: `limit = 0` to skip files entirely
  - Full documentation in README.md Token Limits section
- **Performance mode infrastructure**
  - `[performance]` section in .yeetconfig
  - `mode = "zero-tokenization"` (default) or `"content-aware"`
  - Foundation for future optimization features
- **Automated Homebrew release pipeline**
  - Formula updates now fully automated on tag push
  - Eliminates manual SHA256 calculation and cross-repo syncing
  - 5-10 minute time savings per release

### Fixed
- **CRITICAL**: Per-file token limits now apply correctly
  - FileProcessor was ignoring tokenLimits configuration
  - Token limits always used global maxTokens regardless of patterns
  - Now properly applies custom limits based on filename/path patterns
- **Token limit pattern matching enhanced**
  - Added relative path normalization for accurate matching
  - Path patterns checked before filename patterns
  - Suffix matching for flexible pattern resolution

### Tests
- Added 7 new integration tests (100/100 passing)
- TokenLimitsTests suite covering:
  - Filename pattern matching (`*-lock.json`)
  - Path-based patterns (`database/migrations/**`)
  - Pattern priority rules
  - Edge cases and fallback behavior

## [1.1.0] - 2025-12-23

### Fixed
- **CRITICAL**: GitDiscovery now respects `.yeetconfig` exclude directories (affects 99% of users)
  - Git repositories were only checking static exclusions, ignoring user configuration
  - Configuration.excludeDirectories now properly applied in git repos
- **CRITICAL**: Exclude patterns now work correctly
  - `.yeetconfig` [exclude] patterns were parsed but never applied
  - Added full glob pattern support with `**` for recursive matching
  - Patterns like `instance/*/content/**` now properly exclude files
- **CRITICAL**: --stats flag now shows actual token counts
  - Was showing 0 tokens for all files due to zero-tokenization architecture
  - Added optional per-file tokenization when --stats requested
  - No performance impact when --stats not used

### Added
- `--stats` flag for per-file token analysis
  - Shows top 20 files by token count
  - Displays truncation markers and original counts
  - Helps identify optimization targets
- `--stats-by-dir` flag for directory-level aggregation
  - Groups files by top-level directory
  - Shows token distribution percentages
  - Displays truncation counts per directory
- Enhanced summary statistics
  - Beautiful box-drawing UI
  - File truncation count and percentage
  - Token usage with budget compliance indicators (✓/⚠️)
  - Original tokens → saved tokens calculation
  - Largest/average/median file statistics
  - Optimization tips when over budget
- Glob pattern exclusions with `**` support
  - `instance/*/content/**` excludes all content subdirectories
  - `database/factories/**` excludes entire directory trees
  - Full path-based pattern matching

### Changed
- TruncationStrategy now returns metadata (tokenCount, originalTokenCount, wasTruncated)
- FileProcessor supports optional per-file tokenization
- CollectorConfiguration includes enableTokenCounting parameter

### Performance
- Zero-tokenization architecture maintained when --stats not used
- Optional tokenization only when user requests statistics
- No breaking changes to existing workflows

## [1.0.1] - 2024-12-20

### Fixed
- .yeetconfig loading bug in certain directory structures

## [1.0.0] - 2024-12-19

### Added
- Initial release with complete configuration system
- Git integration with history support
- Token-based truncation with pattern matching
- Zero-tokenization performance optimization
