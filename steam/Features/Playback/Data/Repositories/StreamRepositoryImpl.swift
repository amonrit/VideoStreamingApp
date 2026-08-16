import Foundation

// MARK: - Stream Repository Implementation

/// Concrete implementation of StreamRepository
/// Coordinates between remote and local data sources
class StreamRepositoryImpl: StreamRepository {
    private let remoteDataSource: StreamRemoteDataSource

    init(remoteDataSource: StreamRemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }

    /// Load a stream from a given URL
    func loadStream(from url: String) async throws -> VideoStream {
        // For now, create VideoStream directly from URL
        // In future, could fetch metadata from API
        return VideoStream(
            title: extractTitleFromURL(url),
            urlString: url,
            thumbnailURLString: "https://via.placeholder.com/400x300?text=Stream"
        )
    }

    /// Get the list of available streams
    func getStreams() async throws -> [VideoStream] {
        try await remoteDataSource.fetchStreams()
    }

    /// Get viewer count for a specific stream
    func getViewerCount(for streamId: String) async throws -> Int {
        try await remoteDataSource.fetchViewerCount(streamId: streamId)
    }

    // MARK: - Helper Methods

    private func extractTitleFromURL(_ urlString: String) -> String {
        if let url = URL(string: urlString) {
            return url.lastPathComponent.replacingOccurrences(of: ".m3u8", with: "")
                .replacingOccurrences(of: ".mpd", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .uppercased()
        }
        return "Stream"
    }
}
