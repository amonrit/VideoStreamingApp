//
//  CredentialSecurityTests.swift
//  steamTests
//
//  Integration tests to verify that hardcoded credentials are not present in the app binary.
//  This addresses the CRITICAL security finding from SECURITY_AUDIT_2026-08-17.md.

import XCTest
import Foundation
@testable import steam

class CredentialSecurityTests: XCTestCase {

    // MARK: - Tests

    /// Integration test: Verify hardcoded credentials are not in the binary
    ///
    /// **Security Requirement:**
    /// From SECURITY_AUDIT_2026-08-17.md - Finding #1: Hardcoded credentials in iOS app source code
    ///
    /// **Acceptance Criteria (Issue #17):**
    /// - [ ] Write integration test confirming hardcoded password is not in binary (use strings command)
    ///
    /// **Why this test matters:**
    /// If hardcoded credentials are still in the binary, an attacker could:
    /// 1. Download the app from App Store
    /// 2. Use a decompiler/disassembler to extract the binary
    /// 3. Use the `strings` command to find hardcoded credentials
    /// 4. Gain unauthorized access to the MediaMTX API
    func test_no_hardcoded_changeme_password_in_binary() throws {
        #if os(macOS)
        // Get the path to the built app binary
        let bundle = Bundle(for: type(of: self))
        guard let executablePath = bundle.executablePath else {
            XCTFail("Could not find executable path")
            return
        }

        // Run the `strings` command to extract all human-readable strings from the binary
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
        process.arguments = [executablePath]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            XCTFail("Could not read strings output")
            return
        }

        // Verify the old default password is NOT in the binary
        // This was the vulnerability: static let apiPassword = "changeme123"
        XCTAssertFalse(
            output.contains("changeme123"),
            "SECURITY FAILURE: Hardcoded password 'changeme123' found in binary. " +
            "Credentials must be stored in Keychain, not hardcoded."
        )
        #else
        // `Process` (subprocess spawning) is unavailable on iOS/iOS Simulator,
        // so this binary-inspection check can only run on macOS.
        throw XCTSkip("Process is unavailable on iOS; run this test on a macOS target.")
        #endif
    }

    /// Integration test: Verify no hardcoded apiviewer username pattern
    func test_no_hardcoded_apiviewer_credentials_in_binary() throws {
        #if os(macOS)
        let bundle = Bundle(for: type(of: self))
        guard let executablePath = bundle.executablePath else {
            XCTFail("Could not find executable path")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/strings")
        process.arguments = [executablePath]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            XCTFail("Could not read strings output")
            return
        }

        // The pattern "apiviewer:changeme123" should NOT appear in the binary
        // This indicates hardcoded Basic auth credentials
        XCTAssertFalse(
            output.contains("apiviewer:changeme123"),
            "SECURITY FAILURE: Hardcoded credentials pattern found in binary"
        )

        // Also verify that the plaintext "changeme123" password is not in any form
        XCTAssertFalse(
            output.contains("changeme"),
            "SECURITY FAILURE: Credential pattern containing 'changeme' found in binary"
        )
        #else
        throw XCTSkip("Process is unavailable on iOS; run this test on a macOS target.")
        #endif
    }

    /// Integration test: Verify MediaMTXConfig doesn't hardcode credentials
    ///
    /// **Why:** Ensures that at runtime, MediaMTXConfig properly uses Keychain
    /// or environment variables instead of hardcoded values.
    func test_mediamtx_config_uses_dynamic_credentials() {
        // Set environment variables for this test
        setenv("API_VIEWER_USER", "testuser", 1)
        setenv("API_VIEWER_PASS", "testpass", 1)
        defer {
            unsetenv("API_VIEWER_USER")
            unsetenv("API_VIEWER_PASS")
        }

        // The authHeaderValue should be generated from environment variables,
        // not hardcoded values
        let authHeader = MediaMTXConfig.authHeaderValue

        // Decode the base64 auth header
        guard authHeader.hasPrefix("Basic ") else {
            XCTFail("Auth header should start with 'Basic '")
            return
        }

        let base64Part = String(authHeader.dropFirst(6))
        guard let decodedData = Data(base64Encoded: base64Part),
              let decodedString = String(data: decodedData, encoding: .utf8) else {
            XCTFail("Could not decode auth header")
            return
        }

        // Verify the credentials are from environment, not hardcoded
        XCTAssertTrue(
            decodedString.contains("testuser"),
            "Should contain user from environment variable"
        )
        XCTAssertTrue(
            decodedString.contains("testpass"),
            "Should contain password from environment variable"
        )
        XCTAssertFalse(
            decodedString.contains("changeme123"),
            "Should NOT contain hardcoded 'changeme123' password"
        )
    }
}
