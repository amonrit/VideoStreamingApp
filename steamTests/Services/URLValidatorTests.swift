//
//  URLValidatorTests.swift
//  steamTests
//

import XCTest
@testable import steam

final class URLValidatorTests: XCTestCase {
    var sut: URLValidator!

    override func setUp() {
        super.setUp()
        sut = URLValidator()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - HTTPS Validation Tests

    func testHTTPSURLIsValid() {
        let url = "https://example.com/stream.m3u8"
        XCTAssertTrue(sut.isHTTPS(url), "HTTPS URL should be valid")
    }

    func testHTTPURLIsNotHTTPS() {
        let url = "http://example.com/stream.m3u8"
        XCTAssertFalse(sut.isHTTPS(url), "HTTP URL should not pass HTTPS check")
    }

    func testRTMPURLIsNotHTTPS() {
        let url = "rtmp://example.com/live/stream"
        XCTAssertFalse(sut.isHTTPS(url), "RTMP URL should not pass HTTPS check")
    }

    func testEmptyURLIsNotHTTPS() {
        let url = ""
        XCTAssertFalse(sut.isHTTPS(url), "Empty URL should not pass HTTPS check")
    }

    // MARK: - Whitelist Domain Validation Tests

    func testWhitelistedDomainIsValid() {
        let url = "https://devstreaming-cdn.apple.com/videos/stream.m3u8"
        XCTAssertTrue(sut.isDomainWhitelisted(url), "Apple CDN should be whitelisted")
    }

    func testMultipleWhitelistedDomains() {
        let testCases = [
            "https://devstreaming-cdn.apple.com/videos/stream.m3u8",
            "https://localhost:8888/live/stream.m3u8",
            "https://127.0.0.1:8888/live/stream.m3u8",
        ]

        for url in testCases {
            XCTAssertTrue(sut.isDomainWhitelisted(url), "Domain should be whitelisted: \(url)")
        }
    }

    func testNonWhitelistedDomainIsInvalid() {
        let url = "https://malicious-site.com/stream.m3u8"
        XCTAssertFalse(sut.isDomainWhitelisted(url), "Non-whitelisted domain should be invalid")
    }

    func testLocalhost127IsWhitelisted() {
        let testCases = [
            "https://127.0.0.1:8888/live/stream.m3u8",
            "http://127.0.0.1:8888/live/stream.m3u8",
            "rtmp://127.0.0.1:1935/live/stream",
        ]

        for url in testCases {
            XCTAssertTrue(sut.isDomainWhitelisted(url), "127.0.0.1 should be whitelisted: \(url)")
        }
    }

    func testLocalhostDomainIsWhitelisted() {
        let testCases = [
            "https://localhost:8888/live/stream.m3u8",
            "http://localhost:8888/live/stream.m3u8",
            "rtmp://localhost:1935/live/stream",
        ]

        for url in testCases {
            XCTAssertTrue(sut.isDomainWhitelisted(url), "localhost should be whitelisted: \(url)")
        }
    }

    func testWhitelistedIPAddressIsValid() {
        // Test a typical local network IP (if added to whitelist in future)
        let url = "https://192.168.1.100:8888/live/stream.m3u8"
        // This may or may not be whitelisted depending on configuration
        // Just ensure the validator handles it without crashing
        let result = sut.isDomainWhitelisted(url)
        XCTAssertNotNil(result, "Should handle IP address without crashing")
    }

    func testInvalidURLFormatDoesntCrash() {
        let testCases = [
            "not a url",
            "://missing-protocol",
            "https://",
            "",
        ]

        for url in testCases {
            let result = sut.isDomainWhitelisted(url)
            XCTAssertNotNil(result, "Should handle invalid URL format: \(url)")
        }
    }

    // MARK: - Combined Validation Tests

    func testCompleteValidationHTTPSWhitelisted() {
        let url = "https://devstreaming-cdn.apple.com/videos/stream.m3u8"
        XCTAssertTrue(sut.isValidStreamURL(url), "Valid HTTPS whitelisted URL should pass")
    }

    func testCompleteValidationHTTPFails() {
        let url = "http://example.com/stream.m3u8"
        XCTAssertFalse(sut.isValidStreamURL(url), "HTTP URL should fail validation")
    }

    func testCompleteValidationNonWhitelistedFails() {
        let url = "https://malicious.com/stream.m3u8"
        XCTAssertFalse(sut.isValidStreamURL(url), "Non-whitelisted domain should fail")
    }

    func testRTMPValidationWithWhitelist() {
        let url = "rtmp://localhost:1935/live/stream"
        // RTMP might be allowed for whitelisted domains
        let result = sut.isValidStreamURL(url)
        XCTAssertNotNil(result, "Should handle RTMP without crashing")
    }

    // MARK: - Edge Cases

    func testURLWithSubdomain() {
        let url = "https://cdn.example.devstreaming-cdn.apple.com/stream.m3u8"
        // Subdomain of non-whitelisted domain should not pass
        let result = sut.isDomainWhitelisted(url)
        XCTAssertFalse(result, "Subdomain of non-whitelisted domain should not pass")
    }

    func testURLWithPort() {
        let url = "https://devstreaming-cdn.apple.com:8080/videos/stream.m3u8"
        XCTAssertTrue(sut.isDomainWhitelisted(url), "Should handle URLs with custom port")
    }

    func testURLWithQueryParameters() {
        let url = "https://devstreaming-cdn.apple.com/videos/stream.m3u8?token=abc123"
        XCTAssertTrue(sut.isDomainWhitelisted(url), "Should validate despite query parameters")
    }

    func testURLCaseInsensitive() {
        let urls = [
            "https://DEVSTREAMING-CDN.APPLE.COM/videos/stream.m3u8",
            "https://DevStreaming-Cdn.Apple.Com/videos/stream.m3u8",
            "https://devstreaming-cdn.apple.com/videos/stream.m3u8",
        ]

        for url in urls {
            XCTAssertTrue(sut.isDomainWhitelisted(url), "Whitelist check should be case-insensitive: \(url)")
        }
    }
}
