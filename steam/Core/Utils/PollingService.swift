import Foundation

/// Generic async/await-based polling service that replaces Timer usage.
/// Uses AsyncSequence to emit values at regular intervals, supporting cancellation.
public actor PollingService<Value: Sendable> {
    // MARK: - Types

    /// Result of a polling operation
    public enum PollingResult {
        case value(Value)
        case error(Error)
    }

    /// The async sequence that emits polling values
    public struct PollingSequence: AsyncSequence {
        public typealias Element = Value
        public typealias AsyncIterator = PollingIterator

        fileprivate let service: PollingService<Value>

        public func makeAsyncIterator() -> PollingIterator {
            PollingIterator(service: service)
        }
    }

    /// Iterator for the polling sequence
    public struct PollingIterator: AsyncIteratorProtocol {
        public typealias Element = Value

        fileprivate let service: PollingService<Value>
        fileprivate var isCancelled = false

        public mutating func next() async -> Value? {
            guard !isCancelled else { return nil }

            do {
                let value = try await service.pollOnce()
                return value
            } catch {
                isCancelled = true
                return nil
            }
        }
    }

    // MARK: - Properties

    private let interval: TimeInterval
    private let timeout: TimeInterval
    private let operation: @Sendable () async throws -> Value
    private var pollingTask: Task<Void, Never>?
    private var isRunning = false
    private var lastValue: Value?
    private var lastError: Error?

    // MARK: - Initialization

    /// Creates a polling service that executes an async operation at regular intervals
    /// - Parameters:
    ///   - interval: Time between polls in seconds
    ///   - timeout: Maximum time to wait for each poll operation in seconds
    ///   - operation: Async closure that performs the polling operation
    public init(
        interval: TimeInterval,
        timeout: TimeInterval = 30.0,
        operation: @escaping @Sendable () async throws -> Value
    ) {
        self.interval = interval
        self.timeout = timeout
        self.operation = operation
    }

    // MARK: - Public Methods

    /// Starts polling and returns an async sequence of values
    /// - Returns: AsyncSequence that emits polled values
    public func startPolling() -> PollingSequence {
        isRunning = true
        return PollingSequence(service: self)
    }

    /// Stops the polling operation
    public func stopPolling() {
        isRunning = false
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Gets the last successfully polled value
    /// - Returns: The last value, or nil if no successful poll has occurred
    public func getLastValue() -> Value? {
        lastValue
    }

    /// Gets the last error that occurred during polling
    /// - Returns: The last error, or nil if no error has occurred
    public func getLastError() -> Error? {
        lastError
    }

    // MARK: - Private Methods

    /// Performs a single polling operation with timeout and error handling
    nonisolated private func performPollOnce(
        timeout: TimeInterval,
        interval: TimeInterval,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        // Apply timeout to the operation
        try await withTimeout(interval: timeout) {
            try await operation()
        }
    }

    /// Performs a single polling operation with timeout and error handling
    private func pollOnce() async throws -> Value {
        guard isRunning else {
            throw PollingError.cancelled
        }

        do {
            // Perform the actual polling
            let value = try await performPollOnce(
                timeout: timeout,
                interval: interval,
                operation: operation
            )

            lastValue = value
            lastError = nil

            // Wait for the polling interval before returning
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

            return value
        } catch {
            lastError = error
            throw error
        }
    }

    /// Helper function to apply timeout to an async operation
    private func withTimeout<T>(
        interval: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                throw PollingError.timeout
            }

            // Return first result
            guard let result = try await group.next() else {
                throw PollingError.failed
            }

            // Cancel remaining tasks
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Error Types

/// Errors that can occur during polling
public enum PollingError: LocalizedError {
    case timeout
    case cancelled
    case failed

    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Polling operation timed out"
        case .cancelled:
            return "Polling was cancelled"
        case .failed:
            return "Polling operation failed"
        }
    }
}

// MARK: - Helper Extension

extension PollingService {
    /// Creates a polling service with retry logic
    /// - Parameters:
    ///   - interval: Time between polls in seconds
    ///   - timeout: Maximum time to wait for each poll operation
    ///   - maxRetries: Maximum number of retries per poll
    ///   - retryStrategy: Strategy for calculating retry delays
    ///   - operation: Async closure that performs the polling operation
    /// - Returns: A polling service configured with retry logic
    public static func withRetry(
        interval: TimeInterval,
        timeout: TimeInterval = 30.0,
        maxRetries: Int = 3,
        retryStrategy: RetryStrategy = .exponential(),
        operation: @escaping @Sendable () async throws -> Value
    ) -> PollingService<Value> {
        PollingService(
            interval: interval,
            timeout: timeout,
            operation: {
                var lastError: Error?
                for attempt in 0..<maxRetries {
                    do {
                        return try await operation()
                    } catch {
                        lastError = error
                        if attempt < maxRetries - 1 {
                            let delay = retryStrategy.delay(forAttempt: attempt)
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }
                throw lastError ?? PollingError.failed
            }
        )
    }
}

// MARK: - Usage Example

/*
 Example usage:

 let pollingService = PollingService<Int>(
     interval: 5.0,
     timeout: 10.0
 ) {
     // Fetch viewer count from API
     try await apiClient.getViewerCount()
 }

 // Start polling
 for try await viewerCount in pollingService.startPolling() {
     print("Current viewers: \(viewerCount)")
 }

 // Stop polling when done
 pollingService.stopPolling()

 // With retry:
 let retryService = PollingService.withRetry(
     interval: 5.0,
     maxRetries: 3,
     retryStrategy: .exponential()
 ) {
     try await apiClient.getViewerCount()
 }
 */
