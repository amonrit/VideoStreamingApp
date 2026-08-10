//
//  VideoPlayerWorker.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation
import Combine

class VideoPlayerWorker {
    private var cancellables = Set<AnyCancellable>()

    func setupKVOObservers(
        for item: AVPlayerItem,
        player: AVPlayer,
        onStatusChange: @escaping (AVPlayerItem.Status) -> Void,
        onBufferingChange: @escaping (Bool) -> Void,
        onStall: @escaping () -> Void,
        onFailedToPlayToEnd: @escaping (Error?) -> Void
    ) {
        cancellables.removeAll()

        // Monitor AVPlayerItem Status
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { status in
                onStatusChange(status)
            }
            .store(in: &cancellables)

        // Monitor Buffering (isPlaybackLikelyToKeepUp)
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak player] keepUp in
                guard let player = player else { return }
                if player.rate > 0 {
                    onBufferingChange(!keepUp)
                }
            }
            .store(in: &cancellables)

        // Monitor Playback Stalled
        NotificationCenter.default.publisher(
            for: .AVPlayerItemPlaybackStalled,
            object: item
        )
        .receive(on: DispatchQueue.main)
        .sink { _ in
            onStall()
        }
        .store(in: &cancellables)

        // Monitor Failed to Play to End Time
        NotificationCenter.default.publisher(
            for: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )
        .receive(on: DispatchQueue.main)
        .sink { notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            onFailedToPlayToEnd(error)
        }
        .store(in: &cancellables)
    }

    // MARK: - Debug Info Helpers

    func getResolution(from player: AVPlayer) -> String {
        guard let size = player.currentItem?.presentationSize,
              size.width > 0, size.height > 0 else {
            return "unknown"
        }
        return "\(Int(size.width))x\(Int(size.height))"
    }

    func getBitrate(from player: AVPlayer) -> String {
        guard let event = player.currentItem?.accessLog()?.events.last else {
            return "unknown"
        }
        let kbps = event.observedBitrate / 1000.0
        return String(format: "%.0f kbps", kbps)
    }

    deinit {
        cancellables.removeAll()
    }
}
