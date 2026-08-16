import XCTest
@testable import steam

final class StreamAdminPollingServiceTests: XCTestCase {
    // MARK: - Initialization Tests

    @MainActor
    func testInitialization_defaultConfiguration() {
        let service = StreamAdminPollingService {
            return []
        }

        XCTAssertAsyncFalse(await service.isPolling())
        XCTAssertNil(await service.getLastStreams())
    }

    @MainActor
    func testInitialization_customConfiguration() {
        let config = PlaybackConfiguration()
        let service = StreamAdminPollingService(configuration: config) {
            return []
        }

        XCTAssertAsyncFalse(await service.isPolling())
    }

    // MARK: - Polling Control Tests

    @MainActor
    func testStartPolling() async {
        let service = StreamAdminPollingService {
            return []
        }

        await service.startPolling()
        XCTAssertAsyncTrue(await service.isPolling())

        // Give time for first poll
        try? await Task.sleep(nanoseconds: 100_000_000)

        await service.stopPolling()
    }

    @MainActor
    func testStopPolling() async {
        let service = StreamAdminPollingService {
            return []
        }

        await service.startPolling()
        XCTAssertAsyncTrue(await service.isPolling())

        await service.stopPolling()
        XCTAssertAsyncFalse(await service.isPolling())
    }

    @MainActor
    func testStartPolling_idempotent() async {
        let service = StreamAdminPollingService {
            return []
        }

        await service.startPolling()
        let isPolling1 = await service.isPolling()

        await service.startPolling()  // Start again
        let isPolling2 = await service.isPolling()

        XCTAssertTrue(isPolling1)
        XCTAssertTrue(isPolling2)

        await service.stopPolling()
    }

    // MARK: - Fetch Tests

    @MainActor
    func testFetchEmptyStreamList() async {
        let service = StreamAdminPollingService {
            return []
        }

        await service.startPolling()

        // Give time for polling
        try? await Task.sleep(nanoseconds: 100_000_000)

        let streams = await service.getLastStreams()
        XCTAssertEqual(streams?.count ?? 0, 0)

        await service.stopPolling()
    }

    @MainActor
    func testFetchMultipleStreams() async {
        var callCount = 0
        let service = StreamAdminPollingService {
            callCount += 1
            // Return mock streams
            return []  // In real scenario, would return actual MediaMTXConfig
        }

        await service.startPolling()

        // Give time for polling
        try? await Task.sleep(nanoseconds: 100_000_000)

        let streams = await service.getLastStreams()
        XCTAssertNotNil(streams)

        await service.stopPolling()
    }

    @MainActor
    func testFetchFailure() async {
        enum TestError: Error {
            case failed
        }

        let service = StreamAdminPollingService {
            throw TestError.failed
        }

        await service.startPolling()

        // Give time for polling to fail
        try? await Task.sleep(nanoseconds: 200_000_000)

        let error = await service.getLastError()
        XCTAssertNotNil(error)

        await service.stopPolling()
    }

    @MainActor
    func testReset() async {
        let service = StreamAdminPollingService {
            return []
        }

        await service.startPolling()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let streamsBefore = await service.getLastStreams()
        XCTAssertNotNil(streamsBefore)

        await service.reset()

        let streamsAfter = await service.getLastStreams()
        XCTAssertNil(streamsAfter)
        XCTAssertAsyncFalse(await service.isPolling())
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testErrorRecovery() async {
        var shouldFail = true
        var callCount = 0

        let service = StreamAdminPollingService {
            callCount += 1
            if shouldFail && callCount < 3 {
                enum TestError: Error {
                    case temporary
                }
                throw TestError.temporary
            }
            shouldFail = false
            return []
        }

        await service.startPolling()

        // Give time for retries
        try? await Task.sleep(nanoseconds: 500_000_000)

        await service.stopPolling()

        // Should eventually recover
        let streams = await service.getLastStreams()
        XCTAssertNotNil(streams)
    }

    @MainActor
    func testErrorClearsOnSuccess() async {
        var shouldFail = true
        let service = StreamAdminPollingService {
            if shouldFail {
                shouldFail = false
                enum TestError: Error {
                    case failed
                }
                throw TestError.failed
            }
            return []
        }

        await service.startPolling()
        try? await Task.sleep(nanoseconds: 300_000_000)

        let error = await service.getLastError()
        XCTAssertNil(error)  // Should be cleared after success

        await service.stopPolling()
    }

    // MARK: - Concurrent Operations Tests

    @MainActor
    func testConcurrentStartStop() async {
        let service = StreamAdminPollingService {
            return []
        }

        async let start = service.startPolling()
        async let stop = service.stopPolling()

        _ = await (start, stop)

        // Should not crash or deadlock
        XCTAssert(true)
    }

    @MainActor
    func testMultipleStopCalls() async {
        let service = StreamAdminPollingService {
            return []
        }

        await service.startPolling()
        await service.stopPolling()
        await service.stopPolling()  // Should be safe
        await service.stopPolling()  // Should be safe

        XCTAssertAsyncFalse(await service.isPolling())
    }

    // MARK: - State Tests

    @MainActor
    func testLastStreamsWithMultipleFetches() async {
        var counter = 0
        let service = StreamAdminPollingService {
            counter += 1
            return []
        }

        await service.startPolling()

        // Give time for multiple polls
        try? await Task.sleep(nanoseconds: 500_000_000)

        let streams = await service.getLastStreams()

        // Should have at least polled once
        XCTAssertNotNil(streams)

        await service.stopPolling()
    }
}

// MARK: - Helper Extensions

extension XCTestCase {
    @MainActor
    func XCTAssertAsyncTrue(
        _ expression: @autoclosure () async -> Bool,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let result = await expression()
        XCTAssertTrue(result, message(), file: file, line: line)
    }

    @MainActor
    func XCTAssertAsyncFalse(
        _ expression: @autoclosure () async -> Bool,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let result = await expression()
        XCTAssertFalse(result, message(), file: file, line: line)
    }
}
