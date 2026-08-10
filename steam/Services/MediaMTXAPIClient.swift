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

/// MediaMTX Control API v3 client
final class MediaMTXAPIClient {
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
        request.setValue(MediaMTXConfig.authHeaderValue, forHTTPHeaderField: "Authorization")
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
    /// Path names may contain "/" (e.g. "live/mystream") — passed through as-is.
    func fetchPath(named pathName: String) async throws -> MediaMTXPath {
        let url = baseURL.appendingPathComponent("v3/paths/get/\(pathName)")
        var request = URLRequest(url: url)
        request.setValue(MediaMTXConfig.authHeaderValue, forHTTPHeaderField: "Authorization")
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
}
