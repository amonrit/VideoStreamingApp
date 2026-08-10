//
//  VideoPlayerView.swift
//  steam
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @Binding var isFullScreen: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VideoPlayer(player: viewModel.player)
                .background(Color.black)
                .clipped()

            // Loading Overlay
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading...")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
            }

            // Error Overlay
            if let error = viewModel.errorMessage {
                ZStack {
                    Color.black.opacity(0.6)
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.white)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            viewModel.retry()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }

            // Fullscreen Button
            Button {
                isFullScreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(8)
            }
        }
    }
}

#Preview {
    let module = VideoPlayerRouter.createModule(stream: .sample)
    VideoPlayerView(
        viewModel: module.playbackViewModel,
        isFullScreen: .constant(false)
    )
}
