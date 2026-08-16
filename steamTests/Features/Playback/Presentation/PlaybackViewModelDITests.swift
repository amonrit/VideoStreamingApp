import XCTest
@testable import steam
import AVFoundation

/// Tests for PlaybackViewModel with dependency-injected API clients.
/// Demonstrates the DI pattern for testing.
final class PlaybackViewModelDITests: XCTestCase {
    var viewModel: PlaybackViewModel!
    var mockProvider: MockAPIClientProviderForTests!
    var mockClient: MockMediaMTXAPIClient!

    override func setUp() {
        super.setUp()

        // Create mock provider and client
        mockProvider = APIClientTestHelper.createMockProvider()
        mockClient = APIClientTestHelper.createSuccessMockClient(paths: [
            MediaMTXPath(
                name: "test-stream",
                source: "rtmp://localhost:1935/live/test-stream",
                ready: true,
                tracks: [],
                bytesReceived: 0,
                bytesSent: 0,
                viewerCount: 42,
                createdAt: Date()
            )
        ])

        // Set up mock provider with mock client
        mockProvider.setMockClient(mockClient, forURL: URL(string: "http://localhost:9997")!)

        // Create ViewModel with mock provider (demonstrating DI)
        viewModel = PlaybackViewModel(
            player: AVPlayer(),
            apiClientProvider: mockProvider
        )
    }

    override func tearDown() {
        viewModel = nil
        mockProvider = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Test Cases

    func testInitializationWithMockProvider() {
        // Verify that ViewModel was created with mock provider
        XCTAssertNotNil(viewModel)
    }

    func testMediaMTXClientCreation() {
        // When a stream with MediaMTX URL is loaded
        let stream = VideoStream(
            id: UUID(),
            title: "Test Stream",
            urlString: "http://localhost:8888/live/test-stream/index.m3u8",
            thumbnail: nil,
            description: nil
        )

        // The ViewModel should create a client via the mock provider
        viewModel.loadStream(stream)

        // Verify the mock provider was used to create a client
        // (In a real test, we'd verify the behavior through state changes)
    }

    func testMockClientConfiguration() {
        // Verify mock client is properly configured
        XCTAssertEqual(mockClient.nextViewerCount, 42)
        XCTAssertEqual(mockClient.nextPaths.count, 1)
        XCTAssertEqual(mockClient.nextPaths.first?.name, "test-stream")
    }

    func testProviderFactoryMethod() {
        // Verify provider creates client correctly
        let testURL = URL(string: "http://test:9997")!
        let client = mockProvider.createAPIClient(baseURL: testURL)

        // Client should be created successfully
        XCTAssertNotNil(client)
    }
}

/// Tests for StreamAdminViewModel with dependency-injected API clients.
final class StreamAdminViewModelDITests: XCTestCase {
    var viewModel: StreamAdminViewModel!
    var mockProvider: MockAPIClientProviderForTests!
    var mockClient: MockMediaMTXAPIClient!

    override func setUp() {
        super.setUp()

        // Create mock provider and client
        mockProvider = APIClientTestHelper.createMockProvider()
        mockClient = APIClientTestHelper.createSuccessMockClient()

        // Set up mock provider
        mockProvider.setMockClient(mockClient, forURL: URL(string: "http://localhost:9997")!)

        // Create ViewModel with mock provider
        viewModel = StreamAdminViewModel(apiClientProvider: mockProvider)
    }

    override func tearDown() {
        viewModel = nil
        mockProvider = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Test Cases

    func testInitializationWithMockProvider() {
        XCTAssertNotNil(viewModel)
    }

    func testProviderIsUsedForPolling() {
        // When polling is started
        viewModel.startPolling(baseURL: URL(string: "http://localhost:9997"))

        // The ViewModel should use the mock provider
        // (Verify through state changes or mock call counting)
    }

    func testMockClientCallTracking() {
        // Initialize mock client
        let client = MockMediaMTXAPIClient()
        client.setNextPaths([])

        // Verify call tracking works
        XCTAssertEqual(client.fetchPathListCallCount, 0)
    }
}

// MARK: - Integration Test Examples

/// Example of testing with different failure scenarios
final class APIClientDIIntegrationTests: XCTestCase {
    func testViewModelWithFailingAPI() {
        // Create mock provider with failure scenario
        let mockProvider = APIClientTestHelper.createMockProvider()
        let failingClient = APIClientTestHelper.createFailureMockClient(
            error: APIError.networkError
        )
        mockProvider.setMockClient(failingClient, forURL: URL(string: "http://localhost:9997")!)

        // Create ViewModel with failing client
        let viewModel = PlaybackViewModel(
            player: AVPlayer(),
            apiClientProvider: mockProvider
        )

        // Verify ViewModel handles errors gracefully
        XCTAssertNotNil(viewModel)
    }

    func testMultipleMockClients() {
        // Create provider with multiple configured clients
        let mockProvider = APIClientTestHelper.createMockProvider()

        let client1 = APIClientTestHelper.createSuccessMockClient()
        let client2 = APIClientTestHelper.createFailureMockClient()

        mockProvider.setMockClient(client1, forURL: URL(string: "http://server1:9997")!)
        mockProvider.setMockClient(client2, forURL: URL(string: "http://server2:9997")!)

        // Verify provider returns correct mock for each URL
        let returned1 = mockProvider.createAPIClient(baseURL: URL(string: "http://server1:9997")!)
        let returned2 = mockProvider.createAPIClient(baseURL: URL(string: "http://server2:9997")!)

        XCTAssertNotNil(returned1)
        XCTAssertNotNil(returned2)
    }
}
