import XCTest
@testable import steam

final class ViewerCountStateTests: XCTestCase {
    // MARK: - Initialization Tests

    func testInitialization_defaultValues() {
        let state = ViewerCountState()

        XCTAssertNil(state.currentCount)
        XCTAssertNil(state.lastUpdateTime)
        XCTAssertEqual(state.failureCount, 0)
        XCTAssertFalse(state.isPolling)
        XCTAssertNil(state.lastError)
    }

    func testInitialization_withConfiguration() {
        let config = PlaybackConfiguration(viewerCountPollingInterval: 10.0)
        let state = ViewerCountState(configuration: config)

        XCTAssertEqual(state.pollingInterval, 10.0)
    }

    // MARK: - Computed Properties Tests

    func testPollingInterval() {
        let config = PlaybackConfiguration(viewerCountPollingInterval: 7.5)
        let state = ViewerCountState(configuration: config)

        XCTAssertEqual(state.pollingInterval, 7.5)
    }

    func testMaxFailures() {
        let state = ViewerCountState()
        XCTAssertEqual(state.maxFailures, 3)
    }

    func testCanContinuePolling_noFailures() {
        let state = ViewerCountState()
        XCTAssertTrue(state.canContinuePolling)
    }

    func testCanContinuePolling_belowThreshold() {
        var state = ViewerCountState()
        state.failureCount = 2

        XCTAssertTrue(state.canContinuePolling)
    }

    func testCanContinuePolling_atThreshold() {
        var state = ViewerCountState()
        state.failureCount = 3

        XCTAssertFalse(state.canContinuePolling)
    }

    func testCanContinuePolling_exceedsThreshold() {
        var state = ViewerCountState()
        state.failureCount = 5

        XCTAssertFalse(state.canContinuePolling)
    }

    func testShouldRetry_canRetry() {
        var state = ViewerCountState()
        state.failureCount = 2
        state.isPolling = false

        XCTAssertTrue(state.shouldRetry)
    }

    func testShouldRetry_exceedsMax() {
        var state = ViewerCountState()
        state.failureCount = 3
        state.isPolling = false

        XCTAssertFalse(state.shouldRetry)
    }

    func testShouldRetry_currentlyPolling() {
        var state = ViewerCountState()
        state.failureCount = 1
        state.isPolling = true

        XCTAssertFalse(state.shouldRetry)
    }

    func testFailureProgress_noFailures() {
        let state = ViewerCountState()
        XCTAssertEqual(state.failureProgress, 0.0)
    }

    func testFailureProgress_halfThreshold() {
        var state = ViewerCountState()
        state.failureCount = 1

        XCTAssertEqual(state.failureProgress, 1.0 / 3.0, accuracy: 0.01)
    }

    func testFailureProgress_atThreshold() {
        var state = ViewerCountState()
        state.failureCount = 3

        XCTAssertEqual(state.failureProgress, 1.0)
    }

    func testFailureProgress_exceedsThreshold() {
        var state = ViewerCountState()
        state.failureCount = 5

        XCTAssertEqual(state.failureProgress, 1.0)
    }

    func testTimeSinceLastUpdate_noUpdate() {
        let state = ViewerCountState()
        XCTAssertNil(state.timeSinceLastUpdate)
    }

    func testTimeSinceLastUpdate_withUpdate() {
        var state = ViewerCountState()
        state.lastUpdateTime = Date().addingTimeInterval(-5)

        let timeSince = state.timeSinceLastUpdate
        XCTAssertNotNil(timeSince)
        XCTAssertGreaterThan(timeSince ?? 0, 4.9)
        XCTAssertLessThan(timeSince ?? 0, 5.1)
    }

    func testIsStale_noUpdate() {
        let state = ViewerCountState()
        XCTAssertTrue(state.isStale)
    }

    func testIsStale_recentUpdate() {
        var state = ViewerCountState()
        state.lastUpdateTime = Date().addingTimeInterval(-1)

        XCTAssertFalse(state.isStale)
    }

    func testIsStale_oldUpdate() {
        var state = ViewerCountState()
        // Default interval is 5.0, stale is 1.5x = 7.5
        state.lastUpdateTime = Date().addingTimeInterval(-10)

        XCTAssertTrue(state.isStale)
    }

    // MARK: - State Modification Tests

    func testStartPolling() {
        var state = ViewerCountState()

        XCTAssertFalse(state.isPolling)

        state.startPolling()
        XCTAssertTrue(state.isPolling)
    }

    func testStopPolling() {
        var state = ViewerCountState()
        state.startPolling()

        XCTAssertTrue(state.isPolling)

        state.stopPolling()
        XCTAssertFalse(state.isPolling)
    }

    func testUpdateCount_setsValue() {
        var state = ViewerCountState()

        state.updateCount(42)

        XCTAssertEqual(state.currentCount, 42)
    }

    func testUpdateCount_setsTimestamp() {
        var state = ViewerCountState()

        let beforeTime = Date()
        state.updateCount(10)
        let afterTime = Date()

        if let updateTime = state.lastUpdateTime {
            XCTAssertGreaterThanOrEqual(updateTime, beforeTime)
            XCTAssertLessThanOrEqual(updateTime, afterTime)
        } else {
            XCTFail("lastUpdateTime should be set")
        }
    }

    func testUpdateCount_resetsFailures() {
        var state = ViewerCountState()
        state.failureCount = 2

        state.updateCount(100)

        XCTAssertEqual(state.failureCount, 0)
        XCTAssertNil(state.lastError)
    }

