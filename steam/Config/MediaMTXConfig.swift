//
//  MediaMTXConfig.swift
//  steam
//

import Foundation

/// MediaMTX API configuration and credentials
enum MediaMTXConfig {
    // MARK: - Credentials
    static let apiUsername = "apiviewer"
    static let apiPassword = "changeme123"  // Keep in sync with streaming/.env API_VIEWER_PASS

    // MARK: - Computed Auth Header
    static var authHeaderValue: String {
        let raw = "\(apiUsername):\(apiPassword)"
        let data = Data(raw.utf8)
        let encoded = data.base64EncodedString()
        return "Basic \(encoded)"
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
