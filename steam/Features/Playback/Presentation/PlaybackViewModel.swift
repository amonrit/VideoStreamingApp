//
//  PlaybackViewModel.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation
import SwiftUI
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "playback")

@MainActor
@Observable
final class PlaybackViewModel {
    // MARK: - Core Properties
    let player: AVPlayer
    private let worker: VideoPlayerWorker
    private let stateActor: DefaultPlaybackStateActor
    // `nonisolated(unsafe)` only to permit reading these from `deinit`, which
    // runs nonisolated and can't touch @MainActor-isolated storage directly
    // (plain `nonisolated` isn't accepted on a mutable stored property).
    // Both types are already Sendable (Task, and ViewerCountPollingService as
    // an actor), so this doesn't weaken any actual safety — it only opts out
    // of isolation *checking*. `@ObservationIgnored` because neither is
    // UI-facing state the way the properties below are.
    @ObservationIgnored
    private nonisolated(unsafe) var stateObserverTask: Task<Void, Never>?
    /// Local, `@Observable`-tracked copy of the actor's state. SwiftUI can only
    /// observe reads of stored properties on this class, not reads that reach
    /// through to a separate actor — this is kept in sync by `observeStateChanges()`
    /// and is what all the `var isLoading`-style computed properties below read from.
    private var state = PlaybackStateSnapshot()
    private var retryOrchestrator: RetryOrchestrator?
    private let playbackConfiguration: PlaybackConfiguration = .production
    @ObservationIgnored
    private nonisolated(unsafe) var viewerCountPollingService: ViewerCountPollingService?
    private let apiClientProvider: APIClientProvider
    private var mediaMTXClient: MediaMTXAPIClientProtocol?
    private var mediaMTXPathName: String?
    private var viewerCountFailureCount: Int = 0
    private let maxViewerCountFailures: Int = 3
    private let loadTimeout: TimeInterval = 3.0
    private let stallTimeout: TimeInterval = 2.0
    private var streamLoadingContinuation: CheckedContinuation<Void, Error>?

    /// Initializes PlaybackViewModel with optional custom API client provider and state actor
    /// - Parameters:
    ///   - player: AVPlayer instance for playback (defaults to new instance)
    ///   - apiClientProvider: Custom provider for API clients (defaults to DefaultAPIClientProvider)
    ///   - stateActor: Custom state actor for testing (defaults to DefaultPlaybackStateActor)
    init(
        player: AVPlayer = AVPlayer(),
        apiClientProvider: APIClientProvider = DefaultAPIClientProvider(),
        stateActor: DefaultPlaybackStateActor = DefaultPlaybackStateActor()
    ) {
        self.player = player
        self.apiClientProvider = apiClientProvider
        self.stateActor = stateActor
        self.worker = VideoPlayerWorker()
        self.volume = Double(player.volume)
        self.playbackRate = player.rate
        setupPlayerSettings()
        observeStateChanges()
    }

    /// Observes state changes from the actor and mirrors them into `state`,
    /// the stored property `@Observable` actually tracks.
    private func observeStateChanges() {
        stateObserverTask = Task {
            for await newState in stateActor.stateUpdates {
                state = newState
            }
        }
    }

    private func setupPlayerSettings() {
        player.allowsExternalPlayback = true
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        player.rate = 1.0
        logger.info("✅ AVPlayer configured for HLS streaming with auto-retry strategy")
    }

    // MARK: - State Properties (from Actor, mirrored via `state`)
    /// Loading state from the playback actor
    var isLoading: Bool {
        state.isLoading
    }

    /// Playing state from the playback actor
    var isPlaying: Bool {
        state.isPlaying
    }

    /// Error message from the playback actor
    var errorMessage: String? {
        state.errorMessage
    }

    /// Buffering count from the playback actor
    var bufferingCount: Int {
        state.bufferingCount
    }

    /// Current stream from the playback actor
    var currentStream: VideoStream? {
        state.currentStream
    }

    /// Connection status from the playback actor
    var connectionStatus: ConnectionStatus {
        state.connectionStatus
    }

    /// Retry attempt count from the playback actor
    var retryAttempt: Int {
        state.retryAttempt
    }

    /// Viewer count from the playback actor
    var viewerCount: Int? {
        state.viewerCount
    }

    // MARK: - Stream Loading

