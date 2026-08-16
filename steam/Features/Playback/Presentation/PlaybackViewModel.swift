//
//  PlaybackViewModel.swift
//  steam
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "playback")

class PlaybackViewModel: ObservableObject {
    // MARK: - @Published Properties (Bridge to StateActor)
    /// ✅ Phase 7: These are now synchronized from PlaybackStateActor
    /// Kept for backward compatibility with existing SwiftUI views
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
    private var playbackState: PlaybackState = .idle
    private var cancellables = Set<AnyCancellable>()

    // ✅ Phase 7: State actor for structured concurrency
    private let stateActor: DefaultPlaybackStateActor
    private var stateObserverTask: Task<Void, Never>?

    // ✅ Phase 4: Centralized retry orchestration
    private var retryOrchestrator: RetryOrchestrator?
    private let playbackConfiguration: PlaybackConfiguration = .production

    // ✅ Phase 5: Centralized viewer count polling via service
    private var viewerCountPollingService: ViewerCountPollingService?

    // ✅ Phase 6: Dependency injection for API client
    private let apiClientProvider: APIClientProvider
    private var mediaMTXClient: MediaMTXAPIClient?
    private var mediaMTXPathName: String?
    private var viewerCountFailureCount: Int = 0
    private let maxViewerCountFailures: Int = 3

    // Network timeout constant for stream loading attempts
    private let loadTimeout: TimeInterval = 3.0   // 3 seconds per attempt
    private let stallTimeout: TimeInterval = 2.0  // 2 seconds for stall recovery

    // ✅ Phase 4: Track stream loading state
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

        // MARK: - Setup
        setupPlayerSettings()

