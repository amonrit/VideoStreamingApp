import Foundation

/// Manages polling state for viewer count with automatic failure recovery.
/// Tracks polling status, failures, and provides retry logic for resilience.
public struct ViewerCountState: Equatable, Sendable {
    private let configuration: PlaybackConfiguration

    public internal(set) var currentCount: Int?
    public internal(set) var lastUpdateTime: Date?
    public internal(set) var failureCount: Int = 0
    public internal(set) var isPolling: Bool = false
    public internal(set) var lastError: Error?

    // MARK: - Initialization

    /// Creates a ViewerCountState with specified configuration
    /// - Parameter configuration: PlaybackConfiguration for polling parameters
    public init(configuration: PlaybackConfiguration = .production) {
        self.configuration = configuration
    }

    // MARK: - Computed Properties

    /// Polling interval from configuration
    public var pollingInterval: TimeInterval {
        configuration.viewerCountPollingInterval
    }

    /// Maximum failures before stopping polling
    public var maxFailures: Int {
        3  // Hardcoded for now, could be in configuration
    }

    /// Whether polling can continue
    public var canContinuePolling: Bool {
        failureCount < maxFailures
    }

    /// Whether retry should be attempted
    public var shouldRetry: Bool {
        failureCount < maxFailures && !isPolling
    }

    /// Progress from 0.0 (no failures) to 1.0 (max failures reached)
    public var failureProgress: Double {
        let total = Double(maxFailures)
        let current = Double(failureCount)
        return min(1.0, max(0.0, current / total))
    }

    /// Time since last successful update
    public var timeSinceLastUpdate: TimeInterval? {
        guard let updateTime = lastUpdateTime else { return nil }
        return Date().timeIntervalSince(updateTime)
    }

    /// Whether polling is stale (no update in last interval + buffer)
    public var isStale: Bool {
        guard let timeSinceUpdate = timeSinceLastUpdate else { return true }
        return timeSinceUpdate > (pollingInterval * 1.5)
    }

    // MARK: - State Modification Methods

    /// Starts polling
    public mutating func startPolling() {
        isPolling = true
    }

    /// Stops polling
    public mutating func stopPolling() {
        isPolling = false
    }

    /// Updates viewer count and resets failure counter
    /// - Parameter count: New viewer count value
    public mutating func updateCount(_ count: Int) {
        currentCount = count
        lastUpdateTime = Date()
        failureCount = 0
        lastError = nil
    }

    /// Records a polling failure
    /// - Parameter error: The error that occurred
    public mutating func recordFailure(error: Error) {
        failureCount += 1
        lastError = error
    }

    /// Records successful operation (without updating count)
    public mutating func recordSuccess() {
        lastUpdateTime = Date()
        failureCount = 0
        lastError = nil
    }

    /// Resets all polling state
    public mutating func reset() {
        currentCount = nil
        lastUpdateTime = nil
        failureCount = 0
        isPolling = false
        lastError = nil
    }

    /// Clears failures and allows retry
    public mutating func clearFailures() {
        failureCount = 0
        lastError = nil
    }

    // MARK: - Equatable Conformance

    public static func == (lhs: ViewerCountState, rhs: ViewerCountState) -> Bool {
        lhs.currentCount == rhs.currentCount &&
            lhs.lastUpdateTime == rhs.lastUpdateTime &&
            lhs.failureCount == rhs.failureCount &&
            lhs.isPolling == rhs.isPolling
    }
}

// MARK: - CustomStringConvertible

extension ViewerCountState: CustomStringConvertible {
    public var description: String {
        let countStr = currentCount.map { String($0) } ?? "nil"
        return "ViewerCountState(count: \(countStr), failures: \(failureCount)/\(maxFailures), polling: \(isPolling))"
    }
}
