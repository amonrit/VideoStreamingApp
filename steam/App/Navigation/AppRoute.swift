//
//  AppRoute.swift
//  steam
//

import Foundation

/// All navigation destinations reachable from the app's root `NavigationStack`.
///
/// `AppCoordinator` owns the `navigationPath` built from these routes and maps
/// each case to its destination view via `navigationView(for:)`.
enum AppRoute: Hashable {
    case watchStreams
    case streamAdmin
    case settings
}
