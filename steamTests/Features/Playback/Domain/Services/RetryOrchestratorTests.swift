import XCTest
@testable import steam

@MainActor
final class RetryOrchestratorTests: XCTestCase {
    var sut: RetryOrchestrator!
    var statusMessages: [String] = []

    override func setUp() {
        super.setUp()
        statusMessages = []
        sut = RetryOrchestrator(
            configuration: .debug,
            onStatusChanged: { [weak self] message in
                self?.statusMessages.append(message)
            }
        )
    }

    override func tearDown() {
        sut = nil
        statusMessages = []
        super.tearDown()
    }

    // MARK: - A. Initialization Tests

    func testInitializationWithDefaultConfiguration() async {
        let orchestrator = RetryOrchestrator()
        let state = await orchestrator.getState()

        XCTAssertEqual(state.attemptCount, 0)
        XCTAssertNil(state.lastError)
    }

    func testInitializationWithCustomConfiguration() async {
        let customConfig = PlaybackConfiguration(
            maxRetryAttempts: 5,
            initialRetryDelay: 2.0,
            maxRetryDelay: 10.0
        )
        let orchestrator = RetryOrchestrator(configuration: customConfig)
        let state = await orchestrator.getState()

        XCTAssertEqual(state.attemptCount, 0)
        XCTAssertEqual(state.maxAttempts, 5)
    }

    func testInitializationWithStatusCallback() {
        var callbackFired = false
        let orchestrator = RetryOrchestrator(onStatusChanged: { _ in
            callbackFired = true
        })

        XCTAssertNotNil(orchestrator)
        // Callback fires on first status message
    }

    // MARK: - B. Basic Retry Tests

