//
//  VideoPlayerModels.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

// MARK: - Request

struct VideoPlayerRequest {
    let stream: VideoStream
}

// MARK: - Response

struct VideoPlayerResponse {
    let stream: VideoStream
    let isLoading: Bool
    let isPlaying: Bool
    let errorMessage: String?
    let bufferingCount: Int
    let resolution: String
    let bitrate: String
}

// MARK: - DebugInfoViewModel (deprecated, kept for Presenter compatibility)

class DebugInfoViewModel: ObservableObject {
    @Published var resolution: String = "unknown"
    @Published var bitrate: String = "unknown"
    @Published var bufferingCount: Int = 0
}
