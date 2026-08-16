//
//  ThemeManager.swift
//  steam
//
//  Created by Amonrit on 10/8/2569 BE.
//

import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case light
    case dark
    case auto

    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .auto:
            return "Auto"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            return nil
        }
    }
}

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.auto.rawValue
        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .auto
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
    }

    func cycleTheme() {
        let themes: [AppTheme] = [.light, .dark, .auto]
        if let currentIndex = themes.firstIndex(of: currentTheme) {
            let nextIndex = (currentIndex + 1) % themes.count
            setTheme(themes[nextIndex])
        }
    }
}
