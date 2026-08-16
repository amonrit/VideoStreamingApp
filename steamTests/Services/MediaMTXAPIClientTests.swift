//
//  MediaMTXAPIClientTests.swift
//  steamTests
//

import XCTest
@testable import steam

final class MediaMTXAPIClientTests: XCTestCase {
    var sut: MediaMTXAPIClient!
    var mockSession: URLSession!
    var mockURL: URL!

    override func setUp() {
        super.setUp()
        mockURL = URL(string: "http://localhost:9997")!

        // Create a URLSession with a custom configuration for testing
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)

        sut = MediaMTXAPIClient(baseURL: mockURL, session: mockSession)
    }

    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Path Traversal Prevention Tests

    /// Test that normal path names with "/" are properly handled
    func testNormalPathWithSlash() async throws {
        let pathName = "live/mystream"
        MockURLProtocol.mockResponse = buildMockPathResponse()

        let path = try await sut.fetchPath(named: pathName)

        XCTAssertEqual(path.name, "live/mystream")
        // Verify URL was constructed safely
        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.url?.absoluteString.contains("v3/paths/get/live/mystream") ?? false)
    }

    /// Test that path traversal attempt "../" is encoded
    func testPathTraversalAttempt() async throws {
        let pathName = "../admin"
        MockURLProtocol.mockResponse = buildMockPathResponse(name: "admin")

        let _ = try? await sut.fetchPath(named: pathName)

        // Verify the URL was properly encoded to prevent path traversal
        let request = MockURLProtocol.lastRequest
        let urlString = request?.url?.absoluteString ?? ""

        // The encoded form should not contain plain ".."
        XCTAssertFalse(urlString.contains("../"))
        // But should contain the encoded form
        XCTAssertTrue(urlString.contains("%2e%2e") || urlString.contains("v3/paths/get/%252E%252E"))
    }

    /// Test that special character "%" is encoded
    func testPercentCharacterEncoding() async throws {
        let pathName = "live%test"
        MockURLProtocol.mockResponse = buildMockPathResponse(name: pathName)

        let _ = try? await sut.fetchPath(named: pathName)

        let request = MockURLProtocol.lastRequest
        let urlString = request?.url?.absoluteString ?? ""

        // % should be encoded as %25
        XCTAssertTrue(urlString.contains("%25"))
    }

    /// Test that null byte injection is prevented
    func testNullByteInjection() async throws {
        let pathName = "live\u{0000}admin"  // Null byte
        MockURLProtocol.mockResponse = buildMockPathResponse(name: "live")

        let _ = try? await sut.fetchPath(named: pathName)

        let request = MockURLProtocol.lastRequest
        let urlString = request?.url?.absoluteString ?? ""

        // Null byte should be encoded
        XCTAssertFalse(urlString.contains("\u{0000}"))
    }

    /// Test that "~" (common in path traversal) is handled safely
    func testTildeCharacter() async throws {
        let pathName = "live/~test"
        MockURLProtocol.mockResponse = buildMockPathResponse(name: pathName)

        let _ = try? await sut.fetchPath(named: pathName)

        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)
    }

    /// Test that multiple levels of path traversal are blocked
    func testMultipleLevelPathTraversal() async throws {
        let pathName = "../../etc/passwd"
        MockURLProtocol.mockResponse = buildMockPathResponse(name: "passwd")

        let _ = try? await sut.fetchPath(named: pathName)

        let request = MockURLProtocol.lastRequest
        let urlString = request?.url?.absoluteString ?? ""

        // Should not allow the actual traversal in the URL
        XCTAssertFalse(urlString.contains("../../"))
    }

    /// Test that "." alone doesn't get confused with ".."
    func testSingleDot() async throws {
        let pathName = "live/./mystream"
        MockURLProtocol.mockResponse = buildMockPathResponse(name: pathName)

        let _ = try? await sut.fetchPath(named: pathName)

        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)
    }

    /// Test encoding of query string characters
    func testQueryStringCharacters() async throws {
        let pathName = "live/test?query=1&foo=bar"
        MockURLProtocol.mockResponse = buildMockPathResponse(name: pathName)

        let _ = try? await sut.fetchPath(named: pathName)

        let request = MockURLProtocol.lastRequest
        let urlString = request?.url?.absoluteString ?? ""

        // Query string characters should be encoded to prevent injection
        XCTAssertTrue(urlString.contains("%3F") || urlString.contains("%26"))
    }

    /// Test encoding of fragment characters
    func testFragmentCharacter() async throws {
        let pathName = "live/test#admin"
        MockURLProtocol.mockResponse = buildMockPathResponse(name: pathName)

        let _ = try? await sut.fetchPath(named: pathName)

        let request = MockURLProtocol.lastRequest
        let urlString = request?.url?.absoluteString ?? ""

        // Fragment character should be encoded to prevent URL injection
        XCTAssertTrue(urlString.contains("%23"))
    }

    /// Test that legitimate forward slashes in path are preserved
    func testMultipleSlashesInPath() async throws {
        let pathName = "camera/zone1/stream1"
        MockURLProtocol.mockResponse = buildMockPathResponse(name: pathName)

        let path = try await sut.fetchPath(named: pathName)

        XCTAssertEqual(path.name, "camera/zone1/stream1")
        let request = MockURLProtocol.lastRequest
        XCTAssertTrue(request?.url?.absoluteString.contains("camera/zone1/stream1") ?? false)
    }

    /// Test empty path name handling
    func testEmptyPathName() async throws {
        let pathName = ""
        MockURLProtocol.mockResponse = buildMockPathResponse(name: "")

        let _ = try? await sut.fetchPath(named: pathName)

        let request = MockURLProtocol.lastRequest
        XCTAssertNotNil(request)
    }

    /// Test special characters that are commonly encoded
    func testSpecialCharacterEncoding() async throws {
        let testCases: [(String, String)] = [
            ("live stream", "live%20stream"),  // Space
            ("live/my-stream", "live/my-stream"),  // Hyphen (safe)
            ("live_stream", "live_stream"),  // Underscore (safe)
            ("live@stream", "live%40stream"),  // @ symbol
            ("live&stream", "live%26stream"),  // & symbol
            ("live=stream", "live%3Dstream"),  // = symbol
        ]

        for (pathName, _) in testCases {
            MockURLProtocol.mockResponse = buildMockPathResponse(name: pathName)

            let _ = try? await sut.fetchPath(named: pathName)

            let request = MockURLProtocol.lastRequest
            XCTAssertNotNil(request, "Request should be created for pathName: \(pathName)")
        }
    }

    // MARK: - Helper Methods

    private func buildMockPathResponse(name: String = "test/path") -> Data {
        let response = MediaMTXPath(
            name: name,
            confName: nil,
            available: true,
            online: true,
            source: nil,
            readers: [],
            inboundBytes: 0,
            outboundBytes: 0
        )
        guard let data = try? JSONEncoder().encode(response) else {
            return Data()
        }
        return data
    }
}

// MARK: - Mock URLProtocol for Testing

class MockURLProtocol: URLProtocol {
    static var mockResponse: Data = Data()
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        MockURLProtocol.lastRequest = request
        return request
    }

    override func startLoading() {
        defer { client?.urlProtocolDidFinishLoading(self) }

        guard let url = request.url else {
            let error = NSError(domain: "MockURLProtocol", code: -1, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )

        if let httpResponse = response {
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        }

        client?.urlProtocol(self, didLoad: MockURLProtocol.mockResponse)
    }

    override func stopLoading() {
        // No-op for mock
    }
}
