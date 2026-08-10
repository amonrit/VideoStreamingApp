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
    @Published var isLoading: Bool = false
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    @Published var bufferingCount: Int = 0
    @Published var currentStream: VideoStream?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var retryAttempt: Int = 0
    @Published var viewerCount: Int?

    let player: AVPlayer
    private let worker: VideoPlayerWorker
    private var playbackState: PlaybackState = .idle
    private var cancellables = Set<AnyCancellable>()
    private var retryCount: Int = 0
    private let maxRetries: Int = 2  // max 5s total: 2-3 + 1-2s backoff
    private var retryTimer: Timer?
    private var timeoutTimer: Timer?
    private var isAutoRetrying: Bool = false
    private var totalRetryTime: TimeInterval = 0

    // Viewer count polling
    private var viewerCountTimer: Timer?
    private var mediaMTXClient: MediaMTXAPIClient?
    private var mediaMTXPathName: String?
    private var viewerCountFailureCount: Int = 0
    private let viewerCountPollInterval: TimeInterval = 4.0
    private let maxViewerCountFailures: Int = 3

    // Network timeout constants - FAST retry strategy
    private let loadTimeout: TimeInterval = 3.0   // 3 seconds per attempt
    private let stallTimeout: TimeInterval = 2.0  // 2 seconds for stall recovery

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
        self.worker = VideoPlayerWorker()

        // MARK: - Native AVPlayer Settings
        setupPlayerSettings()
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

    // MARK: - Connection Status Enum
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case buffering
        case failed(String)
    }

    // MARK: - Stream Loading

    func loadStream(_ stream: VideoStream) {
        // ยกเลิก timers เก่า
        retryTimer?.invalidate()
        timeoutTimer?.invalidate()
        stopViewerCountPolling()

        player.pause()
        cancellables.removeAll()
        retryCount = 0
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

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        // Setup viewer count polling if this is a MediaMTX stream
        if let (baseURL, pathName) = MediaMTXConfig.mediaMTXTarget(for: url) {
            mediaMTXClient = MediaMTXAPIClient(baseURL: baseURL)
            mediaMTXPathName = pathName
            logger.info("👁️  MediaMTX viewer count available for path: \(pathName, privacy: .public)")
        } else {
            mediaMTXClient = nil
            mediaMTXPathName = nil
        }

        setupObservers(for: item)
        startLoadingTimeout(for: stream)
        logger.info("✅ Player item created and observers setup")
    }

    // MARK: - Timeout Management

    private func startLoadingTimeout(for stream: VideoStream) {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: loadTimeout, repeats: false) { [weak self] _ in
            self?.handleLoadingTimeout(for: stream)
        }
    }

    private func handleLoadingTimeout(for stream: VideoStream) {
        logger.warning("⏱️ Loading timeout after \(self.loadTimeout)s (attempt \(self.retryCount + 1)/\(self.maxRetries))")

        if retryCount < maxRetries {
            retryCount += 1

            // FAST backoff for 5s limit: 0.5s, 1s (total ~5-6s)
            let backoffTime: TimeInterval = retryCount == 1 ? 0.5 : 1.0
            totalRetryTime += loadTimeout + backoffTime

            logger.info("🔄 Quick-retry \(self.retryCount)/\(self.maxRetries) in \(backoffTime)s (total: \(String(format: "%.1f", self.totalRetryTime))s)...")

            // Keep loading spinner visible (don't show error)
            playbackState.isLoading = true
            playbackState.errorMessage = nil
            updateConnectionStatus(.buffering)

            DispatchQueue.main.async {
                self.retryAttempt = self.retryCount  // Update retry count UI
            }
            updatePlaybackViewModel()

            // Retry with SHORT backoff
            isAutoRetrying = true
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: backoffTime, repeats: false) { [weak self] _ in
                self?.isAutoRetrying = false
                self?.loadStream(stream)
            }
        } else {
            // ถ้า retry หมดแล้ว ถึงขึ้น error
            let error = "Stream connection failed.\nRetried \(maxRetries) times in ~5 seconds.\nCheck:\n• Network connection\n• MediaMTX server"
            logger.error("❌ \(error, privacy: .public)")
            presentError(error)
            updateConnectionStatus(.failed(error))

            DispatchQueue.main.async {
                self.retryAttempt = 0  // Reset on final error
            }
        }
    }

    private func updateConnectionStatus(_ status: ConnectionStatus) {
        DispatchQueue.main.async {
            self.connectionStatus = status
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
        retryCount = 0  // Reset retry count
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
            timeoutTimer?.invalidate()  // ยกเลิก timeout เมื่อพร้อมเล่น
            playbackState.isLoading = false
            playbackState.errorMessage = nil
            updateConnectionStatus(.connected)
            updatePlaybackViewModel()
            logger.info("✅ Stream ready to play")

        case .failed:
            playbackState.isLoading = false
            let errorDesc = player.currentItem?.error?.localizedDescription ?? "Unknown error"

            // ถ้า auto-retry อยู่ ให้ยังคงแสดง loading spinner
            if isAutoRetrying {
                playbackState.isLoading = true
                playbackState.errorMessage = nil
                updateConnectionStatus(.buffering)
            } else {
                playbackState.errorMessage = "Failed to load: \(errorDesc)"
                updateConnectionStatus(.failed(errorDesc))
            }

            updatePlaybackViewModel()
            logger.error("❌ Playback failed: \(errorDesc, privacy: .public)")

        case .unknown:
            playbackState.isLoading = true
            updateConnectionStatus(.buffering)
            updatePlaybackViewModel()
            logger.info("⏳ Loading stream...")

        @unknown default:
            break
        }
    }

    private func handleBuffering(_ isBuffering: Bool) {
        playbackState.isLoading = isBuffering
        if isBuffering {
            playbackState.bufferingCount += 1
            updateConnectionStatus(.buffering)
            logger.info("📦 Buffering... (count: \(self.playbackState.bufferingCount))")
        } else {
            if playbackState.isPlaying {
                updateConnectionStatus(.connected)
            }
            logger.info("✅ Buffering complete")
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

    private func presentError(_ message: String) {
        playbackState.isLoading = false
        playbackState.errorMessage = message
        updatePlaybackViewModel()
    }

    // MARK: - Update Published Properties

    private func updatePlaybackViewModel() {
        DispatchQueue.main.async {
            self.isLoading = self.playbackState.isLoading
            self.isPlaying = self.playbackState.isPlaying
            self.errorMessage = self.playbackState.errorMessage
            self.bufferingCount = self.playbackState.bufferingCount
            self.currentStream = self.playbackState.currentStream
            // retryAttempt is updated separately in handleLoadingTimeout
        }
    }

    // MARK: - Viewer Count Polling

    private func startViewerCountPolling() {
        guard let client = mediaMTXClient, let pathName = mediaMTXPathName else { return }
        viewerCountTimer?.invalidate()
        viewerCountTimer = Timer.scheduledTimer(withTimeInterval: viewerCountPollInterval, repeats: true) { [weak self] _ in
            self?.pollViewerCount(client: client, pathName: pathName)
        }
        // Fire immediately
        viewerCountTimer?.fire()
    }

    private func stopViewerCountPolling() {
        viewerCountTimer?.invalidate()
        viewerCountTimer = nil
    }

    private func pollViewerCount(client: MediaMTXAPIClient, pathName: String) {
        Task { [weak self] in
            do {
                let path = try await client.fetchPath(named: pathName)
                await MainActor.run {
                    self?.viewerCount = path.viewerCount
                    self?.viewerCountFailureCount = 0
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.viewerCountFailureCount += 1
                    logger.warning("👁️  Viewer count poll failed: \(error.localizedDescription, privacy: .public)")

                    // Hide stale count after 3 consecutive failures
                    if self.viewerCountFailureCount >= self.maxViewerCountFailures {
                        self.viewerCount = nil
                    }
                }
            }
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
        cancellables.removeAll()
        retryTimer?.invalidate()
        timeoutTimer?.invalidate()
        viewerCountTimer?.invalidate()
        player.replaceCurrentItem(with: nil)
        logger.info("🔴 PlaybackViewModel deinitialized")
    }
}
