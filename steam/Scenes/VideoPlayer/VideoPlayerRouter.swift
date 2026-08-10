//
//  VideoPlayerRouter.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import Foundation
import AVFoundation

class VideoPlayerRouter {
    // MARK: - Module Creation

    struct Module {
        let viewController: VideoPlayerViewController
        let playbackViewModel: PlaybackViewModel
    }

    static func createModule(stream: VideoStream = .sample) -> Module {
        // Create Components
        let player = AVPlayer()
        let playbackViewModel = PlaybackViewModel(player: player)

        let presenter = VideoPlayerPresenter()

        let worker = VideoPlayerWorker()

        let interactor = VideoPlayerInteractor(player: player)

        // Wire up dependencies
        presenter.viewController = nil  // Will be set below
        interactor.presenter = presenter
        interactor.worker = worker

        // Create ViewController with strong references
        let viewController = VideoPlayerViewController(
            playbackViewModel: playbackViewModel,
            interactor: interactor,
            presenter: presenter,
            worker: worker
        )

        // Set presenter's viewController
        presenter.viewController = viewController

        // Load initial stream
        interactor.loadStream(stream)

        return Module(viewController: viewController, playbackViewModel: playbackViewModel)
    }
}
