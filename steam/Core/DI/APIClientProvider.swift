import Foundation

/// Protocol for providing MediaMTXAPIClient instances.
/// Enables dependency injection and testing with mock clients.
protocol APIClientProvider {
    /// Creates an API client for the specified base URL
    /// - Parameter baseURL: The base URL for the API client
    /// - Returns: Configured MediaMTXAPIClient instance
    func createAPIClient(baseURL: URL) -> MediaMTXAPIClientProtocol

    /// Gets the default API client (if configured)
    /// - Returns: Default MediaMTXAPIClient or nil
    func getDefaultClient() -> MediaMTXAPIClientProtocol?
}

/// Default production implementation of APIClientProvider.
/// Creates real MediaMTXAPIClient instances for production use.
final class DefaultAPIClientProvider: APIClientProvider {
    private let defaultBaseURL: URL?

    /// Initializes with optional default base URL
    /// - Parameter defaultBaseURL: Optional default base URL (defaults to localhost:9997)
    init(defaultBaseURL: URL? = nil) {
        self.defaultBaseURL = defaultBaseURL ?? URL(string: "http://localhost:9997")
    }

    func createAPIClient(baseURL: URL) -> MediaMTXAPIClientProtocol {
        MediaMTXAPIClient(baseURL: baseURL)
    }

    func getDefaultClient() -> MediaMTXAPIClientProtocol? {
        guard let url = defaultBaseURL else { return nil }
        return MediaMTXAPIClient(baseURL: url)
    }
}

/// Mock implementation of APIClientProvider for testing.
/// Allows injection of mock clients with controlled behavior.
final class MockAPIClientProvider: APIClientProvider {
    private var mockClients: [String: MediaMTXAPIClientProtocol] = [:]
    var defaultMockClient: MediaMTXAPIClientProtocol?

    /// Initializes with no mock clients (can be added later)
    init() {}

    /// Sets a mock client for a specific base URL
    /// - Parameters:
    ///   - mockClient: The mock client to use
    ///   - forURL: The base URL key (uses absoluteString)
    func setMockClient(_ mockClient: MediaMTXAPIClientProtocol, forURL url: URL) {
        mockClients[url.absoluteString] = mockClient
    }

    func createAPIClient(baseURL: URL) -> MediaMTXAPIClientProtocol {
        if let mockClient = mockClients[baseURL.absoluteString] {
            return mockClient
        }
        if let defaultMock = defaultMockClient {
            return defaultMock
        }
        // Fallback to real client if no mock configured
        return MediaMTXAPIClient(baseURL: baseURL)
    }

    func getDefaultClient() -> MediaMTXAPIClientProtocol? {
        defaultMockClient
    }
}
