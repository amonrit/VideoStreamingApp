import Foundation

/// Polling service for viewer count updates using PollingService<Int>.
/// Replaces Timer-based polling with modern async/await patterns.
///
/// Actor-isolated so `lastCount`/`lastError`/`isCurrentlyPolling` can't be written
/// by the polling `Task` while a caller reads them at the same time — previously
/// this was a `Sendable` class with `nonisolated(unsafe)` state, which only
/// silenced the compiler rather than making concurrent access safe.
public actor ViewerCountPollingService {
    // MARK: - Properties

    private let configuration: PlaybackConfiguration
    private let fetchCount: @Sendable () async throws -> Int
    private var pollingService: PollingService<Int>?
    private var pollingTask: Task<Void, Never>?
    private var lastCount: Int?
    private var lastError: Error?
    private var isCurrentlyPolling: Bool = false

    // MARK: - Initialization

    /// Creates a viewer count polling service
    /// - Parameters:
    ///   - configuration: PlaybackConfiguration for polling intervals
    ///   - fetchCount: Async closure that fetches current viewer count
    public init(
        configuration: PlaybackConfiguration = .production,
        fetchCount: @escaping @Sendable () async throws -> Int
    ) {
        self.configuration = configuration
        self.fetchCount = fetchCount
    }

    // MARK: - Public Methods

    /// Starts polling for viewer count updates
    public func startPolling() {
        guard !isCurrentlyPolling else { return }

        isCurrentlyPolling = true

        // Create polling service with retry support
        let service = PollingService<Int>.withRetry(
            interval: configuration.viewerCountPollingInterval,
            timeout: configuration.pollingTimeout,
            maxRetries: 2,
            retryStrategy: .exponential(),
            operation: fetchCount
        )
        pollingService = service

        pollingTask = Task {
            do {
                let sequence = await service.startPolling()
                for try await count in sequence {
                    self.lastCount = count
                    self.lastError = nil
                }
            } catch {
                self.lastError = error
            }
        }
    }

    /// Stops polling for viewer count updates
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

    /// Gets the last successfully polled viewer count
    /// - Returns: Viewer count or nil if not yet polled
    public func getLastCount() -> Int? {
        lastCount
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
        lastCount = nil
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
