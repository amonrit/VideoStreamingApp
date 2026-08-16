import XCTest
@testable import steam

final class RetryStrategyTests: XCTestCase {
    // MARK: - Fixed Delay Tests

    func testFixedDelay_alwaysReturnsSameDelay() {
        let strategy = RetryStrategy.fixed(2.0)

        XCTAssertEqual(strategy.delay(forAttempt: 0), 2.0)
        XCTAssertEqual(strategy.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(strategy.delay(forAttempt: 5), 2.0)
    }

    func testFixedDelay_respectsMaxDelay() {
        let strategy = RetryStrategy.fixed(5.0)
        let delay = strategy.delay(forAttempt: 0, maxDelay: 3.0)

        XCTAssertEqual(delay, 3.0)
    }

    func testFixedDelay_totalDelay() {
        let strategy = RetryStrategy.fixed(2.0)
        let totalDelay = strategy.totalDelay(forAttempts: 3)

        XCTAssertEqual(totalDelay, 6.0)
    }

    // MARK: - Linear Backoff Tests

    func testLinearBackoff_increasesLinearly() {
        let strategy = RetryStrategy.linear(baseDelay: 1.0)

        XCTAssertEqual(strategy.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(strategy.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(strategy.delay(forAttempt: 2), 3.0)
        XCTAssertEqual(strategy.delay(forAttempt: 3), 4.0)
    }

    func testLinearBackoff_respectsMaxDelay() {
        let strategy = RetryStrategy.linear(baseDelay: 2.0)
        let delay = strategy.delay(forAttempt: 5, maxDelay: 5.0)

        XCTAssertEqual(delay, 5.0)
    }

    func testLinearBackoff_totalDelay() {
        let strategy = RetryStrategy.linear(baseDelay: 1.0)
        let totalDelay = strategy.totalDelay(forAttempts: 4)

        // 1 + 2 + 3 + 4 = 10
        XCTAssertEqual(totalDelay, 10.0)
    }

    // MARK: - Exponential Backoff Tests

    func testExponentialBackoff_increasesExponentially() {
        let strategy = RetryStrategy.exponential(baseDelay: 1.0, multiplier: 2.0, maxDelay: .infinity)

        XCTAssertEqual(strategy.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(strategy.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(strategy.delay(forAttempt: 2), 4.0)
        XCTAssertEqual(strategy.delay(forAttempt: 3), 8.0)
    }

    func testExponentialBackoff_customMultiplier() {
        let strategy = RetryStrategy.exponential(baseDelay: 1.0, multiplier: 3.0, maxDelay: .infinity)

        XCTAssertEqual(strategy.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(strategy.delay(forAttempt: 1), 3.0)
        XCTAssertEqual(strategy.delay(forAttempt: 2), 9.0)
    }

    func testExponentialBackoff_respectsMaxDelay() {
        let strategy = RetryStrategy.exponential(baseDelay: 1.0, multiplier: 2.0, maxDelay: 10.0)

        XCTAssertEqual(strategy.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(strategy.delay(forAttempt: 3), 8.0)
        XCTAssertEqual(strategy.delay(forAttempt: 4), 10.0)  // Capped at 10.0
        XCTAssertEqual(strategy.delay(forAttempt: 5), 10.0)  // Still capped
    }

    func testExponentialBackoff_totalDelay() {
        let strategy = RetryStrategy.exponential(baseDelay: 1.0, multiplier: 2.0, maxDelay: .infinity)
        let totalDelay = strategy.totalDelay(forAttempts: 4)

        // 1 + 2 + 4 + 8 = 15
        XCTAssertEqual(totalDelay, 15.0)
    }

    // MARK: - Jitter Tests

    func testDelayWithJitter_addsRandomVariation() {
        let strategy = RetryStrategy.fixed(10.0)
        let delay = strategy.delayWithJitter(forAttempt: 0, jitterPercentage: 0.1)

        // Should be between 9.0 and 11.0 (10.0 ± 10%)
        XCTAssertGreaterThanOrEqual(delay, 9.0)
        XCTAssertLessThanOrEqual(delay, 11.0)
    }

    func testDelayWithJitter_zeroJitter() {
        let strategy = RetryStrategy.fixed(5.0)
        let delay = strategy.delayWithJitter(forAttempt: 0, jitterPercentage: 0.0)

        // Should be exactly 5.0 with no jitter
        XCTAssertEqual(delay, 5.0)
    }

    func testDelayWithJitter_neverNegative() {
        let strategy = RetryStrategy.fixed(0.5)

        // Run multiple times to ensure we never get negative values
        for _ in 0..<100 {
            let delay = strategy.delayWithJitter(forAttempt: 0, jitterPercentage: 0.5)
            XCTAssertGreaterThanOrEqual(delay, 0)
        }
    }

    // MARK: - Equatable Tests

    func testEquatable_fixedDelaysEqual() {
        let strategy1 = RetryStrategy.fixed(2.0)
        let strategy2 = RetryStrategy.fixed(2.0)

        XCTAssertEqual(strategy1, strategy2)
    }

    func testEquatable_differentFixedDelaysNotEqual() {
        let strategy1 = RetryStrategy.fixed(2.0)
        let strategy2 = RetryStrategy.fixed(3.0)

        XCTAssertNotEqual(strategy1, strategy2)
    }

    func testEquatable_linearDelaysEqual() {
        let strategy1 = RetryStrategy.linear(baseDelay: 1.0)
        let strategy2 = RetryStrategy.linear(baseDelay: 1.0)

        XCTAssertEqual(strategy1, strategy2)
    }

    func testEquatable_exponentialDelaysEqual() {
        let strategy1 = RetryStrategy.exponential(baseDelay: 1.0, multiplier: 2.0, maxDelay: 30.0)
        let strategy2 = RetryStrategy.exponential(baseDelay: 1.0, multiplier: 2.0, maxDelay: 30.0)

        XCTAssertEqual(strategy1, strategy2)
    }

    func testEquatable_differentStrategiesNotEqual() {
        let fixed = RetryStrategy.fixed(1.0)
        let linear = RetryStrategy.linear(baseDelay: 1.0)

        XCTAssertNotEqual(fixed, linear)
    }

    // MARK: - Hashable Tests

    func testHashable_sameValuesSameHash() {
        let strategy1 = RetryStrategy.fixed(2.0)
        let strategy2 = RetryStrategy.fixed(2.0)

        XCTAssertEqual(strategy1.hashValue, strategy2.hashValue)
    }

    func testHashable_usableInSet() {
        let strategy1 = RetryStrategy.fixed(1.0)
        let strategy2 = RetryStrategy.fixed(1.0)
        let strategy3 = RetryStrategy.fixed(2.0)

        let set = Set([strategy1, strategy2, strategy3])
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Description Tests

    func testDescription_fixed() {
        let strategy = RetryStrategy.fixed(2.0)
        XCTAssertTrue(strategy.description.contains("fixed"))
    }

    func testDescription_linear() {
        let strategy = RetryStrategy.linear(baseDelay: 1.0)
        XCTAssertTrue(strategy.description.contains("linear"))
    }

    func testDescription_exponential() {
        let strategy = RetryStrategy.exponential()
        XCTAssertTrue(strategy.description.contains("exponential"))
    }
}
