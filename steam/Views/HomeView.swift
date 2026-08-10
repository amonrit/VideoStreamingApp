//
//  HomeView.swift
//  steam
//
//  Created by Amonrit on 10/8/2569 BE.
//

import SwiftUI

struct HomeView: View {
    @State private var selectedMenuOption: MenuOption?

    enum MenuOption: Hashable {
        case watchStreams
        case settings
        case about
        case help
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Steam")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.blue)

                    Text("Live Video Streaming")
                        .font(.system(.subheadline, design: .default))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

                Divider()

                // Menu List
                ScrollView {
                    VStack(spacing: 12) {
                        // Watch Streams
                        NavigationLink(
                            destination: VideoStreamListView(),
                            tag: MenuOption.watchStreams,
                            selection: $selectedMenuOption
                        ) {
                            MenuCardView(
                                title: "Watch Streams",
                                subtitle: "Browse and play live streams",
                                icon: "play.circle.fill",
                                iconColor: .blue
                            )
                        }

                        // Settings
                        NavigationLink(
                            destination: SettingsView(),
                            tag: MenuOption.settings,
                            selection: $selectedMenuOption
                        ) {
                            MenuCardView(
                                title: "Settings",
                                subtitle: "Configure your preferences",
                                icon: "gearshape.fill",
                                iconColor: .gray
                            )
                        }

                        // About (Mock)
                        MenuCardView(
                            title: "About",
                            subtitle: "Learn about Steam",
                            icon: "info.circle.fill",
                            iconColor: .orange
                        )
                        .opacity(0.5)

                        // Help (Mock)
                        MenuCardView(
                            title: "Help",
                            subtitle: "Get support and documentation",
                            icon: "questionmark.circle.fill",
                            iconColor: .green
                        )
                        .opacity(0.5)
                    }
                    .padding(16)
                }

                Spacer()

                // Footer
                VStack(spacing: 8) {
                    Divider()

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)

                        Text("MediaMTX Server Connected")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Text("Version 1.0.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 12)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Menu Card View
struct MenuCardView: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
                .background(iconColor.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .default))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(.caption, design: .default))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
}
