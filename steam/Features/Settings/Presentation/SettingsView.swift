//
//  SettingsView.swift
//  steam
//
//  Created by Amonrit on 10/8/2569 BE.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))

                Spacer()

                // Invisible spacer for centering
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .foregroundColor(.clear)
                .hidden()
            }
            .padding(16)

            Divider()

            // Settings Content
            ScrollView {
                VStack(spacing: 20) {
                    // Theme Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Appearance")
                            .font(.system(.headline, design: .default))
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Theme")
                                .font(.system(.subheadline, design: .default))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            HStack(spacing: 12) {
                                Image(systemName: themeIcon(for: themeManager.currentTheme))
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                    .frame(width: 30)

                                Picker("Theme", selection: Binding(
                                    get: { themeManager.currentTheme },
                                    set: { themeManager.setTheme($0) }
                                )) {
                                    ForEach(AppTheme.allCases, id: \.self) { theme in
                                        Text(theme.displayName)
                                            .tag(theme)
                                    }
                                }
                                .pickerStyle(.menu)

                                Spacer()
                            }
                            .padding(16)
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    func themeIcon(for theme: AppTheme) -> String {
        switch theme {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .auto:
            return "circle.half.filled"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
}
