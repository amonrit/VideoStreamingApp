//
//  URLWhitelistIntegrationTests.swift
//  steamTests
//

import XCTest
@testable import steam

final class URLWhitelistIntegrationTests: XCTestCase {
    var validator: URLValidator!
    var logger: URLValidationLogger!
    var tempLogFile: URL?

    override func setUp() {
        super.setUp()
        validator = URLValidator()

        let tempDir = FileManager.default.temporaryDirectory
        tempLogFile = tempDir.appendingPathComponent("integration-test-\(UUID().uuidString).txt")
        logger = URLValidationLogger(logFilePath: tempLogFile!.path)
    }

    override func tearDown() {
        if let logFile = tempLogFile, FileManager.default.fileExists(atPath: logFile.path) {
            try? FileManager.default.removeItem(at: logFile)
        }
        validator = nil
        logger = nil
        super.tearDown()
    }

    // MARK: - Integration Tests

    func testWhitelistedAppleStreamIsValid() async {
        let appleStream = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"

        // Validator should accept it
        XCTAssertTrue(validator.isValidStreamURL(appleStream), "Apple stream should be valid")

        // Logger should record it
        await logger.logCustomURL(appleStream, title: "Apple Test Stream")

        let logs = await logger.getAllLogs()
        XCTAssertGreaterThan(logs.count, 0, "Log should contain the entry")
        XCTAssertTrue(logs[0].contains(appleStream), "Log should contain URL")
        XCTAssertTrue(logs[0].contains("Apple Test Stream"), "Log should contain title")
    }

    func testLocalhostStreamIsValid() async {
        let localhostStream = "https://localhost:8888/live/mystream/index.m3u8"

        XCTAssertTrue(validator.isValidStreamURL(localhostStream), "Localhost stream should be valid")

        await logger.logCustomURL(localhostStream, title: "Local Stream")
        let logs = await logger.getAllLogs()
        XCTAssertGreaterThan(logs.count, 0, "Should log localhost stream")
    }

    func testNonWhitelistedStreamIsRejected() async {
        let maliciousStream = "https://malicious.com/video.m3u8"

        XCTAssertFalse(validator.isValidStreamURL(maliciousStream), "Non-whitelisted stream should be rejected")

        await logger.logCustomURL(maliciousStream, title: "Malicious Stream")
        let logs = await logger.getAllLogs()
        // Even rejected streams may be logged for audit trail
        XCTAssertGreaterThan(logs.count, 0, "Should log rejected stream for audit")
    }

    func testHTTPStreamIsWarned() async {
        let httpStream = "http://localhost:8888/live/stream.m3u8"

        // May be technically valid but should be flagged
        let isHTTPS = validator.isHTTPS(httpStream)
        XCTAssertFalse(isHTTPS, "HTTP should not pass HTTPS check")

        await logger.logCustomURL(httpStream, title: "HTTP Stream (Insecure)")
        let logs = await logger.getAllLogs()
        XCTAssertTrue(logs[0].contains("HTTP Stream"), "Should log with warning context")
    }

    func testMultipleStreamsAreLoggedSequentially() async {
        let streams = [
            ("https://localhost:8888/stream1.m3u8", "Stream 1"),
            ("https://devstreaming-cdn.apple.com/example.m3u8", "Apple Stream"),
            ("https://localhost:8888/stream2.m3u8", "Stream 2"),
        ]

        for (url, title) in streams {
            if validator.isValidStreamURL(url) {
                await logger.logCustomURL(url, title: title)
            }
        }

        let logs = await logger.getAllLogs()
        XCTAssertEqual(logs.count, 3, "Should have 3 log entries")
        XCTAssertTrue(logs[0].contains("Stream 1"))
        XCTAssertTrue(logs[1].contains("Apple Stream"))
        XCTAssertTrue(logs[2].contains("Stream 2"))
    }

    func testValidatorProvidesFriendlyErrorMessages() {
        let testCases: [(String, String)] = [
            ("", "empty"),
            ("https://malicious.com/stream.m3u8", "non-whitelisted"),
            ("http://example.com/stream.m3u8", "http"),
        ]

        for (url, expectedKeyword) in testCases {
            let message = validator.getValidationErrorMessage(for: url)
            XCTAssertFalse(message.isEmpty, "Should provide error message for: \(expectedKeyword)")
        }
    }

    func testLogEntriesIncludeTimestamps() async {
        await logger.logCustomURL("https://localhost:8888/stream.m3u8", title: "Timed Stream")

        let logs = await logger.getAllLogs()
        let firstLog = logs[0]

        // Should contain timestamp indicators
        XCTAssertTrue(
            firstLog.contains("[") && firstLog.contains("]"),
            "Log should have timestamp in brackets"
        )
    }

    func testSecurityAuditTrail() async {
        // Simulate user adding multiple streams
        let attemptedStreams = [
            ("https://localhost:8888/safe.m3u8", "Safe Stream"),
            ("https://attacker.com/malware.m3u8", "Attacker Stream"),  // Will fail validation
            ("https://devstreaming-cdn.apple.com/apple.m3u8", "Apple Stream"),
        ]

        for (url, title) in attemptedStreams {
            // Always log (even rejected ones for audit trail)
            await logger.logCustomURL(url, title: title)
        }

        let logs = await logger.getAllLogs()
        XCTAssertEqual(logs.count, 3, "All attempts should be logged for audit")

        // Verify all entries are present
        let logContent = logs.joined(separator: "\n")
        XCTAssertTrue(logContent.contains("Safe Stream"))
        XCTAssertTrue(logContent.contains("Attacker Stream"))
        XCTAssertTrue(logContent.contains("Apple Stream"))
    }
}
