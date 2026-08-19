//
//  VideoPlayerView.swift
//  steam
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    @Binding var isFullScreen: Bool
    @State private var currentTime: Double = 0.0
    @State private var previousVolume: Double = 1.0

    // showControls, showVolumeSlider, volume, playbackRate now come from ViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Video Player - iOS 16+ native VideoPlayer
            VideoPlayer(player: viewModel.player)
                .background(Color.black)
                .clipped()
                .onTapGesture {
                    withAnimation {
                        viewModel.showControls.toggle()
                    }
                    viewModel.resetControlsVisibilityTimer()
                }
                .task(id: viewModel.currentStream?.id) {
                    // Replaces the old Combine `Timer.publish(...).autoconnect()` —
                    // `.task` cancels automatically when the view disappears or
                    // `id` changes, so there's no timer to tear down manually.
                    while !Task.isCancelled {
                        currentTime = viewModel.player.currentTime().seconds
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }

            // Custom Controls (show/hide on tap)
            if viewModel.showControls {
                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        if !isFullScreen {
                            Button {
                                isFullScreen = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .padding(8)
                        }
                        Spacer()
                    }
                    .background(Color.black.opacity(0.3))

                    Spacer()

                    // Bottom Controls Bar
                    VStack(spacing: 8) {
                        // Progress Bar
                        ProgressBarView(viewModel: viewModel, currentTime: currentTime)

                        // Control Buttons
                        HStack(spacing: 12) {
                            Button {
                                viewModel.player.rate == 0 ? viewModel.play() : viewModel.pause()
                            } label: {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }

                            Button {
                                viewModel.seekBackward(10)
                            } label: {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }

                            Button {
                                viewModel.seekForward(10)
                            } label: {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            Text(viewModel.formatTime(currentTime))
                                .font(.caption)
                                .foregroundColor(.white)

                            Text("/")
                                .foregroundColor(.white.opacity(0.7))

                            Text(viewModel.formatTime(viewModel.currentDuration))
                                .font(.caption)
                                .foregroundColor(.white)

                            // Speed Button
                            Menu {
                                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                                    Button {
                                        viewModel.playbackRate = Float(speed)
                                    } label: {
                                        HStack {
                                            Text("\(speed, specifier: "%.2f")x")
                                            if abs(viewModel.playbackRate - Float(speed)) < 0.01 {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: "speedometer")
                                        .font(.system(size: 16))
                                    Text("\(viewModel.playbackRate, specifier: "%.2f")x")
                                        .font(.caption2)
                                }
                                .foregroundColor(.white)
                                .frame(width: 36)
                            }

                            // Volume Button
                            Button {
                                withAnimation {
                                    viewModel.showVolumeSlider.toggle()
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: viewModel.volume > 0.5 ? "speaker.wave.2" : (viewModel.volume > 0 ? "speaker.wave.1" : "speaker.slash"))
                                        .font(.system(size: 16))
                                    Text("\(Int(viewModel.volume * 100))%")
                                        .font(.caption2)
                                }
                                .foregroundColor(.white)
                                .frame(width: 36)
                            }
                            .overlay(alignment: .topTrailing) {
                                // Volume Slider (ลอยทับ - ไม่ดันอย่างอื่น)
                                if viewModel.showVolumeSlider {
                                    VStack(spacing: 4) {
                                        // High Volume
                                        Image(systemName: "speaker.wave.2")
                                            .font(.system(size: 10))
                                            .foregroundColor(.red)

                                        Slider(value: $viewModel.volume, in: 0...1, step: 0.05)
                                            .onChange(of: viewModel.volume) {
                                                if viewModel.volume > 0 {
                                                    previousVolume = viewModel.volume
                                                }
                                            }
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 70, height: 25)
                                            .accentColor(.red)

                                        // Low Volume
                                        Image(systemName: "speaker.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(8)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(10)
                                    .offset(x: 50, y: -80)
                                    .transition(.opacity.combined(with: .scale))
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color.black.opacity(0.6))
                }
            }

            // Loading Overlay (ไม่ block interaction)
            if viewModel.isLoading && viewModel.errorMessage == nil {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        VStack(spacing: 6) {
                            Text("Connecting...")
                                .foregroundColor(.white)
                                .font(.headline)
                            Text(viewModel.currentStream?.title ?? "Loading stream")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)

                            // Show retry attempt if needed
                            if viewModel.retryAttempt > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Retry \(viewModel.retryAttempt)/2")
                                        .foregroundColor(.orange)
                                        .font(.caption2)
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                }
                .allowsHitTesting(false)  // ✅ ปุ่มทำงานได้ตามปกติ
            }

            // Connection Status Indicator + Viewer Count
            if !viewModel.isLoading && !isFullScreen {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.statusIndicatorColor)
                            .frame(width: 8, height: 8)
                        Text(viewModel.statusIndicatorText)
                            .font(.caption2)
                            .foregroundColor(viewModel.statusIndicatorColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)

                    // Viewer Count Badge
                    if let count = viewModel.viewerCount {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                            Text("\(count)")
                        }
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(6)
                    }

                    Spacer()
                }
                .padding(8)
                .allowsHitTesting(false)
            }

            // Error Overlay with Retry
            if let error = viewModel.errorMessage {
                ZStack {
                    Color.black.opacity(0.8)
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)

                            Text("Connection Failed")
                                .foregroundColor(.white)
                                .font(.headline)

                            Text(error)
                                .foregroundColor(.white.opacity(0.8))
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .lineLimit(4)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 10) {
                            Button {
                                viewModel.retry()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry Connection")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .font(.subheadline.bold())
                            }

                            Button {
                                isFullScreen = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark")
                                    Text("Close")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Progress Bar Component
struct ProgressBarView: View {
    @ObservedObject var viewModel: PlaybackViewModel
    let currentTime: Double
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.3))

                    // Buffered Progress
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: geometry.size.width * bufferedProgress)

                    // Current Progress
                    Capsule()
                        .fill(Color.red)
                        .frame(width: geometry.size.width * currentProgress)

                    // Draggable Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16)
                        .offset(x: geometry.size.width * currentProgress - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDragging = true
                                    let newProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                                    dragValue = newProgress
                                    seek(to: newProgress)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
                .contentShape(Capsule())
                .onTapGesture { value in
                    let newProgress = value.x / geometry.size.width
                    seek(to: newProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var currentProgress: Double {
        let duration = viewModel.currentDuration
        return duration > 0 ? currentTime / duration : 0
    }

    private var bufferedProgress: Double {
        viewModel.bufferedProgress
    }

    private func seek(to progress: Double) {
        viewModel.seek(toProgress: progress)
    }
}

#Preview {
    let viewModel = PlaybackViewModel()
    VideoPlayerView(
        viewModel: viewModel,
        isFullScreen: .constant(false)
    )
}
