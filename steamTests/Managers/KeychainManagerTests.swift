//
//  KeychainManagerTests.swift
//  steamTests
//

import XCTest
@testable import steam

class KeychainManagerTests: XCTestCase {

    var sut: KeychainManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = KeychainManager()
        // Clean up any existing test credentials
        try? await sut.delete(service: "TestService")
    }

    override func tearDown() async throws {
        try? await sut.delete(service: "TestService")
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_save_and_load_credentials() async throws {
        // Given
        let credentials = KeychainManager.Credentials(
            username: "testuser",
            password: "testpassword123"
        )

        // When
        try await sut.save(credentials, service: "TestService")
        let loaded = try await sut.load(service: "TestService", userKey: "DUMMY_USER", passKey: "DUMMY_PASS")

        // Then
        XCTAssertEqual(loaded.username, "testuser")
        XCTAssertEqual(loaded.password, "testpassword123")
    }

    func test_load_from_environment_fallback() async throws {
        // Given
        setenv("TEST_USER", "envuser", 1)
        setenv("TEST_PASS", "envpass", 1)
        defer {
            unsetenv("TEST_USER")
            unsetenv("TEST_PASS")
        }

        // When
        let loaded = try await sut.load(service: "NonexistentService", userKey: "TEST_USER", passKey: "TEST_PASS")

        // Then
        XCTAssertEqual(loaded.username, "envuser")
        XCTAssertEqual(loaded.password, "envpass")
    }

    func test_load_fails_with_missing_environment_variable() async {
        // Given
        unsetenv("MISSING_USER")
        unsetenv("MISSING_PASS")

        // When/Then
        do {
            _ = try await sut.load(service: "NonexistentService", userKey: "MISSING_USER", passKey: "MISSING_PASS")
            XCTFail("Expected environmentVariableNotFound error")
        } catch KeychainManager.KeychainError.environmentVariableNotFound {
            // expected
        } catch {
            XCTFail("Expected environmentVariableNotFound error, got \(error)")
        }
    }

    func test_delete_credentials() async throws {
        // Given
        let credentials = KeychainManager.Credentials(username: "user", password: "pass")
        try await sut.save(credentials, service: "TestService")
        let existsBefore = await sut.exists(service: "TestService")
        XCTAssertTrue(existsBefore)

        // When
        try await sut.delete(service: "TestService")

        // Then
        let existsAfter = await sut.exists(service: "TestService")
        XCTAssertFalse(existsAfter)
    }

    func test_exists_returns_true_when_credentials_stored() async throws {
        // Given
        let credentials = KeychainManager.Credentials(username: "user", password: "pass")
        try await sut.save(credentials, service: "TestService")

        // When
        let exists = await sut.exists(service: "TestService")

        // Then
        XCTAssertTrue(exists)
    }

    func test_exists_returns_false_when_credentials_not_stored() async {
        // When
        let exists = await sut.exists(service: "NonexistentService")

        // Then
        XCTAssertFalse(exists)
    }

    func test_save_overwrites_existing_credentials() async throws {
        // Given
        let oldCredentials = KeychainManager.Credentials(username: "olduser", password: "oldpass")
        try await sut.save(oldCredentials, service: "TestService")

        let newCredentials = KeychainManager.Credentials(username: "newuser", password: "newpass")

        // When
        try await sut.save(newCredentials, service: "TestService")
        let loaded = try await sut.load(service: "TestService", userKey: "DUMMY_USER", passKey: "DUMMY_PASS")

        // Then
        XCTAssertEqual(loaded.username, "newuser")
        XCTAssertEqual(loaded.password, "newpass")
    }

    func test_special_characters_in_credentials() async throws {
        // Given
        let specialChars = "p@ssw0rd!#$%^&*()"
        let credentials = KeychainManager.Credentials(username: "user@example.com", password: specialChars)

        // When
        try await sut.save(credentials, service: "TestService")
        let loaded = try await sut.load(service: "TestService", userKey: "DUMMY_USER", passKey: "DUMMY_PASS")

        // Then
        XCTAssertEqual(loaded.username, "user@example.com")
        XCTAssertEqual(loaded.password, specialChars)
    }

    func test_empty_credentials_handling() async throws {
        // Given
        let credentials = KeychainManager.Credentials(username: "", password: "")

        // When
        try await sut.save(credentials, service: "TestService")
        let loaded = try await sut.load(service: "TestService", userKey: "DUMMY_USER", passKey: "DUMMY_PASS")

        // Then
        XCTAssertEqual(loaded.username, "")
        XCTAssertEqual(loaded.password, "")
    }
}
