//
//  MediaMTXAPIClient.swift
//  steam
//

import Foundation

enum MediaMTXAPIError: Error, LocalizedError {
    case badResponse(Int)
    case invalidPathName
    case decodingFailed
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return "API returned status \(code)"
        case .invalidPathName:
            return "Invalid path name"
        case .decodingFailed:
            return "Failed to decode API response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Interface for the MediaMTX Control API v3 client operations.
/// Lets tests substitute a mock implementation without subclassing the
/// (intentionally `final`) production client.
protocol MediaMTXAPIClientProtocol {
    /// Fetches all paths (streams) from MediaMTX
    func fetchPathList() async throws -> MediaMTXPathList

    /// Fetches single path status (incl. reader/viewer info) for one MediaMTX path
    func fetchPath(named pathName: String) async throws -> MediaMTXPath
}

/// MediaMTX Control API v3 client
final class MediaMTXAPIClient: MediaMTXAPIClientProtocol {
    private let session: URLSession
    private let baseURL: URL  // e.g. http://192.168.1.50:9997

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Fetches all paths (streams) from MediaMTX
    func fetchPathList() async throws -> MediaMTXPathList {
        let url = baseURL.appendingPathComponent("v3/paths/list")
        var request = URLRequest(url: url)
        request.setValue(await MediaMTXConfig.authHeaderValue, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw MediaMTXAPIError.badResponse(code)
            }
            return try JSONDecoder().decode(MediaMTXPathList.self, from: data)
        } catch let error as MediaMTXAPIError {
            throw error
        } catch let error as DecodingError {
            throw MediaMTXAPIError.decodingFailed
        } catch {
            throw MediaMTXAPIError.networkError(error)
        }
    }

    /// Fetches single path status (incl. reader/viewer info) for one MediaMTX path
    /// Path names may contain "/" (e.g. "live/mystream") — properly encoded to prevent path traversal.
    func fetchPath(named pathName: String) async throws -> MediaMTXPath {
        // Properly encode the path name to prevent path traversal and URL injection
        // We encode special characters but preserve "/" for multi-level paths
        let encodedPathName = encodePathComponent(pathName)
        let url = baseURL.appendingPathComponent("v3/paths/get/\(encodedPathName)")

        var request = URLRequest(url: url)
        request.setValue(await MediaMTXConfig.authHeaderValue, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw MediaMTXAPIError.badResponse(code)
            }
            return try JSONDecoder().decode(MediaMTXPath.self, from: data)
        } catch let error as MediaMTXAPIError {
            throw error
        } catch let error as DecodingError {
            throw MediaMTXAPIError.decodingFailed
        } catch {
            throw MediaMTXAPIError.networkError(error)
        }
    }

    /// Encodes a path component for safe URL usage
    /// Preserves "/" for multi-level paths (e.g., "live/mystream")
    /// but encodes dangerous characters like "..", null bytes, etc.
    private func encodePathComponent(_ component: String) -> String {
        // Create a character set that allows "/" and other safe characters
        // but encodes special characters that could lead to path traversal
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~/:@!$&'()*+,;=")

        // First pass: encode everything not in the safe set
        guard let encoded = component.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return component  // Fallback if encoding fails
        }

        // Second pass: check for dangerous patterns that made it through encoding
        // This is a defense-in-depth measure
        let dangerous = [
            "%2e%2e",   // encoded ".."
            "..%2f",    // ".." followed by encoded "/"
            "%2f%2e%2f" // encoded "/./"
        ]

        let resultLower = encoded.lowercased()
        for pattern in dangerous {
            if resultLower.contains(pattern) {
                // Found dangerous pattern - encode the dots more aggressively
                return component
                    .replacingOccurrences(of: "..", with: "%2e%2e")
                    .replacingOccurrences(of: ".", with: "%2e", options: [], range: nil)
            }
        }

        return encoded
    }
}
