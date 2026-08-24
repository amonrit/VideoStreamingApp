//
//  steamApp.swift
//  steam
//
//  Created by Amonrit on 25/6/2569 BE.
//

import SwiftUI

@main
struct steamApp: App {
    @State private var themeManager = ThemeManager()
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $coordinator.navigationPath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        coordinator.navigationView(for: route)
                    }
            }
            .environment(coordinator)
            .environment(themeManager)
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
        }
    }
}