    func loadStream(_ stream: VideoStream) {
        stopViewerCountPolling()
        player.pause()
        viewerCountFailureCount = 0
        logger.info("🛑 Stopped playback of previous stream")

        guard var url = stream.url else {
            let error = "Invalid URL: \(stream.urlString)"
            logger.error("❌ \(error, privacy: .public)")
            presentError(error)
            return
        }

        let urlString = url.absoluteString
        let cleanURLString: String
        if let questionMarkIndex = urlString.firstIndex(of: "?") {
            cleanURLString = String(urlString[..<questionMarkIndex])
        } else {
            cleanURLString = urlString
        }

        if let cleanURL = URL(string: cleanURLString) {
            url = cleanURL
            logger.info("🧹 Cleaned URL: removed session parameters")
        }

        logger.info("📥 Loading stream: \(stream.title, privacy: .public)")
        logger.debug("   Original URL: \(urlString, privacy: .public)")
        logger.debug("   Clean URL: \(url.absoluteString, privacy: .public)")

        Task {
            await stateActor.updateCurrentStream(stream)
            await stateActor.updateLoading(true)
            await stateActor.updateConnectionStatus(.connecting)
            await stateActor.updateViewerCount(nil)
            await loadStreamWithRetry(stream, url: url)
        }
    }

    /// Load stream with automatic retry orchestration
    private func loadStreamWithRetry(_ stream: VideoStream, url: URL) async {
        retryOrchestrator = RetryOrchestrator(
            configuration: playbackConfiguration,
            onStatusChanged: { message in
                logger.info("🔄 Retry: \(message)")
            }
        )

        do {
            _ = try await retryOrchestrator?.attemptWithRetry(
                {
                    try await self.setupStreamWithTimeout(stream, url: url)
                },
                onError: { [weak self] error, attempt in
                    Task {
                        await self?.stateActor.updateRetryAttempt(attempt)
                    }
                    logger.warning("❌ Stream loading attempt \(attempt) failed: \(error.localizedDescription)")
                }
            )

            logger.info("✅ Stream loaded successfully with RetryOrchestrator")
        } catch {
            let errorMessage = "Stream connection failed.\nCheck:\n• Network connection\n• MediaMTX server"
            logger.error("❌ \(errorMessage, privacy: .public)")
            await stateActor.updateError(errorMessage)
            await stateActor.updateConnectionStatus(.failed(errorMessage))
            await stateActor.updateRetryAttempt(0)  // Reset on final error
        }
    }

