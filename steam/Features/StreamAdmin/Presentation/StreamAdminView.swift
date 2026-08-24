//
//  StreamAdminView.swift
//  steam
//

import SwiftUI

struct StreamAdminView: View {
    var viewModel: StreamAdminViewModel
    @State private var showServerConfig = false
    @State private var serverURL = "http://localhost:9997"

    init(viewModel: StreamAdminViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stream Admin")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)

                    Text("Live stream monitoring and statistics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

                Divider()

                // Content
                if viewModel.paths.isEmpty && !viewModel.isLoading {
                    if let error = viewModel.errorMessage {
                        // Error state
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)

                            Text("Connection Failed")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button {
                                viewModel.startPolling()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    } else {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("No Active Streams")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Start a stream to see it here")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button {
                                showServerConfig = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gear")
                                    Text("Configure Server")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                } else {
                    // Streams table
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.paths, id: \.name) { path in
                                StreamRowView(path: path)
                            }
                        }
                        .padding()
                    }
                }

                Spacer()

                // Footer
                if let lastUpdated = viewModel.lastUpdated {
                    VStack(spacing: 8) {
                        Divider()

                        HStack(spacing: 8) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Last updated: \(timeAgoString(lastUpdated))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .onAppear {
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .sheet(isPresented: $showServerConfig) {
                ServerConfigSheet(isPresented: $showServerConfig, serverURL: $serverURL) {
                    if let url = URL(string: serverURL) {
                        viewModel.startPolling(baseURL: url)
                    }
                }
            }
    }

    private func timeAgoString(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Stream Row

struct StreamRowView: View {
    let path: MediaMTXPath

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stream name + status
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(path.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(path.status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Viewer count badge
                if path.viewerCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                        Text("\(path.viewerCount)")
                    }
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
            }

            Divider()

            // Viewers by protocol
            if !path.readersByType.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Viewers by Protocol")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(Array(path.readersByType.sorted { $0.key < $1.key }), id: \.key) { type, count in
                            ProtocolBadgeView(type: type, count: count)
                        }
                        Spacer()
                    }
                }
            }

            Divider()

            // Data counters
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inbound")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatBytes(path.inboundBytes ?? 0))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Outbound")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatBytes(path.outboundBytes ?? 0))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Protocol Badge

struct ProtocolBadgeView: View {
    let type: String
    let count: Int

    var badgeColor: Color {
        switch type {
        case "hlsSession":
            return .orange
        case "rtmpConn", "rtmpsConn":
            return .red
        case "rtspConn", "rtspSession", "rtspsConn", "rtspsSession":
            return .green
        case "webRTCSession":
            return .purple
        case "srtConn":
            return .blue
        case "moqSession":
            return .pink
        default:
            return .gray
        }
    }

    var protocolName: String {
        switch type {
        case "hlsSession":
            return "HLS"
        case "rtmpConn", "rtmpsConn":
            return "RTMP"
        case "rtspConn", "rtspSession", "rtspsConn", "rtspsSession":
            return "RTSP"
        case "webRTCSession":
            return "WebRTC"
        case "srtConn":
            return "SRT"
        case "moqSession":
            return "MoQ"
        default:
            return type.prefix(4).uppercased()
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(protocolName)
            Text("\(count)")
                .fontWeight(.semibold)
        }
        .font(.caption2)
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor)
        .cornerRadius(4)
    }
}

// MARK: - Server Config Sheet

struct ServerConfigSheet: View {
    @Binding var isPresented: Bool
    @Binding var serverURL: String
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("MediaMTX Server") {
                    TextField("Server URL", text: $serverURL)
                        .textContentType(.URL)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif

                    Text("e.g., http://192.168.1.50:9997")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Save & Connect") {
                        onSave()
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Configure Server")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            #endif
        }
    }
}

#Preview {
    StreamAdminView(viewModel: StreamAdminViewModel())
}
