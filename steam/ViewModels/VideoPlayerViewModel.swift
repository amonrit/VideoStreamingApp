//
//  VideoPlayerViewModel.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation
import Combine

final class VideoPlayerViewModel: ObservableObject {
    
    @Published var currentStream: VideoStream {
        didSet {
            load(stream: currentStream)
        }
    }
    
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var bufferingCount: Int = 0
    
    let player: AVPlayer
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    
    init(stream: VideoStream) {
        self.currentStream = stream
        self.player = AVPlayer()
        load(stream: stream)
    }
    
    private func load(stream: VideoStream) {
        guard let url = stream.url else {
            self.errorMessage = "Invalid URL: \(stream.urlString)"
            self.isLoading = false
            self.isPlaying = false
            player.replaceCurrentItem(with: nil)
            return
        }
        
        errorMessage = nil
        isLoading = true
        isPlaying = false
        bufferingCount = 0
        
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        
        setupObservers(for: item)
    }
    
    private func setupObservers(for item: AVPlayerItem) {
        cancellables.removeAll()
        
        item.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    self.isLoading = false
                    self.errorMessage = nil
                case .failed:
                    self.isLoading = false
                    self.errorMessage = "Failed to load video: \(item.error?.localizedDescription ?? "Unknown error")"
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] keepUp in
                guard let self = self else { return }
                if self.player.rate > 0 {
                    self.isLoading = !keepUp
                    if !keepUp {
                        self.bufferingCount += 1
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: item)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isLoading = true
                self.errorMessage = "Buffering..."
                self.bufferingCount += 1
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    self.errorMessage = "Playback error: \(error.localizedDescription)"
                }
            }
            .store(in: &cancellables)
    }
    
    func play() {
        guard errorMessage == nil else { return }
        player.play()
        isPlaying = true
        isLoading = false
    }
    
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    func retry() {
        load(stream: currentStream)
    }
    
    // MARK: - Debug helpers (จริง)
    
    var resolutionText: String {
        guard let size = player.currentItem?.presentationSize,
              size.width > 0, size.height > 0 else {
            return "Resolution: unknown"
        }
        return "Resolution: \(Int(size.width))x\(Int(size.height))"
    }
    
    var bitrateText: String {
        guard let event = player.currentItem?.accessLog()?.events.last else {
            return "Bitrate: unknown"
        }
        let kbps = event.observedBitrate / 1000.0
        return String(format: "Bitrate: %.0f kbps", kbps)
    }
    
    var bufferingText: String {
        "Buffering events: \(bufferingCount)"
    }
    
    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        cancellables.removeAll()
    }
}

