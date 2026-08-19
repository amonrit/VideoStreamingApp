import XCTest
@testable import steam

final class StreamAdminPollingServiceTests: XCTestCase {
    // MARK: - Initialization Tests

    @MainActor
    func testInitialization_defaultConfiguration() async {
        let service = StreamAdminPollingService {
            return 0
        }

        await XCTAssertAsyncFalse(await service.isPolling())
        XCTAssertNil(service.getLastUpdateTime())
    }

    @MainActor
    func testInitialization_customConfiguration() async {
        let config = PlaybackConfiguration()
        let service = StreamAdminPollingService(configuration: config) {
            return 0
        }

        await XCTAssertAsyncFalse(await service.isPolling())
    }

    // MARK: - Polling Control Tests

    @MainActor
    func testStartPolling() async {
        let service = StreamAdminPollingService {
            return 0
        }

        await service.startPolling()
        await XCTAssertAsyncTrue(await service.isPolling())

        // Give time for first poll
        try? await Task.sleep(nanoseconds: 100_000_000)

        await service.stopPolling()
    }

    @MainActor
    func testStopPolling() async {
        let service = StreamAdminPollingService {
            return 0
        }

        await service.startPolling()
        await XCTAssertAsyncTrue(await service.isPolling())

        await service.stopPolling()
        await XCTAssertAsyncFalse(await service.isPolling())
    }

    @MainActor
    func testStartPolling_idempotent() async {
        let service = StreamAdminPollingService {
            return 0
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
            return 0
        }

        await service.startPolling()

        // Give time for polling
        try? await Task.sleep(nanoseconds: 100_000_000)

        let lastUpdateTime = await service.getLastUpdateTime()
        XCTAssertNotNil(lastUpdateTime)
        let error = await service.getLastError()
        XCTAssertNil(error)

        await service.stopPolling()
    }

    @MainActor
    func testFetchMultipleStreams() async {
        var callCount = 0
        let service = StreamAdminPollingService {
            callCount += 1
            // Return mock stream count
            return callCount  // In real scenario, would return pathList.items.count
        }

        await service.startPolling()

        // Give time for polling
        try? await Task.sleep(nanoseconds: 100_000_000)

        let lastUpdateTime = await service.getLastUpdateTime()
        XCTAssertNotNil(lastUpdateTime)

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
            return 0
        }

        await service.startPolling()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let updateTimeBefore = await service.getLastUpdateTime()
        XCTAssertNotNil(updateTimeBefore)

        await service.reset()

        let updateTimeAfter = await service.getLastUpdateTime()
        XCTAssertNil(updateTimeAfter)
        await XCTAssertAsyncFalse(await service.isPolling())
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
            return 0
        }

        await service.startPolling()

        // Give time for retries
        try? await Task.sleep(nanoseconds: 500_000_000)

        await service.stopPolling()

        // Should eventually recover
        let lastUpdateTime = await service.getLastUpdateTime()
        XCTAssertNotNil(lastUpdateTime)
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
            return 0
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
            return 0
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
            return 0
        }

        await service.startPolling()
        await service.stopPolling()
        await service.stopPolling()  // Should be safe
        await service.stopPolling()  // Should be safe

        await XCTAssertAsyncFalse(await service.isPolling())
    }

    // MARK: - State Tests

    @MainActor
    func testLastStreamsWithMultipleFetches() async {
        var counter = 0
        let service = StreamAdminPollingService {
            counter += 1
            return counter
        }

        await service.startPolling()

        // Give time for multiple polls
        try? await Task.sleep(nanoseconds: 500_000_000)

        let lastUpdateTime = await service.getLastUpdateTime()

        // Should have at least polled once
        XCTAssertNotNil(lastUpdateTime)

        await service.stopPolling()
    }
}

// MARK: - Helper Extensions
//
// XCTAssertAsyncTrue/XCTAssertAsyncFalse are defined once, on XCTestCase,
// in ViewerCountPollingServiceTests.swift and shared across the test target.
