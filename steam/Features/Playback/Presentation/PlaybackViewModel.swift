//
//  PlaybackViewModel.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "playback")

class PlaybackViewModel: ObservableObject {
    // MARK: - @Published Properties
    /// Synchronized from PlaybackStateActor for backward compatibility with SwiftUI views
    @Published var isLoading: Bool = false
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    @Published var bufferingCount: Int = 0
    @Published var currentStream: VideoStream?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var retryAttempt: Int = 0
    @Published var viewerCount: Int?

    // MARK: - Core Properties
    let player: AVPlayer
    private let worker: VideoPlayerWorker
    private var cancellables = Set<AnyCancellable>()
    private let stateActor: DefaultPlaybackStateActor
    private var stateObserverTask: Task<Void, Never>?
    private var retryOrchestrator: RetryOrchestrator?
    private let playbackConfiguration: PlaybackConfiguration = .production
    private var viewerCountPollingService: ViewerCountPollingService?
    private let apiClientProvider: APIClientProvider
    private var mediaMTXClient: MediaMTXAPIClient?
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
        self._volume = Published(initialValue: Double(player.volume))
        self._playbackRate = Published(initialValue: player.rate)
        self._showVolumeSlider = Published(initialValue: false)
        self._showControls = Published(initialValue: true)
        setupPlayerSettings()
        startStateObserver()
    }

    /// Observes state changes from actor and syncs to @Published properties for backward compatibility
    private func startStateObserver() {
        stateObserverTask = Task {
            for await state in stateActor.stateUpdates {
                await MainActor.run { [weak self] in
                    self?.syncPublishedProperties(from: state)
                }
            }
        }
    }

    /// Synchronizes @Published properties from actor state
    /// Called whenever the state actor updates
    private func syncPublishedProperties(from state: PlaybackStateSnapshot) {
        self.isLoading = state.isLoading
        self.isPlaying = state.isPlaying
        self.errorMessage = state.errorMessage
        self.bufferingCount = state.bufferingCount
        self.currentStream = state.currentStream
        self.connectionStatus = state.connectionStatus
        self.retryAttempt = state.retryAttempt
        self.viewerCount = state.viewerCount
    }

    private func setupPlayerSettings() {
        player.allowsExternalPlayback = true
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        player.rate = 1.0
        logger.info("✅ AVPlayer configured for HLS streaming with auto-retry strategy")
    }

    // MARK: - Stream Loading

    func loadStream(_ stream: VideoStream) {
        stopViewerCountPolling()
        player.pause()
        cancellables.removeAll()
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
                let count = service.getLastCount()
                let error = service.getLastError()

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

    /// Tracks whether volume slider should be visible
    @Published var showVolumeSlider: Bool = false

    /// Current playback volume (0.0 to 1.0)
    @Published var volume: Double {
        didSet {
            player.volume = Float(volume)
        }
    }

    /// Current playback rate (0.5x to 2.0x)
    @Published var playbackRate: Float {
        didSet {
            player.rate = playbackRate
        }
    }

    /// Tracks whether player controls should be visible
    @Published var showControls: Bool = true

    /// Timer task for auto-hiding controls
    private var hideControlsTask: Task<Void, Never>?

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

    deinit {
        stateObserverTask?.cancel()
        hideControlsTask?.cancel()
        cancellables.removeAll()
        Task {
            await viewerCountPollingService?.stopPolling()
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
