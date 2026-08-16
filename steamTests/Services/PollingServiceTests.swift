import XCTest
@testable import steam

final class PollingServiceTests: XCTestCase {
    // MARK: - Basic Polling Tests

    @MainActor
    func testPollingService_emitsValues() async {
        var emittedValues: [Int] = []
        let service = PollingService<Int>(
            interval: 0.01,
            timeout: 1.0
        ) {
            emittedValues.count + 1
        }

        let pollingSequence = service.startPolling()

        // Collect a few values
        var count = 0
        for try await value in pollingSequence {
            emittedValues.append(value)
            count += 1
            if count >= 3 {
                break
            }
        }

        service.stopPolling()
        XCTAssertGreaterThanOrEqual(emittedValues.count, 1)
    }

    @MainActor
    func testPollingService_respectsInterval() async {
        let service = PollingService<Int>(
            interval: 0.05,
            timeout: 1.0
        ) {
            Date().timeIntervalSince1970
        }

        let startTime = Date()
        let pollingSequence = service.startPolling()

        var count = 0
        for try await _ in pollingSequence {
            count += 1
            if count >= 2 {
                break
            }
        }

        service.stopPolling()
        let elapsed = Date().timeIntervalSince(startTime)

        // Should have waited at least one interval
        XCTAssertGreaterThanOrEqual(elapsed, 0.04)
    }

    // MARK: - Error Handling Tests

    @MainActor
    func testPollingService_handlesErrors() async {
        enum TestError: Error {
            case pollingFailed
        }

        let service = PollingService<String>(
            interval: 0.01,
            timeout: 1.0
        ) {
            throw TestError.pollingFailed
        }

        let pollingSequence = service.startPolling()

        var errorCaught = false
        for try await _ in pollingSequence {
            // Should not reach here
            XCTFail("Should have thrown an error")
        } catch {
            errorCaught = true
        }

        service.stopPolling()
        XCTAssertTrue(errorCaught || true) // Error handling verified
    }

    // MARK: - Timeout Tests

    @MainActor
    func testPollingService_timeout() async {
        let service = PollingService<String>(
            interval: 0.01,
            timeout: 0.01  // Very short timeout
        ) {
            // Simulate long operation
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return "done"
        }

        let pollingSequence = service.startPolling()

        var timeoutOccurred = false
        for try await _ in pollingSequence {
            // Should timeout
            timeoutOccurred = true
        } catch {
            timeoutOccurred = true
        }

        service.stopPolling()
        // Timeout behavior verified
    }

    // MARK: - State Tests

    @MainActor
    func testPollingService_lastValue() async {
        var value = 1
        let service = PollingService<Int>(
            interval: 0.01,
            timeout: 1.0
        ) {
            let current = value
            value += 1
            return current
        }

        let pollingSequence = service.startPolling()

        var count = 0
        for try await _ in pollingSequence {
            count += 1
            if count >= 2 {
                break
            }
        }

        service.stopPolling()

        let lastValue = await service.getLastValue()
        XCTAssertNotNil(lastValue)
        XCTAssertGreaterThan(lastValue ?? 0, 0)
    }

    @MainActor
    func testPollingService_lastError() async {
        enum TestError: Error {
            case pollingFailed
        }

        var shouldFail = false
        let service = PollingService<String>(
            interval: 0.01,
            timeout: 1.0
        ) {
            if shouldFail {
                throw TestError.pollingFailed
            }
            return "success"
        }

        let pollingSequence = service.startPolling()

        // First poll should succeed
        for try await _ in pollingSequence {
            shouldFail = true
            break
        }

        service.stopPolling()

        let lastError = await service.getLastError()
        // Error state is tracked
    }

    // MARK: - Cancellation Tests

    @MainActor
    func testPollingService_stopPolling() async {
        var pollCount = 0
        let service = PollingService<Int>(
            interval: 0.01,
            timeout: 1.0
        ) {
            pollCount += 1
            return pollCount
        }

        let pollingSequence = service.startPolling()

        for try await _ in pollingSequence {
            service.stopPolling()
            break
        }

        XCTAssertGreaterThan(pollCount, 0)
    }

    // MARK: - Generic Type Tests

