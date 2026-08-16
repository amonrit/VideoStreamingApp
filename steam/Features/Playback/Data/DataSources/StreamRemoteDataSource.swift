import Foundation

// MARK: - Stream Remote Data Source

/// Protocol for remote stream data operations
protocol StreamRemoteDataSource {
    /// Fetch list of available streams
    func fetchStreams() async throws -> [VideoStream]

    /// Fetch viewer count for a stream
    func fetchViewerCount(streamId: String) async throws -> Int
}

// MARK: - Default Implementation

/// Default remote data source implementation using MediaMTXAPIClient
class StreamRemoteDataSourceImpl: StreamRemoteDataSource {
    private let apiClient: MediaMTXAPIClient

    init(apiClient: MediaMTXAPIClient) {
        self.apiClient = apiClient
    }

    /// Fetch available streams from MediaMTX server
    func fetchStreams() async throws -> [VideoStream] {
        // This would make an API call to fetch active streams from MediaMTX
        // For now, return sample streams
        return VideoStream.sampleStreams
    }

    /// Fetch viewer count from MediaMTX API
    func fetchViewerCount(streamId: String) async throws -> Int {
        // This would call the MediaMTX API to get viewer metrics
        // Implement based on MediaMTXAPIClient capabilities
        let response = try await apiClient.getStreamStats(pathName: streamId)
        return response.viewerCount ?? 0
    }
}
