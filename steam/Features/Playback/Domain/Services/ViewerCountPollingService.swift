import Foundation

/// Polling service for viewer count updates using PollingService<Int>.
/// Replaces Timer-based polling with modern async/await patterns.
public final class ViewerCountPollingService: Sendable {
    // MARK: - Properties

    private let configuration: PlaybackConfiguration
    private let fetchCount: @Sendable () async throws -> Int
    private var pollingService: PollingService<Int>?
    private var pollingTask: Task<Void, Never>?
    private nonisolated(unsafe) var lastCount: Int?
    private nonisolated(unsafe) var lastError: Error?
    private nonisolated(unsafe) var isCurrentlyPolling: Bool = false

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
        pollingService = PollingService<Int>.withRetry(
            interval: configuration.viewerCountPollingInterval,
            timeout: configuration.pollingTimeout,
            maxRetries: 2,
            retryStrategy: .exponential()
        ) { [weak self] in
            guard let self = self else { throw PollingError.cancelled }
            return try await self.fetchCount()
        }

        // Start polling loop
        guard let service = pollingService else { return }

        pollingTask = Task {
            do {
                for try await count in service.startPolling() {
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
        pollingService?.stopPolling()
        pollingTask?.cancel()
        pollingTask = nil
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
        pollingService?.stopPolling()
        pollingTask?.cancel()
        pollingTask = nil
    }

    deinit {
        stopPolling()
    }
}
