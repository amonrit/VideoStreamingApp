//
//  VideoPlayerInteractor.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation
import Combine

protocol VideoPlayerInteractorInput {
    func loadStream(_ stream: VideoStream)
    func play()
    func pause()
    func retry()
    func getDebugInfo() -> (resolution: String, bitrate: String)
}

class VideoPlayerInteractor: VideoPlayerInteractorInput {
    var presenter: VideoPlayerPresenterInput?
    var worker: VideoPlayerWorker?

    private let player: AVPlayer
    private var playbackState: PlaybackState = PlaybackState()
    private var currentStream: VideoStream?
    private var cancellables = Set<AnyCancellable>()

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
    }

    // MARK: - Load Stream

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

        currentStream = stream
        playbackState = PlaybackState(
            isLoading: true,
            isPlaying: false,
            errorMessage: nil,
            bufferingCount: 0,
            currentStream: stream
        )

        let item = AVPlayerItem(url: url)

        // Add error monitoring for the item
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .sink { [weak self] notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("❌ Playback failed: \(error.localizedDescription)")
                    self?.handleFailedToPlayToEnd(error)
                }
            }
            .store(in: &cancellables)

        player.replaceCurrentItem(with: item)

        setupObservers(for: item)
        updatePlaybackState()
        print("✅ Player item created and observers setup")
    }

    // MARK: - Playback Control

    func play() {
        guard playbackState.errorMessage == nil else { return }
        player.play()
        playbackState.isPlaying = true
        playbackState.isLoading = false
        updatePlaybackState()
        print("▶️  Playing: \(currentStream?.title ?? "unknown")")
    }

    func pause() {
        player.pause()
        playbackState.isPlaying = false
        updatePlaybackState()
        print("⏸️  Paused: \(currentStream?.title ?? "unknown")")
    }

    func retry() {
        guard let stream = currentStream else { return }
        loadStream(stream)
    }

    // MARK: - Setup Observers

    private func setupObservers(for item: AVPlayerItem) {
        worker?.setupKVOObservers(
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
            updatePlaybackState()

        case .failed:
            playbackState.isLoading = false
            playbackState.errorMessage = "Failed to load video"
            updatePlaybackState()

        case .unknown:
            playbackState.isLoading = true
            updatePlaybackState()

        @unknown default:
            break
        }
    }

    private func handleBuffering(_ isBuffering: Bool) {
        playbackState.isLoading = isBuffering
        if isBuffering {
            playbackState.bufferingCount += 1
        }
        updatePlaybackState()
    }

    private func handlePlaybackStall() {
        playbackState.isLoading = true
        playbackState.errorMessage = "Buffering..."
        playbackState.bufferingCount += 1
        updatePlaybackState()
    }

    private func handleFailedToPlayToEnd(_ error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Playback error"
        playbackState.errorMessage = "Playback error: \(errorMessage)"
        updatePlaybackState()
    }

    private func presentError(_ message: String) {
        playbackState.isLoading = false
        playbackState.errorMessage = message
        updatePlaybackState()
    }

    // MARK: - Update Presenter

    private func updatePlaybackState() {
        presenter?.presentPlaybackState(playbackState)
    }

    // MARK: - Debug Info

    func getDebugInfo() -> (resolution: String, bitrate: String) {
        let resolution = worker?.getResolution(from: player) ?? "unknown"
        let bitrate = worker?.getBitrate(from: player) ?? "unknown"
        return (resolution, bitrate)
    }

    deinit {
        cancellables.removeAll()
        player.replaceCurrentItem(with: nil)  // ✅ Clean up player item
    }
}

// MARK: - PlaybackState Model

struct PlaybackState {
    var isLoading: Bool = false
    var isPlaying: Bool = false
    var errorMessage: String?
    var bufferingCount: Int = 0
    var currentStream: VideoStream?
}
