import Foundation

// MARK: - Get Viewer Count Use Case

/// Use case for fetching viewer count for a stream
///
/// Responsibilities:
/// - Request viewer count from data source
/// - Handle errors gracefully
/// - Track failure counts
protocol GetViewerCountUseCaseProtocol {
    func execute(forStreamId streamId: String) async throws -> Int
}

class GetViewerCountUseCase: GetViewerCountUseCaseProtocol {
    private let streamRepository: StreamRepository

    init(streamRepository: StreamRepository) {
        self.streamRepository = streamRepository
    }

    /// Get viewer count for a stream
    /// - Parameter streamId: The ID of the stream
    /// - Returns: Number of viewers
    /// - Throws: Error if API call fails
    func execute(forStreamId streamId: String) async throws -> Int {
        do {
            let count = try await streamRepository.getViewerCount(for: streamId)
            return count
        } catch {
            throw ViewerCountError.fetchFailed(error.localizedDescription)
        }
    }
}

// MARK: - Viewer Count Errors

enum ViewerCountError: LocalizedError {
    case fetchFailed(String)
    case invalidStreamId
    case networkTimeout

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let reason):
            return "Failed to fetch viewer count: \(reason)"
        case .invalidStreamId:
            return "Invalid stream ID"
        case .networkTimeout:
            return "Viewer count request timed out"
        }
    }
}
