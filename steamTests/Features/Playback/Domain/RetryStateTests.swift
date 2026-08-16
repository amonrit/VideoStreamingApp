import XCTest
@testable import steam

final class RetryStateTests: XCTestCase {
    // MARK: - Initialization Tests

    func testInitialization_defaultValues() {
        let state = RetryState()

        XCTAssertEqual(state.attemptCount, 0)
        XCTAssertNil(state.lastAttemptTime)
        XCTAssertEqual(state.totalRetryTime, 0)
        XCTAssertFalse(state.isRetrying)
        XCTAssertNil(state.lastError)
    }

    func testInitialization_withConfiguration() {
        let config = PlaybackConfiguration(
            maxRetryAttempts: 5,
            initialRetryDelay: 0.5
        )
        let state = RetryState(configuration: config)

        XCTAssertEqual(state.maxAttempts, 5)
    }

    func testInitialization_withStrategy() {
        let strategy = RetryStrategy.linear(baseDelay: 1.0)
        let state = RetryState(retryStrategy: strategy)

        XCTAssertNotNil(state.nextDelay)
    }

    // MARK: - Computed Properties Tests

    func testMaxAttempts() {
        let config = PlaybackConfiguration(maxRetryAttempts: 3)
        let state = RetryState(configuration: config)

        XCTAssertEqual(state.maxAttempts, 3)
    }

    func testRemainingAttempts() {
        let config = PlaybackConfiguration(maxRetryAttempts: 3)
        var state = RetryState(configuration: config)

        XCTAssertEqual(state.remainingAttempts, 3)

        state.attemptCount = 1
        XCTAssertEqual(state.remainingAttempts, 2)

        state.attemptCount = 3
        XCTAssertEqual(state.remainingAttempts, 0)
    }

    func testHasRetriesRemaining() {
        let config = PlaybackConfiguration(maxRetryAttempts: 2)
        var state = RetryState(configuration: config)

        XCTAssertTrue(state.hasRetriesRemaining)

        state.attemptCount = 2
        XCTAssertFalse(state.hasRetriesRemaining)
    }

    func testProgress_zeroAttempts() {
        let state = RetryState()
        XCTAssertEqual(state.progress, 0.0)
    }

