//
//  URLValidationLogger.swift
//  steam
//

import Foundation

/// Service for logging custom stream URLs added by users.
/// Provides audit trail with timestamps for security monitoring.
///
/// Actor-isolated instead of the old `DispatchQueue(attributes: .concurrent)` +
/// barrier pattern, so concurrent writers can't interleave into the log file.
/// Not `ObservableObject` — it never published any state for views to observe,
/// that conformance was vestigial.
actor URLValidationLogger {

    private let logFilePath: String
    private let fileManager = FileManager.default
    private let dateFormatter = ISO8601DateFormatter()

    // MARK: - Initialization

    /// Initializes the logger with a file path.
    /// - Parameter logFilePath: Path where logs will be written. Defaults to app's Documents directory.
    init(logFilePath: String? = nil) {
        if let customPath = logFilePath {
            self.logFilePath = customPath
        } else {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logPath = documentsPath.appendingPathComponent("url-validation-logs.txt")
            self.logFilePath = logPath.path
        }
    }

    // MARK: - Public Methods

    /// Logs a custom URL added by the user with a timestamp.
    /// - Parameters:
    ///   - url: The URL being added
    ///   - title: The display title for the stream
    func logCustomURL(_ url: String, title: String) {
        writeLog(url: url, title: title)
    }

    /// Retrieves all logged URLs.
    /// - Returns: Array of log entries as strings
    func getAllLogs() -> [String] {
        readLogs()
    }

    /// Clears all logged URLs (use with caution).
    func clearLogs() {
        try? fileManager.removeItem(atPath: logFilePath)
    }

    // MARK: - Private Methods

    private func writeLog(url: String, title: String) {
        ensureLogFileExists()

        let timestamp = dateFormatter.string(from: Date())
        let logEntry = formatLogEntry(timestamp: timestamp, url: url, title: title)

        // Append to existing log file
        if let data = "\(logEntry)\n".data(using: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
    }

    private func readLogs() -> [String] {
        guard fileManager.fileExists(atPath: logFilePath) else {
            return []
        }

        guard let content = try? String(contentsOfFile: logFilePath, encoding: .utf8) else {
            return []
        }

        return content.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func ensureLogFileExists() {
        guard !fileManager.fileExists(atPath: logFilePath) else {
            return
        }

        fileManager.createFile(atPath: logFilePath, contents: nil, attributes: nil)
    }

    private func formatLogEntry(timestamp: String, url: String, title: String) -> String {
        let sanitizedTitle = title.isEmpty ? "(untitled)" : title
        return "[\(timestamp)] URL: \(url) | Title: \(sanitizedTitle)"
    }
}
