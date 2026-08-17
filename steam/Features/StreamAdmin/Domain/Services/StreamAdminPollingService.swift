import Foundation

/// Polling service for stream updates using PollingService<Int>.
/// Replaces Timer-based polling with modern async/await patterns.
public final class StreamAdminPollingService: Sendable {
    // MARK: - Properties

    private let configuration: PlaybackConfiguration
    private let fetchStreams: @Sendable () async throws -> Int
    private var pollingService: PollingService<Int>?
    private var pollingTask: Task<Void, Never>?
    private nonisolated(unsafe) var lastUpdateTime: Date?
    private nonisolated(unsafe) var lastError: Error?
    private nonisolated(unsafe) var isCurrentlyPolling: Bool = false

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
        pollingService = PollingService<Int>.withRetry(
            interval: 2.0,
            timeout: configuration.pollingTimeout,
            maxRetries: 2,
            retryStrategy: .exponential()
        ) { [weak self] in
            guard let self = self else { throw PollingError.cancelled }
            return try await self.fetchStreams()
        }

        // Start polling loop
        guard let service = pollingService else { return }

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

        guard let service = pollingService else { return }

        Task {
            await service.stopPolling()
        }
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
        pollingService?.stopPolling()
        pollingTask?.cancel()
        pollingTask = nil
    }

    deinit {
        stopPolling()
    }
}
