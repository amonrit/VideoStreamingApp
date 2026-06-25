//
//  VideoPlayerView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        VideoPlayer(player: viewModel.player)
            .ignoresSafeArea()
    }
}

#Preview {
    VideoPlayerView(viewModel: VideoPlayerViewModel())
}
