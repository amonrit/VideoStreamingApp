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
        self.interactor = interactor
        self.presenter = presenter
        self.worker = worker
    }

    // MARK: - Router Methods

    func didSelectStream(_ stream: VideoStream) {
        playbackViewModel.loadStream(stream)
    }

    func playStream() {
        playbackViewModel.play()
    }

    func pauseStream() {
        playbackViewModel.pause()
    }

    func retryLoadStream() {
        playbackViewModel.retry()
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
        // No-op now that debug info is computed from PlaybackViewModel
    }
}
