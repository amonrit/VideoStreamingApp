//
//  ContentView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = VideoPlayerViewModel(stream: .sample)
    @State private var streams: [VideoStream] = VideoStream.sampleStreams
    @State private var isFullScreen = false
    @State private var showDebug = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                
                VideoPlayerView(viewModel: viewModel, isFullScreen: $isFullScreen)
                    .frame(height: 240)
                    .background(Color.black)
                
                HStack {
                    Spacer()
                    Button {
                        showDebug.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "ladybug.fill")
                            Text("Debug")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(showDebug ? Color.red.opacity(0.15) : Color.gray.opacity(0.15))
                        .foregroundColor(showDebug ? .red : .primary)
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                
                if showDebug {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.resolutionText)
                        Text(viewModel.bitrateText)
                        Text(viewModel.bufferingText)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Now Playing")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(viewModel.currentStream.title)
                        .font(.headline)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Divider()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(streams) { stream in
                            SuggestedVideoRow(
                                stream: stream,
                                isCurrent: stream.id == viewModel.currentStream.id
                            )
                            .onTapGesture {
                                select(stream: stream)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Video Player")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $isFullScreen) {
                FullScreenPlayerView(viewModel: viewModel, isPresented: $isFullScreen)
            }
        }
    }
    
    private func select(stream: VideoStream) {
        viewModel.currentStream = stream
        streams = reorderedStreams(selected: stream, from: streams)
    }
    
    private func reorderedStreams(selected: VideoStream, from list: [VideoStream]) -> [VideoStream] {
        var result = list
        result.removeAll { $0.id == selected.id }
        result.insert(selected, at: 0)
        return result
    }
}

private struct SuggestedVideoRow: View {
    
    let stream: VideoStream
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: stream.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color.gray.opacity(0.2)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "video.slash")
                            .foregroundColor(.gray)
                    }
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 120, height: 68)
            .clipped()
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.title)
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .lineLimit(2)
                
                if isCurrent {
                    Text("Now playing")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(isCurrent ? Color.blue.opacity(0.08) : Color.clear)
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
