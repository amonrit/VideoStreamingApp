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

    init(player: AVPlayer = AVPlayer()) {
        self.player = player
    }
}

class DebugInfoViewModel: ObservableObject {
    @Published var resolution: String = "unknown"
    @Published var bitrate: String = "unknown"
    @Published var bufferingCount: Int = 0
}
