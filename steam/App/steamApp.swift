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
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $coordinator.navigationPath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.navigationView(for: route)
                    }
            }
            .environmentObject(coordinator)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
        }
    }
}
