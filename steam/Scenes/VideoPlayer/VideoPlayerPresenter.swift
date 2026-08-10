//
//  VideoPlayerPresenter.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation

protocol VideoPlayerPresenterInput {
    func presentPlaybackState(_ state: PlaybackState)
    func presentDebugInfo(resolution: String, bitrate: String, buffering: Int)
}

protocol VideoPlayerPresenterOutput: AnyObject {
    func displayPlaybackState(_ viewModel: PlaybackViewModel)
    func displayDebugInfo(_ info: DebugInfoViewModel)
}

class VideoPlayerPresenter: VideoPlayerPresenterInput {
    weak var viewController: VideoPlayerPresenterOutput?

    func presentPlaybackState(_ state: PlaybackState) {
        let viewModel = PlaybackViewModel()
        viewModel.isLoading = state.isLoading
        viewModel.isPlaying = state.isPlaying
        viewModel.errorMessage = state.errorMessage
        viewModel.bufferingCount = state.bufferingCount
        viewModel.currentStream = state.currentStream

        DispatchQueue.main.async { [weak self] in
            self?.viewController?.displayPlaybackState(viewModel)
        }
    }

    func presentDebugInfo(resolution: String, bitrate: String, buffering: Int) {
        let debugViewModel = DebugInfoViewModel()
        debugViewModel.resolution = resolution
        debugViewModel.bitrate = bitrate
        debugViewModel.bufferingCount = buffering

        DispatchQueue.main.async { [weak self] in
            self?.viewController?.displayDebugInfo(debugViewModel)
        }
    }
}
