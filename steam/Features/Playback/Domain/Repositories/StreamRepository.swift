import Foundation

// MARK: - Stream Operations Protocol

/// Protocol defining the contract for stream operations
/// Implementation will be in Data layer (StreamRepositoryImpl)
protocol StreamRepository {
    /// Load a stream from a given URL
    func loadStream(from url: String) async throws -> VideoStream

    /// Get the list of available streams
    func getStreams() async throws -> [VideoStream]

    /// Get viewer count for a specific stream
    func getViewerCount(for streamId: String) async throws -> Int
}
