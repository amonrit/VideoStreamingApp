import Foundation

/// Polling service for stream updates using PollingService<Int>.
/// Replaces Timer-based polling with modern async/await patterns.
///
/// Actor-isolated so `lastUpdateTime`/`lastError`/`isCurrentlyPolling` can't be
/// written by the polling `Task` while a caller reads them at the same time —
/// previously this was a `Sendable` class with `nonisolated(unsafe)` state, which
/// only silenced the compiler rather than making concurrent access safe.
public actor StreamAdminPollingService {
    // MARK: - Properties

    private let configuration: PlaybackConfiguration
    private let fetchStreams: @Sendable () async throws -> Int
    private var pollingService: PollingService<Int>?
    private var pollingTask: Task<Void, Never>?
    private var lastUpdateTime: Date?
    private var lastError: Error?
    private var isCurrentlyPolling: Bool = false

    // MARK: - Initialization

    /// Creates a stream admin polling service
    /// - Parameters:
    ///   - configuration: PlaybackConfiguration for polling intervals
    ///   - fetchStreams: Async closure that fetches stream count
    public init(
        configuration: PlaybackConfiguration = .production,
        fetchStreams: @escaping @Sendable () async throws -> Int
    ) {
        self.configuration = configuration
        self.fetchStreams = fetchStreams
    }

    // MARK: - Public Methods

    /// Starts polling for stream updates
    public func startPolling() {
        guard !isCurrentlyPolling else { return }

        isCurrentlyPolling = true

        // Create polling service with retry support
        let service = PollingService<Int>.withRetry(
            interval: 2.0,
            timeout: configuration.pollingTimeout,
            maxRetries: 2,
            retryStrategy: .exponential(),
            operation: fetchStreams
        )
        pollingService = service

        pollingTask = Task {
            do {
                let sequence = await service.startPolling()
                for try await _ in sequence {
                    self.lastUpdateTime = Date()
                    self.lastError = nil
                }
            } catch {
                self.lastError = error
            }
        }
    }

    /// Stops polling for stream updates
    public func stopPolling() {
        isCurrentlyPolling = false
        pollingTask?.cancel()
        pollingTask = nil
        // Dropping the reference is enough — cancelling `pollingTask` already
        // stops the consuming loop, and PollingService.stopPolling() is itself
        // actor-isolated so it can't be awaited from here without making this
        // method async (which would ripple into every call site for little gain).
        pollingService = nil
    }

    /// Gets the last update time
    /// - Returns: Date of last successful update or nil
    public func getLastUpdateTime() -> Date? {
        lastUpdateTime
    }

    /// Gets the last error that occurred during polling
    /// - Returns: Error or nil if no error occurred
    public func getLastError() -> Error? {
        lastError
    }

    /// Checks if currently polling
    /// - Returns: True if polling is active
    public func isPolling() -> Bool {
        isCurrentlyPolling
    }

    /// Resets polling state
    public func reset() {
        lastUpdateTime = nil
        lastError = nil
        isCurrentlyPolling = false
        pollingTask?.cancel()
        pollingTask = nil
        pollingService = nil
    }

    deinit {
        // Actor deinit can't `await`, so we can't call the (actor-isolated)
        // stopPolling() here — cancelling the task directly is enough since
        // it's what actually tears down the consuming loop.
        pollingTask?.cancel()
    }
}
