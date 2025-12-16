import Foundation

/// Default file patterns and exclusions based on copy_context.py
public enum FilePatterns {
    // MARK: - Default Include Patterns

    public static let defaultPatterns: Set<String> = [
        // Web
        "*.ts", "*.js", "*.mjs", "*.jsx", "*.tsx",
        "*.html", "*.htm", "*.css", "*.scss", "*.sass", "*.less",
        "*.vue", "*.svelte", "*.astro",

        // Backend
        "*.php", "*.blade.php",
        "*.py", "*.pyi",
        "*.rb", "*.erb",
        "*.java", "*.kt", "*.kts",
        "*.cs", "*.vb",
        "*.go",

        // Systems
        "*.sh", "*.bash", "*.zsh",
        "*.c", "*.cpp", "*.cxx", "*.cc", "*.h", "*.hpp",
        "*.rs",
        "*.swift",
        "*.lua",

        // Markup & Config
        "*.md", "*.mdx", "*.markdown",
        "*.json", "*.jsonc", "*.json5",
        "*.yaml", "*.yml",
        "*.toml",
        "*.xml",
        "*.ini", "*.conf", "*.cfg",

        // Shaders
        "*.glsl", "*.vsh", "*.fsh", "*.shader",

        // Build
        "Makefile", "makefile",
        "Dockerfile", "dockerfile",
        "*.cmake", "CMakeLists.txt",
        "*.gradle",

        // Unity
        "*.unity", "*.meta", "*.asset", "*.prefab",
    ]

    // MARK: - Excluded Directories

    public static let excludedDirectories: Set<String> = [
        // Dependencies
        "node_modules", "vendor", "bower_components",

        // Build artifacts
        "build", ".build", "dist", "out",
        "target", "bin", "obj",

        // Version control
        ".git", ".svn", ".hg",

        // Environments
        "venv", ".venv", "env", ".env",
        "virtualenv", ".virtualenv",

        // Storage
        "storage", "public/storage",

        // Unity
        "Library", "Temp", "Obj",

        // IDE
        ".idea", ".vscode", ".vs",

        // Cache
        "__pycache__", ".cache", ".pytest_cache",
        ".mypy_cache", ".ruff_cache",
    ]

    // MARK: - Ignored Extensions

    public static let ignoredExtensions: Set<String> = [
        // Archives
        "zip", "tar", "gz", "bz2", "xz", "rar", "7z",

        // Executables
        "exe", "bin", "dll", "so", "dylib",

        // Compiled
        "pyc", "pyo", "class", "o", "a", "jar", "war",

        // Media
        "png", "jpg", "jpeg", "gif", "bmp", "svg", "ico",
        "mp3", "mp4", "avi", "mov", "wav",

        // Fonts
        "woff", "woff2", "ttf", "otf", "eot",

        // Databases
        "db", "sqlite", "sqlite3",

        // Logs
        "log",
    ]

    // MARK: - Low Value Patterns (token budget limits)

    public static let lowValuePatterns: [String: Int] = [
        "*.lock": 500,
        "*-lock.json": 500,
        "*.resolved": 500,
        "*mock*.xml": 1000,
        "*mock*.json": 1000,
        "*api*.json": 2000,
        "*-api-*.md": 2000,
        "*.min.*": 0,  // Skip minified files entirely
    ]

    // MARK: - Pattern Matching

    /// Check if a file name matches a glob pattern
    public static func matches(fileName: String, pattern: String) -> Bool {
        // Convert glob pattern to regex
        var regexPattern = "^"

        for char in pattern {
            switch char {
            case "*":
                regexPattern += ".*"
            case "?":
                regexPattern += "."
            case ".":
                regexPattern += "\\."
            case "+", "[", "]", "(", ")", "{", "}", "^", "$", "|", "\\":
                regexPattern += "\\\(char)"
            default:
                regexPattern += String(char)
            }
        }

        regexPattern += "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return false
        }

        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
        return regex.firstMatch(in: fileName, options: [], range: range) != nil
    }

    /// Check if a path should be excluded
    public static func isExcluded(path: String) -> Bool {
        let components = path.split(separator: "/").map(String.init)
        return components.contains { excludedDirectories.contains($0) }
    }

    /// Get maximum token limit for a file based on patterns
    public static func getTokenLimit(for fileName: String, defaultLimit: Int) -> Int {
        for (pattern, limit) in lowValuePatterns {
            if matches(fileName: fileName, pattern: pattern) {
                return limit
            }
        }
        return defaultLimit
    }
}
