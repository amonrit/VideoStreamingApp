import Foundation

// MARK: - Stream Admin Remote Data Source

/// Protocol for remote stream admin operations
protocol StreamAdminRemoteDataSource {
    /// Fetch all available paths
    func fetchPaths() async throws -> [MediaMTXPath]

    /// Fetch configuration for a specific path
    func fetchPathConfig(_ path: String) async throws -> MediaMTXPath

    /// Start a path (stream)
    func startPath(_ path: String) async throws

    /// Stop a path (stream)
    func stopPath(_ path: String) async throws
}

// MARK: - Default Implementation

/// Default remote data source using MediaMTXAPIClient
class StreamAdminRemoteDataSourceImpl: StreamAdminRemoteDataSource {
    private let apiClient: MediaMTXAPIClient

    init(apiClient: MediaMTXAPIClient) {
        self.apiClient = apiClient
    }

    /// Fetch all paths from MediaMTX
    func fetchPaths() async throws -> [MediaMTXPath] {
        let pathList = try await apiClient.fetchPathList()
        return pathList.items
    }

    /// Fetch configuration for specific path
    func fetchPathConfig(_ path: String) async throws -> MediaMTXPath {
        let pathConfig = try await apiClient.fetchPath(named: path)
        return pathConfig
    }

    /// Start a path
    func startPath(_ path: String) async throws {
        // TODO: Implement when MediaMTXAPIClient adds start/stop endpoints
        // For now, this is a placeholder
        print("Starting path: \(path)")
    }

    /// Stop a path
    func stopPath(_ path: String) async throws {
        // TODO: Implement when MediaMTXAPIClient adds start/stop endpoints
        // For now, this is a placeholder
        print("Stopping path: \(path)")
    }
}