    func testProgress_halfwayThrough() {
        let config = PlaybackConfiguration(maxRetryAttempts: 4)
        var state = RetryState(configuration: config)

        state.attemptCount = 2
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.01)
    }

    func testProgress_maxAttempts() {
        let config = PlaybackConfiguration(maxRetryAttempts: 3)
        var state = RetryState(configuration: config)

        state.attemptCount = 3
        XCTAssertEqual(state.progress, 1.0)
    }

    func testProgress_exceedsMax() {
        let config = PlaybackConfiguration(maxRetryAttempts: 3)
        var state = RetryState(configuration: config)

        state.attemptCount = 5
        XCTAssertEqual(state.progress, 1.0)
    }

    func testNextDelay() {
        let strategy = RetryStrategy.fixed(2.0)
        let state = RetryState(retryStrategy: strategy)

        XCTAssertEqual(state.nextDelay, 2.0)
    }

    func testNextDelayWithJitter() {
        let strategy = RetryStrategy.fixed(10.0)
        let state = RetryState(retryStrategy: strategy)

        let delayWithJitter = state.nextDelayWithJitter

        // Should be within 10% jitter (9.0 to 11.0)
        XCTAssertGreaterThanOrEqual(delayWithJitter, 9.0)
        XCTAssertLessThanOrEqual(delayWithJitter, 11.0)
    }

    func testIsInRetry_whenRetrying() {
        var state = RetryState()

        XCTAssertFalse(state.isInRetry)

        state.isRetrying = true
        XCTAssertTrue(state.isInRetry)
    }

    func testShouldRetry() {
        let config = PlaybackConfiguration(maxRetryAttempts: 2)
        var state = RetryState(configuration: config)

        XCTAssertTrue(state.shouldRetry)

        state.isRetrying = true
        XCTAssertFalse(state.shouldRetry)

        state.isRetrying = false
        state.attemptCount = 2
        XCTAssertFalse(state.shouldRetry)
    }

    // MARK: - State Modification Tests

    func testRecordAttempt() {
        var state = RetryState()

        let beforeTime = Date()
        state.recordAttempt()
        let afterTime = Date()

        XCTAssertEqual(state.attemptCount, 1)
        XCTAssertTrue(state.isRetrying)

        if let attemptTime = state.lastAttemptTime {
            XCTAssertGreaterThanOrEqual(attemptTime, beforeTime)
            XCTAssertLessThanOrEqual(attemptTime, afterTime)
        } else {
            XCTFail("lastAttemptTime should be set")
        }
    }

    func testRecordAttempt_multipleAttempts() {
        var state = RetryState()

        state.recordAttempt()
        XCTAssertEqual(state.attemptCount, 1)

        state.recordAttempt()
        XCTAssertEqual(state.attemptCount, 2)

        state.recordAttempt()
        XCTAssertEqual(state.attemptCount, 3)
    }

    func testRecordFailure() {
        let strategy = RetryStrategy.fixed(1.0)
        var state = RetryState(retryStrategy: strategy)

        enum TestError: Error {
            case failed
        }

        state.recordFailure(error: TestError.failed)

        XCTAssertNotNil(state.lastError)
        XCTAssertGreaterThan(state.totalRetryTime, 0)
    }

    func testRecordSuccess_resetsState() {
        var state = RetryState()

        state.attemptCount = 2
        state.isRetrying = true
        state.totalRetryTime = 5.0

        state.recordSuccess()

        XCTAssertEqual(state.attemptCount, 0)
        XCTAssertFalse(state.isRetrying)
        XCTAssertEqual(state.totalRetryTime, 0)
    }

    func testReset() {
        var state = RetryState()

        state.attemptCount = 3
        state.isRetrying = true
        state.totalRetryTime = 10.0

        state.reset()

        XCTAssertEqual(state.attemptCount, 0)
        XCTAssertFalse(state.isRetrying)
        XCTAssertEqual(state.totalRetryTime, 0)
        XCTAssertNil(state.lastAttemptTime)
        XCTAssertNil(state.lastError)
    }

    // MARK: - Integration Tests

    func testFullRetryFlow() {
        let config = PlaybackConfiguration(maxRetryAttempts: 3)
        let strategy = RetryStrategy.exponential()
        var state = RetryState(configuration: config, retryStrategy: strategy)

        // First attempt
        state.recordAttempt()
        XCTAssertEqual(state.attemptCount, 1)
        XCTAssertTrue(state.hasRetriesRemaining)

        enum TestError: Error {
            case connectionFailed
        }

        state.recordFailure(error: TestError.connectionFailed)

        // Second attempt
        state.recordAttempt()
        XCTAssertEqual(state.attemptCount, 2)

        // Success
        state.recordSuccess()
        XCTAssertEqual(state.attemptCount, 0)
        XCTAssertFalse(state.isRetrying)
    }

    func testRetryProgressTracking() {
        let config = PlaybackConfiguration(maxRetryAttempts: 4)
        var state = RetryState(configuration: config)

        for i in 0..<4 {
            state.attemptCount = i
            let expectedProgress = Double(i) / 4.0
            XCTAssertEqual(state.progress, expectedProgress, accuracy: 0.01)
        }
    }

    func testExponentialBackoffProgression() {
        let config = PlaybackConfiguration(maxRetryAttempts: 5)
        let strategy = RetryStrategy.exponential(baseDelay: 1.0, multiplier: 2.0, maxDelay: 30.0)
        var state = RetryState(configuration: config, retryStrategy: strategy)

        var previousDelay = 0.0

        for _ in 0..<4 {
            let delay = state.nextDelay
            XCTAssertGreaterThanOrEqual(delay, previousDelay)
            previousDelay = delay
            state.recordAttempt()
        }
    }

    // MARK: - Equatable Tests

    func testEquatable_sameStatesEqual() {
        var state1 = RetryState()
        var state2 = RetryState()

        state1.attemptCount = 2
        state1.totalRetryTime = 5.0
        state1.isRetrying = true

        state2.attemptCount = 2
        state2.totalRetryTime = 5.0
        state2.isRetrying = true

        XCTAssertEqual(state1, state2)
    }

    func testEquatable_differentStatesNotEqual() {
        var state1 = RetryState()
        var state2 = RetryState()

        state1.attemptCount = 2
        state2.attemptCount = 3

        XCTAssertNotEqual(state1, state2)
    }

    // MARK: - Description Tests

    func testDescription() {
        var state = RetryState()
        state.attemptCount = 1

        let description = state.description
        XCTAssertTrue(description.contains("RetryState"))
        XCTAssertTrue(description.contains("1"))
    }
}
