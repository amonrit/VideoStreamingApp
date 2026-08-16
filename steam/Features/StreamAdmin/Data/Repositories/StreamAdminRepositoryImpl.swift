import Foundation

// MARK: - Stream Admin Repository Implementation

/// Concrete implementation of StreamAdminRepository
class StreamAdminRepositoryImpl: StreamAdminRepository {
    private let remoteDataSource: StreamAdminRemoteDataSource

    init(remoteDataSource: StreamAdminRemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }

    /// Get all available paths
    func getPaths() async throws -> [MediaMTXPath] {
        try await remoteDataSource.fetchPaths()
    }

    /// Start a stream on a path
    func startStream(on path: String) async throws {
        try await remoteDataSource.startPath(path)
    }

    /// Stop a stream on a path
    func stopStream(on path: String) async throws {
        try await remoteDataSource.stopPath(path)
    }

    /// Get configuration for a path
    func getPathConfig(for path: String) async throws -> MediaMTXPath {
        try await remoteDataSource.fetchPathConfig(path)
    }
}
