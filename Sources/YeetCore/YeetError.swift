import Foundation

/// Errors that can occur during context collection
public enum YeetError: LocalizedError {
    case clipboardFailed
    case unsupportedPlatform
    case invalidPath(String)
    case tokenizerNotFound
    case gitCommandFailed(String)
    case fileReadError(String)
    case tooManyFiles(found: Int, limit: Int)
    case fileTooLarge(path: String, size: Int, limit: Int)
    case tooManyTokens(total: Int, limit: Int)

    public var errorDescription: String? {
        switch self {
        case .clipboardFailed:
            return "Failed to copy output to clipboard"
        case .unsupportedPlatform:
            return "Clipboard operations are only supported on macOS"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .tokenizerNotFound:
            return "Tokenizer encoding file not found"
        case .gitCommandFailed(let message):
            return "Git command failed: \(message)"
        case .fileReadError(let path):
            return "Failed to read file: \(path)"
        case .tooManyFiles(let found, let limit):
            return "Too many files discovered: \(found). Maximum is \(limit)."
        case .fileTooLarge(let path, let size, let limit):
            let sizeMB = size / 1024 / 1024
            let limitMB = limit / 1024 / 1024
            return "File too large: \(path) (\(sizeMB)MB). Maximum is \(limitMB)MB."
        case .tooManyTokens(let total, let limit):
            return "Total tokens (\(total)) exceeds limit of \(limit)."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .tooManyFiles:
            return "Try filtering with --type or --include patterns, or increase limit with --max-files."
        case .fileTooLarge:
            return "Skip large files with exclusion patterns or increase limit with --max-file-size."
        case .tooManyTokens:
            return "Reduce --max-tokens per file or filter to fewer files."
        default:
            return nil
        }
    }
}
