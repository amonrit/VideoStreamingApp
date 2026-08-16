import Foundation

// MARK: - Stream Admin Operations Protocol

/// Protocol defining the contract for stream administration operations
protocol StreamAdminRepository {
    /// Get all available paths (streams)
    func getPaths() async throws -> [MediaMTXPath]

    /// Start a stream on a path
    func startStream(on path: String) async throws

    /// Stop a stream on a path
    func stopStream(on path: String) async throws

    /// Get configuration for a path
    func getPathConfig(for path: String) async throws -> MediaMTXPath
}
