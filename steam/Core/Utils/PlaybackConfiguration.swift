import Foundation

/// Centralizes all playback timing constants and configuration parameters.
/// Replaces magic numbers throughout the app with configurable values.
/// Supports different retry strategies and polling intervals.
public struct PlaybackConfiguration {
    // MARK: - Retry Configuration

    /// Maximum number of retry attempts before giving up
    public let maxRetryAttempts: Int

    /// Initial delay between retry attempts (in seconds)
    public let initialRetryDelay: TimeInterval

    /// Maximum delay between retry attempts (in seconds)
    public let maxRetryDelay: TimeInterval

    /// Backoff multiplier for exponential retry strategy
    public let retryBackoffMultiplier: Double

    /// Retry strategy to use (exponential, linear, or fixed)
    public let retryStrategy: RetryStrategy

    // MARK: - Polling Configuration

    /// Interval for polling viewer count updates (in seconds)
    public let viewerCountPollingInterval: TimeInterval

    /// Interval for health check polling (in seconds)
    public let healthCheckPollingInterval: TimeInterval

    /// Timeout for individual polling requests (in seconds)
    public let pollingTimeout: TimeInterval

    // MARK: - Playback Configuration

    /// Timeout for initial stream connection (in seconds)
    public let streamConnectionTimeout: TimeInterval

    /// Timeout for buffering before considering it a stall (in seconds)
    public let bufferingTimeout: TimeInterval

    /// Timeout for stream loading (in seconds)
    public let streamLoadTimeout: TimeInterval

    // MARK: - Network Configuration

    /// Maximum concurrent network requests
    public let maxConcurrentRequests: Int

    /// Request timeout (in seconds)
    public let requestTimeout: TimeInterval

    // MARK: - Initialization

    /// Creates a PlaybackConfiguration with specified parameters
    /// - Parameters:
    ///   - maxRetryAttempts: Maximum retry attempts (default: 3)
    ///   - initialRetryDelay: Initial retry delay in seconds (default: 1.0)
    ///   - maxRetryDelay: Maximum retry delay in seconds (default: 30.0)
    ///   - retryBackoffMultiplier: Multiplier for exponential backoff (default: 2.0)
    ///   - retryStrategy: Retry strategy to use (default: .exponential())
    ///   - viewerCountPollingInterval: Viewer count poll interval in seconds (default: 5.0)
    ///   - healthCheckPollingInterval: Health check poll interval in seconds (default: 10.0)
    ///   - pollingTimeout: Polling request timeout in seconds (default: 8.0)
    ///   - streamConnectionTimeout: Stream connection timeout in seconds (default: 15.0)
    ///   - bufferingTimeout: Buffering timeout in seconds (default: 20.0)
    ///   - streamLoadTimeout: Stream load timeout in seconds (default: 30.0)
    ///   - maxConcurrentRequests: Max concurrent requests (default: 4)
    ///   - requestTimeout: Request timeout in seconds (default: 30.0)
    public init(
        maxRetryAttempts: Int = 3,
        initialRetryDelay: TimeInterval = 1.0,
        maxRetryDelay: TimeInterval = 30.0,
        retryBackoffMultiplier: Double = 2.0,
        retryStrategy: RetryStrategy = .exponential(),
        viewerCountPollingInterval: TimeInterval = 5.0,
        healthCheckPollingInterval: TimeInterval = 10.0,
        pollingTimeout: TimeInterval = 8.0,
        streamConnectionTimeout: TimeInterval = 15.0,
        bufferingTimeout: TimeInterval = 20.0,
        streamLoadTimeout: TimeInterval = 30.0,
        maxConcurrentRequests: Int = 4,
        requestTimeout: TimeInterval = 30.0
    ) {
        self.maxRetryAttempts = maxRetryAttempts
        self.initialRetryDelay = initialRetryDelay
        self.maxRetryDelay = maxRetryDelay
        self.retryBackoffMultiplier = retryBackoffMultiplier
        self.retryStrategy = retryStrategy
        self.viewerCountPollingInterval = viewerCountPollingInterval
        self.healthCheckPollingInterval = healthCheckPollingInterval
        self.pollingTimeout = pollingTimeout
        self.streamConnectionTimeout = streamConnectionTimeout
        self.bufferingTimeout = bufferingTimeout
        self.streamLoadTimeout = streamLoadTimeout
        self.maxConcurrentRequests = maxConcurrentRequests
        self.requestTimeout = requestTimeout
    }

    // MARK: - Preset Configurations

    /// Default production configuration with exponential retry strategy
    public static let production = PlaybackConfiguration(retryStrategy: .exponential())

    /// Debug configuration with longer timeouts and more retry attempts
    public static let debug = PlaybackConfiguration(
        maxRetryAttempts: 5,
        initialRetryDelay: 0.5,
        viewerCountPollingInterval: 2.0,
        healthCheckPollingInterval: 5.0
    )

    /// Aggressive retry configuration for unreliable networks
    public static let aggressiveRetry = PlaybackConfiguration(
        maxRetryAttempts: 5,
        initialRetryDelay: 0.5,
        maxRetryDelay: 60.0,
        retryBackoffMultiplier: 1.5,
        retryStrategy: .exponential()
    )

    /// Conservative configuration for stable networks
    public static let conservative = PlaybackConfiguration(
        maxRetryAttempts: 2,
        initialRetryDelay: 2.0,
        maxRetryDelay: 15.0,
        viewerCountPollingInterval: 10.0,
        healthCheckPollingInterval: 20.0
    )
}
