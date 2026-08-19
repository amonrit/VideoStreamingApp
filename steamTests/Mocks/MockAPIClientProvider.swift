import Foundation
@testable import steam

/// Mock implementation of APIClientProvider for testing.
/// Allows injection of controlled mock clients.
final class MockAPIClientProviderForTests: APIClientProvider {
    private var mockClients: [String: MockMediaMTXAPIClient] = [:]
    var defaultMockClient: MockMediaMTXAPIClient?

    /// Initializes with no mock clients
    init() {}

    /// Sets a mock client for a specific base URL
    func setMockClient(_ mockClient: MockMediaMTXAPIClient, forURL url: URL) {
        mockClients[url.absoluteString] = mockClient
    }

    /// Gets a mock client for a URL (creates if needed)
    func getMockClient(forURL url: URL) -> MockMediaMTXAPIClient {
        if let existing = mockClients[url.absoluteString] {
            return existing
        }
        let newMock = MockMediaMTXAPIClient()
        mockClients[url.absoluteString] = newMock
        return newMock
    }

    func createAPIClient(baseURL: URL) -> MediaMTXAPIClientProtocol {
        if let mockClient = mockClients[baseURL.absoluteString] {
            return mockClient
        }
        if let defaultMock = defaultMockClient {
            return defaultMock
        }
        // Return default mock if nothing configured
        return MockMediaMTXAPIClient()
    }

    func getDefaultClient() -> MediaMTXAPIClientProtocol? {
        defaultMockClient
    }
}

/// Mock implementation of MediaMTXAPIClientProtocol for testing.
/// Allows control of responses and verification of calls, without depending
/// on the (intentionally `final`) production `MediaMTXAPIClient` class.
final class MockMediaMTXAPIClient: MediaMTXAPIClientProtocol {
    // Control mock responses
    var nextPaths: [MediaMTXPath] = []
    var nextViewerCount: Int = 0
    var nextError: Error?
    var shouldFail: Bool = false

    // Track calls
    var fetchPathListCallCount: Int = 0
    var fetchPathCallCount: Int = 0
    var fetchPathNames: [String] = []

    /// Initializes mock client
    init() {}

    // MARK: - Mock Configuration

    /// Set paths to return on next fetchPathList() call
    func setNextPaths(_ paths: [MediaMTXPath]) {
        self.nextPaths = paths
    }

    /// Set viewer count to return on next fetchPath() call
    func setNextViewerCount(_ count: Int) {
        self.nextViewerCount = count
    }

    /// Set error to throw on next API call
    func setNextError(_ error: Error) {
        self.nextError = error
        self.shouldFail = true
    }

    /// Reset all mock state
    func reset() {
        nextPaths = []
        nextViewerCount = 0
        nextError = nil
        shouldFail = false
        fetchPathListCallCount = 0
        fetchPathCallCount = 0
        fetchPathNames = []
    }

    // MARK: - Mock Verification

    /// Verify fetchPathList was called
    func verifyFetchPathListCalled(_ count: Int = 1) -> Bool {
        fetchPathListCallCount == count
    }

    /// Verify fetchPath was called with specific path name
    func verifyFetchPathCalled(withName name: String, callCount: Int = 1) -> Bool {
        fetchPathNames.filter { $0 == name }.count == callCount
    }

    // MARK: - MediaMTXAPIClientProtocol

    /// Mock the paths fetching behavior
    func fetchPathList() async throws -> MediaMTXPathList {
        fetchPathListCallCount += 1

        if shouldFail, let error = nextError {
            throw error
        }

        return MediaMTXPathList(itemCount: nextPaths.count, pageCount: 1, items: nextPaths)
    }

    /// Mock the individual path fetching behavior
    func fetchPath(named pathName: String) async throws -> MediaMTXPath {
        fetchPathCallCount += 1
        fetchPathNames.append(pathName)

        if shouldFail, let error = nextError {
            throw error
        }

        // Return a mock path with the requested name and viewer count.
        // `viewerCount` is computed from `readers`, so synthesize that many.
        let readers = (0..<nextViewerCount).map { MediaMTXReader(type: "hlsSession", id: "\($0)") }
        return MediaMTXPath(
            name: pathName,
            confName: pathName,
            available: true,
            online: true,
            source: MediaMTXSource(type: "rtmpConn", id: "test"),
            readers: readers,
            inboundBytes: 1000,
            outboundBytes: 2000
        )
    }
}

// MARK: - Test Helpers

/// Helper for setting up test scenarios
class APIClientTestHelper {
    static func createMockProvider() -> MockAPIClientProviderForTests {
        MockAPIClientProviderForTests()
    }

    static func createMockProvider(withDefaultClient client: MockMediaMTXAPIClient) -> MockAPIClientProviderForTests {
        let provider = MockAPIClientProviderForTests()
        provider.defaultMockClient = client
        return provider
    }

    /// Creates a mock client configured for success
    static func createSuccessMockClient(paths: [MediaMTXPath] = []) -> MockMediaMTXAPIClient {
        let client = MockMediaMTXAPIClient()
        client.setNextPaths(paths)
        client.setNextViewerCount(42)
        return client
    }

    /// Creates a mock client configured for failure
    static func createFailureMockClient(error: Error = APIError.networkError) -> MockMediaMTXAPIClient {
        let client = MockMediaMTXAPIClient()
        client.setNextError(error)
        return client
    }

    /// Builds a `MediaMTXPath` fixture with the requested viewer count.
    /// `viewerCount` is computed from `readers`, so this synthesizes that many.
    static func makeTestPath(
        name: String,
        viewerCount: Int = 0,
        online: Bool = true
    ) -> MediaMTXPath {
        let readers = (0..<viewerCount).map { MediaMTXReader(type: "hlsSession", id: "\($0)") }
        return MediaMTXPath(
            name: name,
            confName: name,
            available: true,
            online: online,
            source: MediaMTXSource(type: "rtmpConn", id: "test"),
            readers: readers,
            inboundBytes: 0,
            outboundBytes: 0
        )
    }
}

// MARK: - Test Error Types

enum APIError: Error, Equatable {
    case networkError
    case invalidResponse
    case unauthorized

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized):
            return true
        default:
            return false
        }
    }
}
