import Foundation

/// Orchestrates retry logic with state management and messaging.
/// Centralizes all retry behavior from ViewModels into a reusable service.
///
/// `@MainActor`-isolated (matching this project's default actor isolation, and
/// `RetryState`'s) so `retryState` can never be mutated from two callers at
/// once — previously this was a `Sendable` class with `nonisolated(unsafe)`
/// state, which only silenced the compiler rather than making concurrent
/// access safe.
@MainActor
public final class RetryOrchestrator: Sendable {
    // MARK: - Properties

    private let configuration: PlaybackConfiguration
    private var retryState: RetryState
    private var onStatusChanged: ((String) -> Void)?

    // MARK: - Initialization

    /// Creates a RetryOrchestrator with specified configuration
    /// - Parameters:
    ///   - configuration: PlaybackConfiguration for retry settings
    ///   - onStatusChanged: Optional callback for status messages
    public init(
        configuration: PlaybackConfiguration = .production,
        onStatusChanged: ((String) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.retryState = RetryState(configuration: configuration)
        self.onStatusChanged = onStatusChanged
    }

    // MARK: - Public Methods

    /// Executes an operation with automatic retry logic
    /// - Parameters:
    ///   - operation: Async operation to retry
    ///   - onError: Optional error handler for each failure
    /// - Returns: Result of operation if successful
    public func attemptWithRetry<T: Sendable>(
        _ operation: @Sendable () async throws -> T,
        onError: @Sendable (Error, Int) -> Void = { _, _ in }
    ) async throws -> T {
        reset()

        while retryState.hasRetriesRemaining {
            do {
                retryState.recordAttempt()
                let result = try await operation()
                retryState.recordSuccess()
                notifyStatus("✅ Success on attempt \(retryState.attemptCount)")
                return result
            } catch {
                retryState.recordFailure(error: error)
                onError(error, retryState.attemptCount)

                if retryState.hasRetriesRemaining {
                    let delay = retryState.nextDelay
                    notifyStatus("❌ Attempt \(retryState.attemptCount) failed, retrying in \(String(format: "%.1f", delay))s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    notifyStatus("❌ Failed after \(retryState.attemptCount) attempts")
                    throw error
                }
            }
        }

        throw RetryOrchestratorError.maxRetriesExceeded
    }

    /// Gets current retry state
    /// - Returns: Current RetryState
    public func getState() -> RetryState {
        retryState
    }

    /// Gets last error encountered
    /// - Returns: Error or nil if none
    public func getLastError() -> Error? {
        retryState.lastError
    }

    /// Resets retry state
    public func reset() {
        retryState.reset()
    }

    // MARK: - Private Methods

    private func notifyStatus(_ message: String) {
        onStatusChanged?(message)
    }
}

// MARK: - Error Types

/// Errors that can occur during retry orchestration
public enum RetryOrchestratorError: LocalizedError {
    case maxRetriesExceeded

    public var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
}
