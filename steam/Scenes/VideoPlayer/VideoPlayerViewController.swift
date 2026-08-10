//
//  VideoPlayerViewController.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI
import AVFoundation
import Combine

class VideoPlayerViewController: ObservableObject, VideoPlayerPresenterOutput {
    @Published var playbackViewModel: PlaybackViewModel
    @Published var debugViewModel: DebugInfoViewModel

    // MARK: - Strong References (keep components alive)
    private let interactor: VideoPlayerInteractorInput
    private let presenter: VideoPlayerPresenterInput
    private let worker: VideoPlayerWorker

    init(
        playbackViewModel: PlaybackViewModel = PlaybackViewModel(),
        interactor: VideoPlayerInteractorInput,
        presenter: VideoPlayerPresenterInput,
        worker: VideoPlayerWorker
    ) {
        self.playbackViewModel = playbackViewModel
        self.debugViewModel = DebugInfoViewModel()
        self.interactor = interactor
        self.presenter = presenter
        self.worker = worker
    }

    // MARK: - Router Methods

    func didSelectStream(_ stream: VideoStream) {
        interactor.loadStream(stream)
    }

    func playStream() {
        interactor.play()
    }

    func pauseStream() {
        interactor.pause()
    }

    func retryLoadStream() {
        interactor.retry()
    }

    func updateDebugInfo() {
        let debugInfo = interactor.getDebugInfo()
        let resolution = debugInfo.resolution
        let bitrate = debugInfo.bitrate
        let bufferingCount = playbackViewModel.bufferingCount

        DispatchQueue.main.async {
            self.debugViewModel.resolution = resolution
            self.debugViewModel.bitrate = bitrate
            self.debugViewModel.bufferingCount = bufferingCount
        }
    }

    // MARK: - Presenter Output

    func displayPlaybackState(_ viewModel: PlaybackViewModel) {
        DispatchQueue.main.async {
            // Update existing ViewModel properties instead of replacing
            self.playbackViewModel.isLoading = viewModel.isLoading
            self.playbackViewModel.isPlaying = viewModel.isPlaying
            self.playbackViewModel.errorMessage = viewModel.errorMessage
            self.playbackViewModel.bufferingCount = viewModel.bufferingCount
            self.playbackViewModel.currentStream = viewModel.currentStream
        }
    }

    func displayDebugInfo(_ info: DebugInfoViewModel) {
        DispatchQueue.main.async {
            self.debugViewModel.resolution = info.resolution
            self.debugViewModel.bitrate = info.bitrate
            self.debugViewModel.bufferingCount = info.bufferingCount
        }
    }
}
