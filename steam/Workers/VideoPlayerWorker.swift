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
            .sink { status in
                onStatusChange(status)
            }
            .store(in: &cancellables)

        // Monitor Buffering (isPlaybackLikelyToKeepUp)
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .sink { [weak self] keepUp in
                guard self != nil else { return }
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
        .sink { _ in
            onStall()
        }
        .store(in: &cancellables)

        // Monitor Failed to Play to End Time
        NotificationCenter.default.publisher(
            for: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )
        .sink { notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            onFailedToPlayToEnd(error)
        }
        .store(in: &cancellables)
    }

    // MARK: - Formatting Helpers

    func formatResolution(_ size: CGSize) -> String {
        guard size.width > 0, size.height > 0 else {
            return "Resolution: unknown"
        }
        return "Resolution: \(Int(size.width))x\(Int(size.height))"
    }

    func formatBitrate(from player: AVPlayer) -> String {
        guard let event = player.currentItem?.accessLog()?.events.last else {
            return "Bitrate: unknown"
        }
        let kbps = event.observedBitrate / 1000.0
        return String(format: "Bitrate: %.0f kbps", kbps)
    }

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
