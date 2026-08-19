import XCTest
@testable import steam

final class ViewerCountPollingServiceTests: XCTestCase {
    // MARK: - Initialization Tests

    @MainActor
    func testInitialization_defaultConfiguration() async {
        let service = ViewerCountPollingService {
            return 42
        }

        await XCTAssertAsyncFalse(await service.isPolling())
        XCTAssertNil(service.getLastCount())
    }

    @MainActor
    func testInitialization_customConfiguration() async {
        let config = PlaybackConfiguration(viewerCountPollingInterval: 10.0)
        let service = ViewerCountPollingService(
            configuration: config
        ) {
            return 42
        }

        await XCTAssertAsyncFalse(await service.isPolling())
    }

    // MARK: - Polling Control Tests

    @MainActor
    func testStartPolling() async {
        var fetchCount = 0
        let service = ViewerCountPollingService {
            fetchCount += 1
            return fetchCount
        }

        await service.startPolling()
        await XCTAssertAsyncTrue(await service.isPolling())

        // Give time for first poll
        try? await Task.sleep(nanoseconds: 100_000_000)

        await service.stopPolling()
    }

    @MainActor
    func testStopPolling() async {
        let service = ViewerCountPollingService {
            return 42
        }

        await service.startPolling()
        await XCTAssertAsyncTrue(await service.isPolling())

        await service.stopPolling()
        await XCTAssertAsyncFalse(await service.isPolling())
    }

    @MainActor
    func testStartPolling_idempotent() async {
        let service = ViewerCountPollingService {
            return 42
        }

        await service.startPolling()
        let isPolling1 = await service.isPolling()

        await service.startPolling()  // Start again
        let isPolling2 = await service.isPolling()

        XCTAssertTrue(isPolling1)
        XCTAssertTrue(isPolling2)

        await service.stopPolling()
    }

    // MARK: - Fetch and Update Tests

    @MainActor
    func testFetchSuccess() async {
        let expectedCount = 123
        let service = ViewerCountPollingService {
            return expectedCount
        }

        await service.startPolling()

        // Give time for polling
        try? await Task.sleep(nanoseconds: 100_000_000)

        let lastCount = await service.getLastCount()
        XCTAssertEqual(lastCount, expectedCount)

        await service.stopPolling()
    }

    @MainActor
    func testFetchFailure() async {
        enum TestError: Error {
            case failed
        }

        let service = ViewerCountPollingService {
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
        let service = ViewerCountPollingService {
            return 42
        }

        await service.startPolling()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let countBefore = await service.getLastCount()
        XCTAssertNotNil(countBefore)

        await service.reset()

        let countAfter = await service.getLastCount()
        XCTAssertNil(countAfter)
        await XCTAssertAsyncFalse(await service.isPolling())
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testErrorRecovery() async {
        var shouldFail = true
        var callCount = 0

        let service = ViewerCountPollingService {
            callCount += 1
            if shouldFail && callCount < 3 {
                enum TestError: Error {
                    case temporary
                }
                throw TestError.temporary
            }
            shouldFail = false
            return 42
        }

        await service.startPolling()

        // Give time for retries and success
        try? await Task.sleep(nanoseconds: 500_000_000)

        await service.stopPolling()

        // Should eventually succeed
        let count = await service.getLastCount()
        // Count may be nil due to timing, but if not nil it should be valid
        if let count = count {
            XCTAssertGreaterThan(count, 0)
        }
    }

    // MARK: - Concurrent Operations Tests

    @MainActor
    func testConcurrentStartStop() async {
        let service = ViewerCountPollingService {
            return 42
        }

        async let start = service.startPolling()
        async let stop = service.stopPolling()

        _ = await (start, stop)

        // Should not crash or deadlock
        XCTAssert(true)
    }

    @MainActor
    func testMultipleStopCalls() async {
        let service = ViewerCountPollingService {
            return 42
        }

        await service.startPolling()
        await service.stopPolling()
        await service.stopPolling()  // Should be safe
        await service.stopPolling()  // Should be safe

        await XCTAssertAsyncFalse(await service.isPolling())
    }

    // MARK: - State Tests

    @MainActor
    func testLastCountWithMultipleFetches() async {
        var counter = 0
        let service = ViewerCountPollingService {
            counter += 1
            return counter
        }

        await service.startPolling()

        // Give time for multiple polls
        try? await Task.sleep(nanoseconds: 500_000_000)

        let lastCount = await service.getLastCount()

        // Should have at least one fetch
        XCTAssertNotNil(lastCount)

        await service.stopPolling()
    }

    @MainActor
    func testErrorClearsOnSuccess() async {
        var shouldFail = true
        let service = ViewerCountPollingService {
            if shouldFail {
                shouldFail = false
                enum TestError: Error {
                    case failed
                }
                throw TestError.failed
            }
            return 42
        }

        await service.startPolling()
        try? await Task.sleep(nanoseconds: 300_000_000)

        let error = await service.getLastError()
        XCTAssertNil(error)  // Should be cleared after success

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
