//
//  URLValidator.swift
//  steam
//

import Foundation

/// Service for validating stream URLs against security policies.
/// Ensures URLs are HTTPS and from trusted domains.
class URLValidator {

    // MARK: - Whitelisted Domains

    /// List of trusted domains from which streams can be added.
    /// This prevents users from adding streams from untrusted sources.
    private let whitelistedDomains: [String] = [
        // Apple's official streaming examples
        "devstreaming-cdn.apple.com",

        // Local development and testing
        "localhost",
        "127.0.0.1",

        // Future expansion can add:
        // - Internal company streaming servers
        // - Partnered CDNs
    ]

    // MARK: - Public Validation Methods

    /// Validates that a URL is from a whitelisted domain.
    /// - Parameter urlString: The URL string to validate
    /// - Returns: true if domain is whitelisted, false otherwise
    func isDomainWhitelisted(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        guard let host = url.host?.lowercased() else {
            return false
        }

        // Check exact domain matches
        for domain in whitelistedDomains {
            if host == domain.lowercased() {
                return true
            }
        }

        return false
    }

    /// Validates that a URL uses HTTPS protocol (secure).
    /// - Parameter urlString: The URL string to validate
    /// - Returns: true if URL uses HTTPS, false otherwise
    func isHTTPS(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }

        return url.scheme?.lowercased() == "https"
    }

    /// Validates a complete stream URL against all security policies.
    /// - Parameter urlString: The URL string to validate
    /// - Returns: true if URL passes all validation checks, false otherwise
    ///
    /// Validation checks:
    /// 1. URL must be from a whitelisted domain
    /// 2. URL must use HTTPS (for HLS URLs) or be RTMP from whitelisted domain
    func isValidStreamURL(_ urlString: String) -> Bool {
        guard !urlString.isEmpty else {
            return false
        }

        // Must be from whitelisted domain
        guard isDomainWhitelisted(urlString) else {
            return false
        }

        // For HTTP(S) URLs, must be HTTPS
        if urlString.contains("http://") || urlString.contains("https://") {
            return isHTTPS(urlString)
        }

        // RTMP from whitelisted domain is allowed
        if urlString.contains("rtmp://") {
            return isDomainWhitelisted(urlString)
        }

        return false
    }

    /// Extracts hostname from a URL string safely.
    /// - Parameter urlString: The URL string to parse
    /// - Returns: The hostname if valid, nil otherwise
    func extractHostname(_ urlString: String) -> String? {
        return URL(string: urlString)?.host
    }

    /// Provides a user-friendly validation message.
    /// - Parameter urlString: The URL string that failed validation
    /// - Returns: A descriptive error message
    func getValidationErrorMessage(for urlString: String) -> String {
        if urlString.isEmpty {
            return "URL cannot be empty"
        }

        if !isDomainWhitelisted(urlString) {
            return "This domain is not whitelisted for security reasons"
        }

        if urlString.contains("http://") {
            return "HTTP URLs are not secure. Please use HTTPS instead"
        }

        if !isHTTPS(urlString) && !urlString.contains("rtmp://") {
            return "URL must use HTTPS protocol"
        }

        return "URL validation failed"
    }
}
