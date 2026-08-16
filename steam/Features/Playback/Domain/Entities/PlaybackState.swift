//
//  PlaybackState.swift
//  steam
//

import Foundation

struct PlaybackState {
    var isLoading: Bool = false
    var isPlaying: Bool = false
    var errorMessage: String?
    var bufferingCount: Int = 0
    var currentStream: VideoStream?
}

// MARK: - Convenience Initializers

extension PlaybackState {
    /// Idle state: nothing loading, not playing, no errors
    static let idle = PlaybackState()

    /// Initial loading state for a new stream
    init(loading stream: VideoStream) {
        self.isLoading = true
        self.isPlaying = false
        self.errorMessage = nil
        self.bufferingCount = 0
        self.currentStream = stream
    }
}