    /// Async stream setup with timeout
    private func setupStreamWithTimeout(_ stream: VideoStream, url: URL) async throws {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        if let (baseURL, pathName) = MediaMTXConfig.mediaMTXTarget(for: url) {
            mediaMTXClient = apiClientProvider.createAPIClient(baseURL: baseURL)
            mediaMTXPathName = pathName
            logger.info("👁️  MediaMTX viewer count available for path: \(pathName, privacy: .public)")
        } else {
            mediaMTXClient = nil
            mediaMTXPathName = nil
        }

        setupObservers(for: item)
        logger.info("✅ Player item created and observers setup")
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: PlaybackError.viewModelDeallocated)
                return
            }

            self.streamLoadingContinuation = continuation
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(self.loadTimeout * 1_000_000_000))

                if self.streamLoadingContinuation != nil {
                    self.streamLoadingContinuation?.resume(throwing: PlaybackError.streamLoadTimeout)
                    self.streamLoadingContinuation = nil
                }
            }
            if item.status == .readyToPlay {
                timeoutTask.cancel()
                continuation.resume()
                self.streamLoadingContinuation = nil
            }
        }
    }


    func play() {
        guard errorMessage == nil else { return }
        player.play()
        Task {
            await stateActor.updatePlaying(true)
            await stateActor.updateLoading(false)
            await stateActor.updateConnectionStatus(.connected)
            let currentStream = await stateActor.currentState.currentStream
            logger.info("▶️  Playing: \(currentStream?.title ?? "unknown", privacy: .public)")
        }
        startViewerCountPolling()
    }

    func pause() {
        player.pause()
        Task {
            await stateActor.updatePlaying(false)
            await stateActor.updateConnectionStatus(.disconnected)
            let currentStream = await stateActor.currentState.currentStream
            logger.info("⏸️  Paused: \(currentStream?.title ?? "unknown", privacy: .public)")
        }
        stopViewerCountPolling()
    }

    func retry() {
        Task {
            let stream = await stateActor.currentState.currentStream
            guard let stream = stream else { return }
            await MainActor.run {
                self.loadStream(stream)
            }
        }
    }

    // MARK: - Setup Observers

    private func setupObservers(for item: AVPlayerItem) {
        worker.setupKVOObservers(
            for: item,
            player: player,
            onStatusChange: { [weak self] status in
                self?.handleStatusChange(status)
            },
            onBufferingChange: { [weak self] isBuffering in
                self?.handleBuffering(isBuffering)
            },
            onStall: { [weak self] in
                self?.handlePlaybackStall()
            },
            onFailedToPlayToEnd: { [weak self] error in
                self?.handleFailedToPlayToEnd(error)
            }
        )
    }

    // MARK: - Handle State Changes

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            if let continuation = streamLoadingContinuation {
                continuation.resume()
                streamLoadingContinuation = nil
            }

            Task {
                await stateActor.updateLoading(false)
                await stateActor.updateError(nil)
                await stateActor.updateConnectionStatus(.connected)
            }

            logger.info("✅ Stream ready to play")

        case .failed:
            let errorDesc = player.currentItem?.error?.localizedDescription ?? "Unknown error"
            if let continuation = streamLoadingContinuation {
                continuation.resume(throwing: PlaybackError.playerFailed(errorDesc))
                streamLoadingContinuation = nil
            } else {
                Task {
                    await stateActor.updateConnectionStatus(.failed(errorDesc))
                    await stateActor.updateError("Failed to load: \(errorDesc)")
                }
            }

            logger.error("❌ Playback failed: \(errorDesc, privacy: .public)")

        case .unknown:
            Task {
                await stateActor.updateLoading(true)
                await stateActor.updateConnectionStatus(.buffering)
            }

            logger.info("⏳ Loading stream...")

        @unknown default:
            break
        }
    }

    private func handleBuffering(_ isBuffering: Bool) {
        Task {
            await stateActor.updateLoading(isBuffering)

            if isBuffering {
                let currentCount = await stateActor.currentState.bufferingCount
                await stateActor.updateBufferingCount(currentCount + 1)
                await stateActor.updateConnectionStatus(.buffering)
                let newCount = await stateActor.currentState.bufferingCount
                logger.info("📦 Buffering... (count: \(newCount))")
            } else {
                let isPlaying = await stateActor.currentState.isPlaying
                if isPlaying {
                    await stateActor.updateConnectionStatus(.connected)
                }
                logger.info("✅ Buffering complete")
            }
        }
    }

    private func handlePlaybackStall() {
        Task {
            await stateActor.updateLoading(true)
            await stateActor.updateError("Network unstable - buffering...")
            let currentCount = await stateActor.currentState.bufferingCount
            await stateActor.updateBufferingCount(currentCount + 1)
            await stateActor.updateConnectionStatus(.buffering)
            let newCount = await stateActor.currentState.bufferingCount
            logger.warning("⚠️  Playback stalled (count: \(newCount))")
        }
    }

    private func handleFailedToPlayToEnd(_ error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Playback interrupted"
        Task {
            await stateActor.updateError("Playback error: \(errorMessage)")
            await stateActor.updateConnectionStatus(.failed(errorMessage))
        }
        logger.error("❌ Failed to play to end: \(errorMessage, privacy: .public)")
    }

    private func presentError(_ message: String) {
        Task {
            await stateActor.updateLoading(false)
            await stateActor.updateError(message)
        }
    }


    // MARK: - Viewer Count Polling

    private func startViewerCountPolling() {
        guard let client = mediaMTXClient, let pathName = mediaMTXPathName else { return }
        viewerCountPollingService = ViewerCountPollingService(
            configuration: playbackConfiguration,
            fetchCount: { [weak self] in
                guard let self = self else { throw PollingError.cancelled }
                let path = try await client.fetchPath(named: pathName)
                return path.viewerCount
            }
        )

        Task {
            await viewerCountPollingService?.startPolling()
            while let service = viewerCountPollingService {
                let count = await service.getLastCount()
                let error = await service.getLastError()

                if let count = count {
                    await stateActor.updateViewerCount(count)
                    self.viewerCountFailureCount = 0
                }

                if error != nil {
                    self.viewerCountFailureCount += 1
                    logger.warning("👁️  Viewer count poll failed")

                    // Hide stale count after 3 consecutive failures
                    if self.viewerCountFailureCount >= self.maxViewerCountFailures {
                        await stateActor.updateViewerCount(nil)
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func stopViewerCountPolling() {
        Task {
            await viewerCountPollingService?.stopPolling()
            viewerCountPollingService = nil
        }
    }

    // MARK: - Debug Info

    var resolutionText: String {
        worker.getResolution(from: player)
    }

    var bitrateText: String {
        worker.getBitrate(from: player)
    }

    // MARK: - Time & Status Formatting

    /// Formats seconds to HH:MM:SS or MM:SS format
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, seconds.isFinite else { return "00:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    /// Color for connection status indicator
    var statusIndicatorColor: Color {
        switch connectionStatus {
        case .disconnected:
            return Color.gray
        case .connecting:
            return Color.yellow
        case .connected:
            return Color.green
        case .buffering:
            return Color.orange
        case .failed:
            return Color.red
        }
    }

    /// Text describing connection status
    var statusIndicatorText: String {
        switch connectionStatus {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .buffering:
            return "Buffering..."
        case .failed(let reason):
            return "Failed: \(reason.prefix(20))..."
        }
    }

    /// Seeks backward in the stream
    func seekBackward(_ seconds: Double = 10) {
        let currentSeconds = player.currentTime().seconds
        let newSeconds = max(0, currentSeconds - seconds)
        player.seek(to: CMTime(seconds: newSeconds, preferredTimescale: 1))
    }

    /// Seeks forward in the stream
    func seekForward(_ seconds: Double = 10) {
        let currentSeconds = player.currentTime().seconds
        let newSeconds = currentSeconds + seconds
        player.seek(to: CMTime(seconds: newSeconds, preferredTimescale: 1))
    }

    /// Current playback duration
    var currentDuration: Double {
        player.currentItem?.duration.seconds ?? 0
    }

    /// Buffered progress fraction (0.0 to 1.0) based on the current item's loaded time ranges
    var bufferedProgress: Double {
        guard let range = player.currentItem?.loadedTimeRanges.first?.timeRangeValue else {
            return 0
        }
        let bufferedDuration = CMTimeRangeGetEnd(range).seconds
        let totalDuration = currentDuration
        return totalDuration > 0 ? bufferedDuration / totalDuration : 0
    }

    /// Seeks to a fractional position (0.0 to 1.0) within the current item's duration
    func seek(toProgress progress: Double) {
        guard let duration = player.currentItem?.duration.seconds, duration.isFinite else { return }
        let newTime = CMTime(seconds: progress * duration, preferredTimescale: 600)
        player.seek(to: newTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Tracks whether volume slider should be visible
    var showVolumeSlider: Bool = false

    /// Current playback volume (0.0 to 1.0)
    var volume: Double {
        didSet {
            player.volume = Float(volume)
        }
    }

    /// Current playback rate (0.5x to 2.0x)
    var playbackRate: Float {
        didSet {
            player.rate = playbackRate
        }
    }

    /// Tracks whether player controls should be visible
    var showControls: Bool = true

    /// Timer task for auto-hiding controls
    @ObservationIgnored
    private nonisolated(unsafe) var hideControlsTask: Task<Void, Never>?

    /// Resets the hide controls timer
    func resetControlsVisibilityTimer() {
        hideControlsTask?.cancel()

        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation {
                    self.showControls = false
                    self.showVolumeSlider = false
                }
            }
        }
    }

    // MARK: - Stream Management

    /// Adds a custom stream to the playlist
    func createCustomStream(title: String, url: String) -> VideoStream {
        VideoStream(
            title: title.isEmpty ? "Custom Stream" : title,
            urlString: url,
            thumbnailURLString: "https://via.placeholder.com/120x68/333/666?text=Live"
        )
    }

    /// Validates a stream URL
    func isValidStreamURL(_ url: String) -> Bool {
        guard !url.isEmpty else { return false }
        let isValidProtocol = url.starts(with: "http://") ||
                             url.starts(with: "https://") ||
                             url.starts(with: "rtmp://")

        if !isValidProtocol { return false }

        // For HLS, must end with .m3u8
        if url.contains("http") {
            return url.hasSuffix(".m3u8")
        }

        return true
    }

    /// Checks if URL uses HTTPS protocol
    func isHTTPSURL(_ url: String) -> Bool {
        url.starts(with: "https://")
    }

    /// Whether to warn the user that a custom stream URL they're typing is plain HTTP
    func shouldShowHTTPSWarning(for url: String) -> Bool {
        !url.isEmpty && !isHTTPSURL(url) && url.contains("http://")
    }

    deinit {
        stateObserverTask?.cancel()
        hideControlsTask?.cancel()
        // Capture the service itself, not `self` — by the time this Task runs,
        // `self` has already finished deinitializing, so `[weak self]` would
        // always read nil here and silently skip the cleanup.
        if let service = viewerCountPollingService {
            Task {
                await service.stopPolling()
            }
        }
        player.replaceCurrentItem(with: nil)
        logger.info("🔴 PlaybackViewModel deinitialized")
    }
}

// MARK: - PlaybackError

/// Custom errors for stream loading
enum PlaybackError: LocalizedError {
    case streamLoadTimeout
    case playerFailed(String)
    case viewModelDeallocated

    var errorDescription: String? {
        switch self {
        case .streamLoadTimeout:
            return "Stream loading timed out"
        case .playerFailed(let message):
            return "Player failed: \(message)"
        case .viewModelDeallocated:
            return "ViewModel was deallocated during stream loading"
        }
    }
}
