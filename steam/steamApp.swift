//
//  steamApp.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

@main
struct steamApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.currentTheme.colorScheme)
        }
    }
}
