import Foundation
import AVFoundation

// MARK: - Load Stream Use Case

/// Use case for loading a stream and preparing it for playback
///
/// Responsibilities:
/// - Validate stream URL
/// - Create appropriate AVAsset from URL
/// - Handle URL loading errors
/// - Return playable asset or error
protocol LoadStreamUseCaseProtocol {
    func execute(stream: VideoStream) async throws -> AVAsset
}

class LoadStreamUseCase: LoadStreamUseCaseProtocol {
    private let urlValidator: URLValidator

    init(urlValidator: URLValidator = URLValidator()) {
        self.urlValidator = urlValidator
    }

    /// Load a stream and return a playable AVAsset
    /// - Parameter stream: The VideoStream to load
    /// - Returns: An AVAsset ready for playback
    /// - Throws: Error if URL is invalid or asset cannot be created
    func execute(stream: VideoStream) async throws -> AVAsset {
        // 1. Validate URL
        guard let url = stream.url else {
            throw StreamError.invalidURL("Stream URL is nil")
        }

        // 2. Validate URL against whitelist
        guard urlValidator.isValidStreamURL(url.absoluteString) else {
            let message = urlValidator.getValidationErrorMessage(for: url.absoluteString)
            throw StreamError.urlNotWhitelisted(message)
        }

        // 3. Create and return AVAsset
        let asset = AVURLAsset(url: url)
        return asset
    }
}

// MARK: - Stream Errors

enum StreamError: LocalizedError {
    case invalidURL(String)
    case urlNotWhitelisted(String)
    case assetLoadingFailed(String)
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .urlNotWhitelisted(let url):
            return "URL not whitelisted: \(url)"
        case .assetLoadingFailed(let reason):
            return "Failed to load asset: \(reason)"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        }
    }
}
