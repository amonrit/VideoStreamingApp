//
//  PlaybackViewModel.swift
//  steam
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

class PlaybackViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isPlaying: Bool = false
    @Published var errorMessage: String?
    @Published var bufferingCount: Int = 0
    @Published var currentStream: VideoStream?
    @Published var showDebug: Bool = false

    let player: AVPlayer
    private let worker: VideoPlayerWorker
    private var playbackState: PlaybackState = .idle
    private var cancellables = Set<AnyCancellable>()

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
        self.worker = VideoPlayerWorker()
    }

    // MARK: - Playback Control

    func loadStream(_ stream: VideoStream) {
        player.pause()
        cancellables.removeAll()
        print("🛑 Stopped playback of previous stream")

        guard let url = stream.url else {
            let error = "Invalid URL: \(stream.urlString)"
            print("❌ \(error)")
            presentError(error)
            return
        }

        print("📥 Loading stream: \(stream.title)")
        print("   URL: \(url)")

        playbackState = PlaybackState(loading: stream)
        updatePlaybackViewModel()

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        setupObservers(for: item)
        print("✅ Player item created and observers setup")
    }

    func play() {
        guard playbackState.errorMessage == nil else { return }
        player.play()
        playbackState.isPlaying = true
        playbackState.isLoading = false
        updatePlaybackViewModel()
        print("▶️  Playing: \(playbackState.currentStream?.title ?? "unknown")")
    }

    func pause() {
        player.pause()
        playbackState.isPlaying = false
        updatePlaybackViewModel()
        print("⏸️  Paused: \(playbackState.currentStream?.title ?? "unknown")")
    }

    func retry() {
        guard let stream = playbackState.currentStream else { return }
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
            playbackState.isLoading = false
            playbackState.errorMessage = nil
            updatePlaybackViewModel()

        case .failed:
            playbackState.isLoading = false
            playbackState.errorMessage = "Failed to load video"
            updatePlaybackViewModel()

        case .unknown:
            playbackState.isLoading = true
            updatePlaybackViewModel()

        @unknown default:
            break
        }
    }

    private func handleBuffering(_ isBuffering: Bool) {
        playbackState.isLoading = isBuffering
        if isBuffering {
            playbackState.bufferingCount += 1
        }
        updatePlaybackViewModel()
    }

    private func handlePlaybackStall() {
        playbackState.isLoading = true
        playbackState.errorMessage = "Buffering..."
        playbackState.bufferingCount += 1
        updatePlaybackViewModel()
    }

    private func handleFailedToPlayToEnd(_ error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Playback error"
        playbackState.errorMessage = "Playback error: \(errorMessage)"
        updatePlaybackViewModel()
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
        player.replaceCurrentItem(with: nil)
    }
}
