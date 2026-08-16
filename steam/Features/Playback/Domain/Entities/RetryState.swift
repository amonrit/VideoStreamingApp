import Foundation

/// Encapsulates retry attempt tracking, timing, and backoff calculation.
/// Provides state management for retry logic with configuration-driven behavior.
public struct RetryState: Equatable, Sendable {
    private let configuration: PlaybackConfiguration
    private let retryStrategy: RetryStrategy

    public private(set) var attemptCount: Int = 0
    public private(set) var lastAttemptTime: Date?
    public private(set) var totalRetryTime: TimeInterval = 0
    public private(set) var isRetrying: Bool = false
    public private(set) var lastError: Error?

    // MARK: - Initialization

    /// Creates a RetryState with specified configuration and strategy
    /// - Parameters:
    ///   - configuration: PlaybackConfiguration for retry limits
    ///   - retryStrategy: RetryStrategy for calculating delays
    public init(
        configuration: PlaybackConfiguration = .production,
        retryStrategy: RetryStrategy = .exponential()
    ) {
        self.configuration = configuration
        self.retryStrategy = retryStrategy
    }

    // MARK: - Computed Properties

    /// Maximum number of retry attempts allowed
    public var maxAttempts: Int {
        configuration.maxRetryAttempts
    }

    /// Remaining number of retry attempts available
    public var remainingAttempts: Int {
        max(0, maxAttempts - attemptCount)
    }

    /// Whether there are retry attempts remaining
    public var hasRetriesRemaining: Bool {
        attemptCount < maxAttempts
    }

    /// Delay to wait before next retry attempt
    public var nextDelay: TimeInterval {
        retryStrategy.delay(
            forAttempt: attemptCount,
            maxDelay: configuration.maxRetryDelay
        )
    }

    /// Delay with jitter to prevent thundering herd
    public var nextDelayWithJitter: TimeInterval {
        retryStrategy.delayWithJitter(
            forAttempt: attemptCount,
            maxDelay: configuration.maxRetryDelay,
            jitterPercentage: 0.1
        )
    }

    /// Progress from 0.0 (no retries) to 1.0 (max retries reached)
    public var progress: Double {
        let total = Double(maxAttempts)
        let current = Double(attemptCount)
        return min(1.0, max(0.0, current / total))
    }

    /// Total time spent in retry attempts
    public var totalTime: TimeInterval {
        totalRetryTime
    }

    /// Whether currently in retry state
    public var isInRetry: Bool {
        isRetrying
    }

    // MARK: - State Modification Methods

    /// Records a new retry attempt
    public mutating func recordAttempt() {
        isRetrying = true
        lastAttemptTime = Date()
        attemptCount += 1
    }

    /// Records a failure with error
    /// - Parameter error: The error that occurred
    public mutating func recordFailure(error: Error) {
        lastError = error
        let delay = nextDelay
        totalRetryTime += delay
    }

    /// Records a successful attempt and resets state
    public mutating func recordSuccess() {
        reset()
    }

    /// Resets all retry state
    public mutating func reset() {
        isRetrying = false
        attemptCount = 0
        lastAttemptTime = nil
        totalRetryTime = 0
        lastError = nil
    }

    /// Returns whether retry should be attempted
    public var shouldRetry: Bool {
        hasRetriesRemaining && !isRetrying
    }

    // MARK: - Equatable Conformance

    public static func == (lhs: RetryState, rhs: RetryState) -> Bool {
        lhs.attemptCount == rhs.attemptCount &&
            lhs.lastAttemptTime == rhs.lastAttemptTime &&
            lhs.totalRetryTime == rhs.totalRetryTime &&
            lhs.isRetrying == rhs.isRetrying
    }
}

// MARK: - CustomStringConvertible

extension RetryState: CustomStringConvertible {
    public var description: String {
        "RetryState(attempts: \(attemptCount)/\(maxAttempts), progress: \(String(format: "%.1f", progress * 100))%, time: \(String(format: "%.1f", totalRetryTime))s)"
    }
}
