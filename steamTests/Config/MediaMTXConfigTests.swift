//
//  MediaMTXConfigTests.swift
//  steamTests
//

import XCTest
@testable import steam

class MediaMTXConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clean up any stored credentials before each test
        try? MediaMTXConfig.clearCredentials()
    }

    override func tearDown() {
        super.tearDown()
        try? MediaMTXConfig.clearCredentials()
    }

    // MARK: - Tests

    func test_auth_header_value_with_environment_variables() {
        // Given
        setenv("API_VIEWER_USER", "envuser", 1)
        setenv("API_VIEWER_PASS", "envpass", 1)
        defer {
            unsetenv("API_VIEWER_USER")
            unsetenv("API_VIEWER_PASS")
        }

        // When
        let authHeader = MediaMTXConfig.authHeaderValue

        // Then
        let expected = "Basic \("envuser:envpass".data(using: .utf8)!.base64EncodedString())"
        XCTAssertEqual(authHeader, expected)
        XCTAssertTrue(authHeader.hasPrefix("Basic "))
    }

    func test_api_username_and_password_from_environment() {
        // Given
        setenv("API_VIEWER_USER", "apiuser", 1)
        setenv("API_VIEWER_PASS", "apipass", 1)
        defer {
            unsetenv("API_VIEWER_USER")
            unsetenv("API_VIEWER_PASS")
        }

        // When
        let username = MediaMTXConfig.apiUsername
        let password = MediaMTXConfig.apiPassword

        // Then
        XCTAssertEqual(username, "apiuser")
        XCTAssertEqual(password, "apipass")
    }

    func test_store_and_load_credentials_from_keychain() throws {
        // Given
        try MediaMTXConfig.storeCredentials(username: "keychainuser", password: "keychainpass")

        // When
        let username = MediaMTXConfig.apiUsername
        let password = MediaMTXConfig.apiPassword

        // Then
        XCTAssertEqual(username, "keychainuser")
        XCTAssertEqual(password, "keychainpass")
    }

    func test_has_stored_credentials() throws {
        // Given
        XCTAssertFalse(MediaMTXConfig.hasStoredCredentials)

        // When
        try MediaMTXConfig.storeCredentials(username: "user", password: "pass")

        // Then
        XCTAssertTrue(MediaMTXConfig.hasStoredCredentials)
    }

    func test_clear_credentials() throws {
        // Given
        try MediaMTXConfig.storeCredentials(username: "user", password: "pass")
        XCTAssertTrue(MediaMTXConfig.hasStoredCredentials)

        // When
        try MediaMTXConfig.clearCredentials()

        // Then
        XCTAssertFalse(MediaMTXConfig.hasStoredCredentials)
    }

    func test_auth_header_format() {
        // Given
        setenv("API_VIEWER_USER", "user123", 1)
        setenv("API_VIEWER_PASS", "pass456", 1)
        defer {
            unsetenv("API_VIEWER_USER")
            unsetenv("API_VIEWER_PASS")
        }

        // When
        let authHeader = MediaMTXConfig.authHeaderValue

        // Then
        XCTAssertTrue(authHeader.hasPrefix("Basic "))
        let base64Part = String(authHeader.dropFirst(6)) // Remove "Basic "

        // Verify it's valid base64
        guard let decodedData = Data(base64Encoded: base64Part),
              let decodedString = String(data: decodedData, encoding: .utf8) else {
            XCTFail("Auth header should be valid base64")
            return
        }

        // Verify it contains username:password format
        XCTAssertTrue(decodedString.contains(":"))
        let parts = decodedString.split(separator: ":", maxSplits: 1).map(String.init)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0], "user123")
        XCTAssertEqual(parts[1], "pass456")
    }
}
