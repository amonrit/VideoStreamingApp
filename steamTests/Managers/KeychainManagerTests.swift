//
//  KeychainManagerTests.swift
//  steamTests
//

import XCTest
@testable import steam

class KeychainManagerTests: XCTestCase {

    var sut: KeychainManager!

    override func setUp() {
        super.setUp()
        sut = KeychainManager()
        // Clean up any existing test credentials
        try? sut.delete(service: "TestService")
    }

    override func tearDown() {
        super.tearDown()
        try? sut.delete(service: "TestService")
    }

    // MARK: - Tests

    func test_save_and_load_credentials() throws {
        // Given
        let credentials = KeychainManager.Credentials(
            username: "testuser",
            password: "testpassword123"
        )

        // When
        try sut.save(credentials, service: "TestService")
        let loaded = try sut.load(service: "TestService", userKey: "DUMMY_USER", passKey: "DUMMY_PASS")

        // Then
        XCTAssertEqual(loaded.username, "testuser")
        XCTAssertEqual(loaded.password, "testpassword123")
    }

    func test_load_from_environment_fallback() throws {
        // Given
        setenv("TEST_USER", "envuser", 1)
        setenv("TEST_PASS", "envpass", 1)
        defer {
            unsetenv("TEST_USER")
            unsetenv("TEST_PASS")
        }

        // When
        let loaded = try sut.load(service: "NonexistentService", userKey: "TEST_USER", passKey: "TEST_PASS")

        // Then
        XCTAssertEqual(loaded.username, "envuser")
        XCTAssertEqual(loaded.password, "envpass")
    }

    func test_load_fails_with_missing_environment_variable() {
        // Given
        unsetenv("MISSING_USER")
        unsetenv("MISSING_PASS")

        // When/Then
        XCTAssertThrowsError(
            try sut.load(service: "NonexistentService", userKey: "MISSING_USER", passKey: "MISSING_PASS")
        ) { error in
            guard case KeychainManager.KeychainError.environmentVariableNotFound = error else {
                XCTFail("Expected environmentVariableNotFound error")
                return
            }
        }
    }

    func test_delete_credentials() throws {
        // Given
        let credentials = KeychainManager.Credentials(username: "user", password: "pass")
        try sut.save(credentials, service: "TestService")
        XCTAssertTrue(sut.exists(service: "TestService"))

        // When
        try sut.delete(service: "TestService")

        // Then
        XCTAssertFalse(sut.exists(service: "TestService"))
    }

    func test_exists_returns_true_when_credentials_stored() throws {
        // Given
        let credentials = KeychainManager.Credentials(username: "user", password: "pass")
        try sut.save(credentials, service: "TestService")

        // When
        let exists = sut.exists(service: "TestService")

        // Then
        XCTAssertTrue(exists)
    }

    func test_exists_returns_false_when_credentials_not_stored() {
        // When
        let exists = sut.exists(service: "NonexistentService")

        // Then
        XCTAssertFalse(exists)
    }

    func test_save_overwrites_existing_credentials() throws {
        // Given
        let oldCredentials = KeychainManager.Credentials(username: "olduser", password: "oldpass")
        try sut.save(oldCredentials, service: "TestService")

        let newCredentials = KeychainManager.Credentials(username: "newuser", password: "newpass")

        // When
        try sut.save(newCredentials, service: "TestService")
        let loaded = try sut.load(service: "TestService", userKey: "DUMMY_USER", passKey: "DUMMY_PASS")

        // Then
        XCTAssertEqual(loaded.username, "newuser")
        XCTAssertEqual(loaded.password, "newpass")
    }

    func test_special_characters_in_credentials() throws {
        // Given
        let specialChars = "p@ssw0rd!#$%^&*()"
        let credentials = KeychainManager.Credentials(username: "user@example.com", password: specialChars)

        // When
        try sut.save(credentials, service: "TestService")
        let loaded = try sut.load(service: "TestService", userKey: "DUMMY_USER", passKey: "DUMMY_PASS")

        // Then
        XCTAssertEqual(loaded.username, "user@example.com")
        XCTAssertEqual(loaded.password, specialChars)
    }

    func test_empty_credentials_handling() throws {
        // Given
        let credentials = KeychainManager.Credentials(username: "", password: "")

        // When
        try sut.save(credentials, service: "TestService")
        let loaded = try sut.load(service: "TestService", userKey: "DUMMY_USER", passKey: "DUMMY_PASS")

        // Then
        XCTAssertEqual(loaded.username, "")
        XCTAssertEqual(loaded.password, "")
    }
}