        // ✅ Phase 7: Observe state updates from actor and sync to @Published properties
        startStateObserver()
    }

    // MARK: - Phase 7: State Observation
    /// Starts observing state changes from the actor and syncing to @Published properties
    /// This bridges structured concurrency (actor) with Combine (@Published) for backward compatibility
    private func startStateObserver() {
        stateObserverTask = Task {
            for await state in stateActor.stateUpdates {
                // Sync all state changes to @Published properties on main thread
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
        // ✅ อนุญาตการแคสต์ (AirPlay, HDMI)
        player.allowsExternalPlayback = true

        // ✅ สำหรับ HLS: เปิด automaticallyWaitsToMinimizeStalling เพื่อให้ buffer ค่อย ๆ
        player.automaticallyWaitsToMinimizeStalling = true

        // ✅ ตั้งค่าเสียงเริ่มต้น
        player.volume = 1.0

        // ✅ ตั้ง rate สำหรับการเล่น
        player.rate = 1.0

        logger.info("✅ AVPlayer configured for HLS streaming with auto-retry strategy")
    }

    // MARK: - Stream Loading (Phase 4 Refactored)

    func loadStream(_ stream: VideoStream) {
        // Stop any previous stream loading/polling
        stopViewerCountPolling()
        player.pause()
        cancellables.removeAll()
        viewerCount = nil
        viewerCountFailureCount = 0

        logger.info("🛑 Stopped playback of previous stream")

        guard var url = stream.url else {
            let error = "Invalid URL: \(stream.urlString)"
            logger.error("❌ \(error, privacy: .public)")
            presentError(error)
            return
        }

        // ✅ FIX: Clean URL for MediaMTX HLS compatibility
        let urlString = url.absoluteString
        let cleanURLString: String

        // Remove session parameter and anything after ?
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

        playbackState = PlaybackState(loading: stream)
        updateConnectionStatus(.connecting)
        updatePlaybackViewModel()

        // ✅ Phase 4: Use RetryOrchestrator for automatic retry logic
        Task {
            await loadStreamWithRetry(stream, url: url)
        }
    }

    /// Phase 4: Load stream with automatic retry orchestration
    /// Uses RetryOrchestrator to manage retry attempts, delays, and status messages
    private func loadStreamWithRetry(_ stream: VideoStream, url: URL) async {
        // Initialize orchestrator with status callback for UI updates
        retryOrchestrator = RetryOrchestrator(
            configuration: playbackConfiguration,
            onStatusChanged: { message in
                logger.info("🔄 Retry: \(message)")
                // Update UI with retry attempt count from message if needed
            }
        )

        do {
            _ = try await retryOrchestrator?.attemptWithRetry(
                {
                    try await self.setupStreamWithTimeout(stream, url: url)
                },
                onError: { [weak self] error, attempt in
                    DispatchQueue.main.async {
                        self?.retryAttempt = attempt
                    }
                    logger.warning("❌ Stream loading attempt \(attempt) failed: \(error.localizedDescription)")
                }
            )

            logger.info("✅ Stream loaded successfully with RetryOrchestrator")
        } catch {
            // ✅ Phase 4: Final failure after all retry attempts exhausted
            let errorMessage = "Stream connection failed.\nCheck:\n• Network connection\n• MediaMTX server"
            logger.error("❌ \(errorMessage, privacy: .public)")
            presentError(errorMessage)
            updateConnectionStatus(.failed(errorMessage))

            DispatchQueue.main.async {
                self.retryAttempt = 0  // Reset on final error
            }
        }
    }

    /// ✅ Phase 4: Async stream setup with timeout
    /// Bridges event-driven AVPlayer with async/await for RetryOrchestrator compatibility
    private func setupStreamWithTimeout(_ stream: VideoStream, url: URL) async throws {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        // Setup viewer count polling if this is a MediaMTX stream
        if let (baseURL, pathName) = MediaMTXConfig.mediaMTXTarget(for: url) {
            // ✅ Phase 6: Use dependency-injected API client provider
            mediaMTXClient = apiClientProvider.createAPIClient(baseURL: baseURL)
            mediaMTXPathName = pathName
            logger.info("👁️  MediaMTX viewer count available for path: \(pathName, privacy: .public)")
        } else {
            mediaMTXClient = nil
            mediaMTXPathName = nil
        }

        // Setup KVO observers for status changes
        setupObservers(for: item)
        logger.info("✅ Player item created and observers setup")

        // ✅ Phase 4: Wait for stream to be ready with timeout
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: PlaybackError.viewModelDeallocated)
                return
            }

            self.streamLoadingContinuation = continuation

            // Set timeout for stream loading
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(self.loadTimeout * 1_000_000_000))

                if self.streamLoadingContinuation != nil {
                    self.streamLoadingContinuation?.resume(throwing: PlaybackError.streamLoadTimeout)
                    self.streamLoadingContinuation = nil
                }
            }

            // Observe player status once to check for immediate readiness
            if item.status == .readyToPlay {
                timeoutTask.cancel()
                continuation.resume()
                self.streamLoadingContinuation = nil
            }
        }
    }

    // ✅ Phase 7: Update StateActor and let observation sync @Published properties
    private func updateConnectionStatus(_ status: ConnectionStatus) {
        Task {
            await stateActor.updateConnectionStatus(status)
        }
    }

    func play() {
        guard playbackState.errorMessage == nil else { return }
        player.play()
        playbackState.isPlaying = true
        playbackState.isLoading = false
        updateConnectionStatus(.connected)
        updatePlaybackViewModel()
        startViewerCountPolling()
        logger.info("▶️  Playing: \(self.playbackState.currentStream?.title ?? "unknown", privacy: .public)")
    }

    func pause() {
        player.pause()
        playbackState.isPlaying = false
        updateConnectionStatus(.disconnected)
        updatePlaybackViewModel()
        stopViewerCountPolling()
        logger.info("⏸️  Paused: \(self.playbackState.currentStream?.title ?? "unknown", privacy: .public)")
    }

    func retry() {
        guard let stream = playbackState.currentStream else { return }
        // ✅ Phase 4: RetryOrchestrator will be reset and re-initialized in loadStream
        loadStream(stream)
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
            // ✅ Phase 4: Resume the loading continuation on success
            if let continuation = streamLoadingContinuation {
                continuation.resume()
                streamLoadingContinuation = nil
            }

            playbackState.isLoading = false
            playbackState.errorMessage = nil

            // ✅ Phase 7: Update StateActor
            Task {
                await stateActor.updateLoading(false)
                await stateActor.updateError(nil)
                await stateActor.updateConnectionStatus(.connected)
            }

            updatePlaybackViewModel()
            logger.info("✅ Stream ready to play")

        case .failed:
            playbackState.isLoading = false
            let errorDesc = player.currentItem?.error?.localizedDescription ?? "Unknown error"

            // ✅ Phase 4: Resume continuation with error if loading
            if let continuation = streamLoadingContinuation {
                continuation.resume(throwing: PlaybackError.playerFailed(errorDesc))
                streamLoadingContinuation = nil
            } else {
                // If not loading, just update error state
                playbackState.errorMessage = "Failed to load: \(errorDesc)"

                // ✅ Phase 7: Update StateActor
                Task {
                    await stateActor.updateConnectionStatus(.failed(errorDesc))
                    await stateActor.updateError("Failed to load: \(errorDesc)")
                }
            }

            updatePlaybackViewModel()
            logger.error("❌ Playback failed: \(errorDesc, privacy: .public)")

        case .unknown:
            playbackState.isLoading = true

            // ✅ Phase 7: Update StateActor
            Task {
                await stateActor.updateLoading(true)
                await stateActor.updateConnectionStatus(.buffering)
            }

            updatePlaybackViewModel()
            logger.info("⏳ Loading stream...")

        @unknown default:
            break
        }
    }

    private func handleBuffering(_ isBuffering: Bool) {
        playbackState.isLoading = isBuffering

        // ✅ Phase 7: Update StateActor
        Task {
            await stateActor.updateLoading(isBuffering)

            if isBuffering {
                playbackState.bufferingCount += 1
                await stateActor.updateBufferingCount(self.playbackState.bufferingCount)
                await stateActor.updateConnectionStatus(.buffering)
                logger.info("📦 Buffering... (count: \(self.playbackState.bufferingCount))")
            } else {
                if playbackState.isPlaying {
                    await stateActor.updateConnectionStatus(.connected)
                }
                logger.info("✅ Buffering complete")
            }
        }

        updatePlaybackViewModel()
    }

    private func handlePlaybackStall() {
        playbackState.isLoading = true
        playbackState.errorMessage = "Network unstable - buffering..."
        playbackState.bufferingCount += 1
        updateConnectionStatus(.buffering)
        updatePlaybackViewModel()
        logger.warning("⚠️  Playback stalled (count: \(self.playbackState.bufferingCount))")
    }

    private func handleFailedToPlayToEnd(_ error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Playback interrupted"
        playbackState.errorMessage = "Playback error: \(errorMessage)"
        updateConnectionStatus(.failed(errorMessage))
        updatePlaybackViewModel()
        logger.error("❌ Failed to play to end: \(errorMessage, privacy: .public)")
    }

    // ✅ Phase 7: Update StateActor for errors
    private func presentError(_ message: String) {
        Task {
            await stateActor.updateLoading(false)
            await stateActor.updateError(message)
        }
    }

    // MARK: - Update Published Properties

    private func updatePlaybackViewModel() {
        DispatchQueue.main.async {
            self.isLoading = self.playbackState.isLoading
            self.isPlaying = self.playbackState.isPlaying
            self.errorMessage = self.playbackState.errorMessage
            self.bufferingCount = self.playbackState.bufferingCount
            self.currentStream = self.playbackState.currentStream
            // ✅ Phase 4: retryAttempt is updated from RetryOrchestrator callbacks
        }
    }

    // MARK: - Viewer Count Polling (Phase 5: Service-Based)

    private func startViewerCountPolling() {
        guard let client = mediaMTXClient, let pathName = mediaMTXPathName else { return }

        // ✅ Phase 5: Use ViewerCountPollingService instead of Timer
        viewerCountPollingService = ViewerCountPollingService(
            configuration: playbackConfiguration,
            fetchCount: { [weak self] in
                guard let self = self else { throw PollingError.cancelled }
                let path = try await client.fetchPath(named: pathName)
                return path.viewerCount
            }
        )

        // Start polling and handle results
        Task {
            await viewerCountPollingService?.startPolling()

            // Monitor polling results via task loop
            while let service = viewerCountPollingService {
                let count = service.getLastCount()
                let error = service.getLastError()

                await MainActor.run {
                    if let count = count {
                        self.viewerCount = count
                        self.viewerCountFailureCount = 0
                    }

                    if error != nil {
                        self.viewerCountFailureCount += 1
                        logger.warning("👁️  Viewer count poll failed")

                        // Hide stale count after 3 consecutive failures
                        if self.viewerCountFailureCount >= self.maxViewerCountFailures {
                            self.viewerCount = nil
                        }
                    }
                }

                // Check every 0.5 seconds for updates
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func stopViewerCountPolling() {
        // ✅ Phase 5: Stop service instead of invalidating Timer
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

    deinit {
        // ✅ Phase 7: Cancel state observer task
        stateObserverTask?.cancel()

        cancellables.removeAll()

        // ✅ Phase 5: Stop polling service on dealloc
        Task {
            await viewerCountPollingService?.stopPolling()
        }

        player.replaceCurrentItem(with: nil)
        logger.info("🔴 PlaybackViewModel deinitialized")
    }
}

// MARK: - PlaybackError (Phase 4)

/// ✅ Phase 4: Custom errors for stream loading with RetryOrchestrator
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
