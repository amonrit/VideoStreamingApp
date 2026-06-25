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
    
    @Published var isPlaying = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    let player: AVPlayer
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    
    init(urlString: String = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8") {
        guard let url = URL(string: urlString) else {
            self.player = AVPlayer()
            self.errorMessage = "❌ Invalid URL: \(urlString)"
            return
        }
        
        self.player = AVPlayer(url: url)
        setupObservers()
    }
    
    private func setupObservers() {
        // Monitor player item status (ready, failed, unknown)
        player.currentItem?.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    self.errorMessage = nil
                    self.isLoading = false
                case .failed:
                    self.isLoading = false
                    self.errorMessage = "❌ Failed to load video: \(self.player.currentItem?.error?.localizedDescription ?? "Unknown error")"
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Monitor playback likely to keep up (buffering)
        player.currentItem?.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] isLikelyToKeepUp in
                guard let self = self else { return }
                if !isLikelyToKeepUp && self.player.rate > 0 {
                    self.isLoading = true
                } else {
                    self.isLoading = false
                }
            }
            .store(in: &cancellables)
        
        // Monitor playback stalled
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled)
            .sink { [weak self] _ in
                self?.isLoading = true
                self?.errorMessage = "⏸️ Buffering..."
            }
            .store(in: &cancellables)
        
        // Monitor failed to play to end
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    self.errorMessage = "❌ Playback error: \(error.localizedDescription)"
                }
            }
            .store(in: &cancellables)
    }
    
    func play() {
        if errorMessage != nil {
            return // ห้ามเล่นถ้ามี error
        }
        player.play()
        isPlaying = true
    }
    
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    func retry() {
        errorMessage = nil
        isLoading = true
        
        // Reload the player item
        if let currentItem = player.currentItem {
            player.replaceCurrentItem(with: currentItem)
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        cancellables.removeAll()
    }
}
