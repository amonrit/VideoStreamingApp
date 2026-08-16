import XCTest
@testable import steam

final class PlaybackConfigurationTests: XCTestCase {
    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let config = PlaybackConfiguration()

        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertEqual(config.initialRetryDelay, 1.0)
        XCTAssertEqual(config.maxRetryDelay, 30.0)
        XCTAssertEqual(config.retryBackoffMultiplier, 2.0)
        XCTAssertEqual(config.viewerCountPollingInterval, 5.0)
        XCTAssertEqual(config.healthCheckPollingInterval, 10.0)
        XCTAssertEqual(config.pollingTimeout, 8.0)
        XCTAssertEqual(config.streamConnectionTimeout, 15.0)
        XCTAssertEqual(config.bufferingTimeout, 20.0)
        XCTAssertEqual(config.streamLoadTimeout, 30.0)
        XCTAssertEqual(config.maxConcurrentRequests, 4)
        XCTAssertEqual(config.requestTimeout, 30.0)
    }

    func testCustomInitialization() {
        let config = PlaybackConfiguration(
            maxRetryAttempts: 5,
            initialRetryDelay: 0.5,
            maxRetryDelay: 60.0,
            retryBackoffMultiplier: 1.5,
            retryStrategy: .linear(baseDelay: 1.0),
            viewerCountPollingInterval: 3.0,
            healthCheckPollingInterval: 15.0,
            pollingTimeout: 10.0,
            streamConnectionTimeout: 20.0,
            bufferingTimeout: 25.0,
            streamLoadTimeout: 40.0,
            maxConcurrentRequests: 8,
            requestTimeout: 45.0
        )

        XCTAssertEqual(config.maxRetryAttempts, 5)
        XCTAssertEqual(config.initialRetryDelay, 0.5)
        XCTAssertEqual(config.maxRetryDelay, 60.0)
        XCTAssertEqual(config.retryBackoffMultiplier, 1.5)
        XCTAssertEqual(config.viewerCountPollingInterval, 3.0)
        XCTAssertEqual(config.healthCheckPollingInterval, 15.0)
        XCTAssertEqual(config.pollingTimeout, 10.0)
        XCTAssertEqual(config.streamConnectionTimeout, 20.0)
        XCTAssertEqual(config.bufferingTimeout, 25.0)
        XCTAssertEqual(config.streamLoadTimeout, 40.0)
        XCTAssertEqual(config.maxConcurrentRequests, 8)
        XCTAssertEqual(config.requestTimeout, 45.0)
    }

    // MARK: - Production Preset Tests

    func testProductionPreset() {
        let config = PlaybackConfiguration.production

        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertEqual(config.initialRetryDelay, 1.0)
        XCTAssertEqual(config.maxRetryDelay, 30.0)
    }

    func testDebugPreset_longerTimeouts() {
        let config = PlaybackConfiguration.debug

        // Debug should have more retry attempts
        XCTAssertGreaterThan(config.maxRetryAttempts, PlaybackConfiguration.production.maxRetryAttempts)

        // Debug should have shorter initial delays for faster testing
        XCTAssertLessThan(config.initialRetryDelay, PlaybackConfiguration.production.initialRetryDelay)

        // Debug should have shorter polling intervals
        XCTAssertLessThan(
            config.viewerCountPollingInterval,
            PlaybackConfiguration.production.viewerCountPollingInterval
        )
    }

    func testAggressiveRetryPreset() {
        let config = PlaybackConfiguration.aggressiveRetry

        // Aggressive should allow more retries
        XCTAssertGreaterThanOrEqual(config.maxRetryAttempts, 5)

        // Aggressive should have higher max delay for longer tail coverage
        XCTAssertGreaterThan(
            config.maxRetryDelay,
            PlaybackConfiguration.production.maxRetryDelay
        )
    }

    func testConservativePreset() {
        let config = PlaybackConfiguration.conservative

        // Conservative should have fewer retries
        XCTAssertLessThan(config.maxRetryAttempts, PlaybackConfiguration.production.maxRetryAttempts)

        // Conservative should have longer polling intervals
        XCTAssertGreaterThan(
            config.viewerCountPollingInterval,
            PlaybackConfiguration.production.viewerCountPollingInterval
        )
    }

    // MARK: - Retry Configuration Consistency Tests

    func testRetryConfigurationLogic() {
        let config = PlaybackConfiguration(
            maxRetryAttempts: 3,
            initialRetryDelay: 1.0,
            maxRetryDelay: 10.0
        )

        // Initial delay should be less than max delay
        XCTAssertLessThan(config.initialRetryDelay, config.maxRetryDelay)

        // Max concurrent requests should be positive
        XCTAssertGreaterThan(config.maxConcurrentRequests, 0)
    }

    func testPollingTimeouts() {
        let config = PlaybackConfiguration()

        // Polling timeout should be less than stream connection timeout
        XCTAssertLessThan(config.pollingTimeout, config.streamConnectionTimeout)
    }

    // MARK: - Configuration Bounds Tests

    func testAllTimeoutsArePositive() {
        let config = PlaybackConfiguration()

        XCTAssertGreaterThan(config.streamConnectionTimeout, 0)
        XCTAssertGreaterThan(config.bufferingTimeout, 0)
        XCTAssertGreaterThan(config.streamLoadTimeout, 0)
        XCTAssertGreaterThan(config.pollingTimeout, 0)
        XCTAssertGreaterThan(config.requestTimeout, 0)
    }

    func testAllRetryValuesArePositive() {
        let config = PlaybackConfiguration()

        XCTAssertGreaterThan(config.maxRetryAttempts, 0)
        XCTAssertGreaterThan(config.initialRetryDelay, 0)
        XCTAssertGreaterThan(config.maxRetryDelay, 0)
        XCTAssertGreaterThan(config.retryBackoffMultiplier, 1.0)
    }

    func testAllPollingIntervalsArePositive() {
        let config = PlaybackConfiguration()

        XCTAssertGreaterThan(config.viewerCountPollingInterval, 0)
        XCTAssertGreaterThan(config.healthCheckPollingInterval, 0)
    }

    // MARK: - Edge Case Tests

    func testExtremeLongTimeouts() {
        let config = PlaybackConfiguration(
            streamConnectionTimeout: 300.0,
            bufferingTimeout: 600.0,
            streamLoadTimeout: 900.0
        )

        XCTAssertEqual(config.streamConnectionTimeout, 300.0)
        XCTAssertEqual(config.bufferingTimeout, 600.0)
        XCTAssertEqual(config.streamLoadTimeout, 900.0)
    }

    func testHighRetryAttempts() {
        let config = PlaybackConfiguration(maxRetryAttempts: 10)
        XCTAssertEqual(config.maxRetryAttempts, 10)
    }

    func testSmallRetryDelays() {
        let config = PlaybackConfiguration(
            initialRetryDelay: 0.1,
            maxRetryDelay: 0.5
        )

        XCTAssertEqual(config.initialRetryDelay, 0.1)
        XCTAssertEqual(config.maxRetryDelay, 0.5)
    }

    func testHighConcurrentRequests() {
        let config = PlaybackConfiguration(maxConcurrentRequests: 20)
        XCTAssertEqual(config.maxConcurrentRequests, 20)
    }

    // MARK: - Preset Consistency Tests

    func testPresetsAreConsistent() {
        let presets = [
            PlaybackConfiguration.production,
            PlaybackConfiguration.debug,
            PlaybackConfiguration.aggressiveRetry,
            PlaybackConfiguration.conservative
        ]

        // All presets should have valid configurations
        for preset in presets {
            XCTAssertGreaterThan(preset.maxRetryAttempts, 0)
            XCTAssertGreaterThan(preset.initialRetryDelay, 0)
            XCTAssertGreaterThan(preset.maxRetryDelay, 0)
            XCTAssertLessThanOrEqual(preset.initialRetryDelay, preset.maxRetryDelay)
        }
    }

    // MARK: - Retry Strategy Integration Tests

    func testRetryStrategyStoredCorrectly() {
        let strategy = RetryStrategy.exponential(baseDelay: 0.5, multiplier: 2.0, maxDelay: 60.0)
        let config = PlaybackConfiguration(retryStrategy: strategy)

        XCTAssertEqual(config.retryStrategy, strategy)
    }

    func testDefaultRetryStrategyIsExponential() {
        let config = PlaybackConfiguration()

        // The stored strategy should be the default .exponential
        XCTAssertEqual(config.retryStrategy, .exponential())
    }
}
