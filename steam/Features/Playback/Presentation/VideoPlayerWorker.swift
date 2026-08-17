//
//  VideoPlayerWorker.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation
import Combine
import os

private let logger = Logger(subsystem: "amonrit.steam", category: "worker")

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
                logger.info("📊 Status changed: \(String(describing: status))")
                onStatusChange(status)
            }
            .store(in: &cancellables)

        // Monitor Buffering (isPlaybackLikelyToKeepUp)
        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak player] keepUp in
                guard let player = player else { return }
                if player.rate > 0 {
                    logger.info("📦 Playback \(keepUp ? "keeping up" : "lagging") - buffering: \(!keepUp)")
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
            logger.warning("⚠️  Playback stalled - attempting recovery")
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
            logger.error("❌ Failed to play to end: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            onFailedToPlayToEnd(error)
        }
        .store(in: &cancellables)

        // Monitor Loading State (presentationSize)
        item.publisher(for: \.presentationSize)
            .receive(on: DispatchQueue.main)
            .filter { $0.width > 0 && $0.height > 0 }
            .first()
            .sink { size in
                logger.info("🎬 Video loaded: \(Int(size.width))x\(Int(size.height))")
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
