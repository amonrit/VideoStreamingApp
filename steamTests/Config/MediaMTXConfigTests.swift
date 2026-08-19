//
//  MediaMTXConfigTests.swift
//  steamTests
//

import XCTest
@testable import steam

class MediaMTXConfigTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Clean up any stored credentials before each test
        try? await MediaMTXConfig.clearCredentials()
    }

    override func tearDown() async throws {
        try? await MediaMTXConfig.clearCredentials()
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_auth_header_value_with_environment_variables() async {
        // Given
        setenv("API_VIEWER_USER", "envuser", 1)
        setenv("API_VIEWER_PASS", "envpass", 1)
        defer {
            unsetenv("API_VIEWER_USER")
            unsetenv("API_VIEWER_PASS")
        }

        // When
        let authHeader = await MediaMTXConfig.authHeaderValue

        // Then
        let expected = "Basic \("envuser:envpass".data(using: .utf8)!.base64EncodedString())"
        XCTAssertEqual(authHeader, expected)
        XCTAssertTrue(authHeader.hasPrefix("Basic "))
    }

    func test_api_username_and_password_from_environment() async {
        // Given
        setenv("API_VIEWER_USER", "apiuser", 1)
        setenv("API_VIEWER_PASS", "apipass", 1)
        defer {
            unsetenv("API_VIEWER_USER")
            unsetenv("API_VIEWER_PASS")
        }

        // When
        let username = await MediaMTXConfig.apiUsername
        let password = await MediaMTXConfig.apiPassword

        // Then
        XCTAssertEqual(username, "apiuser")
        XCTAssertEqual(password, "apipass")
    }

    func test_store_and_load_credentials_from_keychain() async throws {
        // Given
        try await MediaMTXConfig.storeCredentials(username: "keychainuser", password: "keychainpass")

        // When
        let username = await MediaMTXConfig.apiUsername
        let password = await MediaMTXConfig.apiPassword

        // Then
        XCTAssertEqual(username, "keychainuser")
        XCTAssertEqual(password, "keychainpass")
    }

    func test_has_stored_credentials() async throws {
        // Given
        let hasCredentialsBefore = await MediaMTXConfig.hasStoredCredentials
        XCTAssertFalse(hasCredentialsBefore)

        // When
        try await MediaMTXConfig.storeCredentials(username: "user", password: "pass")

        // Then
        let hasCredentialsAfter = await MediaMTXConfig.hasStoredCredentials
        XCTAssertTrue(hasCredentialsAfter)
    }

    func test_clear_credentials() async throws {
        // Given
        try await MediaMTXConfig.storeCredentials(username: "user", password: "pass")
        let hasCredentialsBefore = await MediaMTXConfig.hasStoredCredentials
        XCTAssertTrue(hasCredentialsBefore)

        // When
        try await MediaMTXConfig.clearCredentials()

        // Then
        let hasCredentialsAfter = await MediaMTXConfig.hasStoredCredentials
        XCTAssertFalse(hasCredentialsAfter)
    }

    func test_auth_header_format() async {
        // Given
        setenv("API_VIEWER_USER", "user123", 1)
        setenv("API_VIEWER_PASS", "pass456", 1)
        defer {
            unsetenv("API_VIEWER_USER")
            unsetenv("API_VIEWER_PASS")
        }

        // When
        let authHeader = await MediaMTXConfig.authHeaderValue

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
