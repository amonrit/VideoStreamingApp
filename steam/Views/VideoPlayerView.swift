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
            // Main video player
            VideoPlayer(player: viewModel.player)
                .background(Color.black)
                .clipped()
            
            // Loading overlay
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
            
            // Error overlay
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
        }
    }
}

#Preview {
    VideoPlayerView(viewModel: VideoPlayerViewModel(stream: .sample))
}
