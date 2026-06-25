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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                
                // Main video player
                VideoPlayerView(viewModel: viewModel)
                    .frame(height: 240)
                    .background(Color.black)
                
                // Now playing title
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
                
                // Suggested videos list
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
        }
    }
    
    // MARK: - Actions
    
    private func select(stream: VideoStream) {
        // เปลี่ยนวิดีโอหลัก
        viewModel.currentStream = stream
        
        // reset list: ย้ายวิดีโอที่เลือกมาอยู่บนสุด
        streams = reorderedStreams(selected: stream, from: streams)
    }
    
    private func reorderedStreams(selected: VideoStream, from list: [VideoStream]) -> [VideoStream] {
        var result = list
        // ลบตัวที่เลือกออกจาก list เดิม
        result.removeAll { $0.id == selected.id }
        // แทรกไว้ข้างหน้า
        result.insert(selected, at: 0)
        return result
    }
}

// MARK: - Suggested Video Row

private struct SuggestedVideoRow: View {
    
    let stream: VideoStream
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
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
            
            // Title
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