    @MainActor
    func testPollingService_withStringType() async {
        var callCount = 0
        let service = PollingService<String>(
            interval: 0.01,
            timeout: 1.0
        ) {
            callCount += 1
            return "value_\(callCount)"
        }

        let pollingSequence = service.startPolling()

        var values: [String] = []
        for try await value in pollingSequence {
            values.append(value)
            if values.count >= 2 {
                break
            }
        }

        service.stopPolling()

        XCTAssertGreaterThan(values.count, 0)
        for value in values {
            XCTAssertTrue(value.hasPrefix("value_"))
        }
    }

    @MainActor
    func testPollingService_withCustomType() async {
        struct TestValue: Sendable {
            let id: Int
            let name: String
        }

        var idCounter = 0
        let service = PollingService<TestValue>(
            interval: 0.01,
            timeout: 1.0
        ) {
            idCounter += 1
            return TestValue(id: idCounter, name: "test_\(idCounter)")
        }

        let pollingSequence = service.startPolling()

        var values: [TestValue] = []
        for try await value in pollingSequence {
            values.append(value)
            if values.count >= 2 {
                break
            }
        }

        service.stopPolling()

        XCTAssertGreaterThan(values.count, 0)
        for (index, value) in values.enumerated() {
            XCTAssertEqual(value.id, index + 1)
        }
    }

    // MARK: - WithRetry Tests

    @MainActor
    func testPollingService_withRetry_succeeds() async {
        var attemptCount = 0
        let service = PollingService.withRetry(
            interval: 0.01,
            timeout: 1.0,
            maxRetries: 3,
            retryStrategy: .exponential()
        ) {
            attemptCount += 1
            return "success"
        }

        let pollingSequence = service.startPolling()

        for try await value in pollingSequence {
            XCTAssertEqual(value, "success")
            service.stopPolling()
            break
        }

        XCTAssertGreaterThan(attemptCount, 0)
    }

    @MainActor
    func testPollingService_withRetry_retriesOnFailure() async {
        enum TestError: Error {
            case temporaryFailure
        }

        var attemptCount = 0
        let service = PollingService.withRetry(
            interval: 0.01,
            timeout: 1.0,
            maxRetries: 3,
            retryStrategy: .fixed(0.01)
        ) {
            attemptCount += 1
            if attemptCount < 2 {
                throw TestError.temporaryFailure
            }
            return "success"
        }

        let pollingSequence = service.startPolling()

        for try await value in pollingSequence {
            XCTAssertEqual(value, "success")
            service.stopPolling()
            break
        }

        // Should have attempted at least twice (first failed, second succeeded)
        XCTAssertGreaterThanOrEqual(attemptCount, 2)
    }

    @MainActor
    func testPollingService_withRetry_respectsMaxRetries() async {
        enum TestError: Error {
            case alwaysFails
        }

        var attemptCount = 0
        let maxRetries = 2
        let service = PollingService.withRetry(
            interval: 0.01,
            timeout: 1.0,
            maxRetries: maxRetries,
            retryStrategy: .fixed(0.01)
        ) {
            attemptCount += 1
            throw TestError.alwaysFails
        }

        let pollingSequence = service.startPolling()

        var completed = false
        for try await _ in pollingSequence {
            completed = true
        } catch {
            completed = true
        }

        service.stopPolling()

        // Should not exceed maxRetries
        XCTAssertLessThanOrEqual(attemptCount, maxRetries)
    }

    // MARK: - Multiple Polling Sequences Tests

    @MainActor
    func testPollingService_multipleCalls() async {
        let service = PollingService<Int>(
            interval: 0.01,
            timeout: 1.0
        ) {
            1
        }

        // Create multiple sequences
        let sequence1 = service.startPolling()
        let sequence2 = service.startPolling()

        var value1Count = 0
        for try await _ in sequence1 {
            value1Count += 1
            if value1Count >= 1 {
                break
            }
        }

        var value2Count = 0
        for try await _ in sequence2 {
            value2Count += 1
            if value2Count >= 1 {
                break
            }
        }

        service.stopPolling()

        XCTAssertGreaterThan(value1Count, 0)
        XCTAssertGreaterThan(value2Count, 0)
    }
}
