//
//  ContentView.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var playbackViewModel = PlaybackViewModel()
    @State private var streams: [VideoStream] = VideoStream.sampleStreams
    @State private var isFullScreen = false
    @State private var showDebug = false
    @State private var didLoadInitial = false
    @State private var showAddStream = false
    @State private var customURL = ""
    @State private var customTitle = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VideoPlayerView(viewModel: playbackViewModel, isFullScreen: $isFullScreen)
                    .frame(height: 240)
                    .background(Color.black)
                    .onAppear {
                        if !didLoadInitial {
                            playbackViewModel.loadStream(.sample)
                            didLoadInitial = true
                        }
                    }

                // Control Buttons Bar
                HStack(spacing: 12) {
                    // Add Stream Button
                    Button(action: { showAddStream = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add Stream")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.semibold)
                        }
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.green)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }

                    Spacer()

                    // Debug Button
                    Button(action: { showDebug.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "ladybug.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Debug")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.semibold)
                        }
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    showDebug ? Color.red.opacity(0.2) : Color.gray.opacity(0.1),
                                    showDebug ? Color.red.opacity(0.1) : Color.gray.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(showDebug ? .red : .secondary)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(showDebug ? Color.red.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

                if showDebug {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .foregroundColor(.blue)
                            Text("Resolution")
                                .font(.caption.bold())
                            Spacer()
                            Text(playbackViewModel.resolutionText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: "speedometer")
                                .foregroundColor(.orange)
                            Text("Bitrate")
                                .font(.caption.bold())
                            Spacer()
                            Text(playbackViewModel.bitrateText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: "hourglass")
                                .foregroundColor(.red)
                            Text("Buffering Events")
                                .font(.caption.bold())
                            Spacer()
                            Text("\(playbackViewModel.bufferingCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))

                        Text("Now Playing")
                            .font(.system(.caption, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    Text(playbackViewModel.currentStream?.title ?? "Select a stream")
                        .font(.system(.headline, design: .default))
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(streams) { stream in
                            SuggestedVideoRow(
                                stream: stream,
                                isCurrent: stream.id == playbackViewModel.currentStream?.id
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    select(stream: stream)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Video Player")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $isFullScreen) {
                FullScreenPlayerView(viewModel: playbackViewModel, isPresented: $isFullScreen)
            }
            .sheet(isPresented: $showAddStream) {
                AddStreamSheet(
                    isPresented: $showAddStream,
                    customTitle: $customTitle,
                    customURL: $customURL,
                    onAdd: { title, url in
                        addCustomStream(title: title, url: url)
                    }
                )
            }
#endif
        }
    }

    private func select(stream: VideoStream) {
        playbackViewModel.loadStream(stream)
    }

    private func addCustomStream(title: String, url: String) {
        let newStream = VideoStream(
            title: title.isEmpty ? "Custom Stream" : title,
            urlString: url,
            thumbnailURLString: "https://via.placeholder.com/120x68/333/666?text=Live"
        )
        streams.insert(newStream, at: 0)
        select(stream: newStream)
        showAddStream = false
        customTitle = ""
        customURL = ""
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

// MARK: - Add Stream Sheet
struct AddStreamSheet: View {
    @Binding var isPresented: Bool
    @Binding var customTitle: String
    @Binding var customURL: String
    var onAdd: (String, String) -> Void

    var isValidURL: Bool {
        guard !customURL.isEmpty else { return false }
        return customURL.starts(with: "http://") || customURL.starts(with: "https://") || customURL.starts(with: "rtmp://")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Icon
                    VStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)

                        Text("Add Live Stream")
                            .font(.system(.title2, design: .default))
                            .fontWeight(.bold)

                        Text("Connect to your MediaMTX streaming server")
                            .font(.system(.caption, design: .default))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                    // Input Fields
                    VStack(spacing: 16) {
                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Stream Title", systemImage: "text.bubble")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            TextField("e.g., My Live Stream", text: $customTitle)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal, 4)
                        }

                        // URL Input
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Stream URL", systemImage: "link")
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            TextField("http://...", text: $customURL)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Example URLs Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Example URLs", systemImage: "info.circle")
                            .font(.system(.headline, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 12) {
                            // Local Example
                            VStack(alignment: .leading, spacing: 6) {
                                Text("🖥️ Local Machine")
                                    .font(.system(.subheadline, design: .default))
                                    .fontWeight(.semibold)
                                Text("http://localhost:8888/live/{streamname}/index.m3u8")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(10)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)

                            // Network Example
                            VStack(alignment: .leading, spacing: 6) {
                                Text("📱 Network Device")
                                    .font(.system(.subheadline, design: .default))
                                    .fontWeight(.semibold)
                                Text("http://10.117.6.98:8888/live/{streamname}/index.m3u8")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(10)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)

                            // Replace Note
                            HStack(spacing: 8) {
                                Image(systemName: "pencil.tip")
                                    .font(.system(.caption, design: .default))
                                    .foregroundColor(.orange)
                                Text("Replace {streamname} with your stream name")
                                    .font(.system(.caption2, design: .default))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            isPresented = false
                            customTitle = ""
                            customURL = ""
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .font(.system(.subheadline, design: .default))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }

                        Button(action: {
                            onAdd(customTitle, customURL)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Stream")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .font(.system(.subheadline, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .background(isValidURL ? Color.blue : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(!isValidURL)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


#Preview {
    ContentView()
}
