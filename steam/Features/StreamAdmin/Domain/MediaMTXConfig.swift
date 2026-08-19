//
//  MediaMTXConfig.swift
//  steam
//

import Foundation

/// MediaMTX API configuration and credentials
///
/// Retrieves credentials from iOS Keychain at runtime.
/// This eliminates the security vulnerability of hardcoded credentials in the iOS binary.
///
/// **Credential Storage:**
/// - Primary: iOS Keychain (encrypted by OS)
/// - Fallback: Environment variables (for testing)
/// - See docs/CREDENTIAL_MANAGEMENT.md for full strategy
enum MediaMTXConfig {
    // MARK: - Service Identifier
    private static let keychainService = "MediaMTX"
    private static let usernameEnvKey = "API_VIEWER_USER"
    private static let passwordEnvKey = "API_VIEWER_PASS"

    // MARK: - Lazy-Loaded Credentials
    private static var cachedCredentials: KeychainManager.Credentials?
    private static let credentialsLock = NSLock()

    /// Loads credentials from Keychain (or environment fallback) at runtime.
    /// This avoids hardcoding credentials in the app binary.
    ///
    /// The lock is never held across the `await` below — `KeychainManager` is
    /// now an actor, and holding an `NSLock` across a suspension point is
    /// unsafe (the continuation can resume on a different thread than the one
    /// that took the lock). We check the cache, release, do the `await`, then
    /// re-acquire just to write the result.
    private static func loadCredentials() async -> KeychainManager.Credentials? {
        if let cached = credentialsLock.withLock({ cachedCredentials }) {
            return cached
        }

        // Try to load from Keychain
        do {
            let credentials = try await KeychainManager.shared.load(
                service: keychainService,
                userKey: usernameEnvKey,
                passKey: passwordEnvKey
            )
            credentialsLock.withLock { cachedCredentials = credentials }
            return credentials
        } catch {
            // Fallback to environment variables for testing/development
            if let username = ProcessInfo.processInfo.environment[usernameEnvKey],
               let password = ProcessInfo.processInfo.environment[passwordEnvKey] {
                let credentials = KeychainManager.Credentials(username: username, password: password)
                credentialsLock.withLock { cachedCredentials = credentials }
                return credentials
            }
            return nil
        }
    }

    // MARK: - Computed Properties
    /// Retrieves the API username from Keychain (or environment fallback).
    /// Returns empty string if no credentials are available.
    static var apiUsername: String {
        get async { await loadCredentials()?.username ?? "" }
    }

    /// Retrieves the API password from Keychain (or environment fallback).
    /// Returns empty string if no credentials are available.
    static var apiPassword: String {
        get async { await loadCredentials()?.password ?? "" }
    }

    // MARK: - Computed Auth Header
    /// Generates HTTP Basic authentication header from Keychain credentials.
    static var authHeaderValue: String {
        get async {
            let raw = "\(await apiUsername):\(await apiPassword)"
            let data = Data(raw.utf8)
            let encoded = data.base64EncodedString()
            return "Basic \(encoded)"
        }
    }

    // MARK: - Credential Management
    /// Stores credentials in iOS Keychain for persistent, encrypted storage.
    /// Call this during first-time setup or credential rotation.
    ///
    /// - Parameters:
    ///   - username: The API viewer username
    ///   - password: The API viewer password
    /// - Throws: KeychainManager.KeychainError if storage fails
    static func storeCredentials(username: String, password: String) async throws {
        let credentials = KeychainManager.Credentials(username: username, password: password)
        try await KeychainManager.shared.save(credentials, service: keychainService)
        // Reset cache to load the newly stored credentials
        credentialsLock.withLock { cachedCredentials = nil }
    }

    /// Checks if credentials exist in Keychain.
    static var hasStoredCredentials: Bool {
        get async { await KeychainManager.shared.exists(service: keychainService) }
    }

    /// Clears stored credentials from Keychain.
    /// Useful for logout or credential reset scenarios.
    static func clearCredentials() async throws {
        try await KeychainManager.shared.delete(service: keychainService)
        credentialsLock.withLock { cachedCredentials = nil }
    }

    // MARK: - Server Detection
    /// Derives MediaMTX API base URL and path name from a stream URL
    /// Returns (baseURL, pathName) if the URL looks like a MediaMTX HLS URL, else nil
    ///
    /// Example: `http://192.168.1.50:8888/live/mystream/index.m3u8`
    /// → (baseURL: `http://192.168.1.50:9997`, pathName: `live/mystream`)
    static func mediaMTXTarget(for url: URL) -> (baseURL: URL, pathName: String)? {
        guard let host = url.host else { return nil }

        var pathName = url.path
        // Remove leading slash if present
        if pathName.hasPrefix("/") {
            pathName.removeFirst()
        }

        // Check if this is a MediaMTX HLS URL (ends with /index.m3u8)
        guard pathName.hasSuffix("/index.m3u8") else {
            return nil  // Not a MediaMTX HLS URL (e.g., Apple demo streams)
        }

        // Strip the /index.m3u8 suffix to get the path name
        pathName = String(pathName.dropLast("/index.m3u8".count))
        guard !pathName.isEmpty else { return nil }

        // Build base URL on port 9997 (MediaMTX API port)
        guard let baseURL = URL(string: "http://\(host):9997") else {
            return nil
        }

        return (baseURL, pathName)
    }
}
