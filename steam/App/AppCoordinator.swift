import SwiftUI
import Combine

/// Manages app-level navigation and coordination
class AppCoordinator: ObservableObject {
    @Published var isLoggedIn = false

    /// Initialize coordinator with DI container
    init() {
        // TODO: Initialize with dependencies from DIContainer
    }
}
