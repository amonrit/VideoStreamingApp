//
//  ContentView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = VideoPlayerViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Video Player
            VideoPlayerView(viewModel: viewModel)
                .frame(height: 250)
            
            // Error Display (fallback if not shown in player)
            if let error = viewModel.errorMessage, error.contains("Invalid URL") {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(3)
                    
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .border(Color.red.opacity(0.3), width: 1)
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Controls
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.play()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(viewModel.errorMessage != nil ? Color.gray.opacity(0.5) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .font(.subheadline.bold())
                }
                .disabled(viewModel.errorMessage != nil)
                
                Button(action: {
                    viewModel.pause()
                }) {
                    HStack {
                        Image(systemName: "pause.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .font(.subheadline.bold())
                }
            }
            .padding(.horizontal)
            
            // Status Info
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Buffering...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
