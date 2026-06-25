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
        ZStack {
            // Video Player
            VideoPlayer(player: viewModel.player)
                .ignoresSafeArea()
            
            // Loading Indicator
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5, anchor: .center)
                    
                    Text("Loading...")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
            }
            
            // Error Message
            if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Text(error)
                            .foregroundColor(.white)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    
                    // Show Retry button only for specific errors
                    if error.contains("Failed") || error.contains("Playback error") {
                        Button(action: {
                            viewModel.retry()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
            }
        }
    }
}

#Preview {
    VideoPlayerView(viewModel: VideoPlayerViewModel())
}
