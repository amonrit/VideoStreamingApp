import Foundation

/// Defines different strategies for calculating delay between retry attempts.
public enum RetryStrategy {
    /// Fixed delay between retries (e.g., always wait 2 seconds)
    case fixed(TimeInterval)

    /// Linear backoff: delay increases linearly (1s, 2s, 3s, 4s...)
    case linear(baseDelay: TimeInterval)

    /// Exponential backoff: delay increases exponentially (1s, 2s, 4s, 8s...)
    case exponential(baseDelay: TimeInterval = 1.0, multiplier: Double = 2.0, maxDelay: TimeInterval = 30.0)

    // MARK: - Calculation

    /// Calculates the delay for a specific retry attempt number
    /// - Parameters:
    ///   - attempt: The retry attempt number (0-indexed)
    ///   - maxDelay: Maximum allowed delay across all strategies
    /// - Returns: Time interval to wait before this retry attempt
    public nonisolated func delay(forAttempt attempt: Int, maxDelay: TimeInterval? = nil) -> TimeInterval {
        let attemptCount = Double(attempt + 1)

        switch self {
        case .fixed(let delay):
            return min(delay, maxDelay ?? .infinity)

        case .linear(let baseDelay):
            let calculatedDelay = baseDelay * attemptCount
            return min(calculatedDelay, maxDelay ?? .infinity)

        case .exponential(let baseDelay, let multiplier, let strategyMaxDelay):
            let finalMaxDelay = maxDelay ?? strategyMaxDelay
            let calculatedDelay = baseDelay * pow(multiplier, attemptCount - 1)
            return min(calculatedDelay, finalMaxDelay)
        }
    }

    /// Calculates total time spent retrying for a given number of attempts
    /// - Parameters:
    ///   - attempts: Number of retry attempts
    ///   - maxDelay: Maximum allowed delay per retry
    /// - Returns: Total accumulated delay time
    public nonisolated func totalDelay(forAttempts attempts: Int, maxDelay: TimeInterval? = nil) -> TimeInterval {
        (0..<attempts).reduce(0) { total, attempt in
            total + delay(forAttempt: attempt, maxDelay: maxDelay)
        }
    }
}

// MARK: - Convenience Extensions

extension RetryStrategy {
    /// Returns a delay with added jitter to prevent thundering herd
    /// - Parameters:
    ///   - attempt: The retry attempt number
    ///   - maxDelay: Maximum allowed delay
    ///   - jitterPercentage: Percentage of random jitter to add (0.0-1.0, default: 0.1 = 10%)
    /// - Returns: Calculated delay with random jitter applied
    public nonisolated func delayWithJitter(
        forAttempt attempt: Int,
        maxDelay: TimeInterval? = nil,
        jitterPercentage: Double = 0.1
    ) -> TimeInterval {
        let baseDelay = delay(forAttempt: attempt, maxDelay: maxDelay)
        let jitterAmount = baseDelay * jitterPercentage
        let randomJitter = Double.random(in: -jitterAmount...jitterAmount)
        return max(0, baseDelay + randomJitter)
    }
}

// MARK: - Hashable & Equatable

extension RetryStrategy: Hashable, Equatable {
    public static func == (lhs: RetryStrategy, rhs: RetryStrategy) -> Bool {
        switch (lhs, rhs) {
        case (.fixed(let lhsDelay), .fixed(let rhsDelay)):
            return lhsDelay == rhsDelay

        case (.linear(let lhsBase), .linear(let rhsBase)):
            return lhsBase == rhsBase

        case (
            .exponential(let lhsBase, let lhsMult, let lhsMax),
            .exponential(let rhsBase, let rhsMult, let rhsMax)
        ):
            return lhsBase == rhsBase && lhsMult == rhsMult && lhsMax == rhsMax

        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .fixed(let delay):
            hasher.combine(0)
            hasher.combine(delay)

        case .linear(let baseDelay):
            hasher.combine(1)
            hasher.combine(baseDelay)

        case .exponential(let baseDelay, let multiplier, let maxDelay):
            hasher.combine(2)
            hasher.combine(baseDelay)
            hasher.combine(multiplier)
            hasher.combine(maxDelay)
        }
    }
}

// MARK: - CustomStringConvertible

extension RetryStrategy: CustomStringConvertible {
    public var description: String {
        switch self {
        case .fixed(let delay):
            return "RetryStrategy.fixed(\(delay)s)"

        case .linear(let baseDelay):
            return "RetryStrategy.linear(\(baseDelay)s)"

        case .exponential(let baseDelay, let multiplier, let maxDelay):
            return "RetryStrategy.exponential(base: \(baseDelay)s, mult: \(multiplier), max: \(maxDelay)s)"
        }
    }
}
