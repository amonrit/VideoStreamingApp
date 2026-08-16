import Foundation

// MARK: - Retry Playback Use Case

/// Use case for handling playback retry logic with exponential backoff
///
/// Responsibilities:
/// - Track retry attempts
/// - Calculate exponential backoff delay
/// - Determine if retry is allowed
/// - Notify of retry status
protocol RetryPlaybackUseCaseProtocol {
    func shouldRetry() -> Bool
    func nextRetryDelay() -> TimeInterval
    func recordRetry()
    func reset()
    var retryCount: Int { get }
}

class RetryPlaybackUseCase: RetryPlaybackUseCaseProtocol {
    private(set) var retryCount: Int = 0
    private let maxRetries: Int
    private let baseDelay: TimeInterval = 1.0  // 1 second base
    private let maxDelay: TimeInterval = 5.0   // cap at 5 seconds

    init(maxRetries: Int = 3) {
        self.maxRetries = maxRetries
    }

    /// Check if retry is allowed
    /// - Returns: true if retry count is below max, false otherwise
    func shouldRetry() -> Bool {
        retryCount < maxRetries
    }

    /// Calculate next retry delay using exponential backoff
    /// - Returns: Delay in seconds (with some randomization to prevent thundering herd)
    func nextRetryDelay() -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s (capped at 5s)
        let exponentialDelay = min(baseDelay * pow(2.0, Double(retryCount)), maxDelay)

        // Add small random jitter (±10%) to prevent synchronized retries
        let jitter = Double.random(in: -0.1...0.1) * exponentialDelay
        return max(0.1, exponentialDelay + jitter)
    }

    /// Record a retry attempt
    func recordRetry() {
        retryCount += 1
    }

    /// Reset retry counter
    func reset() {
        retryCount = 0
    }
}
