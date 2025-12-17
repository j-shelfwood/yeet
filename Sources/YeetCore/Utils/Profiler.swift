import Foundation

/// Lightweight compile-time profiling utility for measuring performance
///
/// Provides simple timing instrumentation for hot paths without external
/// profiler dependencies. Outputs to stderr to avoid interfering with stdout.
///
/// Usage:
/// ```swift
/// Profiler.start("MyOperation")
/// // ... do work ...
/// Profiler.end("MyOperation")  // Prints: ⏱️ [MyOperation]: 0.1234s
///
/// // Or use measure for automatic cleanup:
/// let result = try Profiler.measure("MyOperation") {
///     // ... do work ...
///     return value
/// }
/// ```
public struct Profiler {
    /// Thread-safe storage for timing marks
    /// NSLock provides synchronization, so we can safely use nonisolated(unsafe)
    private static nonisolated(unsafe) var marks: [String: CFAbsoluteTime] = [:]
    private static let lock = NSLock()

    /// Record the start time for a labeled operation
    ///
    /// - Parameter label: Unique identifier for this timing measurement
    public static func start(_ label: String) {
        lock.lock()
        marks[label] = CFAbsoluteTimeGetCurrent()
        lock.unlock()
    }

    /// Record the end time and print duration for a labeled operation
    ///
    /// - Parameter label: Identifier matching a previous start() call
    public static func end(_ label: String) {
        lock.lock()
        defer { lock.unlock() }

        guard let startTime = marks[label] else { return }
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Print to stderr so it doesn't interfere with stdout piping
        fputs("⏱️ [\(label)]: \(String(format: "%.4f", duration))s\n", stderr)
        marks.removeValue(forKey: label)
    }

    /// Measure a synchronous block of code
    ///
    /// Automatically starts timing, executes the block, and prints the duration.
    ///
    /// - Parameters:
    ///   - label: Identifier for this measurement
    ///   - block: Code to measure
    /// - Returns: The return value of the block
    /// - Throws: Re-throws any error from the block
    public static func measure<T>(_ label: String, block: () throws -> T) rethrows -> T {
        start(label)
        defer { end(label) }
        return try block()
    }

    /// Measure an asynchronous block of code
    ///
    /// Automatically starts timing, executes the async block, and prints the duration.
    ///
    /// - Parameters:
    ///   - label: Identifier for this measurement
    ///   - block: Async code to measure
    /// - Returns: The return value of the block
    /// - Throws: Re-throws any error from the block
    public static func measureAsync<T>(_ label: String, block: () async throws -> T) async rethrows -> T {
        start(label)
        defer { end(label) }
        return try await block()
    }
}
