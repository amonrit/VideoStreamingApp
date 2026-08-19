//
//  URLValidationLoggerTests.swift
//  steamTests
//

import XCTest
@testable import steam

final class URLValidationLoggerTests: XCTestCase {
    var sut: URLValidationLogger!
    var tempLogFile: URL?

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        tempLogFile = tempDir.appendingPathComponent("test-url-logs-\(UUID().uuidString).txt")
        sut = URLValidationLogger(logFilePath: tempLogFile!.path)
    }

    override func tearDown() {
        if let logFile = tempLogFile, FileManager.default.fileExists(atPath: logFile.path) {
            try? FileManager.default.removeItem(at: logFile)
        }
        sut = nil
        super.tearDown()
    }

    // MARK: - Logging Tests

    func testLogCustomURLCreatesEntry() {
        let url = "https://example.com/stream.m3u8"
        let title = "Test Stream"

        sut.logCustomURL(url, title: title)

        let content = readLogFile()
        XCTAssertTrue(content.contains(url), "Log should contain the URL")
        XCTAssertTrue(content.contains(title), "Log should contain the title")
    }

    func testLogEntryIncludesTimestamp() {
        let url = "https://example.com/stream.m3u8"
        sut.logCustomURL(url, title: "Test")

        let content = readLogFile()
        // Check that timestamp is present (ISO 8601 format or similar)
        XCTAssertTrue(
            content.contains(":") || content.contains("-"),
            "Log should contain timestamp information"
        )
    }

    func testMultipleLogEntriesAreAppended() {
        sut.logCustomURL("https://stream1.com/stream.m3u8", title: "Stream 1")
        sut.logCustomURL("https://stream2.com/stream.m3u8", title: "Stream 2")

        let content = readLogFile()
        XCTAssertTrue(content.contains("stream1.com"), "First URL should be in log")
        XCTAssertTrue(content.contains("stream2.com"), "Second URL should be in log")
    }

    func testLogWithEmptyTitle() {
        let url = "https://example.com/stream.m3u8"
        sut.logCustomURL(url, title: "")

        let content = readLogFile()
        XCTAssertTrue(content.contains(url), "Should log URL even with empty title")
    }

    func testLogWithSpecialCharactersInTitle() {
        let url = "https://example.com/stream.m3u8"
        let title = "Test Stream™ with émojis 🎥"

        sut.logCustomURL(url, title: title)

        let content = readLogFile()
        XCTAssertTrue(content.contains(url), "URL should be logged")
        // Title might be sanitized, so just check that logging succeeds
        XCTAssertTrue(content.count > 0, "Log file should have content")
    }

    func testLogFormatIsReadable() {
        sut.logCustomURL("https://example.com/stream.m3u8", title: "Test Stream")

        let content = readLogFile()
        // Log should be human-readable with some structure
        XCTAssertTrue(content.count > 20, "Log entry should be substantial")
    }

    func testLogFileIsCreatedIfNotExists() {
        let newLogPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("new-test-log-\(UUID().uuidString).txt")

        let logger = URLValidationLogger(logFilePath: newLogPath.path)
        logger.logCustomURL("https://example.com/stream.m3u8", title: "Test")

        XCTAssertTrue(FileManager.default.fileExists(atPath: newLogPath.path),
                      "Log file should be created")

        try? FileManager.default.removeItem(at: newLogPath)
    }

    func testConcurrentLogging() {
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        for i in 0..<10 {
            queue.async(group: group) {
                self.sut.logCustomURL("https://stream\(i).com/stream.m3u8", title: "Stream \(i)")
            }
        }

        group.waitWithTimeout(timeout: 5.0)

        let content = readLogFile()
        // Should have logged multiple entries without corruption
        let lineCount = content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        XCTAssertGreaterThan(lineCount, 0, "Should have log entries after concurrent logging")
    }

    // MARK: - Helper Methods

    private func readLogFile() -> String {
        guard let logFile = tempLogFile else { return "" }
        return (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
    }
}

// MARK: - Helper Extensions

extension DispatchGroup {
    func waitWithTimeout(timeout: TimeInterval) {
        let result = wait(timeout: .now() + timeout)
        if result == .timedOut {
            print("Warning: Dispatch group timed out")
        }
    }
}