    func testRecordFailure() {
        enum TestError: Error {
            case pollingFailed
        }

        var state = ViewerCountState()

        state.recordFailure(error: TestError.pollingFailed)

        XCTAssertEqual(state.failureCount, 1)
        XCTAssertNotNil(state.lastError)
    }

    func testRecordFailure_increments() {
        enum TestError: Error {
            case pollingFailed
        }

        var state = ViewerCountState()

        state.recordFailure(error: TestError.pollingFailed)
        XCTAssertEqual(state.failureCount, 1)

        state.recordFailure(error: TestError.pollingFailed)
        XCTAssertEqual(state.failureCount, 2)

        state.recordFailure(error: TestError.pollingFailed)
        XCTAssertEqual(state.failureCount, 3)
    }

    func testRecordSuccess() {
        var state = ViewerCountState()
        state.failureCount = 2

        let beforeTime = Date()
        state.recordSuccess()
        let afterTime = Date()

        XCTAssertEqual(state.failureCount, 0)
        XCTAssertNil(state.lastError)

        if let updateTime = state.lastUpdateTime {
            XCTAssertGreaterThanOrEqual(updateTime, beforeTime)
            XCTAssertLessThanOrEqual(updateTime, afterTime)
        }
    }

    func testReset() {
        var state = ViewerCountState()
        state.currentCount = 100
        state.failureCount = 2
        state.isPolling = true
        state.lastUpdateTime = Date()

        state.reset()

        XCTAssertNil(state.currentCount)
        XCTAssertNil(state.lastUpdateTime)
        XCTAssertEqual(state.failureCount, 0)
        XCTAssertFalse(state.isPolling)
        XCTAssertNil(state.lastError)
    }

    func testClearFailures() {
        enum TestError: Error {
            case failed
        }

        var state = ViewerCountState()
        state.failureCount = 2
        state.lastError = TestError.failed as Error

        state.clearFailures()

        XCTAssertEqual(state.failureCount, 0)
        XCTAssertNil(state.lastError)
    }

    // MARK: - State Transition Tests

    func testStateTransition_idle() {
        let state = ViewerCountState()

        XCTAssertNil(state.currentCount)
        XCTAssertFalse(state.isPolling)
    }

    func testStateTransition_startToPolling() {
        var state = ViewerCountState()

        state.startPolling()

        XCTAssertTrue(state.isPolling)
    }

    func testStateTransition_pollingToSuccess() {
        var state = ViewerCountState()

        state.startPolling()
        state.updateCount(50)

        XCTAssertEqual(state.currentCount, 50)
        XCTAssertEqual(state.failureCount, 0)
    }

    func testStateTransition_pollingToFailure() {
        enum TestError: Error {
            case failed
        }

        var state = ViewerCountState()

        state.startPolling()
        state.recordFailure(error: TestError.failed)

        XCTAssertEqual(state.failureCount, 1)
        XCTAssertNotNil(state.lastError)
    }

    // MARK: - Integration Tests

    func testFullPollingFlow() {
        let config = PlaybackConfiguration(viewerCountPollingInterval: 5.0)
        var state = ViewerCountState(configuration: config)

        // Start polling
        state.startPolling()
        XCTAssertTrue(state.isPolling)

        // First poll succeeds
        state.updateCount(42)
        XCTAssertEqual(state.currentCount, 42)
        XCTAssertEqual(state.failureCount, 0)

        // Continue polling
        state.updateCount(43)
        XCTAssertEqual(state.currentCount, 43)

        state.stopPolling()
        XCTAssertFalse(state.isPolling)
    }

    func testFailureRecovery() {
        enum TestError: Error {
            case networkError
        }

        var state = ViewerCountState()

        // Record failures
        state.recordFailure(error: TestError.networkError)
        state.recordFailure(error: TestError.networkError)
        XCTAssertEqual(state.failureCount, 2)

        // Recover with successful update
        state.updateCount(100)
        XCTAssertEqual(state.failureCount, 0)
        XCTAssertEqual(state.currentCount, 100)
    }

    func testMaxFailureThreshold() {
        enum TestError: Error {
            case failed
        }

        var state = ViewerCountState()

        // Record max failures
        for _ in 0..<3 {
            state.recordFailure(error: TestError.failed)
        }

        XCTAssertFalse(state.canContinuePolling)
        XCTAssertFalse(state.shouldRetry)

        // Clear and retry
        state.clearFailures()
        XCTAssertTrue(state.shouldRetry)
    }

    // MARK: - Equatable Tests

    func testEquatable_sameStatesEqual() {
        var state1 = ViewerCountState()
        var state2 = ViewerCountState()

        state1.currentCount = 42
        state1.failureCount = 1
        state1.isPolling = true

        state2.currentCount = 42
        state2.failureCount = 1
        state2.isPolling = true

        XCTAssertEqual(state1, state2)
    }

    func testEquatable_differentStatesNotEqual() {
        var state1 = ViewerCountState()
        var state2 = ViewerCountState()

        state1.currentCount = 42
        state2.currentCount = 100

        XCTAssertNotEqual(state1, state2)
    }

    // MARK: - Description Tests

    func testDescription() {
        var state = ViewerCountState()
        state.currentCount = 50
        state.failureCount = 1

        let description = state.description
        XCTAssertTrue(description.contains("ViewerCountState"))
        XCTAssertTrue(description.contains("50"))
    }
}
