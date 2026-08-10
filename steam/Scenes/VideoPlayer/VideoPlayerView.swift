//
//  VideoPlayerView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @ObservedObject var viewController: VideoPlayerViewController
    @Binding var isFullScreen: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VideoPlayer(player: viewController.playbackViewModel.player)
                .background(Color.black)
                .clipped()

            // Loading Overlay
            if viewController.playbackViewModel.isLoading {
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
            if let error = viewController.playbackViewModel.errorMessage {
                ZStack {
                    Color.black.opacity(0.6)
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.white)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            viewController.retryLoadStream()
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
    let viewController = VideoPlayerRouter.createModule(stream: .sample)
    return VideoPlayerView(
        viewController: viewController,
        isFullScreen: .constant(false)
    )
}