    func testSuccessfulOperationOnFirstAttempt() async throws {
        var operationCallCount = 0

        let result = try await sut.attemptWithRetry {
            operationCallCount += 1
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(operationCallCount, 1)
        let state = await sut.getState()
        XCTAssertEqual(state.attemptCount, 1)
    }

    func testSuccessfulOperationOnSecondAttempt() async throws {
        var operationCallCount = 0

        let result = try await sut.attemptWithRetry {
            operationCallCount += 1
            if operationCallCount < 2 {
                throw TestError.operationFailed
            }
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(operationCallCount, 2)
        let state = await sut.getState()
        XCTAssertEqual(state.attemptCount, 2)
    }

    func testSuccessfulOperationOnFinalAttempt() async throws {
        var operationCallCount = 0

        let result = try await sut.attemptWithRetry {
            operationCallCount += 1
            if operationCallCount < 3 {
                throw TestError.operationFailed
            }
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(operationCallCount, 3)
    }

    func testFailureAfterMaxRetries() async throws {
        var operationCallCount = 0

        do {
            _ = try await sut.attemptWithRetry {
                operationCallCount += 1
                throw TestError.operationFailed
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(operationCallCount, 3)
            let state = await sut.getState()
            XCTAssertEqual(state.attemptCount, 3)
        }
    }

    func testErrorTypesPropagateCorrectly() async throws {
        do {
            _ = try await sut.attemptWithRetry {
                throw TestError.networkTimeout
            }
            XCTFail("Should have thrown error")
        } catch let error as TestError {
            XCTAssertEqual(error, TestError.networkTimeout)
        }
    }

    // MARK: - C. Retry State Tests

    func testAttemptCountIncrementsCorrectly() async throws {
        var callCount = 0

        _ = try? await sut.attemptWithRetry {
            callCount += 1
            throw TestError.operationFailed
        }

        let state = await sut.getState()
        XCTAssertEqual(state.attemptCount, 3)
    }

    func testRetryDelayIncreasesExponentially() async throws {
        let testConfig = PlaybackConfiguration(
            maxRetryAttempts: 3,
            initialRetryDelay: 1.0,
            maxRetryDelay: 5.0
        )
        let orchestrator = RetryOrchestrator(configuration: testConfig)

        var operationCallCount = 0
        let startTime = Date()

        _ = try? await orchestrator.attemptWithRetry {
            operationCallCount += 1
            throw TestError.operationFailed
        }

        let duration = Date().timeIntervalSince(startTime)

        // Expected: 1s + 2s = 3s (plus some tolerance for execution time)
        // Min delay between attempts: ~2.5s, Max: ~3.5s
        XCTAssertGreaterThanOrEqual(duration, 2.5, "Delay should be at least 2.5 seconds")
        XCTAssertLessThanOrEqual(duration, 5.0, "Delay should not exceed 5 seconds")
    }

    func testJitterAppliedToDelay() async throws {
        let testConfig = PlaybackConfiguration(
            maxRetryAttempts: 1,
            initialRetryDelay: 1.0,
            maxRetryDelay: 5.0
        )

        var delays: [TimeInterval] = []

        for _ in 0..<5 {
            let orchestrator = RetryOrchestrator(configuration: testConfig)
            var callCount = 0
            let startTime = Date()

            _ = try? await orchestrator.attemptWithRetry {
                callCount += 1
                throw TestError.operationFailed
            }

            let duration = Date().timeIntervalSince(startTime)
            delays.append(duration)
        }

        // Delays should vary due to jitter
        let uniqueDelays = Set(delays).count
        XCTAssertGreaterThan(uniqueDelays, 1, "Jitter should create variation in delays")
    }

    func testMaxDelayCapAt5Seconds() async throws {
        let testConfig = PlaybackConfiguration(
            maxRetryAttempts: 5,
            initialRetryDelay: 2.0,
            maxRetryDelay: 5.0
        )
        let orchestrator = RetryOrchestrator(configuration: testConfig)

        var operationCallCount = 0
        let startTime = Date()

        _ = try? await orchestrator.attemptWithRetry {
            operationCallCount += 1
            throw TestError.operationFailed
        }

        let duration = Date().timeIntervalSince(startTime)

        // With capping, delays should not exceed reasonable bounds
        XCTAssertLessThanOrEqual(duration, 10.0, "Total duration should respect max delay cap")
    }

    func testHasRetriesRemainingComputedCorrectly() async throws {
        let state1 = await sut.getState()
        XCTAssertTrue(state1.hasRetriesRemaining)

        _ = try? await sut.attemptWithRetry {
            throw TestError.operationFailed
        }

        let state2 = await sut.getState()
        XCTAssertFalse(state2.hasRetriesRemaining)
    }

    // MARK: - D. Status Callback Tests

    func testStatusCallbackFiresOnEachAttempt() async throws {
        _ = try? await sut.attemptWithRetry {
            throw TestError.operationFailed
        }

        // Should have messages for each attempt + retry delays
        XCTAssertGreaterThan(statusMessages.count, 0)
    }

    func testSuccessMessageFormatCorrect() async throws {
        _ = try await sut.attemptWithRetry {
            return "success"
        }

        let successMessages = statusMessages.filter { $0.contains("✅") }
        XCTAssertGreaterThan(successMessages.count, 0)
    }

    func testFailureMessageWithBackoffTime() async throws {
        _ = try? await sut.attemptWithRetry {
            throw TestError.operationFailed
        }

        let retryMessages = statusMessages.filter { $0.contains("retrying") }
        XCTAssertGreaterThan(retryMessages.count, 0)
        // Should contain time like "in 1.5s..."
        let hasTime = retryMessages.contains { $0.contains("s...") }
        XCTAssertTrue(hasTime, "Retry message should contain backoff time")
    }

    func testFinalFailureMessage() async throws {
        _ = try? await sut.attemptWithRetry {
            throw TestError.operationFailed
        }

        let finalMessages = statusMessages.filter { $0.contains("Failed after") }
        XCTAssertGreaterThan(finalMessages.count, 0)
    }

    // MARK: - E. Error Handling Tests

    func testLastErrorTrackedCorrectly() async throws {
        let testError = TestError.operationFailed

        _ = try? await sut.attemptWithRetry {
            throw testError
        }

        let lastError = await sut.getLastError() as? TestError
        XCTAssertEqual(lastError, testError)
    }

    func testErrorPropagatesToCaller() async throws {
        do {
            _ = try await sut.attemptWithRetry {
                throw TestError.networkTimeout
            }
            XCTFail("Should have thrown error")
        } catch let error as TestError {
            XCTAssertEqual(error, TestError.networkTimeout)
        }
    }

    func testRetryOrchestratorErrorOnMaxRetriesExceeded() async throws {
        do {
            _ = try await sut.attemptWithRetry {
                throw TestError.operationFailed
            }
            XCTFail("Should have thrown RetryOrchestratorError")
        } catch let error as RetryOrchestratorError {
            XCTAssertEqual(error, RetryOrchestratorError.maxRetriesExceeded)
        } catch {
            XCTFail("Should throw RetryOrchestratorError, not \(type(of: error))")
        }
    }

    // MARK: - F. State Management Tests

    func testResetClearsAttemptCount() async throws {
        _ = try? await sut.attemptWithRetry {
            throw TestError.operationFailed
        }

        let stateBefore = await sut.getState()
        XCTAssertGreaterThan(stateBefore.attemptCount, 0)

        await sut.reset()

        let stateAfter = await sut.getState()
        XCTAssertEqual(stateAfter.attemptCount, 0)
    }

    func testResetClearsLastError() async throws {
        _ = try? await sut.attemptWithRetry {
            throw TestError.operationFailed
        }

        let errorBefore = await sut.getLastError()
        XCTAssertNotNil(errorBefore)

        await sut.reset()

        let errorAfter = await sut.getLastError()
        XCTAssertNil(errorAfter)
    }

    func testGetStateReturnsCurrentState() async throws {
        let state1 = await sut.getState()
        XCTAssertEqual(state1.attemptCount, 0)

        _ = try? await sut.attemptWithRetry {
            throw TestError.operationFailed
        }

        let state2 = await sut.getState()
        XCTAssertEqual(state2.attemptCount, 3)
        XCTAssertNotEqual(state1.attemptCount, state2.attemptCount)
    }

    // MARK: - G. Sendable Conformance Tests

    func testCanBePassedToAsyncAwaitContexts() async throws {
        let orchestrator = sut!

        let result = try await Task.detached { () -> String in
            return try await orchestrator.attemptWithRetry {
                return "success"
            }
        }.value

        XCTAssertEqual(result, "success")
    }

    func testWorksWithTaskDetached() async throws {
        let task = Task.detached { [weak self] () -> Bool in
            guard let self = self else { return false }
            let result = try? await self.sut.attemptWithRetry {
                return true
            }
            return result ?? false
        }

        let result = try await task.value
        XCTAssertTrue(result)
    }

    // MARK: - H. Error Callback Tests

    func testErrorCallbackFiredOnFailure() async throws {
        var errorCallbackCount = 0
        var errorAttempts: [Int] = []

        _ = try? await sut.attemptWithRetry(
            { throw TestError.operationFailed },
            onError: { error, attempt in
                errorCallbackCount += 1
                errorAttempts.append(attempt)
            }
        )

        XCTAssertEqual(errorCallbackCount, 3)
        XCTAssertEqual(errorAttempts, [1, 2, 3])
    }

    func testErrorCallbackNotFiredOnSuccess() async throws {
        var errorCallbackCount = 0

        _ = try await sut.attemptWithRetry(
            { return "success" },
            onError: { _, _ in
                errorCallbackCount += 1
            }
        )

        XCTAssertEqual(errorCallbackCount, 0)
    }

    // MARK: - I. Generic Type Tests

    func testWorksWithDifferentReturnTypes() async throws {
        let stringResult = try await sut.attemptWithRetry {
            return "test"
        }
        XCTAssertEqual(stringResult, "test")

        await sut.reset()

        let intResult = try await sut.attemptWithRetry {
            return 42
        }
        XCTAssertEqual(intResult, 42)

        await sut.reset()

        let boolResult = try await sut.attemptWithRetry {
            return true
        }
        XCTAssertTrue(boolResult)
    }

    // MARK: - Helper Types

    enum TestError: Error, Equatable {
        case operationFailed
        case networkTimeout
        case invalidData
    }
}
