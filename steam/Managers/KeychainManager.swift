//
//  KeychainManager.swift
//  steam
//
//  Secure credential storage using iOS Keychain with environment variable fallback.

import Foundation
import Security

/// Secure credential storage using iOS Keychain.
///
/// Implements the credential lifecycle strategy:
/// - **Primary:** iOS Keychain (encrypted by OS)
/// - **Fallback:** Environment variables (for testing)
/// - **Never:** Hardcoded values in source code
///
/// See docs/CREDENTIAL_MANAGEMENT.md for the full credential lifecycle strategy.
class KeychainManager {
    // MARK: - Singleton
    static let shared = KeychainManager()

    // MARK: - Credentials Struct
    struct Credentials {
        let username: String
        let password: String

        init(username: String, password: String) {
            self.username = username
            self.password = password
        }
    }

    // MARK: - Error Handling
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case decodeFailed
        case environmentVariableNotFound(String)
        case missingCredentials

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save credentials to Keychain (status: \(status))"
            case .loadFailed(let status):
                return "Failed to load credentials from Keychain (status: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete credentials from Keychain (status: \(status))"
            case .decodeFailed:
                return "Failed to decode credentials from Keychain data"
            case .environmentVariableNotFound(let variable):
                return "Environment variable '\(variable)' not found"
            case .missingCredentials:
                return "Credentials not found in Keychain or environment"
            }
        }
    }

    private let queue = DispatchQueue(label: "com.steam.keychain", attributes: .concurrent)

    // MARK: - Private Methods

    /// Builds a Keychain query dictionary for the given service and account.
    private func buildQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Attempts to load credentials from Keychain, then falls back to environment variables.
    private func loadCredentials(service: String, userKey: String, passKey: String) throws -> Credentials {
        // Try Keychain first
        if let keychainCreds = try? loadFromKeychain(service: service) {
            return keychainCreds
        }

        // Fallback to environment variables for testing
        guard let username = ProcessInfo.processInfo.environment[userKey] else {
            throw KeychainError.environmentVariableNotFound(userKey)
        }
        guard let password = ProcessInfo.processInfo.environment[passKey] else {
            throw KeychainError.environmentVariableNotFound(passKey)
        }

        return Credentials(username: username, password: password)
    }

    /// Loads credentials from Keychain for a given service.
    private func loadFromKeychain(service: String) throws -> Credentials {
        let usernameQuery = buildQuery(service: service, account: "username")
        let passwordQuery = buildQuery(service: service, account: "password")

        var usernameResult: AnyObject?
        var passwordResult: AnyObject?

        let usernameStatus = SecItemCopyMatching(usernameQuery as CFDictionary, &usernameResult)
        let passwordStatus = SecItemCopyMatching(passwordQuery as CFDictionary, &passwordResult)

        guard usernameStatus == errSecSuccess else {
            throw KeychainError.loadFailed(usernameStatus)
        }
        guard passwordStatus == errSecSuccess else {
            throw KeychainError.loadFailed(passwordStatus)
        }

        guard let usernameData = usernameResult as? Data,
              let passwordData = passwordResult as? Data,
              let username = String(data: usernameData, encoding: .utf8),
              let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.decodeFailed
        }

        return Credentials(username: username, password: password)
    }

    // MARK: - Public Methods

    /// Saves credentials to Keychain for the given service.
    ///
    /// - Parameters:
    ///   - credentials: The username/password pair to save
    ///   - service: The service identifier (e.g., "MediaMTX")
    /// - Throws: KeychainError if save fails
    func save(_ credentials: Credentials, service: String) throws {
        try queue.sync(flags: .barrier) {
            // Save username
            let usernameQuery = buildQuery(service: service, account: "username")
            let usernameData = credentials.username.data(using: .utf8) ?? Data()

            SecItemDelete(usernameQuery as CFDictionary)
            let usernameStatus = SecItemAdd(
                usernameQuery.merging([kSecValueData as String: usernameData], uniquingKeysWith: { _, new in new }) as CFDictionary,
                nil
            )
            guard usernameStatus == errSecSuccess else {
                throw KeychainError.saveFailed(usernameStatus)
            }

            // Save password
            let passwordQuery = buildQuery(service: service, account: "password")
            let passwordData = credentials.password.data(using: .utf8) ?? Data()

            SecItemDelete(passwordQuery as CFDictionary)
            let passwordStatus = SecItemAdd(
                passwordQuery.merging([kSecValueData as String: passwordData], uniquingKeysWith: { _, new in new }) as CFDictionary,
                nil
            )
            guard passwordStatus == errSecSuccess else {
                throw KeychainError.saveFailed(passwordStatus)
            }
        }
    }

    /// Loads credentials from Keychain (or environment as fallback) for the given service.
    ///
    /// Strategy:
    /// 1. Try to load from Keychain
    /// 2. Fall back to environment variables (e.g., API_VIEWER_USER, API_VIEWER_PASS)
    /// 3. Throw error if neither available
    ///
    /// - Parameters:
    ///   - service: The service identifier (e.g., "MediaMTX")
    ///   - userKey: Environment variable key for username (e.g., "API_VIEWER_USER")
    ///   - passKey: Environment variable key for password (e.g., "API_VIEWER_PASS")
    /// - Returns: Loaded Credentials
    /// - Throws: KeychainError if load fails from both Keychain and environment
    func load(service: String, userKey: String, passKey: String) throws -> Credentials {
        try queue.sync {
            try loadCredentials(service: service, userKey: userKey, passKey: passKey)
        }
    }

    /// Deletes credentials from Keychain for the given service.
    ///
    /// - Parameters:
    ///   - service: The service identifier (e.g., "MediaMTX")
    /// - Throws: KeychainError if delete fails
    func delete(service: String) throws {
        try queue.sync(flags: .barrier) {
            let usernameQuery = buildQuery(service: service, account: "username")
            let passwordQuery = buildQuery(service: service, account: "password")

            let usernameStatus = SecItemDelete(usernameQuery as CFDictionary)
            let passwordStatus = SecItemDelete(passwordQuery as CFDictionary)

            // SecItemDelete returns errSecItemNotFound if the item doesn't exist, which is OK
            guard usernameStatus == errSecSuccess || usernameStatus == errSecItemNotFound else {
                throw KeychainError.deleteFailed(usernameStatus)
            }
            guard passwordStatus == errSecSuccess || passwordStatus == errSecItemNotFound else {
                throw KeychainError.deleteFailed(passwordStatus)
            }
        }
    }

    /// Checks if credentials exist in Keychain for the given service.
    ///
    /// - Parameter service: The service identifier
    /// - Returns: true if credentials exist in Keychain
    func exists(service: String) -> Bool {
        let query = buildQuery(service: service, account: "username")
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }
}
