# Changelog

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
